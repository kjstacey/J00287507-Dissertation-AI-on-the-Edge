# FPGA Camera Setup Code

This branch contains the baseline VHDL and Vivado IP used to connect an OV7670 camera module to the ZedBoard and display the captured image through VGA.

The purpose of this branch is to document the **camera hardware setup before dataset-specific preprocessing or neural-network integration**.

The code in this branch provides the common camera foundation later used by the FPGA implementations for MNIST and the additional datasets.

## Scope

This branch covers:

- OV7670 camera configuration;
- camera pixel capture;
- frame storage in Block RAM;
- VGA output;
- ZedBoard pin constraints;
- clock generation; and
- supporting control logic.

It does **not** include:

- MNIST-specific ROI selection;
- 28×28 downsampling;
- thresholding or binarization;
- neural-network input preparation;
- zyNet integration;
- dataset test ROMs;
- inference control;
- performance benchmarking; or
- cloud-assisted FPGA logic.

Those modifications are documented in later platform- and dataset-specific branches.

## Baseline Camera Pipeline

The baseline design implements the following path:

```text id="1o4v4g"
OV7670 Camera
      |
      v
Camera Configuration
      |
      v
Pixel Capture
      |
      v
Frame Block RAM
      |
      v
VGA Output
```

This configuration establishes that the camera can be initialized, captured, stored, and displayed correctly on the ZedBoard before additional image-processing or machine-learning logic is added.

## Source Files

| File | Purpose |
|---|---|
| `ov7670_top.vhd` | Camera-only top-level design connecting the OV7670, frame memory, and VGA output. |
| `ov7670_controller.vhd` | Controls initialization of the OV7670 camera. |
| `ov7670_registers.vhd` | Contains the register configuration values used to initialize the camera. |
| `ov7670_capture.vhd` | Captures camera pixel data and writes it to frame memory. |
| `i2c_sender.vhd` | Implements the serial control interface used for camera configuration. |
| `vga.vhd` | Generates VGA timing and reads image data for display. |
| `debounce.vhd` | Provides switch/button debounce support. |
| `clocking.vhd` | Clock-generation logic used by the camera/VGA design. |
| `ZedBoard.xdc` | ZedBoard pin and I/O constraints for the camera and display interfaces. |
| `blk_mem_gen_0.xci` | Vivado Block Memory Generator configuration used for frame storage. |

## Source and Attribution

The baseline camera implementation was adapted from the OV7670 ZedBoard example published at:

```text id="u8qz6r"
https://github.com/Alexzhang1988/OV7670_guide
```

That project is based primarily on earlier OV7670 FPGA work by **Mike Field**.

Several of the VHDL source files preserve the original author comments and attribution.

The camera register configuration also includes settings derived in part from the Linux kernel `OV7670.c` driver, as noted in the original source comments.

The OmniVision OV7670/OV7171 Implementation Guide was used as supporting documentation for camera configuration, timing, and register behavior.

Xilinx-generated clock and Block RAM components are included where required by the Vivado design.

## Hardware Environment

The baseline implementation was used with:

- ZedBoard Rev E;
- Xilinx Zynq-7000 XC7Z020CLG484-1;
- OV7670 camera module;
- VGA display output; and
- Vivado 2018.1.

The camera and display interfaces operate through the programmable logic of the Zynq device.

## Block RAM

The camera design uses a Vivado Block Memory Generator to store captured image data before VGA display.

The `blk_mem_gen_0.xci` file is included so the memory configuration can be recreated in Vivado.

Generated synthesis and implementation output files are not included because they can be regenerated from the source and IP configuration.

## Relationship to Later FPGA Work

This branch represents the **camera-only baseline**.

Later branches extend this design with dataset-specific processing and neural-network functionality, including:

```text id="zhp3ao"
camera input
    |
    v
dataset-specific preprocessing
    |
    v
processed image storage
    |
    v
neural-network inference
```

Keeping the baseline camera setup separate allows the same hardware foundation to be reused across MNIST, EMNIST, SVHN, CIFAR, and other FPGA experiments without mixing dataset-specific logic into the camera implementation.

## Reproducibility

To recreate the baseline camera design:

1. Create a Vivado project targeting the ZedBoard XC7Z020CLG484-1 device.
2. Add the VHDL source files from this branch.
3. Add the ZedBoard constraints file.
4. Add or regenerate the Block Memory Generator from `blk_mem_gen_0.xci`.
5. Use the included clocking configuration or regenerate the equivalent clock IP if required.
6. Synthesize, implement, and program the design.
7. Verify that the OV7670 camera feed is captured and displayed through VGA.

This branch is intended only to reproduce the working camera interface and display path before machine-learning-specific modifications are introduced.
