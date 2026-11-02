# MNIST FPGA Cloud Live Classification — Notebook and Data

This branch contains the notebook, implementation reports, photographs, and video evidence for the **final live FPGA-to-Cloud Run MNIST classification workflow**.

Unlike the formal cloud measurement branches, this branch does not document controlled 100-image accuracy/latency experiments. It documents the final functional path in which a real camera-derived image is frozen on the FPGA, transmitted to Google Cloud Run for inference, returned to the ZedBoard, and displayed on the board LEDs.

## Live Inference Workflow

```text
OV7670 camera
    ↓
ROI capture / downsampling
    ↓
frozen 28 × 28 image
    ↓
AXI BRAM mailbox
    ↓
Zynq Processing System
    ↓
lwIP / TCP / Mbed TLS
    ↓
HTTPS POST /predict
    ↓
Google Cloud Run
    ↓
MNIST prediction
    ↓
prediction returned to mailbox
    ↓
PL latches result
    ↓
prediction displayed on LEDs
```

## Main Notebook

The main notebook is:

```text
MNIST_FPGA_Cloud_Live_Classification_Notebook.ipynb
```

The notebook documents:

- the live camera-to-cloud architecture;
- the reduced mailbox used by the live build;
- SDK/network behavior;
- HTTPS request handling;
- returned prediction handling;
- LED display of the prediction;
- live diagnostic timing;
- Vivado implementation reports;
- physical setup evidence; and
- the distinction between live deployment and formal cloud measurement.

## Live Inference Video

The branch includes:

```text
Cloud Live Inference10-21-202613-03.mp4
```

This video documents the final live camera-to-cloud classification workflow.

It provides evidence that the complete path operates as an integrated system rather than only as separate FPGA and Cloud Run components.

## Photographic Evidence

The branch currently includes:

```text
FPGA_Live_Cloud_Inference_Overview.jpg
FPGA_Live_Cloud_Power.jpg
```

### Live Cloud Inference Overview

`FPGA_Live_Cloud_Inference_Overview.jpg` shows the physical live-cloud setup, including:

- camera enclosure;
- monitor;
- frozen camera-derived digit;
- ZedBoard;
- Ethernet connection; and
- surrounding test setup.

### Live Cloud Power

`FPGA_Live_Cloud_Power.jpg` documents a physical Kill A Watt observation during the live-cloud configuration.

The physical meter measures the local hardware/system boundary only. It does not include electrical power consumed by the remote Cloud Run infrastructure.

## Live Mailbox Interface

The final live SDK implementation uses only the mailbox fields required for a single frozen image and returned prediction.

```text
0x000–0x30C   784 image bytes
0x310         STATUS
0x314         IMAGE_INDEX
0x318         RESULT
0x31C         EXPECTED / unused for live camera input
```

Handshake values:

```text
0 = idle
1 = image ready
2 = result ready
```

The formal measurement fields used for 100-image summaries and result dumping are not required in this live version.

## Live SDK Behavior

The Zynq Processing System performs:

```text
platform initialization
    ↓
lwIP initialization
    ↓
Ethernet / DHCP
    ↓
DNS
    ↓
TCP
    ↓
Mbed TLS
    ↓
TLS handshake
    ↓
wait for frozen image
```

When the FPGA publishes a frozen image, the PS reads 196 mailbox words containing the 784 image bytes.

The request sent to Cloud Run uses:

```text
POST /predict HTTP/1.1
Content-Type: application/octet-stream
Content-Length: 784
Connection: keep-alive
```

The returned JSON prediction is parsed and written back into the shared mailbox.

## Prediction Output

After Cloud Run returns a prediction:

```text
PS writes RESULT
    ↓
PS writes STATUS = RESULT_READY
    ↓
PL detects returned value
    ↓
PL latches prediction
    ↓
prediction displayed on ZedBoard LEDs
```

The live build therefore uses the returned cloud result directly rather than storing a formal experiment result record.

## Vivado Reports

The branch contains the final live-cloud implementation reports:

```text
design_1_wrapper_utilization_placed_cloud_live.rpt
design_1_wrapper_timing_summary_routed_live_cloud.rpt
design_1_wrapper_route_status_live_cloud.rpt
design_1_wrapper_power_routed_live_cloud.rpt
```

These reports correspond to the final live deployment build, not the earlier formal cloud measurement configuration.

## Vivado Power Estimate

The routed live-cloud power report records approximately:

```text
Total on-chip power: 1.769 W
Dynamic power:       1.621 W
Static power:        0.148 W
```

Vivado marked the estimate as **Low confidence**, so these values should be treated as implementation estimates rather than replacements for physical meter measurements.

## Live Diagnostic Timing

The live SDK client can print prediction and request-latency information during validation.

This timing is a **live diagnostic only**.

It should not be combined with the formal 100-image cloud latency dataset documented in the measurement branches.

## Difference from Formal Cloud Measurement

The formal cloud measurement configuration used:

```text
controlled MNIST ROM
100-image workload
expected labels
accuracy counters
per-image latency records
run-summary storage
TEST_COMPLETE
```

The final live-cloud implementation uses:

```text
frozen camera image
single live request
returned cloud prediction
LED output
```

This branch therefore represents the final functional deployment rather than the experimental measurement configuration.

## Difference from Local Live Classification

The earlier local live implementation classified the frozen image using the FPGA-based ZyNet inference engine.

The live cloud implementation instead uses:

```text
camera image
    ↓
FPGA capture/storage
    ↓
Zynq PS
    ↓
Cloud Run
    ↓
returned prediction
```

The visible output remains on the ZedBoard LEDs, but inference occurs remotely rather than in the local FPGA neural-network hardware.

## Relationship to the Code Branch

The corresponding live-cloud code branch contains:

```text
top_live_cloud.vhd
design_1_bd_live.tcl
cloud_live.bit
main.c
tcp_client.c
```

The code branch preserves the implementation.

This branch preserves:

- notebook documentation;
- Vivado implementation reports;
- photographs; and
- video evidence.

## Related Branches

```text
Cloud
    Cloud Run service configuration

MNIST-FPGA-Cloud-Classification-Measurement-Code
    formal controlled cloud measurement implementation

MNIST-FPGA-Cloud-Classification-Measurement-Notebook-and-Data
    formal cloud results and measurement evidence

MNIST-FPGA-Cloud-Live-Classification-Code
    final live camera-to-cloud implementation

MNIST-FPGA-Cloud-Live-Classification-Notebook-and-Data
    this branch
```

## Purpose

The purpose of this branch is to document the final **live camera-to-cloud MNIST classification system**.

It demonstrates that a camera-derived digit can be frozen on the FPGA, transmitted through the Zynq Processing System to Google Cloud Run, classified remotely, returned to the FPGA, and displayed on the physical board.
