import os
import numpy as np

from flask import Flask, request, jsonify

import network2


app = Flask(__name__)

# Load the exact trained floating-point network that was used
# to generate the zyNet FPGA implementation.
net = network2.load("WeigntsAndBiases.txt")


@app.route("/")
def health():
    return "MNIST cloud inference service is running"


@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_data()

    if len(data) != 784:
        return jsonify({
            "error": "expected exactly 784 bytes",
            "received": len(data)
        }), 400

    # FPGA input is 8-bit fixed point with 7 fractional bits.
    x = np.frombuffer(
        data,
        dtype=np.uint8
    ).astype(np.float64)

    x = x / 128.0

    # network2 expects a 784 x 1 column vector.
    x = x.reshape((784, 1))

    # Run inference using the original floating-point network.
    output = net.feedforward(x)

    prediction = int(np.argmax(output))

    return jsonify({
        "prediction": prediction
    })


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 8080))
    )
