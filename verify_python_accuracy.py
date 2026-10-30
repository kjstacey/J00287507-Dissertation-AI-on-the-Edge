import mnist_loader
import network2

training_data, validation_data, test_data = mnist_loader.load_data_wrapper()

test_data = list(test_data)

net = network2.load("WeigntsAndBiases.txt")

correct = net.accuracy(test_data)
total = len(test_data)

print(f"Correct: {correct} / {total}")
print(f"Accuracy: {correct / total * 100:.2f}%")