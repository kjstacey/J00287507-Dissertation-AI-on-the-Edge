
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
    ├── MNIST model creation and export
    └── EMNIST Balanced model training, validation, and selection

FPGA Camera Setup
    └── Camera-only FPGA configuration and validation

FPGA MNIST Implementation
    ├── Local classification
    ├── Local live camera classification
    ├── Cloud classification
    └── Cloud live camera classification

FPGA EMNIST Implementation
    ├── Local CNN and live camera classification
    ├── Controlled local classification and measurement reports
    ├── Cloud live camera classification
    └── Cloud accuracy, speed, and continuous-inference measurements

Unity MNIST Implementation
    ├── Local Windows PC
    ├── Local Meta Quest 3S
    └── Cloud PC / Quest 3S

Cloud Infrastructure
    ├── MNIST Cloud Run service
    └── EMNIST Balanced Cloud Run service

FPGA Security Evaluation
    └── Configuration review, vendor advisory applicability, and Vivado screenshots

PC Security Evaluation
    └── Windows security review, Unity advisories, and configuration screenshots

Cloud-Assisted Inference Security Evaluation
    └── Client network security, HTTPS/TLS, Cloud Run access, IAM permissions, container configuration, and logging

Meta Quest 3S Security Evaluation
    └── Headset configuration, application permissions, development access, and security research

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

# EMNIST Model Preparation

The EMNIST model branches document the development and selection of a neural network for the EMNIST Balanced dataset. The dataset extends handwritten-digit recognition to 47 classes of handwritten digits and letters.

The selected compact CNN architecture is:

```text
28 × 28 × 1 input
    ↓
Conv 3 × 3 — 16 channels — ReLU
    ↓
Max Pool 2 × 2
    ↓
Conv 3 × 3 — 32 channels — ReLU
    ↓
Max Pool 2 × 2
    ↓
Conv 3 × 3 — 64 channels — ReLU
    ↓
Global Average Pooling
    ↓
Dense 47
    ↓
argmax prediction
```

The network contains **26,351 trainable parameters**.

The validated test-set accuracy of the selected model was:

```text
16,327 / 18,800
86.85%
```

The compact CNN was selected following experiments with fully connected networks and larger CNN architectures. Although the improved CNN achieved higher classification accuracy, the compact model reduced computational complexity and provided a suitable starting point for FPGA implementation.

## `EMNIST-Models`

Entry point for the selected EMNIST Balanced reference model.

This branch contains the trained compact CNN checkpoint and training summary and provides navigation to the model-development branches.

The reference model is preserved in PyTorch format. Additional representations, including a Unity-compatible ONNX model, may be added as implementation work progresses.

## `EMNIST-Models-Code`

Contains the Python source used for:

- dataset verification and orientation correction;
- fully connected model training;
- reference CNN training;
- improved CNN training;
- compact CNN development;
- model validation and comparison; and
- preliminary quantization evaluation.

The original EMNIST dataset is referenced through the official NIST source rather than duplicated in the repository.

## `EMNIST-Models-Data-and-Notebook`

Contains the reproducibility notebook and supporting artifacts documenting:

- dataset verification;
- historical fully connected network experiments;
- CNN model development;
- training and validation histories;
- saved model checkpoints;
- classification accuracy and confusion matrices;
- model-selection comparisons;
- preliminary quantization results; and
- experimental screenshots.

The notebook documents the progression from initial models to the selected compact CNN and preserves the evidence supporting model selection.

The EMNIST model-development branches are separate from the subsequent FPGA and Unity implementation branches. Hardware-specific integer inference, Verilog implementation, Unity integration, and performance measurements are documented in their respective workflows.

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

# FPGA EMNIST Implementation

The EMNIST Balanced implementation extended the established MNIST FPGA camera, memory, and cloud-communication workflows to a compact CNN with 47 output classes. The ZedBoard Rev. E was used for both autonomous inference in programmable logic and cloud-assisted classification through the Zynq ARM processing system and Google Cloud Run. Supporting camera modules and test-data generation files are referenced from their existing branches rather than duplicated.

## `EMNIST-FPGA`

Entry point for the EMNIST FPGA experiments, linking the local CNN, live-camera, controlled benchmarking, and cloud-assisted workflows.

## Local FPGA CNN and live camera

### `EMNIST-FPGA-Live-Classification-Code`

Contains the local CNN hardware modules, trained parameter memory files, FPGA sources, and bitstream used for autonomous EMNIST classification.

### `EMNIST-FPGA-Live-Classification-Notebook-and-Data`

Contains simulation and ILA verification, development documentation, Vivado evidence, and recorded live-camera classification demonstrations.

## Local FPGA controlled measurement

### `EMNIST-FPGA-Local-Classification-Measurements-Code`

Contains the controlled local FPGA implementations, 100-image-block test ROM and expected-label data, ROM-generation script, bitstreams, and relevant implementation reports and measurement evidence. The same generated EMNIST test data is reused in cloud measurement configurations.

### Local FPGA measurement reports

The additional EMNIST local FPGA measurement-report branch preserves routed power, timing, route-status, and utilization evidence for the baseline hardware configuration. The measurement code and reports use their separate branch documentation for exact filenames and build conditions.

## Cloud-assisted live camera classification

### `EMNIST-FPGA-Cloud-Live-Classification-Code`

Contains the modified top-level VHDL, FPGA bitstream, Vivado block-design Tcl, and ARM SDK `main.c` and `tcp_client.c` used for the camera-to-cloud proof of concept.

### `EMNIST-FPGA-Cloud-Live-Classification-Notebook-and-Data`

Contains the implementation notebook, Vivado block and RTL schematics, troubleshooting record, and videos documenting the successful live classification of a handwritten **F**. The live demonstration provides functional evidence rather than controlled accuracy data.

## Cloud-assisted controlled measurement

### `EMNIST-FPGA-Cloud-Classification-Measurement-Code`

Contains separate speed/accuracy and continuous-inference configurations, including their bitstreams, top-level VHDL, SDK source variants, block-design Tcl, and development notebook. The latter configuration repeatedly sends prepared images to the cloud during sustained power observations.

### `EMNIST-FPGA-Cloud-Classification-Measurement-Notebook-and-Data`

Contains consolidated SDK logs, formal and validation CSV records, run summaries, analysis notebook, Vivado reports for speed, live, and continuous configurations, and photographs/videos documenting classification, connection behavior, and physical power conditions.

The controlled FPGA cloud evaluation used **1,000 distinct EMNIST Balanced images**, processed in ten blocks of 100 with three accepted formal runs per block. It recorded **876/1,000 correct classifications (87.60%)**, **3,000 formal cloud requests**, a mean request latency of **62.659 ms**, and an effective throughput of **14.241 classifications/s**. The local FPGA accuracy on the same image subset was **87.2%**. Formal client-observed request timing is distinct from local inference latency and from Cloud Run observability metrics. The cloud server and its deployment assets are documented in `Cloud`.

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

Contains the **MNIST and EMNIST Balanced Google Cloud Run inference services**, documented separately from the FPGA and Unity clients. Both services were deployed in `us-east1` under the `mnist-cloud-fpga` project and expose a `/predict` endpoint accepting 784 raw image bytes and returning a JSON classification.

| Service | Model | Output classes | Setup notebook |
|---|---|---:|---|
| `mnist-cloud-inference` | Fully connected 784–30–20–10 NN | 10 | `Cloud_Run_Inference_Service_Setup_MNIST.ipynb` |
| `emnist-cloud-inference` | Compact CNN | 47 | `EMNIST_Cloud_Run_Inference_Service_Setup.ipynb` |

The branch also preserves the EMNIST deployment archive (`EMNIST_Cloud_Run_Service.zip`), diagnostic test archive (`EMNIST_Cloud_Test_Batch_0900.zip`), source and configuration screenshots, and request, latency, instance, CPU, and memory monitoring evidence. A diagnostic test of EMNIST images 900–999 correctly classified **91/100** images; this was an independent cloud-service check, not the formal FPGA accuracy result.

The EMNIST security evidence records internet-accessible ingress, Google-managed encryption, and an `allUsers` permission that made the service publicly callable despite the authentication selection shown in the console. Security observations and client TLS limitations are discussed in the dedicated security branches.

FPGA and Unity client code, network measurements, and device power results remain in their own implementation branches. Cloud Run request measurements must not be equated with client-observed request-response latency.

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

# Meta Quest 3S Security Evaluation

## `Quest3s-security`

Contains the Meta Quest 3S security evaluation reproducibility notebook, device configuration screenshots, and supporting security research.

The notebook documents the qualitative review of headset authentication, Developer Mode, USB debugging authorization, Horizon OS updates, application deployment, local model and data storage, passthrough camera permissions, and published security vulnerabilities. It supports **Chapter IV, Section 4.7.2.3 — Meta Quest 3S Deployment**.

The branch includes screenshots documenting the connected headset's firmware information and the November 5, 2026 operating-system update. It also contains Tahat et al. (2024), *VR Headset Ransomware Attack Vulnerability*, as supporting research concerning malicious application installation on standalone VR headsets.

Unity implementation code is maintained in `MNIST-Unity-Local-Quest-Code`. Benchmark procedures and experimental data are maintained in `MNIST-Unity-Local-Quest-Data-And-Notebook`. Official Meta documentation and published vulnerability records are referenced from `Manuals-and-Specifications`.

---

# Cloud-Assisted Inference Security Evaluation

## `Cloud-Security`

Contains the cloud-assisted inference security evaluation reproducibility notebook and seven supporting configuration screenshots.

The notebook documents the qualitative evaluation of Ethernet and Wi-Fi connectivity, TLS and HTTPS communication, transmitted data, Cloud Run authentication and public access, IAM permissions, container configuration, application security, and operational logging. It supports **Chapter IV, Section 4.7.3 — Cloud-Assisted Inference Security Results**.

The screenshots document the university network configurations used by the FPGA, PC, and Meta Quest 3S, along with Google Cloud Run networking, IAM permissions, container settings, and request logs.

The evaluation identifies implemented protections and configuration-specific concerns, including public service invocation, broad runtime service account permissions, and limitations in the FPGA's TLS implementation.

The Python inference service, dependencies, and existing deployment evidence are maintained in `Cloud`. Client implementation code and performance measurements remain in their respective implementation branches. Platform documentation and published security references are maintained in `Manuals-and-Specifications`.

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

## 1. Shared Models

```
MNIST-Models
    ↓
MNIST-Models-Code
    ↓
MNIST-Models-Notebooks-and-Data
```

```text
EMNIST-Models
    ↓
EMNIST-Models-Code
    ↓
EMNIST-Models-Data-and-Notebook
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

## 4. FPGA EMNIST

```text
EMNIST-FPGA
    ↓
Local CNN and controlled FPGA measurements
    ↓
Cloud-assisted live camera proof of concept
    ↓
Cloud speed/accuracy and continuous-inference measurements
    ↓
Cloud (EMNIST server-side deployment and monitoring)
```

See the FPGA EMNIST section for the separate Code and Notebook-and-Data branches and reused local test-data files.

## 5. Unity Local PC

```
MNIST-Unity
    ↓
MNIST-Unity-Local-PC-Code
    ↓
MNIST-Unity-Local-PC-Data-And-Notebook
```

## 6. Unity Local Quest 3S

```
MNIST-Unity-Local-Quest3S-Code
    ↓
MNIST-Unity-Local-Quest3S-Data-And-Notebook
```

## 7. Unity Cloud

```
MNIST-Unity-Cloud-Code
    ↓
MNIST-Unity-Cloud-Data-And-Notebook
```

---

## 8. FPGA Security

```
FPGA-Security
    ├── FPGA security evaluation notebook
    └── Vivado bitstream evidence screenshots
```

The notebook references the FPGA implementation code and the vendor security documentation kept in their respective branches.


## 9. Meta Quest 3S Security

**Branch:** `Quest3s-security`

- `Quest3S_Security_Evaluation_Reproducibility.ipynb` — Device security evaluation procedures, observations, and limitations.
- `Quest3S_device_info.png` — Meta Quest Developer Hub device and firmware information.
- `Quest3S_OS_version.jpg` — Horizon OS version and automatic update settings.
- `Tahat et al. - 2024 - VR Headset Ransomware Attack Vulnerability.pdf` — Supporting published research on standalone VR headset security.

**Related branches:**
- `MNIST-Unity-Local-Quest-Code`
- `MNIST-Unity-Local-Quest-Data-And-Notebook`
- `Manuals-and-Specifications`


## 10. Cloud-Assisted Inference Security

**Branch:** `Cloud-Security`

- `Cloud_Security_Evaluation_Reproducibility.ipynb` — Security evaluation procedures, configuration findings, evidence, and limitations.
- `wifi_settings.png` — University WPA2-protected research Wi-Fi configuration.
- `open_settings.png` — University open Wi-Fi configuration used by the Quest 3S.
- `ethernet_properties.png` — University wired-network environment.
- `cloud_networking.png` — Cloud Run ingress, HTTPS endpoints, and network configuration.
- `cloud_iam_permissions.png` — IAM roles and runtime service account permissions.
- `cloud_containers.png` — Container deployment and resource settings.
- `cloud_log.png` — Cloud Run operational request logs.

**Related branches:**
- `Cloud`
- `FPGA-Security`
- `PC-Security`
- `Quest3s-security`
- `Manuals-and-Specifications`


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

Entry-point branches such as `MNIST-Models`, `EMNIST-Models`, `FPGA-Camera-Setup`, `MNIST-FPGA`, and `MNIST-Unity` provide navigation or packaged artifacts without duplicating every development file.

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

The repository documents the **MNIST cross-platform implementation and evaluation workflow**, including FPGA, Windows PC, Meta Quest 3S, local and cloud-assisted inference, and security evaluation.

The repository also documents **EMNIST Balanced model development, local FPGA inference, FPGA cloud-assisted inference, live camera validation, controlled measurements, and the deployed EMNIST Cloud Run service**. The selected compact CNN and its reference model remain in the EMNIST model branches; implementation-specific sources and evidence are maintained in the corresponding FPGA and cloud branches.

EMNIST Unity implementations and subsequent SVHN and CIFAR-10 experiments may be incorporated using the same organization as work progresses.

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
