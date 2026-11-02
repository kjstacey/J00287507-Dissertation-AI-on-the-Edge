# MNIST FPGA Cloud Classification Measurement — Notebook and Data

This branch contains the notebooks, SDK/UART result archive, Vivado reports, photographs, and videos used to document the **MNIST FPGA-to-Cloud Run measurement experiments**.

The work was completed in two stages:

1. **Formal cloud classification measurements**
   - controlled MNIST test images;
   - 100-image batches;
   - classification accuracy;
   - client-side latency;
   - total run time;
   - throughput;
   - communication-error checks.

2. **Cloud power and memory measurements**
   - separate FPGA configuration;
   - local neural-network hardware removed;
   - controlled cloud workload kept;
   - FPGA resource use, Vivado power, physical board power, and PS-side memory characterized separately.

The corresponding source code and bitstreams are maintained in the related cloud measurement code branch.

## Main Results Notebook

The main results notebook is:

```text
MNIST_FPGA_Cloud_Results_Notebook.ipynb
```

The notebook documents:

- formal 100-image cloud runs;
- cloud classification accuracy;
- steady-state latency;
- throughput;
- validation and excluded runs;
- formal cloud measurement FPGA utilization;
- reduced cloud-power FPGA utilization;
- Vivado routed power;
- physical Kill A Watt observations;
- power-test videos;
- memory interpretation; and
- measurement boundaries.

## SDK Result Archive

The consolidated SDK/UART result archive is:

```text
MNIST_FPGA_Cloud_SDK_Result_Logs.md
```

This file contains the preserved measurement information from the formal SDK runs, including:

- accuracy by 100-image block;
- steady-state latency summaries;
- throughput summaries;
- cold-start observations;
- UART summary output;
- excluded-run notes;
- communication-error information; and
- measurement-acceptance criteria.

Where complete per-image console output was no longer available, the archive includes only values that were explicitly preserved.

## Formal Measurement Workload

The controlled cloud experiment evaluated the first 1,000 MNIST test images in ten blocks of 100 images:

```text
000–099
100–199
200–299
300–399
400–499
500–599
600–699
700–799
800–899
900–999
```

The FPGA supplied controlled test images to the Zynq Processing System through the AXI BRAM mailbox.

The PS then:

```text
reads image
    ↓
sends HTTPS request
    ↓
Cloud Run performs inference
    ↓
receives JSON prediction
    ↓
stores prediction and timing
    ↓
returns result to PL
```

## Accuracy Results

Final cloud classification accuracy:

```text
970 / 1000 correct
97.0%
```

Accuracy by block:

| Images | Correct | Accuracy |
|---|---:|---:|
| 0–99 | 98/100 | 98% |
| 100–199 | 97/100 | 97% |
| 200–299 | 96/100 | 96% |
| 300–399 | 98/100 | 98% |
| 400–499 | 96/100 | 96% |
| 500–599 | 97/100 | 97% |
| 600–699 | 95/100 | 95% |
| 700–799 | 100/100 | 100% |
| 800–899 | 98/100 | 98% |
| 900–999 | 95/100 | 95% |

## Latency and Throughput

Per-image latency was measured on the Zynq PS.

Timing began immediately before the first TLS write associated with an image request and ended when the complete HTTP response had been received.

The accepted steady-state results were approximately:

```text
Typical mean latency: 58–60 ms
Minimum observed:     51.934 ms
Maximum observed:    159.652 ms
Typical throughput:   16.8–17.1 classifications/s
```

Cold-start and first-request behavior was documented separately and was not treated as representative steady-state performance.

## Run Videos

The branch includes videos of the controlled 100-image tests.

These document:

- formal 100-image blocks;
- cold-start behavior;
- invalid/error runs used during debugging;
- final accepted measurement runs; and
- later cloud power tests.

The troubleshooting videos are useful as experimental evidence but should not be treated as part of the accepted formal dataset.

Accepted formal runs required:

```text
100 completed images
aligned per-image records
zero communication errors
valid TEST_COMPLETE
```

## Formal Cloud Measurement FPGA Build

The original cloud measurement build included the hardware and instrumentation needed for the controlled accuracy, latency, and throughput tests.

Post-placement utilization:

| Resource | Used | Utilization |
|---|---:|---:|
| LUTs | 4,043 | 7.60% |
| Registers | 5,511 | 5.18% |
| BRAM tiles | 36 | 25.71% |
| DSPs | 2 | 0.91% |

Routed timing:

```text
WNS = 3.926 ns
TNS = 0
```

Routing:

```text
8,459 routable nets
8,459 fully routed
0 routing errors
```

## Reduced Cloud Power Build

After the formal cloud measurements were complete, a second FPGA build was created for power and memory characterization.

The local neural-network hardware was removed because inference was being performed remotely in Cloud Run.

Post-placement utilization:

| Resource | Used | Utilization |
|---|---:|---:|
| LUTs | 2,181 | 4.10% |
| Registers | 2,254 | 2.12% |
| BRAM tiles | 29.5 | 21.07% |
| DSPs | 1 | 0.45% |

Routed timing:

```text
WNS = 3.117 ns
TNS = 0
```

Routing:

```text
4,024 routable nets
4,024 fully routed
0 routing errors
```

## Hardware Reduction

Removing the local neural-network hardware reduced the FPGA footprint before power and memory measurement.

| Resource | Formal Cloud Build | Cloud Power Build | Reduction |
|---|---:|---:|---:|
| LUTs | 4,043 | 2,181 | 1,862 |
| Registers | 5,511 | 2,254 | 3,257 |
| BRAM tiles | 36 | 29.5 | 6.5 |
| DSPs | 2 | 1 | 1 |

The reduced build more accurately represents the FPGA hardware required for cloud-assisted inference.

## Vivado Reports

The branch contains reports for both FPGA configurations.

### Formal cloud measurement build

```text
design_1_wrapper_utilization_placed_cloud_speed.rpt
design_1_wrapper_timing_summary_routed_cloud_speed.rpt
design_1_wrapper_route_status_cloud_speed.rpt
```

### Reduced cloud-power build

```text
design_1_wrapper_utilization_placed_cloud_power.rpt
design_1_wrapper_timing_summary_routed_cloud_power.rpt
design_1_wrapper_route_status_cloud_power.rpt
design_1_wrapper_power_routed_cloud_power.rpt
```

## Vivado Power Estimate

The reduced cloud-power build produced the following routed Vivado estimate:

```text
Total on-chip power: 1.771 W
Dynamic power:       1.621 W
Static power:        0.150 W
```

Vivado marked the estimate as **Low confidence** because no simulation activity file was supplied.

The Vivado value should therefore be treated as an implementation estimate rather than a replacement for physical system measurements.

## Physical Power Evidence

The branch includes JPEG photographs of the cloud power configuration, including:

```text
01_cloud_fpga_network_connected.jpg
02_cloud_power_meter_4_0W.jpg
03_cloud_power_build_zedboard.jpg
04_cloud_power_meter_3_8W.jpg
```

These images document:

- the ZedBoard with Ethernet connected;
- the reduced cloud-power FPGA configuration;
- an approximately 4.0 W physical observation; and
- an approximately 3.8 W physical observation.

Additional power videos document the meter during active operating states.

## Power-Test States

The uploaded videos include states such as:

```text
unprogrammed board
programmed idle
SDK/cloud inference
USB connected
USB disconnected
SDK/cloud inference without USB
```

The videos provide better evidence of meter behavior over time than a single still image.

The physical power measurement boundary includes the local board/system only.

It does not include electrical power consumed by the remote Cloud Run infrastructure.

## Memory Interpretation

The cloud-assisted configuration requires PS-side memory for the communication stack.

Major application buffers included approximately:

```text
TLS receive buffer        32 KB
Mbed TLS memory pool     128 KB
HTTP response buffer       4 KB
HTTP header buffer       ~512 B
784-byte image buffer
```

Additional memory is used by:

- lwIP;
- DHCP;
- DNS;
- TCP;
- Mbed TLS structures;
- stack;
- heap; and
- application state.

The cloud memory result therefore represents the cost of the **networking, TLS, and cloud-client application**, rather than local neural-network model storage.

## Relationship to the Code Branch

The related cloud measurement code branch contains the source required to reproduce the two FPGA configurations, including:

```text
top_cloud_speed.vhd
top_cloud_power.vhd

mnist_test_rom_pkg_cloud_speed.vhd
mnist_test_rom_pkg_cloud_power.vhd

blk_mem_gen_mnist_test_cloud_speed.xcix
blk_mem_gen_mnist_test_cloud_power.xcix

design_1_bd_cloud_speed.tcl
design_1_bd_cloud_power.tcl

design_1_axi_bram_ctrl_0_0_mailbox.xci

main.c
tcp_client.c

design_1_wrapper_cloud_speed.bit
FPGA_MNIST_Cloud_Power.bit
```

The code branch contains implementation source and bitstreams.

This branch contains the resulting measurements and supporting evidence.

## Relationship to the Cloud Service Branch

The Google Cloud Run service is documented separately.

That branch contains:

- Cloud Run setup notebook;
- service configuration;
- source/dependency screenshots;
- security configuration;
- observability screenshots; and
- exported Cloud Run request logs.

Cloud Run server-side request latency should not be substituted for the FPGA client's measured end-to-end request latency.

## Relationship to Live Cloud Classification

This branch documents the **formal controlled cloud measurements** and reduced-hardware cloud power/memory tests.

The later live camera-to-cloud implementation uses a different workflow:

```text
camera image
    ↓
freeze image
    ↓
mailbox
    ↓
PS
    ↓
Cloud Run
    ↓
prediction
    ↓
FPGA output
```

The live camera implementation belongs in the separate live cloud branches.

## Purpose

The purpose of this branch is to preserve the experimental evidence for the MNIST FPGA-to-Cloud Run measurements.

The formal 100-image runs document cloud accuracy, latency, and throughput, while the later reduced-hardware build documents the FPGA resource, memory, and physical power cost of cloud-assisted inference without unnecessary local neural-network hardware.
