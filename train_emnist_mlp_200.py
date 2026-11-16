"""EMNIST Balanced 784-200-47 dense-network experiment.

Same 90/10 stratified seeded split and transposition as previous EMNIST work.
A standalone PyTorch trainer, with original network2-compatible weights/biases
JSON export for later ZyNet inspection. NO encryption and NO FPGA claim.
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
                raise ValueError(f'Invalid EMNIST image header: {path}: {nums}')
            pixels = np.frombuffer(f.read(), dtype=np.uint8)
            if pixels.size != n * 784:
                raise ValueError(f'Image payload length mismatch: {path}')
            # Raw EMNIST IDX images are transposed. Correct exactly once.
            return pixels.reshape(n, 28, 28).transpose(0, 2, 1).copy().reshape(n, 784)
        magic, n = nums
        if magic != 2049:
            raise ValueError(f'Invalid EMNIST label header: {path}: {nums}')
        labels = np.frombuffer(f.read(), dtype=np.uint8).copy()
        if labels.size != n:
            raise ValueError(f'Label payload length mismatch: {path}')
        return labels


class DenseEMNIST(nn.Module):
    def __init__(self, activation: str = 'sigmoid'):
        super().__init__()
        if activation not in ('sigmoid', 'relu'):
            raise ValueError('activation must be sigmoid or relu')
        self.fc1 = nn.Linear(784, 200)
        self.fc2 = nn.Linear(200, 47)
        self.activation = activation

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        hidden = torch.sigmoid(self.fc1(x)) if self.activation == 'sigmoid' else F.relu(self.fc1(x))
        # Output logits for softmax cross-entropy training. At inference, a sigmoid
        # applied to these 47 outputs does NOT change argmax classification.
        return self.fc2(hidden)


def make_split(labels: np.ndarray, seed: int):
    """Exactly the deterministic split procedure used in the improved CNN script."""
    rng = np.random.default_rng(seed)
    training, validation = [], []
    for cls in range(47):
        ids = np.where(labels == cls)[0].copy()
        rng.shuffle(ids)
        validation.append(ids[:240])
        training.append(ids[240:])
    train_idx, val_idx = np.concatenate(training), np.concatenate(validation)
    rng.shuffle(train_idx)
    return train_idx, val_idx


@torch.no_grad()
def evaluate(model, loader, device):
    model.eval()
    correct = 0
    count = 0
    loss_sum = 0.0
    for xb, yb in loader:
        logits = model(xb.to(device))
        yb = yb.to(device)
        loss_sum += F.cross_entropy(logits, yb, reduction='sum').item()
        correct += int((logits.argmax(1) == yb).sum().item())
        count += len(yb)
    return correct, count, loss_sum / count


def export_network2_json(model: DenseEMNIST, filename: Path):
    """Serialize dense-layer arrays in the same sizes/weights/biases shape as network2.save.

    This is a numerical model export, NOT an assertion of ZyNet feasibility.
    'cost' is maintained for compatibility with network2.load; the PyTorch
    training objective is multi-class softmax cross-entropy, not the original
    network2 one-hot sigmoid cross-entropy.
    """
    weights = [model.fc1.weight.detach().cpu().numpy(), model.fc2.weight.detach().cpu().numpy()]
    biases = [model.fc1.bias.detach().cpu().numpy().reshape(-1, 1),
              model.fc2.bias.detach().cpu().numpy().reshape(-1, 1)]
    payload = {
        'sizes': [784, 200, 47],
        'weights': [w.tolist() for w in weights],
        'biases': [b.tolist() for b in biases],
        'cost': 'CrossEntropyCost',
    }
    filename.write_text(json.dumps(payload), encoding='utf-8')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data-dir', type=Path, default=Path('.'))
    p.add_argument('--output-dir', type=Path, default=Path('emnist_mlp_200_output'))
    p.add_argument('--epochs', type=int, default=35)
    p.add_argument('--batch-size', type=int, default=128)
    p.add_argument('--lr', type=float, default=0.003)
    p.add_argument('--decay-factor', type=float, default=0.92)
    p.add_argument('--decay-every', type=int, default=5)
    p.add_argument('--seed', type=int, default=2026)
    p.add_argument('--activation', choices=['sigmoid', 'relu'], default='sigmoid')
    p.add_argument('--smoke-test', action='store_true')
    args = p.parse_args()
    if args.smoke_test:
        args.epochs = 1
        if args.output_dir == Path('emnist_mlp_200_output'):
            args.output_dir = Path('emnist_mlp_200_smoke_output')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(args.seed)
    torch.set_num_threads(min(torch.get_num_threads(), 8))
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    x_train = load_idx(args.data_dir / FILES['train_images'], True)
    y_train = load_idx(args.data_dir / FILES['train_labels'], False)
    if x_train.shape != (112800, 784) or y_train.shape != (112800,):
        raise ValueError('Unexpected EMNIST Balanced training dimensions')
    if not np.array_equal(np.bincount(y_train, minlength=47), np.full(47, 2400)):
        raise ValueError('EMNIST Balanced training class distribution mismatch')
    train_idx, val_idx = make_split(y_train, args.seed)
    np.savez_compressed(args.output_dir / 'split_indices.npz', train=train_idx, validation=val_idx)
    # Same upright row-major pixel order, float32 scaled to [0,1].
    x = torch.from_numpy(x_train.astype(np.float32) / 255.0)
    y = torch.from_numpy(y_train.astype(np.int64))
    train_set = TensorDataset(x[train_idx], y[train_idx])
    val_set = TensorDataset(x[val_idx], y[val_idx])
    if args.smoke_test:
        # Use a small but stratified subset for fast integration testing.
        train_set = TensorDataset(x[train_idx[:2048]], y[train_idx[:2048]])
        val_set = TensorDataset(x[val_idx[:512]], y[val_idx[:512]])
    generator = torch.Generator().manual_seed(args.seed)
    train_loader = DataLoader(train_set, batch_size=args.batch_size, shuffle=True, generator=generator)
    val_loader = DataLoader(val_set, batch_size=512, shuffle=False)

    model = DenseEMNIST(args.activation).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    scheduler = torch.optim.lr_scheduler.StepLR(optimizer, step_size=args.decay_every, gamma=args.decay_factor)
    history = []
    best_correct = -1
    best_epoch = None
    print(f'Device: {device} | 784-200-47 | activation={args.activation} | {len(train_set)} train / {len(val_set)} val', flush=True)
    for epoch in range(1, args.epochs + 1):
        model.train()
        train_loss_sum = 0.0
        for xb, yb in train_loader:
            optimizer.zero_grad(set_to_none=True)
            logits = model(xb.to(device))
            loss = F.cross_entropy(logits, yb.to(device))
            loss.backward()
            optimizer.step()
            train_loss_sum += loss.item() * len(yb)
        correct, total, val_loss = evaluate(model, val_loader, device)
        history.append({
            'epoch': epoch,
            'train_loss': train_loss_sum / len(train_set),
            'validation_correct': correct,
            'validation_total': total,
            'validation_accuracy': correct / total,
            'validation_loss': val_loss,
            'lr': optimizer.param_groups[0]['lr'],
        })
        if correct > best_correct:
            best_correct, best_epoch = correct, epoch
            torch.save(model.state_dict(), args.output_dir / 'best_mlp_checkpoint.pt')
            export_network2_json(model, args.output_dir / 'EMNIST_Balanced_MLP200_Best_WeightsAndBiases.txt')
        scheduler.step()
        print(f'Epoch {epoch:02d}/{args.epochs}: validation {correct}/{total} ({correct/total:.2%}), '
              f'val loss {val_loss:.4f}, best epoch {best_epoch}', flush=True)

    torch.save(model.state_dict(), args.output_dir / 'final_mlp_checkpoint.pt')
    export_network2_json(model, args.output_dir / 'EMNIST_Balanced_MLP200_Final_WeightsAndBiases.txt')
    with (args.output_dir / 'validation_history.csv').open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=history[0].keys())
        writer.writeheader()
        writer.writerows(history)

    summary = {
        'dataset': 'EMNIST Balanced',
        'architecture': [784, 200, 47],
        'model_type': 'dense MLP; no cryptography',
        'hidden_activation': args.activation,
        'output': 'linear logits for training; sigmoid preserves argmax for inference',
        'training_loss': 'multiclass softmax cross entropy (PyTorch CrossEntropyLoss)',
        'export_cost_field': 'CrossEntropyCost (JSON compatibility only)',
        'optimizer': 'Adam',
        'learning_rate': args.lr,
        'decay_factor': args.decay_factor,
        'decay_every_epochs': args.decay_every,
        'batch_size': args.batch_size,
        'seed': args.seed,
        'preprocessing': 'transpose raw 28x28 IDX image once, flatten row-major, scale by /255.0',
        'training_count': len(train_set),
        'validation_count': len(val_set),
        'best_validation_epoch': best_epoch,
        'best_validation_correct': best_correct,
        'best_validation_total': len(val_set),
        'best_validation_accuracy': best_correct / len(val_set),
        'smoke_test': args.smoke_test,
        'test_correct': None,
        'test_accuracy': None,
        'hardware_compatibility': 'NOT established; quantization and ZyNet validation required',
    }
    if not args.smoke_test:
        # Official held-out test is evaluated ONLY ONCE, after best checkpoint chosen.
        x_test = load_idx(args.data_dir / FILES['test_images'], True)
        y_test = load_idx(args.data_dir / FILES['test_labels'], False)
        if x_test.shape != (18800, 784) or y_test.shape != (18800,):
            raise ValueError('Unexpected test dimensions')
        model.load_state_dict(torch.load(args.output_dir / 'best_mlp_checkpoint.pt', map_location=device, weights_only=True))
        test_loader = DataLoader(TensorDataset(torch.from_numpy(x_test.astype(np.float32)/255.0),
                                                   torch.from_numpy(y_test.astype(np.int64))),
                                 batch_size=512, shuffle=False)
        correct, total, loss = evaluate(model, test_loader, device)
        summary.update({'test_correct': correct, 'test_total': total,
                        'test_accuracy': correct / total, 'test_loss': loss})
        print(f'Best checkpoint official test accuracy: {correct}/{total} = {correct/total:.2%}', flush=True)
    (args.output_dir / 'training_summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(f'Outputs saved to: {args.output_dir.resolve()}', flush=True)


if __name__ == '__main__':
    main()
