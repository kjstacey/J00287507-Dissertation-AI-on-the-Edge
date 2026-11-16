"""EMNIST Balanced CNN generalization experiment (software reference; NOT ZyNet RTL).

Requirements: Python 3.12+, numpy, torch. No torchvision required.
Examples:
  python3 train_emnist_cnn_improved.py --smoke-test
  python3 train_emnist_cnn_improved.py --epochs 40

The same seeded stratified 90/10 split as the prior CNN reference is used.
The official test set is evaluated once, after choosing a checkpoint on validation.
"""
from __future__ import annotations
import argparse
import csv
import gzip
import json
import random
import struct
from pathlib import Path
import numpy as np
import torch
from torch import nn
from torch.nn import functional as F
from torch.utils.data import DataLoader, TensorDataset

FILES = {
    'train_images': 'emnist-balanced-train-images-idx3-ubyte.gz',
    'train_labels': 'emnist-balanced-train-labels-idx1-ubyte.gz',
    'test_images': 'emnist-balanced-test-images-idx3-ubyte.gz',
    'test_labels': 'emnist-balanced-test-labels-idx1-ubyte.gz',
}


def load_idx(path: Path, images: bool) -> np.ndarray:
    with gzip.open(path, 'rb') as f:
        nums = struct.unpack('>IIII' if images else '>II', f.read(16 if images else 8))
        if images:
            magic, n, rows, cols = nums
            if magic != 2051 or (rows, cols) != (28, 28):
                raise ValueError(f'Invalid image header: {path}: {nums}')
            a = np.frombuffer(f.read(), dtype=np.uint8)
            if a.size != n * 784:
                raise ValueError(f'Image length mismatch: {path}')
            # Correct orientation exactly once; never flip/rotate as a 'fix' later.
            return a.reshape(n, 28, 28).transpose(0, 2, 1).copy()
        magic, n = nums
        if magic != 2049:
            raise ValueError(f'Invalid label header: {path}: {nums}')
        a = np.frombuffer(f.read(), dtype=np.uint8).copy()
        if a.size != n:
            raise ValueError(f'Label length mismatch: {path}')
        return a


class SmallCNN(nn.Module):
    """Same conv width/depth as the reference CNN; increased dropout only."""
    def __init__(self, dropout=0.4):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(1, 32, 3, padding=1), nn.ReLU(),
            nn.Conv2d(32, 32, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),
            nn.Conv2d(32, 64, 3, padding=1), nn.ReLU(),
            nn.Conv2d(64, 64, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),
        )
        self.classifier = nn.Sequential(
            nn.Flatten(), nn.Linear(64 * 7 * 7, 128), nn.ReLU(),
            nn.Dropout(dropout), nn.Linear(128, 47),
        )

    def forward(self, x):
        return self.classifier(self.features(x))


def augment_batch(x: torch.Tensor, degrees=7.0, translation=2.0, scale_delta=0.06):
    """Small random affine perturbations only. No flips / shears / character-changing rotations."""
    n = x.shape[0]
    angles = (torch.rand(n, device=x.device) * 2 - 1) * (degrees * torch.pi / 180)
    scales = 1 + (torch.rand(n, device=x.device) * 2 - 1) * scale_delta
    cos, sin = torch.cos(angles) / scales, torch.sin(angles) / scales
    # grid coordinates cover [-1,1]; translation pixels -> normalized coordinates
    tx = (torch.rand(n, device=x.device) * 2 - 1) * (2 * translation / 28)
    ty = (torch.rand(n, device=x.device) * 2 - 1) * (2 * translation / 28)
    theta = torch.zeros((n, 2, 3), dtype=x.dtype, device=x.device)
    theta[:, 0, 0] = cos
    theta[:, 0, 1] = -sin
    theta[:, 1, 0] = sin
    theta[:, 1, 1] = cos
    theta[:, 0, 2] = tx
    theta[:, 1, 2] = ty
    grid = F.affine_grid(theta, x.shape, align_corners=False)
    return F.grid_sample(x, grid, mode='bilinear', padding_mode='zeros', align_corners=False)


@torch.no_grad()
def evaluate(model, loader, device, with_predictions=False):
    model.eval()
    total, correct, loss_sum = 0, 0, 0.0
    actual, predicted = [], []
    for x, y in loader:
        x, y = x.to(device), y.to(device)
        logits = model(x)
        loss_sum += F.cross_entropy(logits, y, reduction='sum').item()
        preds = logits.argmax(dim=1)
        correct += int((preds == y).sum())
        total += y.numel()
        if with_predictions:
            actual.append(y.cpu().numpy())
            predicted.append(preds.cpu().numpy())
    result = (correct, total, loss_sum / total)
    if with_predictions:
        return result + (np.concatenate(actual), np.concatenate(predicted))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data-dir', type=Path, default=Path('.'))
    parser.add_argument('--output-dir', type=Path, default=Path('emnist_cnn_improved_output'))
    parser.add_argument('--epochs', type=int, default=40)
    parser.add_argument('--batch-size', type=int, default=128)
    parser.add_argument('--lr', type=float, default=0.001)
    parser.add_argument('--seed', type=int, default=2026)
    parser.add_argument('--patience', type=int, default=12, help='Early stopping patience for validation accuracy')
    parser.add_argument('--smoke-test', action='store_true')
    args = parser.parse_args()
    if args.smoke_test:
        args.epochs = 1
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(args.seed)
    data = {k: load_idx(args.data_dir / name, 'images' in k) for k, name in FILES.items()}
    x, y = data['train_images'], data['train_labels']
    xt, yt = data['test_images'], data['test_labels']
    if len(x) != 112800 or len(xt) != 18800 or not np.array_equal(np.bincount(y, minlength=47), np.full(47, 2400)):
        raise ValueError('The files are not the expected EMNIST Balanced distribution')
    rng = np.random.default_rng(args.seed)
    training, validation = [], []
    for cls in range(47):
        ids = np.where(y == cls)[0].copy()
        rng.shuffle(ids)
        validation.append(ids[:240])
        training.append(ids[240:])
    tr_idx, va_idx = np.concatenate(training), np.concatenate(validation)
    rng.shuffle(tr_idx)
    rng.shuffle(va_idx)
    if args.smoke_test:
        tr_idx, va_idx = tr_idx[:256], va_idx[:128]
    # Same IDX orientation and 0..1 input normalization as reference CNN.
    def make_dataset(images, labels, indices=None):
        if indices is not None:
            images, labels = images[indices], labels[indices]
        return TensorDataset(torch.from_numpy(images[:, None].astype(np.float32) / 255.0),
                             torch.from_numpy(labels.astype(np.int64)))
    tr_loader = DataLoader(make_dataset(x, y, tr_idx), batch_size=args.batch_size, shuffle=True)
    va_loader = DataLoader(make_dataset(x, y, va_idx), batch_size=256)
    test_loader = None if args.smoke_test else DataLoader(make_dataset(xt, yt), batch_size=256)
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model = SmallCNN(dropout=0.4).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=5e-4)
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.5, patience=4, min_lr=1e-5)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    best_path = args.output_dir / ('smoke_checkpoint.pt' if args.smoke_test else 'best_cnn_checkpoint.pt')
    history, best_correct, best_loss, best_epoch = [], -1, float('inf'), None
    stale = 0
    print(f'Device={device}; train={len(tr_idx)}; val={len(va_idx)}; official test={len(xt)}', flush=True)
    for epoch in range(1, args.epochs + 1):
        model.train()
        train_total, train_loss = 0, 0.0
        for xb, yb in tr_loader:
            xb, yb = xb.to(device), yb.to(device)
            xb = augment_batch(xb)
            optimizer.zero_grad(set_to_none=True)
            logits = model(xb)
            loss = F.cross_entropy(logits, yb)
            loss.backward()
            optimizer.step()
            train_loss += loss.item() * yb.size(0)
            train_total += yb.size(0)
        correct, count, val_loss = evaluate(model, va_loader, device)
        scheduler.step(val_loss)
        lr = optimizer.param_groups[0]['lr']
        accuracy = correct / count
        history.append({'epoch': epoch, 'train_loss': train_loss / train_total,
                        'val_correct': correct, 'val_total': count,
                        'val_accuracy': accuracy, 'val_loss': val_loss, 'lr': lr})
        print(f'Epoch {epoch:03}: training loss={train_loss/train_total:.4f}; '
              f'val={correct}/{count} ({accuracy:.2%}); val loss={val_loss:.4f}; lr={lr:.6f}', flush=True)
        if correct > best_correct or (correct == best_correct and val_loss < best_loss):
            best_correct, best_loss, best_epoch = correct, val_loss, epoch
            stale = 0
            torch.save({'model_state_dict': model.state_dict(),
                        'architecture': 'SmallCNN-32-32-64-64-128-47',
                        'dropout': 0.4, 'seed': args.seed, 'epoch': epoch,
                        'preprocessing': 'transpose raw IDX; divide by 255.0'}, best_path)
        else:
            stale += 1
        if stale >= args.patience and not args.smoke_test:
            print(f'Early stopping: no new best validation accuracy for {args.patience} epochs')
            break
    checkpoint = torch.load(best_path, map_location=device, weights_only=True)
    model.load_state_dict(checkpoint['model_state_dict'])
    summary = {'dataset': 'EMNIST Balanced', 'model': 'CNN generalization experiment (not ZyNet compatible)',
               'device': str(device), 'seed': args.seed, 'architecture': checkpoint['architecture'],
               'training_count': len(tr_idx), 'validation_count': len(va_idx),
               'official_test_count': len(xt), 'best_validation_epoch': best_epoch,
               'best_validation_correct': best_correct, 'best_validation_total': len(va_idx),
               'best_validation_accuracy': best_correct / len(va_idx),
               'best_validation_loss': best_loss, 'history': history,
               'preprocessing': 'transpose raw IDX then divide by 255.0',
               'augmentation': 'train only: rotations up to 7 deg; translations up to 2 px; scale 0.94..1.06',
               'dropout': 0.4, 'weight_decay': 5e-4,
               'checkpoint_selection': 'highest validation accuracy; val loss breaks ties'}
    if not args.smoke_test:
        test_correct, test_total, test_loss, actual, predicted = evaluate(model, test_loader, device, True)
        confusion = np.zeros((47, 47), dtype=np.int64)
        np.add.at(confusion, (actual, predicted), 1)
        np.savetxt(args.output_dir / 'test_confusion_matrix.csv', confusion, fmt='%d', delimiter=',')
        summary.update({'test_correct': test_correct, 'test_total': test_total,
                        'test_accuracy': test_correct / test_total, 'test_loss': test_loss})
        print(f'Independent official test: {test_correct}/{test_total} ({test_correct/test_total:.2%})')
    filename = 'smoke_summary.json' if args.smoke_test else 'training_summary.json'
    (args.output_dir / filename).write_text(json.dumps(summary, indent=2), encoding='utf-8')
    with (args.output_dir / 'validation_history.csv').open('w', newline='', encoding='utf-8') as out:
        writer = csv.DictWriter(out, fieldnames=history[0].keys())
        writer.writeheader()
        writer.writerows(history)
    print(f'Best validation: {best_correct}/{len(va_idx)} epoch {best_epoch}')
    print(f'Files saved to: {args.output_dir.resolve()}')


if __name__ == '__main__':
    main()
