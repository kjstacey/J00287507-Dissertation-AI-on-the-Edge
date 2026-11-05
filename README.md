
# Machine Learning on the Edge: Dissertation Reproducibility Repository

This repository contains source code, notebooks, experimental data, screenshots, logs, and supporting documentation for the dissertation:

**Machine Learning on the Edge: Performance and Security Evaluation of Artificial Neural Network Implementations in Embedded Systems**

The repository documents the implementation and evaluation of artificial neural network inference across multiple deployment environments, including:

- FPGA-based local inference;
- FPGA-assisted cloud inference;
- Windows PC local inference;
- Meta Quest 3S local inference;
- Windows PC cloud-assisted inference; and
- Meta Quest 3S cloud-assisted inference.

The repository is organized primarily through Git branches. Branches separate model preparation, implementation code, experimental notebooks/data, camera setup, cloud integration, security evaluation, and supporting hardware documentation.

This structure preserves the development and measurement workflow without requiring every branch to duplicate the same shared files.

---

## Repository Organization

The major branch groups are:

```
Model Preparation
    └── MNIST model creation and export

FPGA Camera Setup
    └── Camera-only FPGA configuration and validation

FPGA MNIST Implementation
    ├── Local classification
    ├── Local live camera classification
    ├── Cloud classification
    └── Cloud live camera classification

Unity MNIST Implementation
    ├── Local Windows PC
    ├── Local Meta Quest 3S
    └── Cloud PC / Quest 3S

Cloud Infrastructure
    └── Server-side cloud inference implementation

FPGA Security Evaluation
    └── Configuration review, vendor advisory applicability, and Vivado screenshots

PC Security Evaluation
    └── Windows security review, Unity advisories, and configuration screenshots

Supporting Documentation
    └── Hardware manuals and specifications
```

---

# MNIST Model Preparation

The MNIST model branches document the shared neural network used as the starting point for the FPGA and Unity experiments.

The model architecture is:

```
784 input values
    ↓
Dense 30 — sigmoid
    ↓
Dense 20 — sigmoid
    ↓
Dense 10 — sigmoid
    ↓
argmax prediction
```

The network contains **24,350 trainable parameters**.

The validated test-set accuracy of the shared model was:

```
9663 / 10000
96.63%
```

## `MNIST-Models`

Entry point for the shared MNIST model artifacts.

This branch contains packaged versions of the model used by the FPGA and Unity workflows and provides navigation to the model-development branches.

## `MNIST-Models-Code`

Contains the Python source used for:

- model training;
- saved weight/bias handling;
- model validation;
- ZyNet/FPGA parameter preparation;
- ONNX export;
- MNIST binary test-data generation; and
- accuracy verification.

## `MNIST-Models-Notebooks-and-Data`

Contains the notebooks and supporting artifacts documenting:

- historical MNIST training;
- ZyNet/FPGA model preparation;
- ONNX model creation;
- model validation; and
- generated model artifacts.

---

# FPGA Camera Setup

The FPGA camera branches document the camera-only hardware pipeline used before neural-network inference was added.

The baseline camera path is:

```
OV7670 Camera
    ↓
Camera Configuration
    ↓
Pixel Capture
    ↓
Frame BRAM
    ↓
VGA Output
```

This baseline intentionally excludes MNIST preprocessing, classification, cloud communication, and benchmark logic.

## `FPGA-Camera-Setup`

Entry point for the camera-only FPGA implementation.

Includes the packaged Vivado project used as the baseline for later FPGA work.

## `FPGA-Camera-Setup-Code`

Contains the camera-related FPGA source files, including the VHDL and configuration files required for:

- OV7670 camera configuration;
- pixel capture;
- frame-buffer storage;
- VGA display; and
- ZedBoard pin configuration.

## `FPGA-Camera-Setup-Notebook-and-Data`

Contains the notebook and visual evidence documenting:

- camera wiring;
- FPGA configuration;
- camera debugging;
- progressive VGA output validation; and
- the final working camera pipeline.

---

# FPGA MNIST Implementation

The FPGA branches document local and cloud-assisted MNIST classification using the FPGA camera and model implementation.

## `MNIST-FPGA`

Entry point for the FPGA MNIST implementation.

This branch connects the model, camera, local-classification, live-classification, and cloud-classification workflows.

---

## FPGA Local Classification

### `MNIST-FPGA-Local-Classification-Measurement-Code`

Contains the source used for controlled FPGA local-classification measurements.

### `MNIST-FPGA-Local-Classification-Measurement-Notebook-and-Data`

Contains the corresponding measurement notebook, benchmark results, screenshots, logs, and supporting data.

---

## FPGA Live Local Classification

### `MNIST-FPGA-Live-Classification-Code`

Contains the FPGA source used for live camera-to-local-classification operation.

### `MNIST-FPGA-Live-Classification-Notebook-and-Data`

Documents the live local-classification workflow and supporting experimental evidence.

---

## FPGA Cloud Classification

### `MNIST-FPGA-Cloud-Classification-Measurement-Code`

Contains the FPGA/cloud client implementation used for controlled cloud-assisted classification measurements.

### `MNIST-FPGA-Cloud-Classification-Measurement-Notebook-and-Data`

Contains the controlled FPGA cloud benchmark documentation and experimental data.

---

## FPGA Cloud Live Classification

### `MNIST-FPGA-Cloud-Live-Classification-Code`

Contains the FPGA/cloud implementation used for live camera-based cloud classification.

### `MNIST-FPGA-Cloud-Live-Classification-Notebook-and-Data`

Contains the live cloud-classification notebook, measurements, screenshots, and supporting data.

---

# Unity MNIST Implementation

The Unity branches document MNIST inference on Windows PC and Meta Quest 3S.

The Unity work is divided into local and cloud-assisted execution.

## `MNIST-Unity`

Entry point for the Unity MNIST implementation.

This branch serves as the navigation layer for the PC, Quest, and cloud Unity experiments.

---

# Local Windows PC

The PC implementation uses Unity Inference Engine to execute the ONNX model locally.

Two backends were tested:

```
BackendType.CPU
BackendType.GPUCompute
```

## `MNIST-Unity-Local-PC-Code`

Contains the Unity source used for local Windows inference, including:

- Unity scene;
- C# benchmark scripts;
- local camera pipeline;
- ONNX model asset; and
- MNIST test binaries.

The same project was reused across CPU and GPU testing by changing the active inference backend and benchmark configuration.

## `MNIST-Unity-Local-PC-Data-And-Notebook`

Contains:

- Unity project setup documentation;
- CPU/GPU benchmark documentation;
- accuracy evidence;
- latency results;
- throughput results;
- process-memory evidence;
- camera benchmarks;
- power-measurement evidence;
- screenshots; and
- videos.

---

# Local Meta Quest 3S

The Quest implementation extends the working PC Unity project rather than recreating it from scratch.

The Quest-specific changes include:

```
Windows build
    → Android / Quest build

WebCamTexture
    → PassthroughCameraAccess

Desktop Main Camera
    → Meta XR rig

Mouse interaction
    → XR poke and ray interaction
```

## `MNIST-Unity-Local-Quest3S-Code`

Contains the Quest-specific code delta:

- `QuestCameraMNISTInference.cs`;
- `QuestCameraPreview.cs`;
- `SecondScene.unity`;
- Unity metadata files; and
- the Quest-enabled package manifest.

The shared PC model and benchmark assets are referenced from the local PC implementation rather than duplicated.

## `MNIST-Unity-Local-Quest3S-Data-And-Notebook`

Contains:

- PC-to-Quest conversion documentation;
- Android build configuration;
- Meta XR SDK setup;
- XR rig configuration;
- Canvas conversion;
- poke and ray interaction;
- MQDH deployment workflow;
- GPU benchmarks;
- CPU benchmarks;
- tethered testing;
- untethered testing;
- OVR Metrics logs; and
- Quest benchmark screenshots.

The local Quest benchmark sequence includes:

```
GPU tethered
GPU untethered
CPU tethered
CPU untethered
```

---

# Unity Cloud-Assisted Inference

The cloud Unity implementation reuses the existing PC and Quest scenes.

No separate cloud-specific scenes were created.

The primary change is the inference path:

```
Local:
Input
    ↓
Unity Inference Engine
    ↓
Local prediction
```

```
Cloud:
Input
    ↓
HTTP request
    ↓
Google Cloud Run
    ↓
Prediction response
```

## `MNIST-Unity-Cloud-Code`

Contains the four cloud-specific Unity scripts:

```
CloudMNISTSingleTest.cs
CloudMNISTBenchmark.cs
CloudCameraMNISTInference.cs
QuestCloudCameraMNISTInference.cs
```

These provide:

- single-image cloud validation;
- controlled 1,000-image cloud benchmarking;
- PC webcam-to-cloud inference; and
- Quest passthrough-camera-to-cloud inference.

## `MNIST-Unity-Cloud-Data-And-Notebook`

Contains the combined PC and Quest cloud benchmark documentation.

PC evidence includes:

- controlled cloud benchmarks;
- camera benchmarks;
- editor versus standalone-build observations;
- Windows memory evidence;
- power-measurement videos; and
- Internet-dependency evidence.

Quest evidence includes:

- tethered cloud benchmarks;
- untethered cloud benchmarks;
- controlled accuracy/latency/throughput;
- frozen-camera benchmarks;
- end-to-end camera benchmarks;
- live camera classification;
- live camera throughput; and
- OVR Metrics telemetry.

The cloud controlled benchmark evaluates:

```
1000 MNIST images
```

The observed cloud subset accuracy was:

```
957 / 1000
95.70%
```

This result is kept distinct from the 10,000-image local model validation result.

---

# Cloud Infrastructure

## `Cloud`

Contains the server-side cloud inference implementation and deployment materials used by the FPGA and Unity cloud-assisted experiments.

The Unity clients communicate with the deployed prediction service through HTTP requests.

The client-side MNIST representation is converted to a compact 784-byte request before transmission.

---

# FPGA Security Evaluation

## `FPGA-Security`

Contains the FPGA security evaluation notebook and two Vivado 2018.1 screenshots documenting the bitstream-generation workflow and reviewed security settings.

The notebook records the qualitative review of JTAG and debugging access, bitstream protection, pretrained model parameters, Zynq-7000 security advisories, ARM Cortex-A9 vulnerabilities, development software, and OV7670 image acquisition. It supports **Chapter IV, Section 4.7.2.1 — FPGA Deployment**.

Vivado project source and model-parameter logic are maintained in `MNIST-FPGA-Live-Classification-Code`. Vendor manuals, technical specifications, and security notices are referenced from `Manuals-and-Specifications` rather than duplicated here.

# PC Security Evaluation

## `PC-Security`

Contains the PC security evaluation notebook and 14 supporting screenshots documenting the Windows 11 Pro 25H2 security configuration of the HP ZBook Fury 17 G7 workstation.

The notebook records the qualitative review of operating-system protections, user authentication and administrator privileges, Secure Boot, TPM 2.0, BitLocker encryption, Unity software security advisories, local model and data storage, and Lumens VC-B2U USB camera access. It supports **Chapter IV, Section 4.7.2.2 — PC Deployment**.

The screenshots document Windows security settings, account configuration, installed updates, camera permissions, and the organization of experimental files.

Unity implementation code and model-loading scripts are maintained in `MNIST-Unity-Local-PC-Code`. Benchmark procedures and experimental data are maintained in `MNIST-Unity-Local-PC-Data-And-Notebook`. Microsoft and Unity security documentation and published advisories are referenced from `Manuals-and-Specifications` rather than duplicated here.

---


# Manuals and Specifications

## `Manuals-and-Specifications`

Contains archived hardware documentation and links to supporting technical references used during implementation and measurement.

Examples include documentation for:

- ZedBoard;
- OV7670 camera;
- P4400 Kill A Watt meter;
- HP ZBook workstation;
- Meta Quest 3S;
- Unity;
- Meta Quest development tools;
- Xilinx Vivado / SDK; and
- related hardware and software environments.

These materials support reproducibility of the platform configuration and measurement procedures.

---

# Experimental Design

The repository separates several measurement categories.

## Model Correctness

```
Classification accuracy
```

## Controlled Performance

```
Inference latency
Throughput
```

## Resource Requirements

```
Process memory
Device memory
FPGA hardware resources
```

## Power and Energy

```
Whole-system PC power
FPGA power
Quest device telemetry
```

## Camera/Application Performance

```
Frozen-camera inference
End-to-end camera latency
Live camera throughput
```

## Deployment Conditions

Where applicable, evidence distinguishes:

```
CPU vs GPU
Local vs cloud
Editor vs standalone build
Quest tethered vs untethered
Controlled input vs live camera
```

---

# Measurement Boundaries

Care should be taken when comparing measurements from different deployment environments because not all latency values represent the same boundary.

### Local Unity inference

Typically measures:

```
worker.Schedule()
    ↓
synchronous output readback
```

### Cloud inference

Measures:

```
request transmission
    ↓
network
    ↓
cloud processing
    ↓
response transmission
```

### Frozen-camera benchmark

Uses an already prepared camera-derived input.

### End-to-end camera benchmark

Includes camera acquisition and preprocessing before prediction.

The notebooks in each branch document the exact measurement procedure used for that environment.

---

# Recommended Navigation

A reader interested in reproducing the experiments can follow this general order.

## 1. Shared Model

```
MNIST-Models
    ↓
MNIST-Models-Code
    ↓
MNIST-Models-Notebooks-and-Data
```

## 2. FPGA Camera

```
FPGA-Camera-Setup
    ↓
FPGA-Camera-Setup-Code
    ↓
FPGA-Camera-Setup-Notebook-and-Data
```

## 3. FPGA MNIST

```
MNIST-FPGA
    ↓
Local Classification
    ↓
Live Classification
    ↓
Cloud Classification
    ↓
Cloud Live Classification
```

## 4. Unity Local PC

```
MNIST-Unity
    ↓
MNIST-Unity-Local-PC-Code
    ↓
MNIST-Unity-Local-PC-Data-And-Notebook
```

## 5. Unity Local Quest 3S

```
MNIST-Unity-Local-Quest3S-Code
    ↓
MNIST-Unity-Local-Quest3S-Data-And-Notebook
```

## 6. Unity Cloud

```
MNIST-Unity-Cloud-Code
    ↓
MNIST-Unity-Cloud-Data-And-Notebook
```

---

## 7. FPGA Security

```
FPGA-Security
    ├── FPGA security evaluation notebook
    └── Vivado bitstream evidence screenshots
```

The notebook references the FPGA implementation code and the vendor security documentation kept in their respective branches.

---

# Code and Data Branch Convention

Where practical, implementation areas are separated into:

```
...-Code
```

and:

```
...-Notebook-and-Data
```

branches.

### Code branches

Contain source code and implementation-specific assets.

### Notebook/Data branches

Contain:

- explanatory notebooks;
- benchmark procedures;
- screenshots;
- CSV files;
- hardware/resource logs;
- photographs;
- videos; and
- other experimental evidence.

Entry-point branches such as `MNIST-Models`, `FPGA-Camera-Setup`, `MNIST-FPGA`, and `MNIST-Unity` provide navigation or packaged artifacts without duplicating every development file.

---

# Reproducibility Notes

This repository preserves the implementation as it evolved during the dissertation research.

In some cases:

- the same Unity project was reused across CPU and GPU configurations;
- Quest functionality was added to the existing PC project;
- cloud functionality was added by replacing local inference components;
- screenshots preserve both Editor and standalone-build execution;
- multiple screenshots represent repeated trials rather than duplicate evidence; and
- device telemetry logs cover measurement sessions rather than one isolated benchmark.

The notebooks document these relationships so that the repository reflects the actual experimental workflow rather than an artificial reconstruction of separate projects.

---

# Current Repository Scope

The branches listed above document the **MNIST implementation and evaluation workflow**, including the FPGA security evaluation.

Additional dissertation datasets and implementation branches may be added using the same general organizational pattern as the repository is completed.

---

# License

See the `LICENSE` file included in the repository and individual branches where applicable.

---

# Dissertation Context

This repository serves as the reproducibility archive for the dissertation research.

The repository provides the implementation and experimental evidence.

The dissertation provides the formal:

- research questions;
- methodology;
- statistical analysis;
- cross-platform results;
- performance interpretation;
- security analysis;
- deployment trade-offs; and
- conclusions.

Repository artifacts should therefore be interpreted together with the corresponding dissertation methodology and results sections.
