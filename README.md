# MNIST Model Artifacts

This branch serves as the main entry point for the MNIST model used in the dissertation project.

The MNIST network is a fully connected feed-forward neural network with the architecture:

```text
784 -> 30 -> 20 -> 10
```

using sigmoid activation after each fully connected layer.

The network contains **24,350 trainable parameters** and was used as the common model for the FPGA, PC, Meta Quest 3S, and cloud-assisted MNIST experiments.

## Repository Structure

The MNIST model materials are separated into branches based on purpose.

### Model Code Branch

The model-code branch contains the Python source used to:

- train and load the MNIST model;
- verify Python classification accuracy;
- prepare the model for ZyNet/FPGA use;
- convert the model to ONNX;
- generate FPGA parameter files; and
- generate the MNIST test-data files used by Unity.

This branch is intended for users who want to inspect or reproduce the model-processing code.

### Model Notebooks and Data Branch

The notebooks/data branch contains:

- `MNIST_ZyNet_Model_Creation.ipynb`;
- `MNIST_ONNX_Model_Creation.ipynb`;
- historical model-development screenshots;
- packaged ZyNet-generated artifacts; and
- packaged ONNX model artifacts.

This branch provides step-by-step documentation of how the deployable model representations were created.

## Files in This Branch

This main branch contains packaged model artifacts for convenient access.

| File | Description |
|---|---|
| `mnist_onnx_model.zip` | ONNX model and supporting artifacts used by the Unity PC and Meta Quest 3S implementations. |
| `zynet_fpga_model_parameters.zip` | FPGA model parameter files generated from the trained MNIST network. |
| `zynet_model_fpga_src.zip` | ZyNet-generated FPGA source associated with the MNIST model. |

These packages provide the model-level artifacts needed by the platform-specific implementations without requiring the reader to reproduce the conversion process first.

## Model Deployment Paths

The same trained MNIST network was prepared for two primary local deployment paths:

```text
                         Trained MNIST Model
                                |
               +----------------+----------------+
               |                                 |
               v                                 v
          ZyNet / FPGA                      ONNX / Unity
               |                                 |
               v                                 v
     FPGA parameters and                 mnist_model.onnx
       generated source                         |
               |                                 v
               v                         PC / Meta Quest 3S
            ZedBoard
```

The cloud-assisted implementations used the same MNIST classification model through the corresponding remote inference workflow.

## Model Validation

The software version of the model classified:

```text
9,663 / 10,000
```

MNIST test images correctly, corresponding to:

```text
96.63%
```

classification accuracy on the complete MNIST test set.

The ONNX representation used by Unity reproduced the same controlled classification accuracy.

The FPGA implementation used the same trained network parameters but required a separate hardware representation and numerical implementation.

## Scope of This Branch

This branch contains **model-level artifacts only**.

The following are maintained separately:

- FPGA hardware integration;
- Vivado projects;
- camera acquisition and preprocessing;
- FPGA latency and throughput instrumentation;
- PC Unity implementation;
- Meta Quest 3S Unity implementation;
- CPU and GPU benchmarks;
- cloud-assisted inference clients;
- power and memory measurements; and
- experimental results.

This organization separates model creation and conversion from the platform-specific implementation and benchmarking code used in the dissertation experiments.

## Reproducibility

For detailed reproduction of the model artifacts:

- use the **model-code branch** for the underlying Python source; and
- use the **model notebooks and data branch** for the documented ZyNet and ONNX workflows.

The packaged ZIP files in this branch provide the resulting model artifacts used by the deployment implementations.
