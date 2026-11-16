"""Load the five official EMNIST Balanced gzip IDX files.

Raw EMNIST IDX images are transposed relative to upright characters.
This module transposes each 28x28 image and flattens it in row-major order.
Training normalization for the Python reference model is uint8 / 255.0.
This is NOT an FPGA input-quantization specification.
"""
from pathlib import Path
import gzip
import struct
import numpy as np

CLASSES = 47
DIM = 28


def read_idx_gz(path):
    with gzip.open(path, 'rb') as f:
        header = f.read(4)
        if len(header) != 4 or header[:2] != b'\x00\x00':
            raise ValueError(f'Invalid IDX header: {path}')
        dtype_code, dims = header[2], header[3]
        if dtype_code != 8 or dims not in (1, 3):
            raise ValueError(f'Expected uint8 IDX with 1 or 3 dims: {path}')
        shape_data = f.read(4 * dims)
        if len(shape_data) != 4 * dims:
            raise ValueError(f'Truncated shape in {path}')
        shape = struct.unpack('>' + 'I' * dims, shape_data)
        payload = f.read()
    arr = np.frombuffer(payload, dtype=np.uint8)
    if arr.size != int(np.prod(shape)):
        raise ValueError(f'Data size mismatch in {path}: got {arr.size}, expected {shape}')
    return arr.reshape(shape)


def load_split(folder, split):
    folder = Path(folder)
    prefix = f'emnist-balanced-{split}'
    images = read_idx_gz(folder / f'{prefix}-images-idx3-ubyte.gz')
    labels = read_idx_gz(folder / f'{prefix}-labels-idx1-ubyte.gz')
    expected = 112800 if split == 'train' else 18800
    if images.shape != (expected, DIM, DIM) or labels.shape != (expected,):
        raise ValueError(f'Unexpected {split} shape: {images.shape}, {labels.shape}')
    if labels.min() != 0 or labels.max() != CLASSES - 1:
        raise ValueError('Unexpected label range')
    if not np.all(np.bincount(labels, minlength=CLASSES) == (2400 if split == 'train' else 400)):
        raise ValueError('Unexpected class distribution')
    # Transpose EACH raw image, then use the same row-major input order in every platform.
    upright = images.transpose(0, 2, 1).reshape(-1, DIM * DIM)
    return upright, labels


def load_mapping(folder):
    pairs = {}
    with open(Path(folder) / 'emnist-balanced-mapping.txt', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                label, codepoint = map(int, line.split())
                pairs[label] = chr(codepoint)
    if set(pairs) != set(range(CLASSES)):
        raise ValueError('Mapping must cover all 47 class IDs')
    return pairs


def stratified_train_validation_indices(labels, validation_per_class=240, seed=2026):
    """Create deterministic 90/10 train/validation partitions from training data only."""
    rng = np.random.default_rng(seed)
    train, validation = [], []
    for label in range(CLASSES):
        indices = np.flatnonzero(labels == label)
        indices = rng.permutation(indices)
        validation.extend(indices[:validation_per_class])
        train.extend(indices[validation_per_class:])
    return rng.permutation(train), rng.permutation(validation)


def to_examples(raw, labels, num_classes=CLASSES, training=False):
    """Convert raw upright images into original network2-compatible (x,y) tuples."""
    scaled = raw.astype(np.float32) / 255.0
    if training:
        result = np.eye(num_classes, dtype=np.float32)[labels]
        return [(scaled[i].reshape(784, 1), result[i].reshape(num_classes, 1))
                for i in range(len(labels))]
    return [(scaled[i].reshape(784, 1), int(labels[i])) for i in range(len(labels))]
