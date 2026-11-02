# MNIST FPGA Local Classification Measurement — Notebook and Data

This branch contains the notebooks, Vivado measurement artifacts, ILA captures, implementation reports, physical power evidence, and supporting data used for the **local FPGA MNIST measurement experiments**.

These experiments were performed after the live camera-to-FPGA classifier had already been verified. Separate copies of the Vivado project were created so that measurement-specific changes could be made without altering the earlier working implementation.

Three local measurement configurations were used:

```text
Accuracy
    controlled MNIST ROM
    → expected-label comparison
    → correct / total counts

Speed
    controlled MNIST ROM
    → FPGA cycle counters
    → latency and throughput

Continuous
    frozen camera-derived image
    → repeated local inference
    → sustained-operation power measurement
```

The corresponding implementation source and bitstreams are maintained in the related measurement-code branch.

## Measurement Scope

The local FPGA experiments evaluated:

- controlled classification accuracy;
- per-image inference latency;
- 100-image execution time;
- effective throughput;
- FPGA resource utilization;
- Vivado-estimated power;
- physical board-level power; and
- sustained continuous inference.

The controlled accuracy and speed tests used known MNIST dataset images rather than live camera input so that the measurements were repeatable and could be compared against software implementations.

The continuous-inference configuration returned to a frozen camera-derived 28 × 28 image and repeatedly classified the same stored image to create a sustained local workload.

## Accuracy Measurement

The accuracy implementation used controlled MNIST images stored in FPGA ROM.

Each test image contained:

```text
784 8-bit pixel values
1 expected class label
```

The first 1,000 MNIST test images were evaluated in ten batches of 100 images.

For each batch:

1. 100 image files were collected;
2. 78,400 pixel values were written to a Xilinx `.coe` file;
3. a matching VHDL label package was generated;
4. the Block Memory Generator ROM was rebuilt;
5. a new FPGA bitstream was generated;
6. the design was programmed; and
7. the number of correct classifications was recorded.

The final controlled FPGA result was:

```text
969 / 1000 correct
96.9% accuracy
```

### Accuracy by Batch

```text
Images 0–99      98 / 100
Images 100–199   98 / 100
Images 200–299   96 / 100
Images 300–399   98 / 100
Images 400–499   95 / 100
Images 500–599   99 / 100
Images 600–699   93 / 100
Images 700–799   98 / 100
Images 800–899   98 / 100
Images 900–999   96 / 100
```

The resulting overall accuracy was **96.9%**.

## Accuracy ILA Data

The accuracy project includes ILA capture files such as:

```text
hw_ila_data_1_accuracy.ila
hw_ila_data_1_accuracy.wcfg
hw_ila_data_1_accuracy.wdb
```

These files preserve the hardware-debug capture environment associated with the controlled classification test.

The `.wdb` file contains the waveform data, while the `.wcfg` stores the waveform display configuration.

## Speed Measurement

The speed project used the same controlled MNIST ROM mechanism as the accuracy implementation but added cycle counters to measure performance directly in FPGA clock cycles.

The neural-network inference clock was:

```text
25 MHz
```

which corresponds to:

```text
40 ns per cycle
```

Latency was measured from presentation of the first pixel of an image to assertion of the neural-network output-valid signal.

This timing interval includes:

- transmission of all 784 input pixels; and
- the subsequent processing required to produce the classification result.

The measured latency was:

```text
1,646 cycles
65.84 µs
0.06584 ms
```

The observed inference cycle count was deterministic for the evaluated workload.

## Throughput Measurement

The speed configuration also measured the total execution time for a 100-image sequence.

The measured result was:

```text
100 images
164,899 total cycles
6.59596 ms total batch time
```

The batch contained:

```text
164,600 cycles of image inference
299 cycles of controller/inter-image overhead
```

The resulting effective throughput was approximately:

```text
15,160.8 classifications per second
```

## Speed ILA Data

The speed project includes:

```text
hw_ila_data_1_speed.ila
hw_ila_data_1_speed.wcfg
hw_ila_data_1_speed.wdb
```

The ILA capture includes signals associated with the NN input and result path, including:

```text
nn_scan_addr
stored_doutb
nn_data_in
NN input-valid
scan complete
NN predicted digit
NN output-valid
freeze state
```

These files support the cycle-count measurements used for the local FPGA latency and throughput results.

## Continuous Inference

A separate project copy was used for continuous local inference.

Unlike the accuracy and speed versions, this configuration used the **frozen camera-derived image stored in BRAM** rather than the controlled MNIST ROM.

The workflow was:

```text
capture one physical image
        ↓
freeze the 28 × 28 image
        ↓
classify locally
        ↓
restart classification
        ↓
classify the same frozen image again
        ↓
repeat continuously
```

This provided a sustained neural-network workload for board-level power observations.

The continuous build was not used for the formal latency result.

## Vivado Resource Reports

The branch contains post-implementation utilization reports for the measurement builds.

### Accuracy Build

Approximate post-placement utilization:

```text
Slice LUTs:     8,626
Registers:      4,088
BRAM tiles:     39.5
DSP slices:     1
```

The increased BRAM usage reflects the controlled 100-image MNIST ROM and measurement-specific logic.

### Speed Build

Approximate post-placement utilization:

```text
Slice LUTs:     10,416
Registers:       7,271
BRAM tiles:         46
DSP slices:          1
```

This project includes both the controlled MNIST ROM and additional timing instrumentation.

### Continuous Build

Approximate post-placement utilization:

```text
Slice LUTs:     8,460
Registers:      4,075
BRAM tiles:        20
DSP slices:         0
```

The continuous configuration is much closer to the original live local implementation because it does not require the large controlled test-image ROM.

These measurement-build resource values should not be substituted for the cleaner local FPGA baseline utilization reported elsewhere.

## Vivado Timing and Route Reports

The branch includes implementation reports such as:

```text
design_1_wrapper_timing_summary_routed_speed.rpt
design_1_wrapper_route_status_accuracy.rpt
```

The speed timing report documents the routed timing status for the measurement build.

## Vivado Power Estimate

The continuous build includes a routed Vivado power report.

The estimated power was approximately:

```text
Total on-chip power: 1.755 W
Dynamic power:       1.606 W
Static power:        0.149 W
```

These values are implementation estimates produced by Vivado and are separate from the physical wall-power measurements.

## Physical Power Measurement

Physical board-level power was measured externally using a Kill A Watt meter.

The photographs and videos in this branch document the test sequence across:

- board baseline;
- programmed board;
- speed testing;
- accuracy testing; and
- continuous inference.

The observed local FPGA power states were primarily:

```text
Unprogrammed board:              approximately 2.6–2.7 W
Programmed/local operating:      approximately 2.7–2.8 W
Continuous local inference:      approximately 2.7–2.8 W
Occasional brief observations:   approximately 2.9 W
```

Because these ranges overlap, the external meter did not resolve a distinct sustained increase attributable only to neural-network inference.

The physical measurements therefore characterize the complete FPGA system rather than isolated accelerator power.

## Power Images and Videos

The still images document representative board states and measurement conditions.

The associated videos provide stronger evidence of the meter behavior over time, particularly during continuous inference.

These files are supporting experimental evidence rather than the sole numerical record of the power measurements.

## Relationship to the Live FPGA Implementation

The local measurement projects were created from copies of the previously verified live-classification project.

This preserved the earlier development stages while allowing each experimental configuration to be modified independently.

The progression was:

```text
Live local classification
        ↓
Accuracy project
        ↓
Speed / latency project

Live local classification
        ↓
Continuous inference project
```

The accuracy and speed versions replaced the camera-derived NN input with controlled MNIST ROM data.

The continuous version used the frozen camera-derived image and repeatedly classified it.

## Relationship to the Code Branch

The related measurement-code branch contains:

```text
ov7670_top_accuracy.vhd
ov7670_top_speed.vhd
ov7670_top_continuous.vhd
memGenTestNNMultiImage.py
blk_mem_gen_mnist_test.xcix
measurement bitstreams
generated COE files
mnist_test_rom_pkg.vhd
```

This branch focuses on the **measurement evidence, reports, captures, notebook, photographs, and videos** associated with those implementations.

## Scope Boundary

This branch contains only **local FPGA measurements**.

It does not include:

- Cloud Run inference;
- FPGA-to-cloud communication;
- cloud-assisted latency;
- TLS/network measurements;
- cloud-assisted power measurements; or
- live camera-to-cloud classification.

Those experiments are documented in the cloud-specific branches.

## Purpose

The purpose of this branch is to preserve the complete experimental record for the local FPGA MNIST measurements.

Together, the controlled accuracy data, ILA captures, Vivado reports, latency and throughput measurements, continuous-inference configuration, and physical power evidence document how the verified live FPGA implementation was converted into repeatable local performance experiments.
