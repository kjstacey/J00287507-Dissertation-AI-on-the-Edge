# EMNIST FPGA Cloud Live Classification — Code

## Overview

This branch contains the modified Vivado and Xilinx SDK files used for the **live EMNIST FPGA-to-cloud classification implementation** on the ZedBoard Rev. E.

The implementation builds upon the existing MNIST cloud-assisted architecture and reuses the camera acquisition, image preprocessing, VGA display, and supporting hardware components from earlier FPGA implementations.

The FPGA captures a handwritten character, transfers its processed image to the Zynq ARM processing system, and receives a classification from the EMNIST CNN hosted on Google Cloud Run. The returned result is displayed using the ZedBoard's onboard LEDs.

The completed implementation successfully classified a handwritten **F**.

## Implementation Files

| File | Description |
|---|---|
| `design_1_wrapper.bit` | Generated FPGA bitstream for the live-cloud implementation |
| `FZTEBUMILV7T646.vhd` | Modified top-level VHDL for camera-to-cloud classification |
| `main.c` | ARM application initialization and network processing |
| `tcp_client.c` | HTTPS communication with the remote EMNIST inference service |
| `design_1_bd.tcl` | Vivado block-design configuration for Zynq processing and shared BRAM communication |

## Reused Components

The implementation reuses the existing camera controller, capture logic, VGA interface, clocking, and memory components. These files are maintained in earlier FPGA implementation branches and are not duplicated here.

The local EMNIST CNN and controlled test-image ROM are not included because the live-cloud configuration performs inference remotely.

## Supporting Documentation

The accompanying [EMNIST FPGA Cloud Live Classification — Notebook and Data](../EMNIST-FPGA-Cloud-Live-Classification-Notebook-and-Data) branch contains the development notebook, Vivado schematics, troubleshooting documentation, and demonstration videos.

The Cloud Run service implementation and formal classification measurements are maintained separately.

## Scope

This branch preserves the implementation-specific hardware and embedded software files used to establish the live EMNIST camera-to-cloud proof of concept. It is not intended to contain the complete Vivado project or duplicate the shared hardware components from previous implementations.
