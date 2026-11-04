# FPGA Security Evaluation

This branch contains the security evaluation notebook and supporting Vivado screenshots for the **ZedBoard Revision E (Zynq-7020)** used in the local and cloud-assisted FPGA implementations.

The purpose of this branch is to preserve the evidence and documentation supporting the FPGA security evaluation presented in **Chapter IV, Section 4.7.2.1** of the dissertation.

## Files

| **File** | **Purpose** |
| --- | --- |
| `FPGA_Security_Evaluation_Revised.ipynb` | Documents the security evaluation procedure, configuration review, vendor advisory applicability, findings, and limitations. |
| `write_bitstream_log.png` | Vivado 2018.1 bitstream generation log used to document the programming workflow. |
| `bitstream_settings.png` | Vivado 2018.1 configuration screenshot used to review bitstream security settings. |

## Evaluation Scope

The notebook documents the security review of:

- JTAG programming and bitstream protection;
- physical and debugging interfaces;
- development workstation access;
- pretrained NN parameter integrity;
- Zynq-7000 and ARM Cortex-A9 security advisories;
- Vivado 2018.1 and Xilinx SDK 2018.1 documentation; and
- OV7670 camera and image acquisition security.

The evaluation used configuration inspection, source-code review, and published technical references. It did not include penetration testing or deliberate exploitation.

## Related Branches

**MNIST FPGA Live Classification Code** contains the Vivado project, HDL modules, model-generation scripts, and parameter initialization logic examined during the security review.

**Manuals and Specifications** contains hardware documentation, AMD/Xilinx technical references, and security advisories used to evaluate the experimental configuration.

The FPGA Security branch preserves the evaluation record without duplicating those materials.

## Reproducibility

The Jupyter notebook provides the evaluation sequence, identifies the supporting evidence, and documents how published vulnerabilities were evaluated against the actual FPGA configuration.

The two Vivado screenshots preserve the configuration evidence examined during the review.

Detailed security findings and their interpretation are maintained in the notebook and dissertation. Network communication, TLS, and cloud service security are addressed separately in the cloud-assisted security evaluation.
