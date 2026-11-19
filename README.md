# EMNIST FPGA Cloud Classification — Measurement Notebook and Data

## Overview

This branch contains the experimental data, analysis notebook, Vivado reports, and supporting evidence for the **EMNIST cloud-assisted FPGA classification experiments** conducted using the ZedBoard Rev. E.

The implementation reused the MNIST FPGA-to-cloud workflow, adapting it for the 47-class EMNIST Balanced CNN hosted on Google Cloud Run.

The experiments evaluated classification accuracy, request latency, throughput, FPGA resource utilization, and power consumption.

## Measurement Notebook and Data

| File | Description |
|---|---|
| [Measurement Notebook](EMNIST_FPGA_Cloud_Classification_Measurement.ipynb) | Experimental procedures, analysis, and results |
| [Formal Classification Records](EMNIST_FPGA_Cloud_Formal_Classification_Records.csv) | 3,000 classification requests from 30 formal runs |
| [Validation Records](EMNIST_FPGA_Cloud_Validation_Records.csv) | 1,000 requests from ten validation runs |
| [Run Summaries](EMNIST_FPGA_Cloud_Run_Summaries.csv) | Accuracy, latency, and throughput summaries for all 40 runs |
| [Complete SDK Results Log](EMNIST_FPGA_Cloud_SDK_Result_Logs_Complete.md) | Original experimental output and measurement records |

## Summary of Results

| Measurement | Result |
|---|---|
| Distinct test images | 1,000 |
| Formal classification requests | 3,000 |
| Classification accuracy | 87.60% |
| Mean request latency | 62.659 ms |
| Effective throughput | 14.241 classifications/s |
| Communication errors during accepted runs | 0 |

The notebook provides the detailed analysis and distinguishes formal measurements from preliminary validation and startup observations.

## Vivado Reports

The branch includes placed-utilization, routed-timing, and routed-power reports for three FPGA configurations:

- **Continuous:** Sustained cloud inference and power measurement.
- **Live:** Camera-to-cloud classification implementation.
- **Speed:** Controlled classification performance testing.

These reports document hardware resource requirements and implementation characteristics.

## Supporting Evidence

The branch also includes photographs and videos documenting the ten controlled 100-image blocks, cloud connection behavior, continuous inference, and physical power measurements with and without development USB connections.

## Scope

This branch preserves the experimental evidence and analysis for the EMNIST cloud-assisted FPGA implementation.

The live camera demonstration, implementation source code, and Google Cloud Run service files are maintained in separate repository branches.
