import mnist_loader
import network2
import numpy as np

_, _, test_data = mnist_loader.load_data_wrapper()
test_data = list(test_data)

net = network2.load("WeigntsAndBiases.txt")

thresholds = [0.30, 0.40, 0.50, 0.60, 0.70]

print("Original grayscale:")
correct = net.accuracy(test_data)
print(f"{correct}/10000 = {correct / 100:.2f}%")
print()

for threshold in thresholds:

    binary_test_data = []

    for x, y in test_data:
        binary_x = (x >= threshold).astype(np.float64)
        binary_test_data.append((binary_x, y))

    correct = net.accuracy(binary_test_data)

    print(
        f"Threshold {threshold:.2f}: "
        f"{correct}/10000 = {correct / 100:.2f}%"
    )