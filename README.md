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
- [Zynq 7000 SoC Technical Reference Manual (UG585)](https://docs.amd.com/r/en-US/ug585-zynq-7000-SoC-TRM/Introduction?tocId=Hf6C7Oo5ABvv2hkWRoiihQ).
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

### FPGA Security Advisories and Vulnerability References

The following resources support the security evaluation of the ZedBoard Rev E, Xilinx Zynq-7020 SoC, Vivado 2018.1, and Xilinx SDK 2018.1 used in the dissertation experiments.

These references document hardware security features, published vulnerabilities, development-tool considerations, and the applicability of security advisories to the experimental configurations.

#### AMD/Xilinx Security Documentation

- [Zynq-7000 SoC Technical Reference Manual (UG585)](https://docs.amd.com/r/en-US/ug585-zynq-7000-SoC-TRM/Introduction?tocId=Hf6C7Oo5ABvv2hkWRoiihQ)
  - Documents secure boot, bitstream protection, authentication, programming interfaces, and hardware security capabilities.

- [AMD Advisory 73541 — Defeating Bitstream Encryption](https://docs.amd.com/r/en-US/73541/Solution)
  - Describes security weaknesses involving 7-Series FPGA bitstream encryption and recommended countermeasures.

- [AMD Answer Record 70394 — Zynq-7000 Meltdown and Spectre Vulnerabilities](https://adaptivesupport.amd.com/s/article/70394?language=en_US)
  - Identifies ARM Cortex-A9 susceptibility to Spectre Variant 1 (CVE-2017-5753) and Variant 2 (CVE-2017-5715).
  - Relevant to the Zynq-7020 processing system, particularly ARM execution during cloud-assisted inference.

- [AMD Answer Record 71292 — Zynq-7000 FSBL Security Advisory](https://adaptivesupport.amd.com/s/article/71292?language=en_US)
  - Documents a security issue affecting Zynq-7000 FSBL versions 2018.2 and earlier.
  - Reviewed in relation to the JTAG programming workflow and Xilinx SDK 2018.1.

- [AMD Answer Record 76974 — Zynq-7000 FSBL Authentication Attack](https://adaptivesupport.amd.com/s/article/76974?language=en_US)
  - Describes an authentication-related attack affecting certain Zynq-7000 FSBL configurations.
  - Associated with CVE-2022-23822.

- [AMD Answer Record 70699 — Vivado 2018.1 IP Release Notes](https://adaptivesupport.amd.com/s/article/70699?language=en_US)
  - Provides IP change information for Vivado 2018.1.
  - Used to review the IP components incorporated into the experimental FPGA design.

#### Vulnerability Databases

- [OpenCVE — Xilinx Zynq-7000 Vulnerabilities](https://app.opencve.io/cve/?product=zynq-7000&vendor=xilinx)
  - Provides an index of published CVEs associated with the Zynq-7000 device family.

- [NVD — CVE-2021-44850](https://nvd.nist.gov/vuln/detail/CVE-2021-44850)
  - Documents a Zynq-7000 boot ROM vulnerability involving manipulated SD-card boot images.
  - The experimental implementations used JTAG programming rather than SD-card boot.

- [NVD — CVE-2022-23822](https://nvd.nist.gov/vuln/detail/CVE-2022-23822)
  - Documents an authentication-related vulnerability involving the Zynq-7000 FSBL.
  - Applicability depends on the boot and authentication configuration.

- [NVD — CVE-2021-27208](https://nvd.nist.gov/vuln/detail/CVE-2021-27208)
  - Documents a Zynq-7000 NAND flash boot vulnerability.
  - The NAND boot attack path was not part of the documented experimental workflow.

#### Additional References Reviewed

- [AMD Support — Broken 7-Series Encryption and Zynq-7000 Countermeasures](https://adaptivesupport.amd.com/s/question/0D52E00006hpX05SAE/broken-7series-encryption-and-countermeasures-of-zynq7000?language=en_US)
  - Community discussion related to FPGA bitstream encryption.
  - AMD Advisory 73541 provides the primary technical reference.

- [AMD Answer Record 66071 — Zynq UltraScale+ MPSoC Design Advisories](https://adaptivesupport.amd.com/s/article/66071?language=en_US)
  - Reviewed for device-family applicability.
  - Concerns Zynq UltraScale+ devices rather than the Zynq-7020 used in the experiments.

- [NVD — CVE-2025-52541](https://nvd.nist.gov/vuln/detail/CVE-2025-52541)
  - Describes a Windows Vivado vulnerability reported in connection with newer Vivado versions.
  - Applicability to Vivado 2018.1 was not established; therefore, it was excluded from the confirmed vulnerability findings.

#### Application to the Dissertation

The FPGA security evaluation examined the documented advisories in relation to the actual experimental configuration:

- ZedBoard Revision E with Zynq-7020 (XC7Z020CLG484-1).
- JTAG programming through Vivado 2018.1.
- Xilinx SDK 2018.1 for cloud-assisted ARM application execution.
- Pretrained NN weights and biases initialized within the PL.
- Physical and debugging access through JTAG and UART.
- ARM Cortex-A9 execution during cloud-assisted inference.

Published vulnerabilities were not automatically treated as exploitable in the experimental implementation. Findings were evaluated according to the affected device, software version, required attack conditions, and documented configuration.

The security evaluation results are presented in Chapter IV, Section 4.7 of the dissertation. These links provide supporting vendor documentation and vulnerability records rather than evidence that exploitation occurred during testing.

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


### PC Security Advisories and Vulnerability References

The following resources support the security evaluation of the HP ZBook Fury 17 G7 workstation, Windows 11 Pro 25H2, Unity Editor 6000.3.22f1, and Unity Inference Engine 2.6.1 used in the dissertation experiments.

These references document operating-system security protections, development-software vulnerabilities, Unity package security, and the applicability of published advisories to the local PC inference configuration.

#### Microsoft Windows Security Documentation

- [Windows Security](https://support.microsoft.com/en-us/windows/stay-protected-with-the-windows-security-app-ae70cccf-f6e7-23b4-1b9f-7bcd8c4bb3b9)
  - Documents Microsoft Defender Antivirus, firewall protection, account protection, and device security.
  - Used to interpret the security settings recorded on the experimental workstation.

- [Windows Hello](https://learn.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/)
  - Documents Windows Hello authentication and PIN-based sign-in.
  - Relevant to the PIN authentication used to access the workstation.

- [BitLocker Drive Encryption](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/)
  - Documents Windows drive encryption and data protection.
  - Used to evaluate the absence of BitLocker encryption on the internal system drive and connected external drives.

- [Secure Boot](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-secure-boot)
  - Describes UEFI Secure Boot and its role in verifying trusted boot components.
  - Relevant because Secure Boot was disabled on the experimental workstation.

- [Virtualization-Based Security](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-vbs)
  - Documents Windows virtualization-based security capabilities.
  - Relevant to the active virtualization-based security reported in Windows System Information.

- [Kernel DMA Protection](https://learn.microsoft.com/en-us/windows/security/hardware-security/kernel-dma-protection-for-thunderbolt)
  - Documents protection against unauthorized direct memory access through supported external interfaces.
  - Relevant because Kernel DMA Protection was reported as enabled.

- [Windows Camera Privacy Settings](https://support.microsoft.com/en-us/windows/manage-app-permissions-for-a-camera-in-windows-87ebc757-1f87-7bbf-84b5-0686afb6ca6b)
  - Documents camera access permissions for Windows applications.
  - Used to interpret desktop application camera access and Unity Editor's recorded camera usage.

#### Unity Security Advisories

- [Unity Editor 6000.3.22f1 Release Notes](https://unity.com/releases/editor/whats-new/6000.3.22f1)
  - Documents the Unity Editor version used in the experiments.
  - Provides version-specific release information for the development environment.

- [Unity October 2026 — eMudhra Certificate Authority Compromise](https://unity.com/security/unity-emudhra-compromise)
  - Documents a certificate-authority trust issue affecting specified Unity releases.
  - Relevant to Unity Editor 6000.3.22f1 and the certificate trust environment.
  - Applicability was reviewed in relation to the workstation's Windows security updates and certificate configuration.

- [Unity October 2026 — Brotli Decoder Vulnerability](https://unity.com/security/unity-brotli-decoder-vulnerability)
  - Documents a Brotli decompression vulnerability affecting specified Unity versions.
  - Relevant to the installed Editor release and potentially affected package-management operations.
  - No Brotli decompression operations were identified in the reviewed local inference scripts.

- [Unity September 2025 — Security Update Advisory](https://unity.com/security/sept-2025-01)
  - Documents CVE-2025-59489, affecting certain applications built with Unity.
  - The installed Unity 6000.3.22f1 version followed the first patched release in the Unity 6000.3 release line.

#### Unity Inference and Application Documentation

- [Unity Inference Engine Documentation](https://docs.unity3d.com/Packages/com.unity.ai.inference@latest/)
  - Documents model loading, inference workers, execution backends, and tensor processing.
  - Relevant to Unity Inference Engine 2.6.1 and local ONNX model execution.
  - The reviewed implementation loaded models through Unity ModelAsset references and executed inference using CPU or GPU Compute backends.

- [Unity WebCamTexture Documentation](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/WebCamTexture.html)
  - Documents camera acquisition through Unity's WebCamTexture interface.
  - Relevant to the Lumens VC-B2U USB camera used for local PC classification.
  - The reviewed application selected the first enumerated camera, which corresponded to the Lumens camera when connected.

#### Application to the Dissertation

The PC security evaluation examined these references in relation to the actual experimental configuration:

- HP ZBook Fury 17 G7 running Windows 11 Pro 25H2.
- Windows Hello PIN authentication and administrator-level access.
- Microsoft Defender, Windows Firewall, TPM 2.0, virtualization-based security, and Kernel DMA Protection.
- Disabled Secure Boot and BitLocker drive encryption.
- Unity Editor 6000.3.22f1 with Unity Inference Engine 2.6.1.
- Locally stored ONNX models, Unity projects, and MNIST benchmark datasets.
- Internal system-drive storage during experimentation and external Seagate drive storage after testing.
- Lumens VC-B2U USB camera with Windows desktop camera access enabled.
- Representative Unity C# scripts used for local inference and benchmarking.

Published security advisories were evaluated according to the installed software versions, affected components, required attack conditions, and observed application behavior.

The review identified operating-system protections, configuration-related security concerns, and relevant Unity advisories without demonstrating exploitation or unauthorized access.

The PC security evaluation results are presented in Chapter IV, Section 4.7.2.2 of the dissertation. These references provide supporting technical documentation and vulnerability information rather than evidence that an attack occurred during experimentation.


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
