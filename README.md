
# PC Security Evaluation

This branch contains the security evaluation notebook and supporting Windows configuration screenshots for the **HP ZBook Fury 17 G7** used in the local PC inference experiments.

The purpose of this branch is to preserve the evidence and documentation supporting the PC security evaluation presented in **Chapter IV, Section 4.7.2.2** of the dissertation.

## Files

The following notebook documents the evaluation procedure, evidence, findings, and limitations.

| **File** | **Purpose** |
| --- | --- |
| `PC_Security_Evaluation_Reproducibility.ipynb` | Documents the PC security evaluation, including operating-system protections, account access, Unity software security, model and data storage, camera access, and published security advisories. |

### Windows Security and Configuration Screenshots

The following screenshots were captured during the November 5, 2026, security review.

| **File** | **Purpose** |
| --- | --- |
| `security_at_a_glance.png` | Overall Windows Security protection status. |
| `virus_and_threat_protection.png` | Antivirus protection, scan status, and security intelligence updates. |
| `firewall_and_network_protection.png` | Windows Firewall configuration for domain, private, and public networks. |
| `device_security.png` | Windows hardware and device-security features. |
| `security_processor_details.png` | TPM 2.0 specifications and operational status. |
| `system_settings.png` | Windows version, hardware configuration, Secure Boot status, virtualization-based security, and Kernel DMA Protection. |
| `bit_locker.png` | BitLocker encryption status for the internal and external drives. |
| `latest_updates.png` | Windows feature and security update history. |

### Account and Access Screenshots

| **File** | **Purpose** |
| --- | --- |
| `user_account_info.png` | Experimental user account and administrator privileges. |
| `all_user_info.png` | Windows account configuration and work-or-school account association. |
| `sign_in_options.png` | Windows Hello PIN and available sign-in methods. |
| `account_protection.png` | Windows Hello and Dynamic Lock status. |

### Application and Experimental Data Screenshots

| **File** | **Purpose** |
| --- | --- |
| `camera_access_settings.png` | Windows camera privacy settings and Unity Editor camera-access history. |
| `unity_project_directory_structure.png` | Organization of the Unity projects, ONNX model, benchmark datasets, and supporting research files. |

## Evaluation Scope

The notebook documents the security review of:

- Windows 11 Pro 25H2 security protections;
- user authentication and administrator privileges;
- Secure Boot, TPM, virtualization-based security, and BitLocker;
- antivirus, firewall, and Windows updates;
- Unity Editor 6000.3.22f1 and Unity Inference Engine 2.6.1;
- locally stored ONNX models and experimental datasets;
- internal and external drive access; and
- Lumens VC-B2U USB camera access and image-input security.

The evaluation used configuration inspection, application source-code review, and published technical references. It did not include penetration testing or deliberate exploitation.

## Related Branches

**MNIST-Unity-Local-PC-Code** contains the Unity implementation and C# scripts examined during the security review, including model loading, camera acquisition, and benchmark execution.

**MNIST-Unity-Local-PC-Data-And-Notebook** contains the experimental procedures, performance measurements, and supporting results for local PC inference.

**Manuals-and-Specifications** contains hardware documentation, Microsoft security references, Unity documentation, and published security advisories used to evaluate the experimental configuration.

The PC-Security branch preserves the security evaluation record without duplicating these materials.

## Reproducibility

The Jupyter notebook documents the evaluation sequence, identifies the supporting screenshots and source-code evidence, and explains how published security advisories were evaluated against the actual workstation and Unity configuration.

The screenshots preserve the system settings observed on November 5, 2026. They document the configuration at the time of the security review rather than independently establishing that every setting remained unchanged throughout earlier experiments.

Detailed security findings and their interpretation are maintained in the notebook and dissertation.

Cloud communication, HTTPS, and Google Cloud Run security are addressed separately in the cloud-assisted security evaluation.
