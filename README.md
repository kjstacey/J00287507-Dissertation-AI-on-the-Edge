# MNIST FPGA Cloud Classification Measurement Code

This branch contains the FPGA and Zynq Processing System source used for the **MNIST FPGA-to-Cloud Run measurement experiments**.

The experiments were performed in two stages:

1. **Cloud accuracy, latency, and throughput measurement**
2. **Cloud power and memory measurement**

The first configuration kept the instrumentation needed to evaluate controlled 100-image cloud inference runs. A second FPGA configuration was then created for power and memory measurements with the local neural-network hardware removed so that unnecessary local inference logic would not inflate the cloud-assisted resource measurements.

## Measurement Workflow

The experimental progression was:

```text
Controlled MNIST test images
        ↓
FPGA cloud speed/accuracy build
        ↓
100-image cloud measurement runs
        ↓
accuracy + latency + throughput
        ↓
separate cloud power build
        ↓
remove local NN hardware
        ↓
power + memory measurements
```

The two FPGA builds therefore serve different measurement purposes.

## System Architecture

The cloud-assisted inference path used both the Zynq programmable logic and processing system:

```text
MNIST image in PL
        ↓
AXI BRAM mailbox
        ↓
Zynq PS
        ↓
lwIP / TCP
        ↓
Mbed TLS
        ↓
HTTPS
        ↓
Google Cloud Run
        ↓
MNIST inference
        ↓
JSON prediction
        ↓
PS writes result to mailbox
        ↓
PL receives result
```

The Cloud Run inference service is documented separately in the `Cloud` branch.

## Cloud Speed / Accuracy Build

The formal measurement FPGA configuration is represented by:

```text
top_cloud_speed.vhd
mnist_test_rom_pkg_cloud_speed.vhd
blk_mem_gen_mnist_test_cloud_speed.xcix
design_1_bd_cloud_speed.tcl
design_1_wrapper_cloud_speed.bit
```

This configuration used controlled MNIST images and supported the formal 100-image cloud measurement workload.

The programmable logic supplied images and expected labels to the processing system through the shared mailbox.

The PS then sent each image to Cloud Run and returned the prediction to the PL.

## Formal Cloud Measurements

The speed/accuracy configuration was used to evaluate:

- cloud classification accuracy;
- per-image request latency;
- minimum latency;
- maximum latency;
- latency sum;
- total 100-image run time;
- effective throughput;
- correct classifications;
- incorrect classifications; and
- communication errors.

The formal test size was:

```text
100 images per run
```

Multiple 100-image blocks were used to cover the first 1,000 MNIST test images.

## Cloud Power Build

The second FPGA configuration is represented by:

```text
top_cloud_power.vhd
mnist_test_rom_pkg_cloud_power.vhd
blk_mem_gen_mnist_test_cloud_power.xcix
design_1_bd_cloud_power.tcl
FPGA_MNIST_Cloud_Power.bit
```

This build was created after the formal accuracy, latency, and throughput measurements were complete.

The local neural-network inference hardware was removed because it was not required when inference was performed remotely by Cloud Run.

The cloud power build kept the hardware required to create a repeatable cloud workload:

- controlled MNIST image source;
- MNIST test ROM;
- image-control logic;
- AXI BRAM mailbox;
- Zynq Processing System;
- Ethernet interface; and
- PL/PS control logic.

This configuration was used for cloud-assisted power and memory measurements.

## Why the Local Neural Network Was Removed

The cloud-assisted inference path does not require the local ZyNet inference engine.

Keeping it in the design during power/resource measurements would have included hardware that was not actually necessary for cloud inference.

The power configuration therefore represents the FPGA-assisted cloud architecture more accurately:

```text
controlled input
      ↓
PL control
      ↓
shared mailbox
      ↓
PS networking / TLS
      ↓
Cloud Run inference
```

rather than:

```text
local NN hardware + cloud inference
```

## Controlled MNIST ROM

Both cloud measurement configurations used generated MNIST test data.

The corresponding ROM packages are:

```text
mnist_test_rom_pkg_cloud_speed.vhd
mnist_test_rom_pkg_cloud_power.vhd
```

and the packaged Block Memory Generator configurations are:

```text
blk_mem_gen_mnist_test_cloud_speed.xcix
blk_mem_gen_mnist_test_cloud_power.xcix
```

The controlled ROM allowed the cloud measurements to use repeatable inputs rather than relying on manual live-camera capture.

## Zynq Block Designs

The Vivado block designs are represented by:

```text
design_1_bd_cloud_speed.tcl
design_1_bd_cloud_power.tcl
```

These Tcl scripts recreate the major processing-system architecture used by the cloud experiments, including:

- Zynq Processing System;
- AXI interconnect;
- AXI BRAM Controller;
- shared mailbox memory; and
- PL-to-PS address mapping.

The mailbox was mapped at:

```text
0x40000000
```

## AXI BRAM Mailbox

The branch also contains:

```text
design_1_axi_bram_ctrl_0_0_mailbox.xci
```

This file documents the mailbox-related Vivado IP configuration used by the PL/PS communication path.

The shared mailbox carried:

- packed image data;
- status values;
- image index;
- expected label;
- returned prediction;
- summary measurement values; and
- per-image result records.

## SDK / Processing-System Application

The formal cloud measurement application is represented by:

```text
main.c
tcp_client.c
```

These files correspond to the controlled 100-image measurement implementation rather than the later live camera-to-cloud application.

### `main.c`

`main.c` handles the processing-system application framework, including:

- platform initialization;
- Ethernet initialization;
- DHCP;
- DNS setup;
- lwIP polling;
- TCP timers;
- cloud application startup; and
- repeated calls to the cloud/TLS state machine.

The SDK project directory was reused during later development, so the measurement version in this branch should be used when reproducing the formal cloud experiments.

### `tcp_client.c`

`tcp_client.c` contains the main cloud measurement implementation, including:

- Cloud Run hostname resolution;
- TCP connection;
- Mbed TLS initialization;
- persistent TLS connection;
- HTTPS request construction;
- transmission of the 784-byte MNIST image;
- HTTP response parsing;
- prediction extraction;
- expected/predicted comparison;
- per-image latency measurement;
- accuracy and error counters;
- 100-image run timing;
- per-image BRAM records; and
- final experiment summary data.

## Persistent HTTPS Connection

The measurement client used:

```text
HTTPS
TCP port 443
Connection: keep-alive
```

The TCP/TLS connection remained open across multiple image requests.

This prevented connection establishment and TLS handshake time from being added independently to every image classification.

## Latency Measurement

Per-image latency was measured on the Zynq PS.

Timing started immediately before the first TLS write belonging to an image request and stopped when the complete HTTP response had been received.

The measurement therefore includes:

```text
request transmission
+ network delay
+ Cloud Run processing
+ neural-network inference
+ response transmission
+ response receipt
```

This is different from Cloud Run's own server-side request latency.

## Throughput Measurement

A separate timer measured the complete 100-image test.

The timer started immediately before the first HTTPS request and ended after the final prediction had been written back through the mailbox.

Effective throughput was calculated from the complete run time.

## Bitstreams

The branch contains two FPGA bitstreams:

```text
design_1_wrapper_cloud_speed.bit
FPGA_MNIST_Cloud_Power.bit
```

`design_1_wrapper_cloud_speed.bit` corresponds to the formal speed/accuracy/throughput configuration.

`FPGA_MNIST_Cloud_Power.bit` corresponds to the reduced cloud power/memory configuration.

## Measurement Notebook

The branch also includes:

```text
MNIST_FPGA_Cloud_Classification_Measurements.ipynb
```

The notebook explains the experimental progression and measurement boundaries:

```text
accuracy / latency / throughput
            ↓
power / memory
```

It also documents why the local inference hardware was removed before the power and memory stage.

Measured evidence, logs, reports, screenshots, and power documentation can be placed in the corresponding cloud measurement Notebook-and-Data branch.

## Current Files

```text
FPGA_MNIST_Cloud_Power.bit
MNIST_FPGA_Cloud_Classification_Measurements.ipynb

blk_mem_gen_mnist_test_cloud_power.xcix
blk_mem_gen_mnist_test_cloud_speed.xcix

design_1_axi_bram_ctrl_0_0_mailbox.xci
design_1_bd_cloud_power.tcl
design_1_bd_cloud_speed.tcl

design_1_wrapper_cloud_speed.bit

main.c
tcp_client.c

mnist_test_rom_pkg_cloud_power.vhd
mnist_test_rom_pkg_cloud_speed.vhd

top_cloud_power.vhd
top_cloud_speed.vhd
```

## Relationship to Live Cloud Classification

This branch documents the **formal cloud measurement configurations**.

The later live camera-to-cloud implementation uses a different PL and SDK workflow:

```text
camera
   ↓
freeze 28 × 28 image
   ↓
mailbox
   ↓
Cloud Run
   ↓
prediction
   ↓
FPGA output
```

That implementation belongs in the separate live cloud classification branches.

## Purpose

The purpose of this branch is to preserve the source required to reproduce the MNIST FPGA-to-cloud measurement configurations.

The formal speed/accuracy build documents the controlled 100-image performance experiment, while the separate power build documents the reduced hardware configuration used to evaluate the resource and power cost of cloud-assisted inference without unnecessary local neural-network hardware.
