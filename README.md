# MNIST Model Code

This branch contains the source files and supporting artifacts used to prepare the MNIST neural-network model for the FPGA and Unity implementations in this project.

The same trained MNIST network was used as the starting point for both deployment paths. The network is a fully connected feed-forward neural network with the architecture:

```text
784 -> 30 -> 20 -> 10
```

Each non-input layer uses a sigmoid activation function. The network contains 24,350 trainable parameters.

The saved trained model is stored in:

```text
WeigntsAndBiases.txt
```

The filename spelling is preserved because it is the filename used throughout the original project.

## Model Workflow

The model-preparation process follows two deployment paths:

```text
                         WeigntsAndBiases.txt
                                  |
                 +----------------+----------------+
                 |                                 |
                 v                                 v
          ZyNet / FPGA path                 ONNX / Unity path
                 |                                 |
                 v                                 v
       weights.mem / biases.mem             mnist_model.onnx
                 |                                 |
                 v                                 v
             ZedBoard                    PC and Meta Quest 3S
```

The FPGA and Unity implementations therefore begin with the same trained network rather than independently trained models.

## Reproducibility Notebooks

Two notebooks document the model-preparation process:

### `MNIST_ZyNet_Model_Creation.ipynb`

Documents the preparation of the trained MNIST network for the ZyNet FPGA implementation, including generation of the parameter files used by the hardware design.

### `MNIST_ONNX_Model_Creation.ipynb`

Documents conversion of `WeigntsAndBiases.txt` to the ONNX representation used by Unity Inference Engine / Sentis.

The notebook verifies:

- the `784 -> 30 -> 20 -> 10` architecture;
- the 24,350 model parameters;
- conversion of the dense layers to ONNX `Gemm` operations;
- sigmoid activation after each layer;
- ONNX graph validity;
- Python and ONNX prediction consistency;
- classification accuracy on the complete 10,000-image MNIST test set; and
- creation of the binary MNIST test files used by Unity.

The ONNX model used in the experiments produced a classification accuracy of **96.63% (9,663 / 10,000)** on the complete MNIST test set.

## Files

### Model and Training Files

| File | Description |
|---|---|
| `trainNN.py` | Original Python script used to train and save the MNIST network. |
| `network2.py` | Feed-forward neural-network implementation used for training, loading, and Python inference. |
| `mnist_loader.py` | Loads and prepares the MNIST training, validation, and test datasets. |
| `mnist.pkl.gz` | MNIST dataset used by the Python model. |
| `WeigntsAndBiases.txt` | Saved trained network architecture, weights, and biases. |
| `verify_python_accuracy.py` | Loads the saved network and verifies its accuracy on the MNIST test set. |

### ZyNet / FPGA Preparation

| File | Description |
|---|---|
| `genWeightsAndBias.py` | Supporting parameter-generation code for the ZyNet workflow. |
| `convert.py` | Supporting conversion code used during FPGA model preparation. |
| `mnistZyNet.py` | ZyNet-related MNIST model-generation script. |
| `mnistZyNet2.py` | Additional ZyNet-related model-generation script. |
| `weights.mem` | Generated FPGA weight-memory initialization data. |
| `biases.mem` | Generated FPGA bias-memory initialization data. |
| `genTestData.py` | Supporting MNIST test-data generation code for FPGA testing. |
| `test_binary_mnist.py` | Supporting test code for the binary/thresholded MNIST representation. |

The complete FPGA hardware implementation, camera logic, Vivado project, performance measurement code, and cloud-assisted FPGA implementation are documented separately from this model-code branch.

### ONNX / Unity Preparation

| File | Description |
|---|---|
| `export_to_onnx.py` | Converts `WeigntsAndBiases.txt` into the ONNX model used by Unity. |
| `export_all_test.py` | Exports all 10,000 MNIST test images and labels to binary files for Unity. |
| `export_one_test.py` | Exports one MNIST test image to a human-readable text file for validation. |

The ONNX exporter creates three fully connected stages represented as:

```text
Gemm -> Sigmoid
Gemm -> Sigmoid
Gemm -> Sigmoid
```

The input tensor has shape:

```text
[1, 784]
```

and the output tensor has shape:

```text
[1, 10]
```

The predicted digit is selected from the output neuron with the largest activation.

The Unity application code, PC and Quest benchmarking scripts, camera-processing code, and cloud client implementations are maintained separately from this model-code branch.

## Generated Files

Some files in this workflow are generated from source data and scripts rather than manually created.

Examples include:

```text
weights.mem
biases.mem
mnist_model.onnx
mnist_test_images.bin
mnist_test_labels.bin
```

These artifacts may be regenerated using the corresponding notebook or Python scripts.

## MNIST Test Data for Unity

`export_all_test.py` converts the MNIST test set into two binary files:

```text
mnist_test_images.bin
mnist_test_labels.bin
```

The image file contains 10,000 images stored as `float32` values. Each image contains 784 values representing the original 28 × 28 MNIST image.

The label file contains 10,000 corresponding labels stored as `uint8` values.

These files were used for controlled classification and performance testing in the Unity PC and Meta Quest 3S implementations.

## Software Requirements

The Python model-generation code requires Python with NumPy.

The ONNX workflow additionally uses:

```text
onnx
onnxruntime
```

A typical installation is:

```bash
pip install numpy onnx onnxruntime
```

The original model code was developed using an earlier Python environment, so minor compatibility changes may be required when reproducing the workflow with current library versions.

## Repository Scope

This branch is limited to **model preparation and deployment-model generation**.

Platform-specific implementation code is kept separately, including:

- FPGA HDL and Vivado projects;
- FPGA camera and memory architecture;
- FPGA performance instrumentation;
- Unity PC implementation;
- Meta Quest 3S implementation;
- camera-processing implementations;
- cloud-assisted inference clients; and
- experimental benchmark results.

This separation keeps the common MNIST model source distinct from the platform-specific implementations used to evaluate it.
