# EMNIST FPGA Cloud Classification — Measurement Code

## Overview

This branch contains the modified Vivado and Xilinx SDK files used for **controlled EMNIST cloud-assisted FPGA classification and continuous-inference testing** on the ZedBoard Rev. E.

The implementation builds upon the MNIST cloud accuracy workflow, adapting it for the 47-class EMNIST Balanced CNN hosted on Google Cloud Run.

Two configurations were developed: one for controlled accuracy, latency, and throughput measurements, and another for continuous inference during power testing.

## Implementation Files

| File | Description |
|---|---|
| `design_1_wrapper_speed.bit` | FPGA bitstream for controlled classification measurements |
| `top_speed.vhd` | Top-level VHDL for the speed/accuracy configuration |
| `mainemnistaccuracy.c` | ARM application for controlled measurements |
| `tcp_clientemnistaccuracy.c` | Cloud communication and classification recording |
| `design_1_wrapper_continuous.bit` | FPGA bitstream for continuous inference |
| `top_continuous.vhd` | Top-level VHDL for continuous operation |
| `main_emnist_power.c` | ARM application for sustained power testing |
| `tcp_client_power.c` | Cloud communication during continuous inference |
| `design_1_bd.tcl` | Vivado Zynq and shared BRAM block design |
| `emnist_measurements_block_diagram.png` | Vivado block-design documentation |

## Development Notebook

[EMNIST FPGA Cloud Measurement Code Development Notebook](EMNIST_FPGA_Cloud_Classification_Measurement_Code_Development.ipynb)

The notebook documents the adaptation from MNIST cloud classification to EMNIST and the subsequent modifications for continuous cloud inference.

## Reused Components

The implementation reuses camera, memory, and supporting FPGA components from earlier projects. EMNIST test-image ROM data and expected-label files are maintained in the `EMNIST-fpga-local-classification-measurements-code` branch and are not duplicated here.

## Experimental Data

The corresponding `EMNIST-FPGA-Cloud-Classification-Measurement-Notebook-and-Data` branch contains the SDK measurement logs, CSV datasets, Vivado reports, power observations, and experimental analysis.

## Scope

This branch preserves the implementation-specific code for controlled EMNIST cloud classification and continuous-inference testing. Live camera classification and Google Cloud Run service deployment are documented in separate branches.
