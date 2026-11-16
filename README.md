# EMNIST Models

This branch contains the selected EMNIST Balanced reference model and serves as the entry point for the model-development and implementation branches associated with the dissertation:

**Machine Learning on the Edge: Performance and Security Evaluation of Artificial Neural Network Implementations in Embedded Systems**

The EMNIST experiments extend the original MNIST handwritten-digit classification task to 47 classes representing handwritten digits and letters.

Multiple fully connected and convolutional neural network (CNN) architectures were evaluated before selecting a compact CNN for subsequent FPGA and Unity implementations.

**Status: In Progress**

The selected PyTorch reference model has been developed and validated. Additional model representations, including Unity-compatible versions, will be added as the implementation work progresses.

---

## Repository Organization

The EMNIST model work is separated into three branches:

```text
EMNIST-Models
    ├── EMNIST-Models-Code
    └── EMNIST-Models-Data-and-Notebook
```

### `EMNIST-Models`

Entry point for the selected EMNIST model artifacts.

This branch preserves the trained reference model and provides navigation to the model-development code and experimental evidence.

### `EMNIST-Models-Code`

Contains the Python source used for:

- EMNIST dataset preparation and verification;
- fully connected network training;
- CNN model development;
- model training and validation;
- architecture comparisons; and
- preliminary numerical-precision evaluation.

### `EMNIST-Models-Data-and-Notebook`

Contains the reproducibility notebook and supporting artifacts documenting:

- dataset verification;
- historical model-development experiments;
- training and validation results;
- classification accuracy;
- saved model checkpoints;
- confusion matrices;
- model comparisons; and
- preliminary quantization results.

---

# Selected EMNIST Model

The selected reference model is a compact CNN developed using the EMNIST Balanced dataset.

The model architecture is:

```text
28 × 28 × 1 Input
    ↓
Conv 3 × 3 — 16 channels — ReLU
    ↓
Max Pool 2 × 2
    ↓
Conv 3 × 3 — 32 channels — ReLU
    ↓
Max Pool 2 × 2
    ↓
Conv 3 × 3 — 64 channels — ReLU
    ↓
Global Average Pooling
    ↓
Dense 47
    ↓
argmax prediction
```

The network contains **26,351 trainable parameters**.

The validated reference-model results were:

```text
Validation accuracy:
87.10%

Test images:
18,800

Correct classifications:
16,327

Test accuracy:
86.85%
```

The compact architecture was selected to balance classification performance with model complexity and the resource limitations of the FPGA implementation.

A larger CNN achieved 89.47% test accuracy but was not selected as the primary hardware implementation model.

---

# Model Artifacts

The primary model artifacts are:

| Artifact | Purpose |
|---|---|
| `best_cnn_checkpoint_compact.pt` | Selected trained compact CNN checkpoint |
| `training_summary_compact.json` | Training configuration and reference-model validation results |

The PyTorch checkpoint preserves the selected model's trained parameters and provides the starting point for subsequent implementation work.

Additional experimental checkpoints and training results are maintained in `EMNIST-Models-Data-and-Notebook` rather than duplicated in this branch.

---

# FPGA Model Adaptation

The compact CNN was selected for implementation on the ZedBoard FPGA.

The adaptation workflow includes:

```text
Trained PyTorch Model
    ↓
Parameter Quantization
    ↓
Integer Arithmetic Reference
    ↓
Verilog CNN Implementation
    ↓
Simulation and Verification
    ↓
ZedBoard Implementation
```

The FPGA implementation uses the trained reference model as the starting point for hardware-specific parameter conversion and inference logic.

Integer arithmetic, parameter memory files, simulation results, Vivado projects, and hardware measurements are maintained in the corresponding FPGA implementation branches.

These materials are not duplicated in this model entry-point branch.

---

# Unity Model Adaptation

**Status: Planned / In Progress**

The EMNIST model will also be adapted for inference using Unity on the Windows PC and Meta Quest 3S.

The intended model workflow is:

```text
Selected PyTorch CNN
    ↓
ONNX Model Export
    ↓
Unity Inference Engine
    ↓
Windows PC / Meta Quest 3S
    ↓
CPU and GPU Evaluation
```

The Unity-compatible model has not yet been included in this branch.

Once model export and validation are completed, the corresponding ONNX model and supporting information may be added here.

The Unity implementation branches will document the application integration, execution backends, classification validation, and performance measurements.

---

# Dataset

The EMNIST Balanced dataset contains:

- 112,800 training images;
- 18,800 test images;
- 47 balanced classification categories; and
- 28 × 28 grayscale images.

Official dataset source:

https://www.nist.gov/itl/products-and-services/emnist-dataset

The dataset is not duplicated in this branch.

Dataset preparation, image orientation correction, and training procedures are documented in the model-development code and reproducibility notebook.

---

# Current Repository Scope

This branch currently represents the selected EMNIST reference model.

The remaining development work includes:

- completing additional deployment-specific model representations;
- exporting and validating a Unity-compatible ONNX model;
- documenting implementation-specific model adaptations; and
- linking the completed FPGA and Unity implementation branches.

The primary Python training scripts, complete experimental results, and development notebooks remain in their respective branches.

---

# Reproducibility Notes

The saved PyTorch checkpoint preserves the selected trained model rather than requiring a new training run.

Retraining may produce different weights or classification results depending on the training configuration and software environment.

The reference model's reported accuracy was obtained using the independent EMNIST Balanced test set.

Subsequent FPGA and Unity classification results will be reported separately because numerical representations, execution environments, and evaluation conditions may differ.

The model-development notebook documents the original training and validation workflow.

---

# Dissertation Context

This branch supports the EMNIST model development and reference-model validation presented in the dissertation.

The selected model establishes the starting point for evaluating CNN inference across the FPGA, Windows PC, and Meta Quest 3S computational environments.

The repository preserves the trained model and implementation artifacts, while the dissertation provides the formal methodology, results, performance comparisons, security evaluation, and interpretation of deployment trade-offs.

This README will be updated as the remaining EMNIST implementation work is completed.
