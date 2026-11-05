
# Cloud-Assisted Inference Security Evaluation

This branch contains the supporting evidence and reproducibility notebook for **Chapter IV, Section 4.7.3 — Cloud-Assisted Inference Security Results** of the dissertation *Machine Learning on the Edge: Performance and Security Evaluation of Artificial Neural Network Implementations in Embedded Systems*.

The evaluation examines communication security, data transmission, authentication and access control, and cloud service security for the FPGA, PC, and Meta Quest 3S implementations.

## Files

| File | Description |
|---|---|
| `Cloud_Security_Evaluation_Reproducibility.ipynb` | Reproducibility notebook documenting the evaluation procedure, findings, evidence, and limitations. |
| `wifi_settings.png` | Windows configuration of the WPA2-Personal university research Wi-Fi network. |
| `open_settings.png` | Windows properties of the university open Wi-Fi network used by the Quest 3S. |
| `ethernet_properties.png` | Windows Ethernet properties documenting the university wired-network environment. |
| `cloud_networking.png` | Cloud Run ingress restrictions, HTTPS endpoints, and networking settings. |
| `cloud_log.png` | Cloud Run operational request logs and application-server messages. |
| `cloud_iam_permissions.png` | Project IAM permissions and runtime service account role assignments. |
| `cloud_containers.png` | Cloud Run container configuration, resource limits, and runtime settings. |

## Evaluation Scope

The security evaluation covers:

- **Client connectivity:** FPGA Ethernet, PC WPA2-protected Wi-Fi, and Quest 3S open Wi-Fi.
- **Communication protection:** FPGA TLS configuration and Unity HTTPS communication.
- **Cloud networking:** Public ingress, HTTPS endpoints, and network restrictions.
- **Authentication and authorization:** Public invocation permissions and runtime service account privileges.
- **Application security:** Python request validation, model loading, and dependency configuration.
- **Data handling:** Transmitted classification inputs, service responses, and operational logging.
- **Availability:** Container resource limits, scaling settings, and potential service disruption.

The evaluation distinguishes implemented security controls from potential vulnerabilities and limitations. No penetration testing, unauthorized access, network interception, or exploitation was performed.

## Related Branches

| Branch | Contents |
|---|---|
| `Cloud` | Python inference service, dependencies, deployment evidence, and existing Cloud Run security screenshot. |
| `FPGA-Security` | FPGA hardware, development-interface, and local deployment security. |
| `PC-Security` | Windows workstation and local Unity deployment security. |
| `Quest3s-security` | Meta Quest 3S device and application security. |
| `Manuals-and-Specifications` | Platform documentation and published security references. |

Cloud-assisted implementation code, performance notebooks, and experimental measurements remain in their respective implementation branches.

## Reproducibility

Open `Cloud_Security_Evaluation_Reproducibility.ipynb` in GitHub or Jupyter to review the procedures and evidence.

All seven screenshots referenced directly in the notebook are stored in this branch. Existing application code and cloud deployment evidence are referenced from the `Cloud` branch rather than duplicated.

The configuration screenshots were collected during the November 5, 2026 security review. The Cloud Run logs include experimental requests from October 28, 2026.

## Scope and Limitations

This branch documents the security characteristics of the evaluated cloud-assisted deployment. The findings are based on configuration inspection, source-code review, operational evidence, and the experimental network arrangements.

Potential threats were identified qualitatively and were not validated through attacks. Security-related performance trade-offs will be addressed separately after the remaining dataset evaluations are completed.
