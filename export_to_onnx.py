import json
import numpy as np
import onnx
from onnx import helper, TensorProto, numpy_helper

INPUT_FILE = "WeigntsAndBiases.txt"
OUTPUT_FILE = "mnist_model.onnx"

# ------------------------------------------------------------
# Load the trained network
# ------------------------------------------------------------
with open(INPUT_FILE, "r") as f:
    data = json.load(f)

sizes = data["sizes"]
weights = [np.array(w, dtype=np.float32) for w in data["weights"]]
biases = [np.array(b, dtype=np.float32).reshape(-1) for b in data["biases"]]

print("Network sizes:", sizes)

# Expected:
# [784, 30, 20, 10]

if sizes != [784, 30, 20, 10]:
    raise ValueError(f"Unexpected network size: {sizes}")

# ------------------------------------------------------------
# ONNX input/output
# ------------------------------------------------------------
input_info = helper.make_tensor_value_info(
    "input",
    TensorProto.FLOAT,
    [1, 784]
)

output_info = helper.make_tensor_value_info(
    "output",
    TensorProto.FLOAT,
    [1, 10]
)

nodes = []
initializers = []

previous_output = "input"

# ------------------------------------------------------------
# Build Dense + Sigmoid layers
# Original Python uses:
#   sigmoid(Wx + b)
#
# ONNX Gemm expects:
#   Y = A * B + C
#
# Original weights are shaped [output, input],
# so transpose them to [input, output].
# ------------------------------------------------------------
for i, (w, b) in enumerate(zip(weights, biases), start=1):

    weight_name = f"W{i}"
    bias_name = f"B{i}"
    gemm_output = f"gemm{i}"
    sigmoid_output = "output" if i == len(weights) else f"sigmoid{i}"

    w_transposed = w.T.astype(np.float32)

    initializers.append(
        numpy_helper.from_array(w_transposed, name=weight_name)
    )

    initializers.append(
        numpy_helper.from_array(b.astype(np.float32), name=bias_name)
    )

    nodes.append(
        helper.make_node(
            "Gemm",
            inputs=[previous_output, weight_name, bias_name],
            outputs=[gemm_output],
            name=f"Dense{i}"
        )
    )

    nodes.append(
        helper.make_node(
            "Sigmoid",
            inputs=[gemm_output],
            outputs=[sigmoid_output],
            name=f"Sigmoid{i}"
        )
    )

    previous_output = sigmoid_output

# ------------------------------------------------------------
# Create graph
# ------------------------------------------------------------
graph = helper.make_graph(
    nodes,
    "MNIST_Feedforward_Network",
    [input_info],
    [output_info],
    initializer=initializers
)

model = helper.make_model(
    graph,
    producer_name="MNIST_Unity_Exporter",
    opset_imports=[helper.make_opsetid("", 13)]
)

# Keep IR version conservative for compatibility
model.ir_version = 8

# ------------------------------------------------------------
# Validate and save
# ------------------------------------------------------------
onnx.checker.check_model(model)

onnx.save(model, OUTPUT_FILE)

print(f"Successfully created {OUTPUT_FILE}")