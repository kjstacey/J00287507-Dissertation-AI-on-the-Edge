"""Compare two existing EMNIST Balanced CNN checkpoints under fake quantization.

This is NOT integer FPGA inference: calculations and biases remain floating-point;
weights and ReLU activation outputs are rounded/clamped to 8- or 12-bit grids.
Use the VALIDATION data to choose a model/precision; optional official test is
for a locked final configuration only, NOT for iterative model selection.
"""
from __future__ import annotations
import argparse
import csv
import gzip
import json
import struct
from copy import deepcopy
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F


class ImprovedCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(1,32,3,padding=1),nn.ReLU(),
            nn.Conv2d(32,32,3,padding=1),nn.ReLU(),nn.MaxPool2d(2),
            nn.Conv2d(32,64,3,padding=1),nn.ReLU(),
            nn.Conv2d(64,64,3,padding=1),nn.ReLU(),nn.MaxPool2d(2))
        self.classifier = nn.Sequential(nn.Flatten(),nn.Linear(64*7*7,128),nn.ReLU(),nn.Dropout(0.4),nn.Linear(128,47))
    def forward(self,x): return self.classifier(self.features(x))

class CompactCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(1,16,3,padding=1),nn.ReLU(),nn.MaxPool2d(2),
            nn.Conv2d(16,32,3,padding=1),nn.ReLU(),nn.MaxPool2d(2),
            nn.Conv2d(32,64,3,padding=1),nn.ReLU())
        self.pool = nn.AdaptiveAvgPool2d(1)
        self.classifier = nn.Linear(64,47)
    def forward(self,x): return self.classifier(torch.flatten(self.pool(self.features(x)),1))


def load_idx(path, images):
    with gzip.open(path, 'rb') as f:
        if images:
            magic,n,r,c = struct.unpack('>IIII',f.read(16))
            if (magic,r,c)!=(2051,28,28): raise ValueError(f'Invalid image header: {path}')
            a=np.frombuffer(f.read(),dtype=np.uint8)
            if a.size!=n*784: raise ValueError('image count mismatch')
            return a.reshape(n,28,28).transpose(0,2,1).copy()
        magic,n=struct.unpack('>II',f.read(8))
        if magic!=2049: raise ValueError(f'Invalid label header: {path}')
        a=np.frombuffer(f.read(),dtype=np.uint8).copy()
        if a.size!=n: raise ValueError('label count mismatch')
        return a


def make_val_indices(labels, seed=2026):
    rng=np.random.default_rng(seed)
    val=[]
    for cls in range(47):
        idx=np.where(labels==cls)[0].copy()
        rng.shuffle(idx)
        val.append(idx[:240])
    idx=np.concatenate(val)
    rng.shuffle(idx)
    return idx


def load_ckpt(path, kind):
    ckpt=torch.load(path,map_location='cpu',weights_only=True)
    if ckpt.get('seed')!=2026: raise ValueError(f'{path}: expected seed 2026')
    m=ImprovedCNN() if kind=='improved' else CompactCNN()
    m.load_state_dict(ckpt['model_state_dict'],strict=True)
    m.eval()
    return m,ckpt


def signed_fake_quant(x, bits):
    q=(1<<(bits-1))-1
    maxval=x.detach().abs().max().item()
    if maxval==0: return x.clone()
    scale=maxval/q
    return torch.round(x/scale).clamp(-q,q)*scale


def unsigned_fake_quant(x, bits, peak):
    q=(1<<bits)-1
    if peak<=0: return torch.zeros_like(x)
    scale=peak/q
    return torch.round(x/scale).clamp(0,q)*scale


@torch.no_grad()
def predict(model,images,batch_size):
    out=[]
    for start in range(0,len(images),batch_size):
        arr=np.asarray(images[start:start+batch_size],dtype=np.float32)/255.0
        x=torch.from_numpy(arr[:,None].copy())
        out.append(model(x).argmax(1).numpy())
    return np.concatenate(out)


def activation_calibration(model, images, batch_size):
    # Calibration set must be a subset of the validation split, NEVER the test set.
    maxima={}
    hooks=[]
    for name,module in model.named_modules():
        if isinstance(module,nn.ReLU):
            def record(mod,inp,out,key=name):
                maxima[key]=max(maxima.get(key,0),float(out.detach().max().item()))
            hooks.append(module.register_forward_hook(record))
    try: predict(model,images,batch_size)
    finally:
        for hook in hooks: hook.remove()
    return maxima


def fake_quant_model(model,bits,activation_maxima):
    # Weight-only round-trip followed by ReLU output quantization.
    # Biases and accumulation stay fp32; this is *not* bit-exact fixed point.
    quant=deepcopy(model)
    with torch.no_grad():
        for module in quant.modules():
            if isinstance(module,(nn.Conv2d,nn.Linear)):
                module.weight.copy_(signed_fake_quant(module.weight,bits))
    hooks=[]
    for name,module in quant.named_modules():
        if isinstance(module,nn.ReLU):
            peak=activation_maxima[name]
            hooks.append(module.register_forward_hook(
                lambda mod,inp,out,peak=peak: unsigned_fake_quant(out,bits,peak)))
    # Preserve hook handles for entire prediction evaluation.
    return quant,hooks


def count_ops(model):
    ops=0
    for m in model.modules():
        if isinstance(m,nn.Conv2d):
            # Output size tracked using dummy input below instead of guessing.
            pass
    hooks=[]
    def fn(mod,inp,out):
        nonlocal ops
        if isinstance(mod,nn.Conv2d):
            ops+=out.numel()*(mod.in_channels//mod.groups)*mod.kernel_size[0]*mod.kernel_size[1]
        elif isinstance(mod,nn.Linear): ops+=out.numel()*mod.in_features
    for m in model.modules():
        if isinstance(m,(nn.Conv2d,nn.Linear)):hooks.append(m.register_forward_hook(fn))
    with torch.no_grad():model(torch.zeros(1,1,28,28))
    for h in hooks:h.remove()
    return ops


def activation_sizes(model):
    feats={}
    hs=[]
    for name,mod in model.named_modules():
        if isinstance(mod,(nn.Conv2d,nn.MaxPool2d,nn.AdaptiveAvgPool2d,nn.Linear)):
            hs.append(mod.register_forward_hook(lambda mm,xx,yy,key=name: feats.__setitem__(key,int(yy.numel()))))
    with torch.no_grad():model(torch.zeros(1,1,28,28))
    for h in hs:h.remove()
    return feats


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--data-dir',type=Path,default=Path('.'))
    ap.add_argument('--improved',type=Path,default=Path('emnist_cnn_improved_output/best_cnn_checkpoint.pt'))
    ap.add_argument('--compact',type=Path,default=Path('emnist_compact_cnn_output/best_cnn_checkpoint.pt'))
    ap.add_argument('--output-dir',type=Path,default=Path('emnist_quantization_comparison'))
    ap.add_argument('--batch-size',type=int,default=128)
    ap.add_argument('--calibration-count',type=int,default=512)
    ap.add_argument('--limit',type=int,default=0,help='Validation subset for quick test; default 0 uses all 11280')
    ap.add_argument('--official-test',action='store_true',help='Optional: evaluate locked models on official test (not recommended for tuning)')
    args=ap.parse_args()
    torch.set_num_threads(min(4,torch.get_num_threads()))
    tr_images=load_idx(args.data_dir/'emnist-balanced-train-images-idx3-ubyte.gz',True)
    tr_labels=load_idx(args.data_dir/'emnist-balanced-train-labels-idx1-ubyte.gz',False)
    if len(tr_labels)!=112800 or not np.array_equal(np.bincount(tr_labels,minlength=47),np.full(47,2400)):
        raise ValueError('Unexpected EMNIST Balanced training dataset')
    idx=make_val_indices(tr_labels)
    val_images=tr_images[idx]
    val_labels=tr_labels[idx]
    if args.limit:val_images,val_labels=val_images[:args.limit],val_labels[:args.limit]
    test_images=test_labels=None
    if args.official_test:
        test_images=load_idx(args.data_dir/'emnist-balanced-test-images-idx3-ubyte.gz',True)
        test_labels=load_idx(args.data_dir/'emnist-balanced-test-labels-idx1-ubyte.gz',False)
    args.output_dir.mkdir(parents=True,exist_ok=True)
    rows=[]
    details={'limitations':('Per-tensor symmetric quantization of weights and unsigned quantization of ReLU outputs. '
               'Activations calibrated from validation images; floating-point accumulation and biases; '
               'no integer datapath, clipping study, measured FPGA power, timing, or hardware area.'),
             'input_preprocessing':'transpose raw IDX once; divide by 255.0',
             'calibration_source':'first N images from seeded validation split',
             'validation_count':len(val_images), 'results':{}}
    for name,path,kind in [('improved',args.improved,'improved'),('compact',args.compact,'compact')]:
        print(f'Loading {name}: {path}',flush=True)
        base,meta=load_ckpt(path,kind)
        calibration=activation_calibration(base,val_images[:args.calibration_count],args.batch_size)
        base_pred=predict(base,val_images,args.batch_size)
        nparam=sum(p.numel() for p in base.parameters())
        ops=count_ops(base)
        sizes=activation_sizes(base)
        detail={'checkpoint':str(path),'epoch':meta.get('epoch'),'parameters':nparam,
                'macs_per_image':ops,'activation_elements_by_layer':sizes,
                'largest_single_activation_elements':max(sizes.values()),
                'activation_calibration_maxima':calibration}
        for bits in (32,8,12):
            if bits==32: model=base;hs=[];pred=base_pred
            else:
                model,hs=fake_quant_model(base,bits,calibration)
                try:pred=predict(model,val_images,args.batch_size)
                finally:
                    for h in hs:h.remove()
            row={'model':name,'precision_bits':bits,'validation_correct':int((pred==val_labels).sum()),
                 'validation_count':len(val_labels), 'validation_accuracy':round(float(np.mean(pred==val_labels)),8),
                 'agreement_with_fp32':round(float(np.mean(pred==base_pred)),8),
                 'parameters':nparam,'theoretical_packed_weight_and_bias_bytes':nparam*bits//8 if bits==32 or bits==8 else (nparam*bits+7)//8,
                 'macs_per_image':ops}
            if args.official_test:
                if bits==32:test_pred=predict(base,test_images,args.batch_size)
                else:
                    model,hs=fake_quant_model(base,bits,calibration)
                    try:test_pred=predict(model,test_images,args.batch_size)
                    finally:
                        for h in hs:h.remove()
                row['official_test_accuracy']=round(float(np.mean(test_pred==test_labels)),8)
            rows.append(row)
            print(f'{name} {bits}-bit: validation {row["validation_accuracy"]:.2%}; agreement {row["agreement_with_fp32"]:.2%}',flush=True)
        details['results'][name]=detail
    with (args.output_dir/'comparison.csv').open('w',newline='',encoding='utf-8') as f:
        wr=csv.DictWriter(f,fieldnames=rows[0].keys());wr.writeheader();wr.writerows(rows)
    (args.output_dir/'technical_details.json').write_text(json.dumps(details,indent=2),encoding='utf-8')
    print('Saved:',args.output_dir.resolve())

if __name__=='__main__':main()
