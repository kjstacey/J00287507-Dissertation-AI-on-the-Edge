# MNIST FPGA Measurement Implementations

This branch contains the source changes, generated MNIST ROM data, FPGA bitstreams, and supporting files used for the **non-cloud MNIST FPGA measurement implementations**.

These versions were created by copying the previously verified live-classification Vivado project and modifying the top-level control logic for specific experiments. This allowed the original live implementation to remain unchanged while separate versions were used for:

- controlled classification accuracy;
- inference latency and throughput; and
- continuous local inference.

The underlying camera modules, ZyNet neural-network RTL, board constraints, and model parameters were unchanged from the earlier live-classification implementation.

## Measurement Versions

Three top-level implementations are included:

```text
ov7670_top_accuracy.vhd
ov7670_top_speed.vhd
ov7670_top_continuous.vhd
```

Each corresponds to a separate Vivado project copy and generated bitstream.

## 1. Accuracy Implementation

The accuracy implementation replaced the live camera-derived NN input with controlled MNIST test images stored in FPGA ROM.

The corresponding top-level source is:

```text
ov7670_top_accuracy.vhd
```

The controlled test design:

1. reads a known 28 × 28 MNIST image from ROM;
2. sends all 784 pixels to the ZyNet input;
3. waits for the classification result;
4. compares the predicted class with the known label;
5. increments correct and total counters; and
6. advances to the next image.

Testing was performed in batches of 100 images.

The final controlled FPGA evaluation covered the first 1,000 MNIST test images as ten consecutive 100-image batches.

## MNIST ROM Generation

The script:

```text
memGenTestNNMultiImage.py
```

generates the controlled FPGA test data.

For a selected 100-image block, the script reads the previously generated MNIST test-data files and creates:

- one Xilinx `.coe` file containing 78,400 pixel values; and
- a matching `mnist_test_rom_pkg.vhd` file containing the expected class labels.

Each batch contains:

```text
100 images × 784 pixels = 78,400 pixels
```

The `.coe` file is used to initialize the Vivado Block Memory Generator ROM, while the VHDL package supplies the corresponding expected labels.

The starting image index in the generator is changed for each 100-image block before regenerating the files.

## Controlled MNIST COE Files

The branch includes the generated ROM initialization files for the controlled 1,000-image experiment:

```text
mnist_test_pixels_0000.coe
mnist_test_pixels_0100.coe
mnist_test_pixels_0200.coe
mnist_test_pixels_0300.coe
mnist_test_pixels_0400.coe
mnist_test_pixels_0500.coe
mnist_test_pixels_0600.coe
mnist_test_pixels_0700.coe
mnist_test_pixels_0800.coe
mnist_test_pixels_0900.coe
```

The batch beginning at image 0 was used as the initial configuration and is represented by the generated ROM/package files associated with that project version.

Each `.coe` corresponds to one consecutive block of 100 MNIST test images.

## Expected-Label Package

The generated label package is:

```text
mnist_test_rom_pkg.vhd
```

It defines:

- the number of test images;
- the 784-pixel image size; and
- the expected class label for each image in the active 100-image batch.

The `.coe` file and label package must correspond to the same image block.

## MNIST Test ROM IP

The controlled dataset is stored using the Vivado Block Memory Generator IP:

```text
blk_mem_gen_mnist_test.xcix
```

This IP configuration defines the single-port ROM used by the accuracy and speed implementations.

The ROM was initialized from the appropriate `.coe` file before each batch was rebuilt.

## 2. Speed Implementation

The speed implementation was created from the validated controlled-accuracy project so that the accuracy version could remain unchanged.

The corresponding source is:

```text
ov7670_top_speed.vhd
```

It uses the same controlled MNIST ROM input mechanism as the accuracy project but adds hardware counters for performance measurement.

The timing logic measures:

- per-image inference latency;
- minimum latency;
- maximum latency;
- accumulated latency;
- total 100-image execution cycles; and
- effective throughput.

Inference timing begins when the first pixel of an image is presented to ZyNet and ends when the network asserts its output-valid signal.

The neural-network clock is 25 MHz.

This implementation produced the controlled local FPGA timing result documented separately in the measurement notebook/data branch.

## 3. Continuous Implementation

The continuous implementation is:

```text
ov7670_top_continuous.vhd
```

Unlike the accuracy and speed versions, it does **not** use the controlled MNIST ROM as its active input.

Instead, it returns to the live-camera pipeline:

```text
OV7670
   ↓
28 × 28 frozen camera image
   ↓
stored BRAM
   ↓
ZyNet
```

After one classification completes, the same frozen camera-derived image is submitted again while the image remains frozen.

This produces a sustained local inference workload and was used to observe continuous-operation behavior and physical board power consumption.

It should not be confused with the controlled latency benchmark.

## FPGA Bitstreams

Each measurement project has its own generated bitstream:

```text
design_1_wrapper_accuracy.bit
design_1_wrapper_speed.bit
design_1_wrapper_continuous.bit
```

These preserve the complete programmed FPGA configuration for each measurement version.

The bitstreams represent the full hardware designs rather than the neural-network model by itself.

## Relationship to the Live Implementation

These projects were derived from the earlier live FPGA implementation rather than built independently.

The development sequence was:

```text
Live camera classification
        ↓
copy Vivado project
        ↓
controlled accuracy implementation
        ↓
copy validated accuracy project
        ↓
speed / latency implementation
```

A separate project copy was also used for continuous classification of a frozen camera image.

The unchanged camera source, ZyNet RTL, FPGA model parameters, constraints, and other shared modules are documented in the earlier live-classification code branch.

This branch contains only the files that distinguish the measurement implementations from that baseline.

## Scope

This branch contains the **measurement implementation code and generated ROM inputs**.

Formal experimental results, screenshots, ILA captures, calculations, and analysis should be kept in the corresponding measurement notebook/data branch.

The three implementations should therefore be interpreted as:

```text
accuracy
    controlled dataset → classification correctness

speed
    controlled dataset → latency + throughput

continuous
    frozen camera image → repeated sustained inference
```

## Purpose

The purpose of this branch is to preserve the FPGA implementation changes used to move from functional live-camera classification to controlled and repeatable local FPGA experiments.

Keeping the accuracy, speed, and continuous versions separate preserves the exact hardware configuration used for each measurement while avoiding changes to the original live-classification project.
