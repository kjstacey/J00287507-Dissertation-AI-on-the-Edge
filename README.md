# EMNIST FPGA Live Classification — Notebook and Data

This branch contains the reproducibility notebook, simulation logs, Vivado implementation verification, screenshots, and videos documenting the development and functional validation of the EMNIST Balanced CNN on the ZedBoard FPGA as part of the dissertation:

**Machine Learning on the Edge: Performance and Security Evaluation of Artificial Neural Network Implementations in Embedded Systems**

The implementation adapted the compact CNN developed in Python for FPGA inference, verified its operation through incremental simulation and standalone hardware testing, and integrated the completed network with the existing OV7670 camera system.

The camera acquisition, VGA display, and stored-image functions originated from the MNIST FPGA implementation and are not documented again in detail here.

This branch focuses on the EMNIST CNN development, hardware verification, and live camera integration. The corresponding VHDL, Verilog, model parameters, and bitstream are maintained separately in `EMNIST-FPGA-Live-Classification-Code`.

---

## Repository Contents

The primary reproducibility document is:

`EMNIST_FPGA_Live_Classification_Reproducibility.ipynb`

The notebook documents:

- preparation of the Python-trained compact CNN for FPGA inference;
- integer arithmetic and quantized model parameters;
- incremental CNN construction in Vivado 2018.1;
- behavioral simulation and debugging;
- standalone CNN verification on the ZedBoard;
- integration with the existing OV7670 camera pipeline;
- image preprocessing and thresholding adjustments;
- live classification of physical characters;
- Vivado routing verification; and
- implementation limitations and reproducibility notes.

The notebook follows the chronological implementation process and references the retained experimental evidence.

---

# Compact EMNIST CNN

The implementation uses the compact CNN selected during EMNIST model development.

The network architecture is:

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

The original model contains **26,351 trainable parameters**.

The Python reference model achieved:

```text
16,327 / 18,800
86.85%
```

on the independent EMNIST Balanced test set.

This accuracy represents the trained software reference model, not the FPGA's live-camera classification accuracy.

The model training scripts, validation results, and original PyTorch checkpoint are documented in the `EMNIST-Models` branch group.

---

# Python Model to FPGA Implementation

The FPGA development began with the trained compact CNN and its integer arithmetic reference.

The implementation workflow was:

```text
Trained PyTorch CNN
    ↓
Integer Arithmetic Reference
    ↓
Weight and Bias Quantization
    ↓
Fixed-Point Scaling
    ↓
Verilog CNN Implementation
    ↓
Incremental Behavioral Simulation
    ↓
Standalone FPGA Verification
    ↓
Live Camera Integration
```

The model parameters were converted into memory initialization files for the convolutional and fully connected layers.

The CNN implementation used integer multiply-accumulate operations and layer-specific fixed-point scaling.

The file `emnist_integer_comparison.png` preserves supporting evidence from the integer-reference development process.

The corresponding Python conversion utilities and hardware-specific model parameter files are maintained with the relevant source-code branches rather than duplicated here.

---

# Incremental Vivado Development

The CNN was constructed and verified incrementally using Vivado 2018.1.

The development sequence progressed through:

1. First convolutional layer;
2. First maximum pooling layer;
3. Second convolutional layer;
4. Second maximum pooling layer;
5. Third convolutional layer;
6. Global average pooling;
7. Fully connected classification; and
8. Complete CNN operation.

The retained simulation logs document the development progression and the corrections made before successful execution.

## Simulation Logs

The branch includes the original simulation records:

```text
model_test_simulation_run1.txt
model_test2_simulation_run1.txt
model_test3_simulation_run1.txt
model_test4_simulation_run1.txt
model_test4_simulation_run2.txt
model_test5_simulation_run1.txt
model_test6_simulation_run1.txt
model_test7_simulation_run1.txt
model_test8_simulation_run1.txt
model_test9_simulation_run1.txt
model_test10_simulation_run1.txt
model_test_11_simulation_run1.txt
model_test_12_simulation_run1.txt
model_test13_simulation_run1.txt
model_test13_simulation_run2.txt
model_test_board_simulation_run1.txt
```

The original filenames and run numbers are preserved to maintain the development history.

Some logs document intermediate problems rather than successful tests. These records are retained as evidence of the iterative construction and verification process.

The reproducibility notebook identifies the relevant milestones without treating every simulation run as a successful final configuration.

---

# Standalone CNN Verification

Before camera integration, the complete compact CNN was verified using a fixed EMNIST input image stored in FPGA memory.

The final standalone simulation produced:

```text
Predicted class: 45
Predicted score: 950
```

These results matched the corresponding integer-reference expectations for the fixed test image.

The CNN was subsequently implemented on the ZedBoard and examined using Vivado's Integrated Logic Analyzer (ILA).

## Hardware Verification Artifact

`emnist_score_verification.ila`

This file preserves the earlier hardware-debug capture used to examine the standalone CNN classification output.

The ILA verification belongs to the standalone CNN demonstration project.

**The subsequent live-camera implementation did not include a debug core.**

---

# Vivado Implementation Verification

Two routing reports are preserved:

| File | Configuration |
|---|---|
| `emnist_zedboard_reve_demo_top_route_status.rpt` | Standalone compact CNN demonstration |
| `ov7670_top_route_status.rpt` | Integrated live-camera CNN |

The standalone CNN report recorded 6,654 fully routed nets and zero routing errors.

The live-camera integration report recorded 4,318 fully routed nets and zero routing errors.

These reports document successful routing of the respective implementations.

They are retained as implementation verification rather than as performance measurements.

Resource utilization, timing benchmarks, throughput, and power consumption are documented separately in the FPGA measurement workflow.

---

# OV7670 Camera Integration

Following standalone verification, the compact CNN was integrated with the working OV7670 camera configuration established during the MNIST experiments.

The integration preserved the existing camera acquisition, live-image display, stored-thumbnail display, and image-capture controls.

The primary change was replacing the CNN's fixed-image ROM input with writable memory containing camera-derived pixels.

The live classification pipeline was:

```text
OV7670 Camera
    ↓
Pixel Capture
    ↓
112 × 112 Region of Interest
    ↓
28 × 28 Downsampling
    ↓
Binary Thresholding
    ↓
Stored Image Memory
    ├── VGA Thumbnail
    └── CNN Input Memory
            ↓
        Compact EMNIST CNN
            ↓
        47-Class Prediction
            ↓
        ZedBoard LEDs
```

## Image Preprocessing

The working implementation retained the downsampling and thresholding procedure previously used for MNIST.

Pixels were sampled at four-pixel intervals from the selected camera region, producing a 28 × 28 image.

The upper four bits of each selected RGB444 pixel were compared with a threshold of seven.

The resulting input values were:

```text
Pixel value > 7  → 127
Pixel value ≤ 7  → 0
```

An initial EMNIST integration used grayscale conversion and inversion. This produced unexpected image representations and incorrect classifications.

Restoring the original MNIST thresholding and thumbnail display produced a recognizable binary image and enabled successful live character classification.

The resulting camera inputs differed from the grayscale images used during original CNN training.

---

# Live Camera Classification

The integrated FPGA implementation was tested using physical character images presented to the OV7670 camera.

The ZedBoard displayed the predicted EMNIST class using six LEDs, with an additional LED indicating completion of inference.

The tests included the digits 2 and 7 and the letters F and V.

## Classification Observations

| Physical input | Observed prediction | Result |
|---|---|---|
| Digit 2 | Class 2 | Correct |
| Digit 7 | Class 7 | Correct |
| Letter F | Class 15 | Correct |
| Letter V | Class 19 | Incorrect |

The tests confirmed that the camera-derived images reached the CNN and that the hardware completed classification for different physical inputs.

Classification behavior was affected by image positioning, illumination, and the thresholded input representation.

These demonstrations established **functional proof of concept** rather than a controlled classification accuracy measurement.

---

# Photographic Evidence

The following photographs document the live classification demonstrations:

- `emnist_2_live_classification.JPG`
- `emnist_7_live_classification.JPG`
- `emnist_F_live_classification.JPG`
- `emnist_v_live_classification.JPG`

The photographs preserve the camera setup, displayed character, and observed FPGA classification output.

They are referenced directly in the reproducibility notebook.

---

# Video Evidence

The original live-classification recordings were converted and compressed to MP4 format for repository storage.

The retained videos are:

| Character | Video |
|---|---|
| 2 | `Emnist 2 Live Classification V11-16-202609-36.mp4` |
| 7 | `Emnist 7 Live Classification V11-16-202609-36.mp4` |
| F | `Emnist F Live Classification V11-16-202609-37.mp4` |
| V | `Emnist V Live Classification V11-16-202609-50.mp4` |

The MP4 files preserve the functional demonstrations while reducing repository storage requirements.

The original MOV files are not duplicated in this branch.

The notebook links to these videos using their repository filenames.

---

# Relationship to the MNIST FPGA Implementation

The OV7670 camera system was developed and validated during the MNIST FPGA experiments.

That work already documents:

- camera wiring and configuration;
- pixel acquisition;
- VGA display;
- image storage;
- region-of-interest selection;
- downsampling;
- thresholding; and
- camera-related debugging.

The EMNIST integration reused those working components.

This notebook therefore concentrates on the modifications required to replace the MNIST NN with the compact EMNIST CNN and establish camera-based character classification.

The original MNIST FPGA notebooks should be consulted for the detailed camera development and preprocessing procedures.

---

# Reproducibility Notes

The retained simulation logs, routing reports, photographs, and videos preserve evidence of the implementation process.

The original CNN model was trained using Python and PyTorch. Its FPGA implementation used quantized parameters and custom integer arithmetic.

The standalone CNN was verified before camera integration.

The final camera implementation used the working MNIST binary preprocessing procedure rather than the original grayscale representation used during training.

The camera demonstrations involved a limited number of manually positioned physical characters under nonstandardized illumination.

Consequently, the observed classifications establish functional operation but should not be interpreted as a formal classification accuracy result.

The ILA artifact documents the earlier standalone CNN implementation and does not represent instrumentation of the final live-camera design.

---

# Repository Scope

This branch contains:

- the EMNIST FPGA live-classification reproducibility notebook;
- incremental behavioral simulation logs;
- standalone CNN hardware verification evidence;
- Vivado routing verification reports;
- integer-reference comparison evidence;
- live classification photographs; and
- compressed MP4 demonstration videos.

This branch does not contain:

- primary model-training Python scripts;
- original EMNIST dataset files;
- complete Vivado project source;
- CNN Verilog source and parameter memories;
- FPGA bitstreams;
- resource utilization measurements;
- inference latency or throughput benchmarks; or
- power consumption measurements.

These materials are maintained in their respective model, code, or measurement branches.

---

# Related Branches

## `EMNIST-Models`

Contains the selected compact CNN reference model.

## `EMNIST-Models-Code`

Contains the Python source used for model training and selection.

## `EMNIST-Models-Data-and-Notebook`

Contains the model-development reproducibility notebook, training results, and saved checkpoints.

## `EMNIST-FPGA-Live-Classification-Code`

Contains the VHDL and Verilog implementation, CNN parameter memories, Vivado IP configurations, constraints, and completed bitstream.

## MNIST FPGA Implementation Branches

Document the original OV7670 camera development, stored-image processing, local FPGA inference, and associated validation procedures.

Additional EMNIST FPGA measurement branches will document controlled classification accuracy, resource utilization, inference latency, throughput, and power consumption.

---

# Dissertation Context

This branch supports the EMNIST FPGA implementation methodology and live-camera functional-validation results presented in the dissertation.

The notebook documents the progression from the trained compact CNN to standalone FPGA inference and subsequent OV7670 camera integration.

The retained evidence demonstrates implementation development, standalone verification, and functional classification of physical character inputs.

The dissertation provides the formal methodology, results, experimental limitations, and interpretation of the completed implementation.
