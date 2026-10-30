# FPGA Camera Setup

This branch serves as the main entry point for the baseline OV7670 camera implementation used with the ZedBoard.

The camera setup was completed before any dataset-specific preprocessing or neural-network hardware was added. It provides the reusable camera foundation later used by the FPGA implementations for MNIST and the additional datasets.

The baseline pipeline is:

```text
OV7670 Camera
      |
      v
Camera Configuration
      |
      v
Pixel Capture
      |
      v
Dual-Port Block RAM
      |
      v
VGA Display
```

## Purpose

The goal of this stage was to establish a working camera interface independently of the neural-network implementation.

The baseline verifies that the ZedBoard can:

- configure the OV7670;
- receive camera timing and pixel data;
- capture pixels in programmable logic;
- store the frame in Block RAM; and
- display the captured image through VGA.

Dataset-specific processing and NN integration are documented separately.

## Branch Organization

The FPGA camera materials are separated into supporting branches by purpose.

### Camera Setup – Code

Contains the reusable source required for the baseline implementation, including:

- VHDL camera-control logic;
- pixel-capture logic;
- VGA logic;
- clocking;
- ZedBoard constraints; and
- the Block Memory Generator configuration.

Use this branch to inspect or rebuild the camera-only design from source.

### Camera Setup – Notebook and Data

Contains:

- `FPGA_Camera_Setup.ipynb`;
- physical wiring photographs;
- handwritten wiring notes;
- troubleshooting images;
- the final wiring reference; and
- documentation of the progression from initial VGA output to a working live camera feed.

Use this branch for setup documentation and reproduction guidance.

## Camera-Only Vivado Project

This main branch also contains a ZIP archive of the original **camera-only Vivado project**.

The archive represents the working project before dataset-specific image-processing or neural-network hardware was introduced.

It includes the camera/VGA implementation using:

- ZedBoard Rev E;
- XC7Z020CLG484-1;
- OV7670 camera;
- 100 MHz board clock;
- generated 50 MHz camera-control clock;
- generated 25 MHz VGA clock;
- 12-bit RGB frame pixels;
- 19-bit frame-buffer addressing; and
- dual-port Block RAM between the camera capture and VGA display paths.

The Vivado project archive is provided as a convenience for reopening the historical implementation. The source-code branch contains the cleaner reusable source files needed to recreate the design.

## Vivado Project Scope

The archived project is limited to the generic camera baseline.

It does **not** include:

- MNIST-specific ROI selection;
- 28×28 downsampling;
- thresholding or binarization;
- processed-image storage;
- zyNet;
- model weights or biases;
- test-image ROMs;
- inference control;
- ILA instrumentation for NN benchmarking;
- Zynq PS cloud communication; or
- cloud-assisted classification.

Those features were introduced in later FPGA implementations.

## Hardware and Development Environment

The baseline was developed using:

- **ZedBoard Rev E**
- **Xilinx Zynq-7000 XC7Z020CLG484-1**
- **OV7670 camera module**
- **VGA monitor**
- **Vivado 2018.1**

The camera frame is stored in programmable-logic Block RAM.

The design does not require external DDR or Zynq processing-system memory, so Rev E DDR configuration changes used in later PS-based work are not part of this baseline.

## Source and Attribution

The baseline camera implementation was adapted from:

**Alex Zhang — OV7670 Guide**

```text
https://github.com/Alexzhang1988/OV7670_guide
```

That project is based primarily on earlier OV7670 FPGA work by **Mike Field**.

The original source also credits the Linux kernel `OV7670.c` driver for portions of the camera register configuration.

The OmniVision OV7670/OV7171 Implementation Guide was used as supporting documentation for camera timing, synchronization, SCCB communication, and register behavior.

## Validation

The camera baseline was considered complete when:

- the OV7670 initialization sequence completed;
- the camera pixel clock was active;
- the FPGA captured `VSYNC`, `HREF`, and parallel pixel data;
- frame data were written to Block RAM;
- the VGA logic read the stored frame; and
- a recognizable live camera image was displayed on the monitor.

This established a known-working hardware baseline before later image-processing and NN components were added.

## Relationship to Later FPGA Work

Later FPGA branches extend this camera foundation:

```text
OV7670
   |
   v
Camera Capture
   |
   v
Dataset-Specific Preprocessing
   |
   v
Processed Image Storage
   |
   v
Neural-Network Inference
```

Keeping the camera implementation separate allows the same hardware interface to support multiple datasets without repeating the initial camera bring-up process.

## Reproducibility

For the most useful reproduction path:

- use the **Camera Setup – Code** branch for the VHDL, constraints, and IP configuration;
- use the **Camera Setup – Notebook and Data** branch for wiring and validation documentation; and
- use the camera-only Vivado ZIP in this branch if the complete historical project is needed.
