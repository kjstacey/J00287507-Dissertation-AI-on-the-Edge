import gzip
import pickle

INPUT_FILE = "mnist.pkl.gz"
OUTPUT_FILE = "mnist_test_0000.txt"

with gzip.open(INPUT_FILE, "rb") as f:
    training_data, validation_data, test_data = pickle.load(
        f, encoding="latin1"
    )

images, labels = test_data

image = images[0]
label = int(labels[0])

with open(OUTPUT_FILE, "w") as f:
    f.write(str(label) + "\n")
    f.write(",".join(str(float(pixel)) for pixel in image))

print("Created:", OUTPUT_FILE)
print("Expected digit:", label)
print("Pixel count:", len(image))