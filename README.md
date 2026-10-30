# MNIST Model Notebooks and Data

This branch contains the reproducibility notebooks, supporting documentation images, and packaged model artifacts for the MNIST portion of the dissertation project.

The branch complements the MNIST model-code branch. The model-code branch contains the Python source used to train, convert, and validate the MNIST network, while this branch provides the notebooks and generated artifacts needed to document and reproduce the two deployment-model preparation workflows.

The MNIST network used throughout the study has the architecture:

```text
784 -> 30 -> 20 -> 10
```

with sigmoid activation after each fully connected layer.

The network contains **24,350 trainable parameters**.

## Notebooks

### `MNIST_ZyNet_Model_Creation.ipynb`

Documents preparation of the trained MNIST model for the ZyNet FPGA implementation.

The notebook covers the steps required to reproduce the model artifacts used by the FPGA workflow, including:

- loading the trained network;
- examining the network architecture and activation functions;
- converting the trained parameters for ZyNet;
- generating the weight and bias memory files used by the FPGA implementation; and
- documenting the generated RTL associated with the ZyNet model.

The FPGA hardware integration, camera-processing logic, benchmarking logic, and Vivado implementation are maintained separately from this branch.

### `MNIST_ONNX_Model_Creation.ipynb`

Documents conversion of the same trained MNIST model to the ONNX representation used by Unity Inference Engine / Sentis.

The notebook covers:

- loading the saved trained model;
- verifying the `784 -> 30 -> 20 -> 10` architecture;
- validating the Python model on the MNIST test set;
- converting the three fully connected layers to ONNX `Gemm` operations;
- preserving sigmoid activation after each layer;
- validating the ONNX graph;
- comparing Python and ONNX predictions;
- validating ONNX classification accuracy on the complete 10,000-image MNIST test set; and
- generating the MNIST test-data files used by the Unity implementations.

The ONNX model used by the PC and Meta Quest 3S implementations produced **96.63% classification accuracy (9,663 / 10,000)** on the complete MNIST test set.

## Packaged Model Artifacts

### `zynet_generated_rtl.zip`

Contains the ZyNet-generated RTL and related model files created from the trained MNIST network.

These files represent the model-generation output used as the basis for the FPGA implementation.

Platform-specific modifications, integration code, camera logic, BRAM architecture, timing instrumentation, and cloud-assisted FPGA code are maintained separately.

### `mnist_onnx_model.zip`

Contains the ONNX model and supporting files used by the Unity deployment workflow.

This package includes the model representation and related test-data artifacts used by the PC and Meta Quest 3S implementations.

The ONNX model represents the network as:

```text
Gemm -> Sigmoid
Gemm -> Sigmoid
Gemm -> Sigmoid
```

with input shape:

```text
[1, 784]
```

and output shape:

```text
[1, 10]
```

## Historical Documentation Images

The following images document the original MNIST model-development environment and results:

| File | Description |
|---|---|
| `mnist_historical_training_script.png` | Original training script showing the MNIST network configuration and training call. |
| `mnist_saved_model_file.png` | Saved `WeightsAndBiases` model artifact created during the original workflow. |
| `mnist_sigmoid_activation.png` | Original implementation of the sigmoid activation function used by the network. |
| `mnist_training_results.png` | Console output from the original training process showing evaluation accuracy during the final epochs. |

These images are included as historical documentation rather than as required inputs for reproduction.

## Relationship Between the Two Model Paths

Both deployment paths begin with the same trained MNIST network.

```text
                        Trained MNIST Model
                               |
              +----------------+----------------+
              |                                 |
              v                                 v
        ZyNet / FPGA                      ONNX / Unity
              |                                 |
              v                                 v
      Generated RTL and                  mnist_model.onnx
      parameter memories                       |
              |                                 v
              v                         PC / Meta Quest 3S
           ZedBoard
```

The FPGA and Unity implementations therefore evaluate different execution environments using the same underlying trained network rather than independently trained models.

## Repository Organization

This branch is intended to answer:

> How were the deployable MNIST model artifacts created and documented?

It does not contain the complete experimental implementations.

Separate branches or directories should contain:

- FPGA HDL integration and Vivado projects;
- camera acquisition and preprocessing;
- FPGA benchmarking and measurement logic;
- PC Unity implementation;
- Meta Quest 3S Unity implementation;
- local CPU and GPU benchmark scripts;
- cloud-assisted inference clients;
- performance results; and
- security-analysis artifacts.

Keeping these components separate distinguishes **model preparation** from **platform deployment and experimental measurement**.

## Dissertation Context

The MNIST workflow establishes the initial cross-platform model-preparation and deployment process used in the dissertation.

The notebooks and packaged artifacts in this branch support reproducibility of the model representations used for:

- FPGA inference;
- PC CPU inference;
- PC GPU inference;
- Meta Quest 3S CPU inference;
- Meta Quest 3S GPU inference; and
- cloud-assisted implementations using the same MNIST model.
