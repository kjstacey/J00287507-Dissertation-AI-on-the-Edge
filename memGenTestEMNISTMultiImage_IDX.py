"""Generate EMNIST Balanced 100-image Vivado ROM batches directly from IDX files.

Reads either original uncompressed IDX (..-ubyte) or .gz IDX files without
extracting per-image text files. Original EMNIST IDX image orientation is
transposed to match the trained compact CNN's canonical input orientation.
Pixels remain uint8 0..255, ordered row-major after the transpose.

Example:
  python memGenTestEMNISTMultiImage_IDX.py \
    --images emnist-balanced-test-images-idx3-ubyte.gz \
    --labels emnist-balanced-test-labels-idx1-ubyte.gz \
    --output-dir output --start-index 0

For batch starts 0,100,...,900 the script produces one .coe ROM initialization,
a matching 6-bit VHDL label package, and a CSV manifest for traceability.
"""
import argparse
import csv
import gzip
import struct
from pathlib import Path

COUNT = 100
IMAGE_SIDE = 28
PIXELS = 784
CLASSES = 47


def read_idx(path: Path, expected_magic: int):
    opener = gzip.open if path.suffix.lower() == '.gz' else open
    with opener(path, 'rb') as f:
        header = f.read(16 if expected_magic == 2051 else 8)
        if len(header) != (16 if expected_magic == 2051 else 8):
            raise ValueError(f'{path}: incomplete IDX header')
        values = struct.unpack('>IIII' if expected_magic == 2051 else '>II', header)
        if values[0] != expected_magic:
            raise ValueError(f'{path}: IDX magic {values[0]} expected {expected_magic}')
        if expected_magic == 2051:
            _, number, rows, cols = values
            if (rows, cols) != (IMAGE_SIDE, IMAGE_SIDE):
                raise ValueError(f'{path}: expected 28x28, found {rows}x{cols}')
            size = number * rows * cols
        else:
            _, number = values
            size = number
        body = f.read()
        if len(body) != size:
            raise ValueError(f'{path}: expected {size} bytes, found {len(body)}')
    return number, body


def transpose_28(image: bytes) -> bytes:
    # Raw EMNIST IDX convention -> upright canonical 28x28 used in training.
    return bytes(image[col * IMAGE_SIDE + row]
                 for row in range(IMAGE_SIDE) for col in range(IMAGE_SIDE))


def generate(images_path: Path, labels_path: Path, out: Path, start_index: int):
    if not (0 <= start_index <= 900 and start_index % COUNT == 0):
        raise ValueError('start-index must be 0,100,...,900')
    n_images, data = read_idx(images_path, 2051)
    n_labels, label_data = read_idx(labels_path, 2049)
    if n_images != n_labels:
        raise ValueError(f'Image and label counts differ: {n_images} vs {n_labels}')
    if start_index + COUNT > n_images:
        raise ValueError('Batch exceeds the test partition')
    out.mkdir(parents=True, exist_ok=True)
    selected = []
    all_pixels = bytearray()
    for idx in range(start_index, start_index + COUNT):
        label = label_data[idx]
        if label >= CLASSES:
            raise ValueError(f'Test index {idx}: label {label} is outside 0..46')
        raw = data[idx * PIXELS:(idx + 1) * PIXELS]
        corrected = transpose_28(raw)
        all_pixels.extend(corrected)
        selected.append((idx, label))

    coe_path = out / f'emnist_test_pixels_{start_index:04d}.coe'
    coe_path.write_text('memory_initialization_radix=16;\n'
                        'memory_initialization_vector=\n'
                        + ',\n'.join(f'{value:02X}' for value in all_pixels)
                        + ';\n', encoding='ascii')
    entries = ',\n'.join(f'        {i:3d} => "{label:06b}"'
                         for i, (_idx, label) in enumerate(selected))
    package_path = out / 'emnist_test_rom_pkg.vhd'
    package_path.write_text(
        'library IEEE;\nuse IEEE.STD_LOGIC_1164.ALL;\n'
        'use IEEE.NUMERIC_STD.ALL;\n\n'
        'package emnist_test_rom_pkg is\n'
        '    constant EMNIST_TEST_COUNT : integer := 100;\n'
        '    constant EMNIST_PIXELS_PER_IMAGE : integer := 784;\n'
        '    type emnist_label_type is array (0 to EMNIST_TEST_COUNT - 1)\n'
        '        of std_logic_vector(5 downto 0);\n'
        '    constant EMNIST_LABEL_ROM : emnist_label_type := (\n'
        + entries + '\n    );\n'
        'end package emnist_test_rom_pkg;\n', encoding='ascii')
    manifest_path = out / f'emnist_test_labels_{start_index:04d}.csv'
    with manifest_path.open('w', newline='', encoding='ascii') as f:
        writer = csv.writer(f)
        writer.writerow(['batch_position', 'original_test_index', 'class_id'])
        for i, (idx, label) in enumerate(selected):
            writer.writerow([i, idx, label])
    print(f'IMG count: {n_images}; label count: {n_labels}')
    print(f'Batch indices: {start_index}..{start_index + 99}')
    print('Pixel transformation: raw IDX 28x28 transpose, uint8 unchanged')
    print(f'Generated {len(selected)} labels and {len(all_pixels)} pixel bytes')
    for p in (coe_path, package_path, manifest_path):
        print(p)
    return coe_path, package_path, manifest_path


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--images', type=Path, required=True, help='EMNIST Balanced test images IDX or .gz')
    ap.add_argument('--labels', type=Path, required=True, help='EMNIST Balanced test labels IDX or .gz')
    ap.add_argument('--output-dir', type=Path, required=True)
    ap.add_argument('--start-index', type=int, default=0)
    args = ap.parse_args()
    generate(args.images, args.labels, args.output_dir, args.start_index)

if __name__ == '__main__':
    main()
