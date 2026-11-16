# EMNIST Models — Notebook and Data

This branch contains the reproducibility notebook, experimental results, saved model parameters, screenshots, and supporting data for the EMNIST Balanced model-development experiments conducted as part of the dissertation:

**Machine Learning on the Edge: Performance and Security Evaluation of Artificial Neural Network Implementations in Embedded Systems**

The EMNIST experiments extended handwritten digit recognition to 47 classes representing handwritten digits and letters. The model-development process evaluated multiple fully connected and convolutional neural network (CNN) architectures before selecting a compact CNN for subsequent FPGA and Unity implementations.

This branch preserves the experimental evidence supporting model development, validation, comparison, and selection. The corresponding Python source code is maintained separately in `EMNIST-Models-Code`.

---

## Repository Contents

The primary reproducibility document is:

`EMNIST_Model_Development_Reproducibility_Revised.ipynb`

The notebook documents:

- EMNIST Balanced dataset verification and image orientation;
- initial fully connected network experiments;
- expanded fully connected network architectures;
- reference and improved CNN experiments;
- compact CNN development and selection;
- training and validation results;
- saved model checkpoints;
- classification accuracy and confusion matrices;
- preliminary quantization comparisons; and
- final model artifacts and reproducibility considerations.

The notebook follows the chronological model-development workflow and includes screenshots retained from the original experiments.

---

# EMNIST Balanced Dataset

The experiments used the EMNIST Balanced dataset, consisting of:

- 112,800 training images;
- 18,800 test images;
- 47 balanced classification categories; and
- 28 × 28 grayscale images.

The official dataset is available from the National Institute of Standards and Technology:

https://www.nist.gov/itl/products-and-services/emnist-dataset

The original dataset files are not duplicated in this branch.

The model-development scripts corrected the orientation of the original IDX images and used a stratified training and validation partition.

## Dataset Verification

The retained dataset verification artifacts include:

- `EMNIST_Balanced_Orientation_Check.png` — Original versus corrected image orientation.
- `EMNIST_Balanced_Reference_Vectors.npz` — Reference image vectors and corresponding class labels.
- `EMNIST_Balanced_Verification_Summary.txt` — Dataset structure, image dimensions, and class mapping.
- `emnist_verifier_results.png` — Screenshot documenting dataset verification.

The verification process confirmed the expected image dimensions, dataset sizes, class distribution, and label mapping.

---

# Model Development

The experiments progressed from fully connected networks to convolutional architectures.

```text
EMNIST Balanced Dataset
    ↓
Dataset Verification
    ↓
Initial Fully Connected Models
    ↓
Expanded Fully Connected Models
    ↓
Reference CNN
    ↓
Improved CNN
    ↓
Compact CNN
    ↓
Model Comparison and Selection
    ↓
FPGA and Unity Implementation
```

## Fully Connected Network Experiments

The initial experiments evaluated dense neural networks adapted from the original MNIST model-development approach.

Retained artifacts include:

- `EMNIST_Balanced_baseline_Training_Summary.json`
- `EMNIST_Balanced_baseline_WeightsAndBiases...`
- `EMNIST_Balanced_expanded_Training_Summary.json`
- `EMNIST_Balanced_expanded_Best_WeightsAndBiases...`
- `EMNIST_Balanced_expanded_Final_WeightsAndBiases...`
- `EMNIST_Balanced_MLP200_Best_WeightsAndBiases...`
- `EMNIST_Balanced_MLP200_Final_WeightsAndBiases...`
- `training_summary_mlp200.json`
- `validation_history_mlp200.csv`
- `best_mlp_checkpoint.pt`
- `final_mlp_checkpoint.pt`

The original filenames are preserved in the repository. Truncated names above identify the corresponding weights-and-biases artifacts.

Supporting screenshots document the historical training runs, model evaluation, and development results.

These experiments provided comparisons of fully connected architectures before convolutional models were evaluated.

---

# CNN Experiments

The CNN experiments evaluated spatial feature extraction for handwritten character classification.

Three CNN configurations were examined:

1. Reference CNN;
2. Improved CNN; and
3. Compact CNN.

## Reference CNN

The initial CNN experiment provided a convolutional reference for comparison with the fully connected models.

Retained artifacts include:

- `best_cnn_checkpoint.pt`
- `training_summary.json`
- `validation_history.csv`
- `test_confusion_matrix.csv`
- `emnist_cnn_train_result.png`

## Improved CNN

The improved CNN incorporated additional regularization and image augmentation.

Retained artifacts include:

- `best_cnn_checkpoint_improved.pt`
- `training_summary_improved.json`
- `validation_history_improved.csv`
- `emnist_cnn2_train_result.png`

The improved CNN achieved a test accuracy of **89.47%**.

## Compact CNN

The compact CNN was developed to reduce model complexity while maintaining sufficient classification performance for subsequent FPGA implementation.

The selected architecture is:

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

The selected model contains **26,351 trainable parameters**.

Its validation and test results were:

```text
Validation accuracy:
87.10%

Test classifications:
16,327 / 18,800

Test accuracy:
86.85%
```

Retained artifacts include:

- `best_cnn_checkpoint_compact.pt`
- `training_summary_compact.json`
- `validation_history_compact.csv`
- `test_confusion_matrix_compact.csv`
- `emnist_compact_train_result.png`

The selected checkpoint preserves the trained parameters used as the starting point for subsequent implementation work.

---

# Model Comparison and Selection

The improved CNN achieved higher classification accuracy than the compact CNN. However, the compact architecture reduced model complexity and was selected for implementation on the ZedBoard FPGA.

The model-development workflow also examined the effects of reduced numerical precision.

Retained comparison artifacts include:

- `quantization_comparison.csv`
- `technical_details.json`
- `emnist_quantization_comparison.png`

These comparisons informed model selection and the feasibility of adapting the selected CNN to integer arithmetic.

The preliminary quantization experiments were software evaluations and should not be interpreted as FPGA hardware accuracy or performance measurements.

---

# Experimental Screenshots

The repository retains screenshots documenting the original training and verification sessions.

These include:

- `emnist_epoch_100_results1.png`
- `emnist_epoch_100_results2.png`
- `emnist_smoke_test1.png`
- `emnist_smoke_test2.png`
- `emnist_mlp_smoke_test.png`
- `emnist_mlp_train_result.png`
- `emnist_cnn2_smoke_test.png`
- `emnist_cnn2_train_result.png`
- `emnist_compact_smoke_test.png`
- `emnist_compact_train_result.png`

Smoke-test screenshots document initial execution checks rather than final classification results.

The complete training results and saved model artifacts provide the authoritative evidence for the reported model performance.

The reproducibility notebook places relevant screenshots alongside the corresponding development stages.

---

# Saved Model Artifacts

The repository preserves the trained model checkpoints and supporting weights-and-biases files.

The checkpoints provide the exact trained parameter values associated with the completed experiments.

The compact CNN checkpoint is particularly important because it establishes the common reference model for the subsequent FPGA and Unity implementations.

The notebook and data branch preserves the trained artifacts, while implementation-specific parameter conversion and inference execution are documented in separate branches.

---

# Reproducibility Notes

The model-development notebook uses the retained training summaries, validation histories, checkpoints, and classification results to document the experimental progression.

The dataset is not included in this repository and must be obtained separately from NIST if retraining is required.

The associated training scripts are available in `EMNIST-Models-Code`.

Retraining may produce different numerical parameters or classification results depending on the software environment and training configuration. The retained checkpoints preserve the trained model instances used in the documented experiments.

The reference software results remain separate from subsequent FPGA classification accuracy, integer arithmetic verification, hardware resource utilization, inference latency, and power measurements.

---

# Repository Scope

This branch contains:

- the EMNIST model-development reproducibility notebook;
- dataset verification artifacts;
- model training summaries;
- saved weights and biases;
- trained model checkpoints;
- validation histories;
- confusion matrices;
- model comparison results; and
- historical experimental screenshots.

This branch does not contain:

- the original EMNIST dataset;
- the primary model-training Python scripts;
- FPGA Verilog source;
- Vivado projects;
- hardware-specific inference test vectors;
- FPGA latency or power benchmarks; or
- Unity implementation code.

These materials are maintained in their respective repository branches.

---

# Related Branches

## `EMNIST-Models-Code`

Contains the Python source used for EMNIST dataset preparation, model training, validation, and comparison.

## FPGA Implementation Branches

Document conversion of the selected CNN into hardware-compatible representations, FPGA implementation, simulation, and hardware validation.

## Unity Implementation Branches

Document adaptation of the selected trained model for Windows PC and Meta Quest 3S inference.

The master repository README provides the complete branch organization and navigation.

---

# Dissertation Context

This branch supports the EMNIST model-development methodology and reference-model validation presented in the dissertation.

The reproducibility notebook and associated artifacts preserve the experimental development history and supporting results.

The dissertation provides the formal interpretation of model selection, classification performance, implementation requirements, and subsequent comparisons among the evaluated computational platforms.
