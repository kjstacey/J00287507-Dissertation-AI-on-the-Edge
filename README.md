# EMNIST FPGA Live Classification — Code

This branch contains the FPGA source code, model parameters, memory configurations, hardware constraints, and bitstream used for live camera-based EMNIST Balanced classification as part of the dissertation:

**Machine Learning on the Edge: Performance and Security Evaluation of Artificial Neural Network Implementations in Embedded Systems**

The implementation integrates the compact EMNIST convolutional neural network (CNN) with the OV7670 camera system on the ZedBoard Rev E.

The design builds upon the existing FPGA camera configuration developed during the MNIST experiments. The original live-camera display, image capture, stored-thumbnail display, and camera configuration components were preserved while the MNIST neural network was replaced with the compact EMNIST CNN.

The implementation provides functional validation of the camera-to-CNN pipeline using physical character images.

---

## Implementation Overview

The live classification pipeline is:

```text
OV7670 Camera
    ↓
Camera Configuration and Pixel Capture
    ↓
112 × 112 Region of Interest
    ↓
Downsampling and Thresholding
    ↓
28 × 28 Stored Image
    ├── VGA Thumbnail Display
    └── CNN Input Memory
            ↓
        Conv1 — ReLU — MaxPool1
            ↓
        Conv2 — ReLU — MaxPool2
            ↓
        Conv3 — ReLU
            ↓
        Global Average Pooling
            ↓
        Fully Connected 47-Class Output
            ↓
        Predicted Class
            ↓
        ZedBoard LEDs
```

The FPGA performs camera acquisition, input preparation, and CNN inference locally. The implementation does not require cloud communication or a connected development computer to perform classification after programming.

---

# Hardware and Development Environment

The implementation used:

- ZedBoard Rev E with Zynq-7000 XC7Z020 FPGA;
- OV7670 camera module;
- VGA display;
- Xilinx Vivado 2018.1;
- VHDL for the camera and top-level integration;
- Verilog for the CNN processing modules; and
- memory initialization files containing trained model parameters.

The design used the existing camera clock-generation components and a 25 MHz CNN inference clock.

---

# Repository Contents

The branch preserves the source files required for the live classification implementation.

## Camera and Integration Sources

The camera subsystem originated from the working camera configuration used during the MNIST experiments.

The VHDL components include:

| Component | Purpose |
|---|---|
| `ov7670_top.vhd` | Camera/CNN integration, image preprocessing, capture control, and LED output |
| `ov7670_capture.vhd` | OV7670 pixel capture |
| `ov7670_controller.vhd` | Camera initialization and configuration |
| `ov7670_registers.vhd` | Camera register settings |
| `i2c_sender.vhd` | Camera configuration communication |
| `vga.vhd` | VGA display output |
| `clocking.vhd` | Clock generation |
| `debounce.vhd` | Button input handling |

Several camera components retain their original filenames and internal structure from the initial camera project.

The final `ov7670_top.vhd` includes the compact CNN interface and uses the restored MNIST thresholding procedure that was retained for the working live EMNIST implementation.

## CNN Verilog Sources

The compact CNN was implemented through the following hierarchy:

**Complete network and integration stages**

```text
emnist_complete_cnn_bram_top.v
conv1_bram_top.v
conv1_pool1_bram_top.v
conv1_pool1_conv2_bram_top.v
conv1_pool1_conv2_pool2_bram_top.v
conv1_pool1_conv2_pool2_conv3_bram_top.v
conv1_pool1_conv2_pool2_conv3_gap_bram_top.v
```

**Convolution controllers and arithmetic**

```text
conv1_controller_sync.v
conv2_controller_sync.v
conv3_controller_sync.v

conv3x3_mac_q24.v
conv144_mac_q24.v
conv288_mac_q24.v
```

**Pooling and classification**

```text
maxpool1_controller.v
maxpool2_controller.v
gap64_controller.v
fc47_controller.v
```

The CNN arithmetic and trained parameters were carried forward from the previously verified standalone implementation.

The camera integration modified the input-memory interface so that the first convolutional layer could process captured image data rather than the original fixed-image ROM.

---

# Model Architecture

The implemented model is the compact CNN selected during EMNIST model development.

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

The original trained model contains **26,351 trainable parameters**.

The PyTorch reference model achieved **86.85% classification accuracy** on the complete EMNIST Balanced test set.

That result represents software reference-model accuracy, not camera-based FPGA classification accuracy.

The training scripts, original checkpoint, and model-development experiments are maintained in the `EMNIST-Models` branch group.

---

# Model Parameter Files

The CNN uses memory initialization files containing the quantized model parameters.

| File | Purpose |
|---|---|
| `weights.mem` | First convolutional layer weights |
| `bias.mem` | First convolutional layer biases |
| `weights2.mem` | Second convolutional layer weights |
| `bias2.mem` | Second convolutional layer biases |
| `weights3.mem` | Third convolutional layer weights |
| `bias3.mem` | Third convolutional layer biases |
| `fc_weights.mem` | Fully connected layer weights |
| `fc_bias.mem` | Fully connected layer biases |

The implementation uses integer arithmetic and layer-specific fixed-point scaling.

The Q24 scaling multipliers are defined within the working convolution RTL rather than loaded from separate multiplier memory files.

The original `image.mem` file used for standalone CNN verification was replaced by a writable input memory populated with camera-derived pixels.

---

# Camera Image Preparation

The camera preprocessing follows the working procedure developed for MNIST.

A 112 × 112 region of the captured image is sampled at four-pixel intervals in both directions to produce a 28 × 28 representation.

The region begins at camera column 24 and row 4.

The selected pixels are thresholded using the upper four bits of the captured RGB444 representation.

The thresholding procedure produces:

```text
Pixel value > 7
    → 127

Pixel value ≤ 7
    → 0
```

The resulting 784-byte image is stored for display and supplied to the CNN input memory.

The stored thumbnail can be inspected through the VGA display before or during classification.

An alternative grayscale conversion was investigated during integration, but the original thresholding procedure was retained for the working functional demonstration.

---

# Camera Controls and Classification Output

The implementation preserves the working camera controls.

| Control | Function |
|---|---|
| Capture button | Freezes or releases the captured image |
| Stored-view switch OFF | Displays the live camera image |
| Stored-view switch ON | Displays the stored 28 × 28 thumbnail |
| LEDs 0–5 | Display the predicted EMNIST class as a binary value |
| LED 6 | Indicates completion of CNN inference |
| LED 7 | Indicates the CNN overflow diagnostic |

The network supports 47 output classes, represented by class IDs 0–46.

The predicted class is displayed using six LEDs rather than decoded into a character on the VGA display.

The EMNIST Balanced character mapping is documented in the model-development materials.

---

# Vivado Configuration

The project uses the original camera memory IP configurations:

```text
blk_mem_gen_0.xci
blk_mem_gen_stored.xci
```

The corresponding ZedBoard constraints file defines the FPGA connections for:

- system clock;
- OV7670 camera;
- VGA output;
- capture and camera configuration buttons;
- live/stored image selection switch; and
- classification LEDs.

The synthesis top is:

```text
ov7670_top
```

The implementation is a mixed-language Vivado project containing VHDL camera modules and Verilog CNN modules.

To reconstruct the design, the camera sources, complete CNN hierarchy, model parameter files, memory IP configurations, and final hardware constraints must be included.

The memory initialization files must be available to Vivado during synthesis.

---

# Bitstream

The completed bitstream is retained in this branch as the programmable FPGA artifact for the live EMNIST classification configuration.

The bitstream represents the integrated camera and CNN implementation, rather than the earlier standalone fixed-image CNN demonstration.

The supporting source files document the hardware configuration from which the implementation was constructed.

---

# Functional Validation

The integrated design was tested using physical character images presented to the OV7670 camera.

The tests confirmed that the system could:

- acquire camera images;
- generate and display the stored 28 × 28 representation;
- transfer captured pixels to the CNN;
- complete local CNN inference;
- produce different predictions for different character inputs; and
- display the predicted class through the ZedBoard LEDs.

Informal testing included successful classification of the digits **2** and **7** and the letter **F**.

Other character inputs produced incorrect classifications under the tested acquisition conditions.

Image positioning, illumination, and thresholding affected the captured representation and classification behavior.

These observations established **proof of concept for live camera-based EMNIST CNN inference**.

They were not treated as a controlled classification accuracy experiment.

Formal accuracy, inference latency, throughput, resource utilization, and power measurements are documented separately from this functional demonstration.

---

# Relationship to Previous Implementations

The implementation reused the existing OV7670 camera pipeline from the MNIST FPGA work.

The principal changes were:

- replacing the MNIST NN with the compact EMNIST CNN;
- providing writable camera-derived input memory for the first convolutional layer;
- connecting the CNN processing stages to the camera capture controls;
- supporting 47 output classes; and
- updating LED output to display a six-bit class ID and inference status.

The existing live/stored image switch, VGA display, and camera configuration remained part of the implementation.

The standalone EMNIST CNN verification preceded the camera integration. The original fixed-image testing established arithmetic and classification behavior before physical camera inputs were introduced.

---

# Reproducibility Notes

The repository preserves the final working camera integration and the CNN source hierarchy.

The parameter files correspond to the trained compact CNN selected during model development.

The working camera pipeline uses binary thresholding rather than the original grayscale representation used during PyTorch training.

Consequently, camera-based classification behavior may differ from software reference-model accuracy.

The live-camera tests were intended to demonstrate functional integration. They did not establish classification accuracy over a standardized physical character dataset.

Generated Vivado caches, intermediate prototype modules, duplicate IP netlists, and earlier diagnostic configurations are not required for this branch.

---

# Related Branches

## `EMNIST-Models`

Contains the selected trained EMNIST reference model.

## `EMNIST-Models-Code`

Contains the Python model-development and training scripts.

## `EMNIST-Models-Data-and-Notebook`

Contains model-development reproducibility documentation, training results, saved checkpoints, and model-selection evidence.

## `EMNIST-FPGA-Live-Classification-Notebook-and-Data`

Intended to preserve the live camera integration procedure, screenshots, functional-validation observations, and supporting experimental evidence.

Additional FPGA measurement branches will document controlled classification accuracy, inference timing, hardware utilization, and power consumption separately.

---

# Dissertation Context

This branch supports the EMNIST live-camera FPGA integration methodology and functional-validation results described in the dissertation.

The implementation demonstrates that the selected compact CNN can be integrated with the existing OV7670 acquisition system and execute classification locally on the ZedBoard.

The repository preserves the implementation source and programmable artifact.

The dissertation provides the formal methodology, results, experimental limitations, and interpretation of the hardware implementation.
