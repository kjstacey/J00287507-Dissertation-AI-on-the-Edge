# EMNIST FPGA Implementation

## Overview

This branch serves as the main reference for the **EMNIST Balanced FPGA experiments** conducted on the ZedBoard Rev. E as part of the *Machine Learning on the Edge* dissertation research.

The experiments extended the previously developed MNIST FPGA workflow to a 47-class convolutional neural network (CNN) for handwritten character recognition.

Two deployment configurations were evaluated:

- **Local FPGA inference:** The CNN executes within the Zynq-7020 programmable logic.
- **Cloud-assisted FPGA inference:** The ZedBoard captures and preprocesses images, while Google Cloud Run performs classification.

Both configurations included controlled classification experiments, performance and resource measurements, and live-camera functional validation using the OV7670.

## Implementation and Experimental Branches

The project files are organized into separate branches to preserve implementation code, development documentation, and experimental measurements.

| Branch | Contents |
|---|---|
| EMNIST FPGA Live Classification — Code | Local CNN implementation, trained parameters, and FPGA hardware files |
| EMNIST FPGA Live Classification — Notebook and Data | Simulation results, ILA verification, and live-camera demonstrations |
| EMNIST FPGA Local Classification — Measurements and Code | Controlled test images, ROM files, FPGA configurations, accuracy and performance evidence |
| EMNIST FPGA Local Classification — Measurement Reports | Vivado utilization, timing, routing, and power reports |
| EMNIST FPGA Cloud Live Classification — Code | FPGA bitstream, modified VHDL, and ARM cloud communication code |
| EMNIST FPGA Cloud Live Classification — Notebook and Data | Development notebook, troubleshooting, schematics, and demonstration videos |
| EMNIST FPGA Cloud Classification — Measurement Code | Controlled classification and continuous-inference FPGA and SDK implementations |
| EMNIST FPGA Cloud Classification — Measurement Notebook and Data | SDK logs, CSV datasets, measurement analysis, Vivado reports, and power evidence |

The cloud inference service and its deployment files are documented separately.

## Experimental Results

Controlled evaluation used the first 1,000 images from the EMNIST Balanced test set.

| Measurement | Local FPGA | Cloud-Assisted FPGA |
|---|---|---|
| Classification accuracy | 87.2% | 87.6% |
| Correct classifications | 872/1,000 | 876/1,000 |
| Inference location | Zynq programmable logic | Google Cloud Run |

Latency, throughput, hardware resource utilization, and power measurements are documented in the respective experimental branches.

## Development Environment

- **Hardware:** ZedBoard Revision E, Xilinx Zynq-7020
- **Camera:** OV7670
- **FPGA development:** Vivado 2018.1
- **Embedded development:** Xilinx SDK 2018.1
- **Cloud inference:** Google Cloud Run
- **Dataset:** EMNIST Balanced, 47 classes

## Reproducibility

The repository preserves the trained CNN implementation, FPGA design files, controlled test inputs, measurement procedures, experimental logs, and supporting evidence.

The MNIST implementation served as the foundation for the EMNIST experiments. Shared components and previously documented procedures are referenced rather than duplicated in every branch.

This organization supports comparison of local and cloud-assisted inference while maintaining separate records for development, functional validation, and quantitative evaluation.
