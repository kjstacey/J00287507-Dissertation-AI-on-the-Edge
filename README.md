# Manuals and Specifications

This branch contains manuals, hardware specifications, archived vendor documentation, and official online references for the hardware and software environments used in the dissertation experiments.

The purpose of this branch is to provide a single reference location for platform specifications, development-tool documentation, instrumentation manuals, and vendor resources associated with the FPGA, PC, Meta Quest 3S, Unity, and cloud-assisted implementations.

## Archived Manuals and Specifications

The following files are stored directly in this branch.

| File | Purpose |
|---|---|
| `FPGA Camera Specs.pdf` | OV7670 camera specifications and implementation information used for the FPGA camera interface. |
| `zedboard-schematic-rev-e1-public.pdf` | ZedBoard Rev E schematic used as a hardware reference for the FPGA implementation. |
| `2026 - P4400 KILL A WATT TM Operation Manual.pdf` | Operation manual for the Kill A Watt meter used for external power measurements. |
| `HP_ZBook_Fury_17_G7_User_Guide.html` | Archived HP support and user-guide page for the PC platform used in the study. |

## Official Online References

The following official vendor documentation provides specifications and development references for the software and hardware environments used in the study.

### Meta Quest 3S

- [Meta Quest device specifications and comparison](https://developers.meta.com/vr/essentials/compare-devices/)
- [Meta Quest Unity development overview](https://developers.meta.com/vr/documentation/unity/unity-development-overview/)
- [Meta Quest Developer Hub documentation](https://developers.meta.com/vr/documentation/spatial-sdk/meta-quest-developer-hub/)
- [OVR Metrics Tool documentation](https://developers.meta.com/vr/documentation/unity/ts-ovrmetricstool/)
- [OVR Metrics Tool statistics guide](https://developers.meta.com/vr/documentation/unity/ts-ovrstats/)
- [Meta Quest Developer Hub Performance Analyzer and Metrics](https://developers.meta.com/vr/documentation/unity/ts-mqdh-logs-metrics/)

These resources document the Meta Quest 3S hardware and development environment, Meta Quest Developer Hub, and OVR Metrics Tool used for device-side performance monitoring.

OVR Metrics Tool provides runtime measurements associated with application and headset behavior, including frame rate, CPU and GPU utilization, memory-related information, thermal and throttling indicators, and other device-performance statistics. Meta Quest Developer Hub was used to support device management, application deployment, logging, and performance monitoring.

### Unity

- [Unity Editor 6000.3.22f1 release information](https://unity.com/releases/editor/whats-new/6000.3.22f1)
- [Unity 6 Meta Quest development documentation](https://docs.unity.com/en-us/engine/6000.3/manual/xr/configuring-project-for/meta-quest-develop)
- [Unity Inference Engine documentation](https://docs.unity3d.com/Packages/com.unity.ai.inference@latest/)

The dissertation experiments used Unity Editor **6000.3.22f1** and Unity Inference Engine / Sentis for ONNX model execution on the PC and Meta Quest 3S.

Unity supported:

- CPU inference;
- GPU Compute inference;
- controlled MNIST benchmarking;
- camera-based inference;
- Meta Quest deployment;
- XR interaction; and
- cloud-assisted client applications.

### FPGA Development

- [Vivado Design Suite 2018.1 Release Notes, Installation, and Licensing Guide (UG973)](https://docs.amd.com/v/u/2018.1-English/ug973-vivado-release-notes-install-license)
- [Vivado Design Suite 2018.1 Implementation Guide (UG904)](https://docs.amd.com/v/u/2018.1-English/ug904-vivado-implementation)
- [Xilinx SDK / XSCT 2018.1 Reference Guide (UG1208)](https://docs.amd.com/v/u/2018.1-English/ug1208-xsct-reference-guide)
- [Xilinx SDK 2018.1 System Performance Analysis Guide (UG1145)](https://docs.amd.com/v/u/2018.1-English/ug1145-sdk-system-performance)

Vivado 2018.1 was used for FPGA:

- behavioral simulation;
- synthesis;
- implementation;
- IP configuration;
- bitstream generation;
- hardware programming; and
- Integrated Logic Analyzer debugging.

Xilinx SDK 2018.1 was used for the Zynq processing-system software associated with the cloud-assisted FPGA implementation.

### HP ZBook Fury 17 G7

- [HP ZBook Fury 17 G7 setup and user guides](https://support.hp.com/us-en/product/setup-user-guides/hp-zbook-fury-17-g7-mobile-workstation/34386188)

The HP ZBook Fury 17 G7 served as the PC platform for:

- Unity CPU inference;
- Unity GPU Compute inference;
- controlled dataset benchmarking;
- camera-based inference;
- cloud-assisted Unity testing;
- memory measurements; and
- whole-system AC power measurements.

An archived copy of the HP support/user-guide page is also stored in this branch.

### Google Cloud Run

- [Google Cloud Run documentation](https://docs.cloud.google.com/run/docs)

Google Cloud Run was used to host the remote inference service for the cloud-assisted configurations.

Relevant Cloud Run documentation includes:

- service deployment;
- container execution;
- HTTPS request handling;
- service configuration;
- logging;
- request processing; and
- runtime behavior.

The cloud-assisted experiments used client applications on the FPGA, PC, and Meta Quest 3S to send image data to the remote inference service and receive classification results.

## Measurement and Instrumentation References

### P4400 Kill A Watt

The physical power measurements used the **P4400 Kill A Watt** meter.

The archived operation manual documents the instrument used for external power observations associated with:

- the ZedBoard FPGA platform; and
- the PC system.

The FPGA measurements represented board-level input power, while the PC measurements represented whole-system AC consumption.

### Meta Quest 3S Device Telemetry

Meta Quest 3S power and performance measurements used device-reported telemetry rather than external AC power measurement.

OVR Metrics Tool and Meta Quest Developer Hub provided measurements associated with:

- CPU utilization;
- GPU utilization;
- application memory;
- device power;
- frame rate; and
- runtime behavior.

These Quest measurements therefore have a different measurement boundary from the Kill A Watt measurements used for the FPGA and PC systems.

## Hardware References

### ZedBoard

The archived ZedBoard schematic documents the hardware configuration and interfaces of the **ZedBoard Rev E** used in the FPGA experiments.

The FPGA implementation targeted:

```text
XC7Z020CLG484-1
```

The schematic was used as a reference for:

- programmable-logic interfaces;
- Pmod/header connections;
- VGA output;
- LEDs and switches;
- clock inputs;
- power connections; and
- Zynq processing-system hardware.

### OV7670 Camera

The archived camera specification document supports the OV7670 camera implementation used for FPGA image acquisition.

The documentation provides information related to:

- parallel pixel data;
- PCLK;
- VSYNC;
- HREF;
- SCCB control;
- supported image formats;
- camera register configuration; and
- image timing.

The camera setup and later dataset-specific preprocessing are documented separately in the FPGA implementation branches.

## Reference Scope

This branch is intended for **manuals, specifications, vendor documentation, and development-environment references only**.

It does not contain:

- implementation source code;
- Vivado projects;
- Unity projects;
- trained models;
- ONNX files;
- FPGA model parameters;
- benchmark scripts;
- experimental CSV files;
- benchmark screenshots;
- camera-development photographs;
- statistical analysis files; or
- experimental results.

Those materials are maintained in the corresponding model, implementation, notebook, and experimental-data branches.

## Reproducibility Use

The materials in this branch support reproduction by documenting the hardware and software environments used throughout the experiments.

They provide references for:

- ZedBoard hardware;
- OV7670 camera operation;
- external power instrumentation;
- HP workstation hardware;
- Meta Quest 3S hardware;
- Quest performance monitoring;
- Vivado 2018.1;
- Xilinx SDK 2018.1;
- Unity Editor 6000.3.22f1;
- Unity Inference Engine / Sentis;
- Meta Quest Unity development;
- Meta Quest Developer Hub;
- OVR Metrics Tool; and
- Google Cloud Run.

Where practical, hardware manuals and specifications are archived directly in the repository. Vendor-maintained software and platform documentation is referenced through official online links so that the repository does not duplicate large or frequently updated documentation sets.
