"""Verify official EMNIST Balanced IDX gzip files and export upright reference images.

Windows: py -m pip install numpy matplotlib
         py emnist_balanced_verify.py
Optional: py emnist_balanced_verify.py --data-dir "C:\\path\\to\\data" --output-dir results
"""
from __future__ import annotations
import argparse
import gzip
import struct
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')  # Save plots to files; no Jupyter or display required.
import matplotlib.pyplot as plt

PREFIX = 'emnist-balanced'


def read_idx_gz(path: Path):
    with gzip.open(path, 'rb') as stream:
        magic = struct.unpack('>I', stream.read(4))[0]
        if magic == 2051:
            count, height, width = struct.unpack('>III', stream.read(12))
            data = np.frombuffer(stream.read(), dtype=np.uint8)
            if data.size != count * height * width:
                raise ValueError(f'Wrong image payload length in {path.name}')
            return data.reshape(count, height, width)
        if magic == 2049:
            count = struct.unpack('>I', stream.read(4))[0]
            data = np.frombuffer(stream.read(), dtype=np.uint8)
            if data.size != count:
                raise ValueError(f'Wrong label payload length in {path.name}')
            return data
        raise ValueError(f'Unexpected IDX magic number {magic} in {path.name}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', type=Path, default=Path(__file__).resolve().parent,
                        help='Folder containing the five original EMNIST Balanced files')
    parser.add_argument('--output-dir', type=Path, default=None,
                        help='Output folder (default: <data-dir>/emnist_verification_output)')
    args = parser.parse_args()
    data_dir = args.data_dir.resolve()
    output_dir = (args.output_dir or data_dir / 'emnist_verification_output').resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    train_images = read_idx_gz(data_dir / f'{PREFIX}-train-images-idx3-ubyte.gz')
    train_labels = read_idx_gz(data_dir / f'{PREFIX}-train-labels-idx1-ubyte.gz')
    test_images = read_idx_gz(data_dir / f'{PREFIX}-test-images-idx3-ubyte.gz')
    test_labels = read_idx_gz(data_dir / f'{PREFIX}-test-labels-idx1-ubyte.gz')
    assert train_images.shape == (112800, 28, 28)
    assert train_labels.shape == (112800,)
    assert test_images.shape == (18800, 28, 28)
    assert test_labels.shape == (18800,)

    mapping = {}
    with (data_dir / f'{PREFIX}-mapping.txt').open(encoding='utf-8') as fh:
        for line in fh:
            if line.strip():
                class_id, codepoint = map(int, line.split())
                mapping[class_id] = chr(codepoint)
    assert set(mapping) == set(range(47))
    assert set(np.unique(train_labels)) == set(range(47))
    assert set(np.unique(test_labels)) == set(range(47))
    train_counts = np.bincount(train_labels, minlength=47)
    test_counts = np.bincount(test_labels, minlength=47)
    assert np.all(train_counts == 2400)
    assert np.all(test_counts == 400)
    print('Verified: 112800 training images, 18800 test images, 47 balanced classes.')
    print('Image shape: 28 x 28; dtype: uint8; raw range:', int(train_images.min()), int(train_images.max()))

    # Raw official IDX arrays require a transpose to display in an upright orientation.
    fig, axes = plt.subplots(2, 10, figsize=(14, 4))
    for col, class_id in enumerate(range(10, 20)):
        idx = int(np.flatnonzero(train_labels == class_id)[0])
        for row, image in enumerate((train_images[idx], train_images[idx].T)):
            ax = axes[row, col]
            ax.imshow(image, cmap='gray', vmin=0, vmax=255)
            ax.set_title(f'{class_id}: {mapping[class_id]}', fontsize=9)
            ax.axis('off')
    fig.suptitle('Raw EMNIST Balanced IDX images (top) vs. transposed/upright (bottom)')
    fig.tight_layout()
    fig.savefig(output_dir / 'EMNIST_Balanced_Orientation_Check.png', dpi=160)
    plt.close(fig)

    fig, axes = plt.subplots(5, 10, figsize=(13, 7))
    for class_id in range(47):
        idx = int(np.flatnonzero(train_labels == class_id)[0])
        ax = axes.flat[class_id]
        ax.imshow(train_images[idx].T, cmap='gray', vmin=0, vmax=255)
        ax.set_title(f'{class_id}: {mapping[class_id]}', fontsize=9)
        ax.axis('off')
    for ax in list(axes.flat)[47:]:
        ax.axis('off')
    fig.suptitle('EMNIST Balanced: one upright training example from each class')
    fig.tight_layout()
    fig.savefig(output_dir / 'EMNIST_Balanced_Class_Examples.png', dpi=160)
    plt.close(fig)

    # One deterministic sample per class, drawn only from the official TEST partition.
    indices = np.array([np.flatnonzero(test_labels == k)[0] for k in range(47)], dtype=np.int32)
    vectors = np.stack([test_images[i].T.flatten() for i in indices]).astype(np.uint8)
    labels = test_labels[indices]
    assert np.array_equal(labels, np.arange(47))
    np.savez_compressed(output_dir / 'EMNIST_Balanced_Reference_Vectors.npz',
                        test_indices=indices, pixels_u8=vectors, class_ids=labels)
    with (output_dir / 'EMNIST_Balanced_Verification_Summary.txt').open('w', encoding='utf-8') as out:
        out.write('EMNIST Balanced verification\n')
        out.write('Training: 112800 images (2400/class)\nTest: 18800 images (400/class)\n')
        out.write('28x28 grayscale uint8; original IDX arrays transposed to display upright.\n')
        out.write('Reference vectors are upright, flattened row-major, unnormalized uint8.\n')
        out.write('Class ID -> character:\n')
        for k in range(47):
            out.write(f'{k:02d} -> {mapping[k]}\n')
    print('Files saved to:', output_dir)
    for file in sorted(output_dir.iterdir()):
        print(' -', file.name)
    print('Review the two PNG images before using the reference vectors for model training.')


if __name__ == '__main__':
    main()
