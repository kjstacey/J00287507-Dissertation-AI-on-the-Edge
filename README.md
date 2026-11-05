
# Meta Quest 3S Security Evaluation

This branch contains the supporting evidence and reproducibility notebook for the Meta Quest 3S local-inference security evaluation presented in **Chapter IV, Section 4.7.2.3 — Meta Quest 3S Deployment** of the dissertation *Machine Learning on the Edge: Performance and Security Evaluation of Artificial Neural Network Implementations in Embedded Systems*.

The evaluation examines the headset's security configuration, application deployment, camera permissions, model and data storage, and published security research. It is a qualitative assessment based on observed settings, implementation review, and documented security concerns rather than penetration testing.

## Files

| File | Description |
|---|---|
| `Quest3S_Security_Evaluation_Reproducibility.ipynb` | Reproducibility notebook documenting the evaluation procedure, evidence, findings, and limitations. |
| `Quest3S_device_info.png` | Meta Quest Developer Hub screenshot showing headset identification, system version, firmware information, and connection status. |
| `Quest3S_OS_version.jpg` | Headset settings screenshot documenting Horizon OS version 2.9, automatic update settings, and the November 5, 2026 installation date. |
| `Tahat et al. - 2024 - VR Headset Ransomware Attack Vulnerability.pdf` | Published IEEE research investigating Android ransomware execution on an Oculus Quest 2, included as supporting literature on headset security and development interfaces. |

## Evaluation Scope

The notebook documents the following areas:

- **Device authentication and physical access:** Persistent Meta account session and absence of a headset unlock passcode.
- **Developer access:** Developer Mode, USB debugging authorization, and application installation through Unity Build and Run.
- **Operating-system security:** Horizon OS version information, automatic updates, and published security advisories.
- **Application and model security:** APK packaging, locally included ONNX model and benchmark data, and potential asset-integrity concerns.
- **Camera access:** Explicit application authorization and image acquisition through `PassthroughCameraAccess`.
- **Published research:** Relevant Meta security documentation and experimental ransomware research involving the Oculus Quest 2.

The evaluation distinguishes observed security controls from potential threats. No malware installation, privilege escalation, unauthorized access, application modification, or exploitation testing was performed.

## Related Branches

| Branch | Contents |
|---|---|
| `MNIST-Unity-Local-Quest-Code` | Unity implementation and inference scripts for the Quest 3S. |
| `MNIST-Unity-Local-Quest-Data-And-Notebook` | Local-inference benchmarking procedures and experimental results. |
| `Manuals-and-Specifications` | Official platform documentation, software references, and published security advisories. |
| `PC-Security` | Security evaluation of the Windows development workstation. |
| `FPGA-Security` | Security evaluation of the ZedBoard implementation. |

## Reproducibility

Open `Quest3S_Security_Evaluation_Reproducibility.ipynb` in GitHub or Jupyter to review the documented configuration and evidence.

The notebook references the screenshots and supporting publication stored in this branch. The operating-system screenshot reflects the November 5, 2026 security review, following an automatic update, and does not independently establish the exact firmware build installed during earlier experiments.

Application source code and performance measurements remain in their respective implementation branches to avoid duplication.

## Scope and Limitations

This branch documents security characteristics of the experimental Meta Quest 3S configuration. Findings from published vulnerability advisories and the Quest 2 ransomware study are discussed for context but do not demonstrate exploitation of the experimental headset.

The evaluation does not establish that the device, application, or packaged model was free from vulnerabilities.
