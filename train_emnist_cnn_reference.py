"""EMNIST Balanced CNN software accuracy reference (NOT ZyNet-ready).

Run on Windows:
    python3 -m pip install numpy torch
    python3 train_emnist_cnn_reference.py --epochs 30
    python3 train_emnist_cnn_reference.py --smoke-test

The official test set is evaluated once after selecting the best checkpoint
by validation accuracy. Data orientation is corrected by transpose.
"""
from __future__ import annotations
import argparse
import gzip
import json
import random
import struct
from pathlib import Path
import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader, TensorDataset

FILES = {
    "train_images": "emnist-balanced-train-images-idx3-ubyte.gz",
    "train_labels": "emnist-balanced-train-labels-idx1-ubyte.gz",
    "test_images": "emnist-balanced-test-images-idx3-ubyte.gz",
    "test_labels": "emnist-balanced-test-labels-idx1-ubyte.gz",
}

def load_idx(path: Path, images: bool) -> np.ndarray:
    with gzip.open(path, 'rb') as f:
        header = f.read(16 if images else 8)
        nums = struct.unpack('>IIII' if images else '>II', header)
        if images:
            magic, n, rows, cols = nums
            if magic != 2051 or (rows, cols) != (28, 28):
                raise ValueError(f'Unexpected IDX image header in {path}: {nums}')
            data = np.frombuffer(f.read(), dtype=np.uint8)
            if data.size != n * 28 * 28:
                raise ValueError(f'Image count mismatch in {path}')
            return data.reshape(n, 28, 28).transpose(0, 2, 1).copy()
        magic, n = nums
        if magic != 2049:
            raise ValueError(f'Unexpected IDX label header in {path}: {nums}')
        data = np.frombuffer(f.read(), dtype=np.uint8).copy()
        if len(data) != n:
            raise ValueError(f'Label count mismatch in {path}')
        return data

class SmallCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(1, 32, kernel_size=3, padding=1), nn.ReLU(),
            nn.Conv2d(32, 32, kernel_size=3, padding=1), nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(32, 64, kernel_size=3, padding=1), nn.ReLU(),
            nn.Conv2d(64, 64, kernel_size=3, padding=1), nn.ReLU(),
            nn.MaxPool2d(2),
        )
        self.classifier = nn.Sequential(
            nn.Flatten(), nn.Linear(64 * 7 * 7, 128), nn.ReLU(),
            nn.Dropout(0.3), nn.Linear(128, 47)
        )
    def forward(self, x):
        return self.classifier(self.features(x))

@torch.no_grad()
def evaluate(model, loader, device):
    model.eval()
    correct = 0
    total = 0
    loss_sum = 0.0
    criterion = nn.CrossEntropyLoss(reduction='sum')
    for x, y in loader:
        x, y = x.to(device), y.to(device)
        logits = model(x)
        loss_sum += criterion(logits, y).item()
        correct += (logits.argmax(1) == y).sum().item()
        total += y.numel()
    return correct, total, loss_sum / total

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--data-dir', type=Path, default=Path('.'))
    p.add_argument('--output-dir', type=Path, default=Path('emnist_cnn_reference_output'))
    p.add_argument('--epochs', type=int, default=30)
    p.add_argument('--batch-size', type=int, default=128)
    p.add_argument('--lr', type=float, default=0.001)
    p.add_argument('--seed', type=int, default=2026)
    p.add_argument('--smoke-test', action='store_true')
    args = p.parse_args()
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(args.seed)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    data = {k: load_idx(args.data_dir / name, 'images' in k) for k, name in FILES.items()}
    x, y = data['train_images'], data['train_labels']
    xt, yt = data['test_images'], data['test_labels']
    if len(x) != 112800 or len(xt) != 18800 or y.min() != 0 or y.max() != 46:
        raise ValueError('Unexpected EMNIST Balanced dataset size or labels')
    # Stratified 90/10 train/validation split, using ONLY the original training set.
    rng = np.random.default_rng(args.seed)
    train_parts, val_parts = [], []
    for cls in range(47):
        ids = np.where(y == cls)[0].copy()
        rng.shuffle(ids)
        nval = len(ids) // 10
        val_parts.append(ids[:nval])
        train_parts.append(ids[nval:])
    train_idx = np.concatenate(train_parts)
    val_idx = np.concatenate(val_parts)
    rng.shuffle(train_idx)
    rng.shuffle(val_idx)
    if args.smoke_test:
        train_idx = train_idx[:512]
        val_idx = val_idx[:256]
        args.epochs = 1
    def dataset(x_data, y_data, idx=None):
        if idx is not None:
            x_data, y_data = x_data[idx], y_data[idx]
        # Float32 [0, 1] and exactly one orientation correction at IDX load.
        return TensorDataset(torch.from_numpy(x_data[:, None].astype(np.float32) / 255.0),
                             torch.from_numpy(y_data.astype(np.int64)))
    train_loader = DataLoader(dataset(x, y, train_idx), batch_size=args.batch_size, shuffle=True)
    val_loader = DataLoader(dataset(x, y, val_idx), batch_size=256, shuffle=False)
    test_loader = DataLoader(dataset(xt, yt), batch_size=256, shuffle=False)
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model = SmallCNN().to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)
    loss_fn = nn.CrossEntropyLoss()
    history = []
    best_correct = -1
    best_epoch = None
    path = args.output_dir / ('smoke_checkpoint.pt' if args.smoke_test else 'best_cnn_checkpoint.pt')
    print(f'Device: {device}; train={len(train_idx)}, val={len(val_idx)}, test={len(xt)}')
    for epoch in range(1, args.epochs + 1):
        model.train()
        total_loss, total = 0.0, 0
        for xb, yb in train_loader:
            xb, yb = xb.to(device), yb.to(device)
            optimizer.zero_grad(set_to_none=True)
            output = model(xb)
            loss = loss_fn(output, yb)
            loss.backward()
            optimizer.step()
            total_loss += loss.item() * yb.size(0)
            total += yb.size(0)
        scheduler.step()
        correct, count, val_loss = evaluate(model, val_loader, device)
        history.append({'epoch': epoch, 'train_loss': total_loss / total,
                        'val_correct': correct, 'val_total': count, 'val_accuracy': correct / count,
                        'val_loss': val_loss})
        print(f'Epoch {epoch:03d}: train loss={total_loss/total:.4f}, '
              f'validation={correct}/{count} ({100*correct/count:.2f}%)')
        if correct > best_correct:
            best_correct, best_epoch = correct, epoch
            torch.save({'model_state_dict': model.state_dict(),
                        'architecture': 'SmallCNN-32-32-64-64-128-47',
                        'seed': args.seed, 'epoch': epoch,
                        'preprocessing': 'raw IDX transpose, divide by 255.0'}, path)
    # The test set is not used for training or checkpoint selection.
    checkpoint = torch.load(path, map_location=device, weights_only=True)
    model.load_state_dict(checkpoint['model_state_dict'])
    test_correct, test_count, test_loss = evaluate(model, test_loader, device)
    summary = {'dataset': 'EMNIST Balanced', 'model': 'CNN software reference (not ZyNet compatible)',
               'device': str(device), 'seed': args.seed,
               'training_count': len(train_idx), 'validation_count': len(val_idx),
               'test_count': test_count, 'best_validation_epoch': best_epoch,
               'best_validation_correct': best_correct, 'best_validation_total': len(val_idx),
               'test_correct': test_correct, 'test_accuracy': test_correct/test_count,
               'test_loss': test_loss, 'history': history,
               'preprocessing': 'transpose raw IDX then divide by 255.0'}
    (args.output_dir / ('smoke_summary.json' if args.smoke_test else 'training_summary.json')).write_text(
        json.dumps(summary, indent=2), encoding='utf-8')
    print(f'Best validation: {best_correct}/{len(val_idx)} at epoch {best_epoch}')
    print(f'Independent test: {test_correct}/{test_count} ({100*test_correct/test_count:.2f}%)')
    print(f'Saved: {path} and summary JSON')

if __name__ == '__main__':
    main()
