# MNIST FPGA

This branch serves as the **main index for the MNIST FPGA implementation work**.

The project evolved through several stages, beginning with local live classification on the FPGA, then controlled local benchmarking, followed by FPGA-to-cloud measurement, and finally live camera-to-cloud classification.

The detailed source, notebooks, reports, media, and measurement evidence are organized into dedicated subbranches.

This main branch also contains the cross-comparison notebook:

```text
MNIST_FPGA_Implementation_Cross_Comparison.ipynb
```

which summarizes the major FPGA implementations and their results.

## MNIST Model

The MNIST classifier used throughout the FPGA work is a fully connected feed-forward neural network:

```text
784 → 30 → 20 → 10
```

The network uses sigmoid activations and selects the predicted digit from the ten output values.

Reference software accuracy:

```text
9663 / 10000
96.63%
```

The local FPGA implementation uses the generated fixed-point ZyNet RTL representation of the trained model.

The Cloud Run implementation executes the floating-point software model remotely.

## Project Progression

The FPGA work developed in the following sequence:

```text
trained MNIST model
        ↓
local FPGA live classification
        ↓
local FPGA formal measurement
        ↓
FPGA-to-Cloud formal measurement
        ↓
FPGA-to-Cloud live classification
```

Each stage has a different purpose.

The **live branches** demonstrate complete end-to-end operation with a camera-derived image.

The **measurement branches** use controlled MNIST dataset inputs to obtain reproducible quantitative results.

## Branch Organization

### Local Live Classification

```text
MNIST-FPGA-Live-Classification-Code
MNIST-FPGA-Live-Classification-Notebook-and-Data
```

These branches document the first working live FPGA classifier.

The workflow is:

```text
OV7670 camera
    ↓
ROI capture
    ↓
28 × 28 frozen image
    ↓
local ZyNet inference
    ↓
predicted digit
    ↓
ZedBoard LEDs
```

The code branch contains the FPGA source and implementation artifacts.

The Notebook-and-Data branch contains:

- development notebook;
- photographs;
- videos;
- Vivado reports;
- bitstream;
- test data; and
- other implementation evidence.

## Local Classification Measurement

```text
MNIST-FPGA-Local-Classification-Measurement-Code
MNIST-FPGA-Local-Classification-Measurement-Notebook-and-Data
```

These branches document the controlled local FPGA benchmark.

Controlled MNIST images were loaded into FPGA memory so that accuracy, latency, throughput, resource use, and power could be measured independently of manual camera capture.

Formal local results include:

```text
Accuracy:
969 / 1000
96.9%

Latency:
1,646 cycles
65.84 µs

Throughput:
15,160.8 classifications/s
```

The local measurement work used separate accuracy, speed, and continuous-inference configurations.

## FPGA-to-Cloud Measurement

```text
MNIST-FPGA-Cloud-Classification-Measurement-Code
MNIST-FPGA-Cloud-Classification-Measurement-Notebook-and-Data
```

These branches document the formal FPGA-to-Cloud Run experiments.

The measurement path is:

```text
controlled MNIST image
        ↓
programmable logic
        ↓
AXI BRAM mailbox
        ↓
Zynq Processing System
        ↓
lwIP / TCP / Mbed TLS
        ↓
HTTPS
        ↓
Google Cloud Run
        ↓
prediction
        ↓
mailbox
        ↓
programmable logic
```

The formal cloud experiment evaluated the first 1,000 MNIST test images in controlled 100-image blocks.

Formal cloud results include:

```text
Accuracy:
970 / 1000
97.0%

Typical steady-state latency:
approximately 58–60 ms

Observed formal latency range:
51.934–159.652 ms

Typical throughput:
approximately 16.8–17.1 classifications/s
```

A separate reduced-hardware FPGA build was created afterward for power and memory characterization.

The local neural-network hardware was removed from that configuration because inference was being performed remotely.

## FPGA-to-Cloud Live Classification

```text
MNIST-FPGA-Cloud-Live-Classification-Code
MNIST-FPGA-Cloud-Live-Classification-Notebook-and-Data
```

These branches document the final live camera-to-cloud implementation.

The workflow is:

```text
OV7670 camera
    ↓
freeze 28 × 28 image
    ↓
AXI BRAM mailbox
    ↓
Zynq Processing System
    ↓
Cloud Run
    ↓
returned prediction
    ↓
programmable logic
    ↓
ZedBoard LEDs
```

Unlike the formal cloud measurement version, the live implementation removes:

```text
controlled 100-image ROM
accuracy counters
per-image result records
100-image run summaries
TEST_COMPLETE storage
```

The live design sends one frozen camera image to Cloud Run and displays the returned digit directly on the board.

## Cloud Run Service

The Google Cloud Run service is documented in the separate:

```text
Cloud
```

branch.

That branch contains:

- Cloud Run setup notebook;
- service configuration;
- source and dependency documentation;
- security settings;
- observability screenshots;
- request logs; and
- dataset/model deployment notes.

This separation keeps the remote inference service independent from the FPGA and Unity client implementations.

## Cross-Comparison Notebook

This main branch contains:

```text
MNIST_FPGA_Implementation_Cross_Comparison.ipynb
```

The notebook compares the major FPGA implementations across:

- architecture;
- inference location;
- accuracy;
- latency;
- throughput;
- FPGA utilization;
- Vivado power estimates;
- physical power boundaries;
- memory requirements; and
- live deployment behavior.

The comparison keeps formal benchmark results separate from functional live demonstrations.

## High-Level Comparison

| Implementation | Input | Inference Location | Primary Purpose |
|---|---|---|---|
| Local Live | Frozen camera image | FPGA | Functional local demonstration |
| Local Measurement | Controlled MNIST | FPGA | Local benchmarking |
| Cloud Measurement | Controlled MNIST | Cloud Run | Cloud-assisted benchmarking |
| Cloud Live | Frozen camera image | Cloud Run | Functional cloud demonstration |

## Key Formal Results

| Metric | Local FPGA | FPGA-to-Cloud |
|---|---:|---:|
| Accuracy | 96.90% | 97.00% |
| Typical latency | 65.84 µs | ~58–60 ms |
| Throughput | 15,160.8/s | ~16.8–17.1/s |

The local FPGA provides substantially lower latency and higher throughput because inference occurs directly in programmable logic.

The cloud-assisted configuration reduces the amount of local inference hardware but introduces network and remote-service latency.

## FPGA Resource Comparison

The preferred local deployment baseline is:

```text
LUTs:       8,455
Registers:  4,075
BRAM:          20
DSPs:           0
```

The reduced cloud-assisted configuration used for cloud power/resource characterization is:

```text
LUTs:       2,181
Registers:  2,254
BRAM:        29.5
DSPs:           1
```

Measurement-specific builds contain additional ROM, counters, debugging logic, and instrumentation and should not be used as the primary deployment-resource comparison.

## Power Measurement Boundaries

Vivado implementation estimates and physical power measurements are both documented in the project but represent different boundaries.

### Local FPGA

The local configuration includes the complete local inference engine.

### Cloud-Assisted FPGA

Physical power measurements include:

- FPGA;
- Zynq PS;
- Ethernet;
- networking;
- TLS;
- cloud-client application.

They do **not** include the electrical power consumed by the remote Cloud Run infrastructure.

Cloud-assisted power should therefore not be interpreted as complete end-to-end cloud energy consumption.

## Repository Philosophy

The repository intentionally separates:

```text
Code
```

from:

```text
Notebook-and-Data
```

for each major implementation stage.

Code branches contain source, hardware configuration, and reproducible build artifacts.

Notebook-and-Data branches contain:

- notebooks;
- results;
- reports;
- logs;
- photographs;
- videos; and
- experimental evidence.

This structure preserves the development history while keeping individual branches focused on a specific implementation or measurement stage.

## Purpose

The purpose of the `MNIST-FPGA` branch is to provide a central entry point for the complete FPGA portion of the MNIST study.

It connects the local and cloud-assisted implementations, points to the detailed source and evidence branches, and provides a cross-comparison of the major results without duplicating the full contents of each subbranch.
