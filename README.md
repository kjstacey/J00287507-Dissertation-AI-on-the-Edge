# FPGA Camera Setup Notebook and Data

This branch contains the documentation notebook, photographs, wiring records, and supporting project artifacts used to document the baseline OV7670 camera setup on the ZedBoard.

The branch complements the **FPGA Camera Setup – Code** branch. The code branch contains the reusable VHDL and Vivado source required to implement the camera interface, while this branch documents how the camera was physically connected, configured, tested, and validated before dataset-specific preprocessing or neural-network hardware was added.

## Scope

This branch documents the camera-only baseline:

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

The baseline establishes a working camera-to-display pipeline that can be reused by later FPGA implementations.

This branch does **not** document:

- dataset-specific ROI selection;
- 28×28 image conversion;
- thresholding or binarization;
- neural-network input preparation;
- zyNet integration;
- inference control;
- performance benchmarking; or
- cloud-assisted FPGA processing.

Those components are documented in later dataset- and implementation-specific branches.

## Notebook

### `FPGA_Camera_Setup.ipynb`

The notebook documents the complete camera-baseline setup, including:

- hardware and development environment;
- source-code provenance;
- OV7670 control and data signals;
- ZedBoard pin assignments;
- physical jumper wiring;
- camera capture and frame-buffer architecture;
- generated 50 MHz and 25 MHz clocks;
- dual-port Block RAM use;
- VGA display output;
- diagnostic LEDs and camera reinitialization controls;
- staged troubleshooting; and
- final functional validation of the live camera feed.

The notebook intentionally stops once the camera can capture and display a recognizable image.

## Hardware Environment

The baseline camera setup used:

- ZedBoard Rev E;
- Xilinx Zynq-7000 XC7Z020CLG484-1;
- OV7670 camera module;
- VGA monitor;
- Vivado 2018.1; and
- jumper-wire connections between the camera and ZedBoard headers.

The design uses programmable-logic Block RAM for camera-frame storage.

The Zynq processing system and external DDR memory are not required for this baseline, so later Rev E DDR configuration changes are outside the scope of this branch.

## Camera-Only Project Architecture

The camera-only Vivado project uses three clock domains:

```text
100 MHz ZedBoard clock
        |
        v
     clocking
     /      \
 50 MHz    25 MHz
   |          |
   v          v
camera       VGA
control

OV7670 PCLK
     |
     v
pixel capture
     |
     v
dual-port BRAM
     |
     v
25 MHz VGA read
```

The frame buffer stores 12-bit RGB pixel values and uses 19-bit frame addressing in the baseline camera design.

## Documentation Images

The `images/` directory contains photographs taken during camera setup and troubleshooting.

Recommended filenames are:

```text
camera_zedboard_header_wiring.jpg
camera_zedboard_overview.jpg
ov7670_wiring_overview.jpg
ov7670_pin_labels.jpg
ov7670_connected_to_zedboard.jpg
zedboard_header_connection.jpg
camera_wiring_notes.jpg
final_camera_wiring_placement.jpeg
vga_initial_corrupted_output.jpg
vga_partial_camera_output.jpg
vga_working_camera_output.jpg
```

The photographs document both intermediate and final development states.

### Wiring Images

The wiring photographs show:

- OV7670 pin labels;
- jumper-wire routing;
- ZedBoard header placement;
- camera power and signal connections; and
- the final physical jumper placement used for the working camera configuration.

The `ZedBoard.xdc` file in the code branch is the authoritative source for FPGA package-pin assignments. The photographs and handwritten notes provide physical and historical setup references.

### Troubleshooting Images

The VGA photographs document the progression from an incomplete camera setup to a working feed:

```text
corrupted/striped VGA output
        |
        v
partial valid image
        |
        v
working live camera feed
```

These images are included because they provide evidence of the camera bring-up process and help distinguish camera-interface problems from later dataset-processing or NN-integration problems.

## Final Camera Wiring

`final_camera_wiring_placement.jpeg` documents the final jumper placement after the camera connection was working.

For reproduction:

1. use the constraints file from the code branch for signal-to-package-pin mapping;
2. verify the labeled OV7670 module pins;
3. use the final wiring photograph as a physical routing reference; and
4. verify camera clock and configuration activity before troubleshooting VGA output.

Jumper-wire colors should be treated as documentation aids rather than as electrical identifiers.

## Vivado Project Artifacts

This branch may also preserve selected files from the original camera-only Vivado project when useful for historical or reproducibility purposes.

The most important reusable project artifact is:

```text
blk_mem_gen_0.xci
```

which records the exact Block Memory Generator configuration used for the camera frame buffer.

The complete Vivado build directories are not required.

Files such as the following can be regenerated and do not need to be preserved:

```text
.cache/
.runs/
.gen/
.sim/
synthesis output
implementation output
temporary project files
```

If the original `.xpr` project file is kept, it should be treated as a convenience for reopening the historical project rather than as a required source artifact.

## Source and Attribution

The baseline camera implementation was adapted from:

**Alex Zhang — OV7670 Guide**

```text
https://github.com/Alexzhang1988/OV7670_guide
```

That project is based primarily on earlier OV7670 FPGA work by **Mike Field**.

The original VHDL source also notes that portions of the camera register configuration were derived from the Linux kernel `OV7670.c` driver.

The **OmniVision OV7670/OV7171 Implementation Guide** was used as supporting documentation for camera timing, register behavior, synchronization signals, and SCCB configuration.

## Validation

The camera baseline was considered functional once:

- camera configuration completed;
- the OV7670 pixel clock was active;
- `VSYNC`, `HREF`, and parallel pixel data were captured;
- frame data were written to Block RAM;
- VGA logic successfully read the stored frame; and
- a recognizable live image appeared on the VGA monitor.

The working camera feed establishes the reusable hardware baseline for later FPGA experiments.

## Relationship to Later FPGA Branches

This branch ends with:

```text
OV7670 -> Capture -> Frame BRAM -> VGA
```

Later FPGA branches extend the baseline with dataset-specific processing:

```text
OV7670
   |
   v
camera capture
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

Separating the generic camera setup from later model-specific logic allows the same camera foundation to support MNIST, EMNIST, SVHN, CIFAR, and other datasets without duplicating the hardware bring-up process.

## Repository Organization

Use:

- the **FPGA Camera Setup – Code** branch for the reusable VHDL, constraints, and Vivado IP configuration; and
- this **Notebook and Data** branch for setup documentation, photographs, historical records, and the reproducibility notebook.

Together, the two branches document both the implementation and the physical validation of the camera baseline.
