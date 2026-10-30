import gzip
import pickle
import numpy as np

INPUT_FILE = "mnist.pkl.gz"

IMAGE_OUTPUT = "mnist_test_images.bin"
LABEL_OUTPUT = "mnist_test_labels.bin"

with gzip.open(INPUT_FILE, "rb") as f:
    training_data, validation_data, test_data = pickle.load(
        f, encoding="latin1"
    )

images, labels = test_data

images = np.asarray(images, dtype=np.float32)
labels = np.asarray(labels, dtype=np.uint8)

print("Images shape:", images.shape)
print("Labels shape:", labels.shape)

images.tofile(IMAGE_OUTPUT)
labels.tofile(LABEL_OUTPUT)

print("Created:", IMAGE_OUTPUT)
print("Created:", LABEL_OUTPUT)