# MNIST FPGA Cloud Live Classification Code

This branch contains the source and FPGA build artifacts for the **live MNIST camera-to-cloud classification implementation**.

Unlike the formal cloud measurement branch, this version does not use controlled 100-image test batches or store per-image measurement records.

Instead, it performs one live classification at a time:

```text
camera image
    ↓
freeze 28 × 28 image
    ↓
copy image to shared AXI BRAM mailbox
    ↓
Zynq PS sends HTTPS request
    ↓
Cloud Run performs MNIST inference
    ↓
prediction returned to mailbox
    ↓
programmable logic latches result
    ↓
prediction displayed on LEDs
```

## Branch Files

```text
top_live_cloud.vhd
design_1_bd_live.tcl
cloud_live.bit

main.c
tcp_client.c
```

## `top_live_cloud.vhd`

`top_live_cloud.vhd` contains the programmable-logic side of the live cloud implementation.

Its responsibilities include:

- camera capture;
- frozen-image storage;
- 28 × 28 image handling;
- transfer of the frozen image into the AXI BRAM mailbox;
- mailbox status handshaking;
- detection of the returned cloud prediction;
- latching the returned digit; and
- displaying the prediction through the ZedBoard LEDs.

The live design uses the frozen camera-derived image rather than the controlled MNIST test ROM used by the formal measurement configuration.

## Shared Mailbox

The PL and PS communicate through shared AXI BRAM.

The live interface uses the core mailbox fields:

```text
0x000–0x30C   784 image bytes packed four per word
0x310         STATUS
0x314         IMAGE_INDEX
0x318         RESULT
0x31C         EXPECTED / unused for live camera input
```

The handshake values are:

```text
0 = idle
1 = image ready
2 = result ready
```

The live path does not need the formal measurement branch's:

```text
accuracy counters
error counters
latency summary fields
100-image total-run timer
TEST_COMPLETE field
per-image result records
```

## Live Image Flow

The PL captures and freezes a camera image before publishing it to the processing system.

The 28 × 28 frozen image contains:

```text
784 pixels
```

Four 8-bit pixels are packed into each 32-bit mailbox word.

The processing system waits for:

```text
STATUS = IMAGE_READY
```

then reads the image from the mailbox.

## `main.c`

`main.c` provides the Zynq Processing System application framework.

It handles:

- platform initialization;
- lwIP initialization;
- Ethernet interface setup;
- DHCP;
- DNS;
- TCP timer servicing;
- DNS timer servicing;
- startup of the cloud application; and
- continuous polling of the live cloud state machine.

The main application loop continues processing Ethernet traffic and calling the cloud client so that TCP, TLS, HTTPS, and mailbox communication can progress.

## `tcp_client.c`

`tcp_client.c` implements the live Cloud Run client.

Its responsibilities include:

- resolving the Cloud Run hostname;
- opening the TCP connection;
- initializing Mbed TLS;
- completing the TLS handshake;
- reading one frozen 784-byte image from the mailbox;
- constructing the HTTPS request;
- sending the image to Cloud Run;
- receiving the HTTP response;
- parsing the returned prediction;
- writing the prediction back to the mailbox; and
- returning control to the PL.

The live request uses:

```text
POST /predict HTTP/1.1
Content-Type: application/octet-stream
Content-Length: 784
Connection: keep-alive
```

## Cloud Run Service

The live client communicates with the MNIST Cloud Run service:

```text
mnist-cloud-inference-221036165238.us-east1.run.app
```

using:

```text
HTTPS
TCP port 443
```

The Cloud Run service returns a response in the form:

```json
{"prediction": 7}
```

## Persistent Network Connection

The application performs the network setup before live inference begins:

```text
DHCP
  ↓
DNS
  ↓
TCP
  ↓
TLS handshake
  ↓
ready for live camera inference
```

The TCP/TLS connection remains available for later image requests.

This avoids rebuilding the connection for every captured digit.

## DNS Support

The live SDK project uses the same DNS approach developed during the cloud measurement work.

The application:

- enables lwIP DNS support;
- initializes DNS explicitly;
- services `dns_tmr()` from the main loop; and
- resolves the Cloud Run hostname before opening the TCP connection.

## TLS Configuration

The live client uses Mbed TLS for encrypted HTTPS communication.

The experimental implementation uses the same development TLS configuration as the completed MNIST cloud experiments.

Encryption is active, but the implementation is not intended as a production security configuration.

## Returned Prediction

After a successful Cloud Run response, the PS writes the predicted digit to:

```text
MAILBOX_RESULT
```

and then sets:

```text
STATUS = RESULT_READY
```

The programmable logic detects the returned result, latches the predicted digit, and presents it on the ZedBoard LEDs.

## LED Output

The live cloud design uses the board LEDs to provide immediate physical output of the returned classification.

The prediction is displayed from the cloud result latched by the programmable logic after the mailbox handshake completes.

This replaces the formal measurement branch's result-record storage.

## Block Design

`design_1_bd_live.tcl` recreates the Vivado block design used by the live cloud implementation.

The design includes the Zynq Processing System and the AXI BRAM mailbox used for communication between the programmable logic and processing system.

This Tcl file is included so the PS/PL communication architecture can be reconstructed without relying only on generated Vivado project files.

## Bitstream

The final live cloud FPGA configuration is:

```text
cloud_live.bit
```

This bitstream corresponds to the live camera-to-cloud classification design.

## Difference from the Formal Cloud Measurement Build

The formal cloud measurement configuration used:

```text
controlled MNIST ROM
100-image workload
expected labels
accuracy counters
latency summaries
per-image records
TEST_COMPLETE
```

The live cloud configuration removes those experiment-specific structures.

The live design instead uses:

```text
frozen camera image
single live request
returned prediction
LED display
```

## Difference from Local Live Classification

The earlier local live implementation used the ZyNet hardware classifier directly on the FPGA.

The live cloud implementation changes the classification path to:

```text
camera
  ↓
FPGA preprocessing/storage
  ↓
mailbox
  ↓
Zynq PS
  ↓
Cloud Run
  ↓
prediction
  ↓
LED output
```

The local neural-network inference engine is therefore not used to generate the live cloud prediction.

## Related Branches

The related cloud branches separate service setup, formal measurement, and live deployment:

```text
Cloud
    Cloud Run service configuration

MNIST-FPGA-Cloud-Classification-Measurement-Code
    formal controlled measurement implementation

MNIST-FPGA-Cloud-Classification-Measurement-Notebook-and-Data
    formal results and supporting evidence

MNIST-FPGA-Cloud-Live-Classification-Code
    this branch

MNIST-FPGA-Cloud-Live-Classification-Notebook-and-Data
    live camera-to-cloud evidence
```

## Purpose

The purpose of this branch is to preserve the final FPGA and SDK implementation used to classify a **frozen live camera image through Google Cloud Run** and display the returned digit directly on the ZedBoard LEDs.

The branch intentionally excludes the formal 100-image measurement infrastructure so that it represents the final live cloud classification path rather than the earlier experimental measurement configuration.
