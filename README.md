# EMNIST FPGA Cloud Live Classification — Notebook and Data

## Overview

This branch documents the live EMNIST cloud-assisted classification implementation using the ZedBoard Rev. E and OV7670 camera.

The implementation reused the MNIST FPGA-to-cloud workflow, adapting it for the 47-class EMNIST CNN hosted on Google Cloud Run. Functional validation confirmed the successful classification of a handwritten **F**.

## Development Notebook

[EMNIST FPGA Cloud Live Classification Notebook](EMNIST_FPGA_Cloud_Live_Classification.ipynb)

The notebook documents the system architecture, implementation process, shared-memory communication, Vivado schematics, and functional validation.

## Demonstration Videos

- [Live EMNIST Cloud Classification](emnist_cloud_live_classification.mp4)
- [ZedBoard Hardware Overview](emnist_cloud_overview_board.mp4)

## Vivado Schematics

- [Block Design](emnist_live_blockdesign.png)
- [Elaborated RTL Schematic](emnist_live_elaborted_rtl.png)

## Development and Troubleshooting

[EMNIST FPGA Cloud Live Classification — Development and Troubleshooting](EMNIST_FPGA_Cloud_Live_Classification_Development_and_Troubleshooting.md)

This record summarizes the development changes and troubleshooting completed during the transition from MNIST to EMNIST cloud-assisted classification.

## Scope

This branch contains the notebook and supporting evidence for the **live camera-to-cloud proof of concept**.

The Vivado and Xilinx SDK source code, Cloud Run service implementation, and controlled accuracy, latency, throughput, power, and resource measurements are maintained in separate repository branches.
