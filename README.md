# MNIST FPGA Live Classification

This branch contains the source code for the first working **live MNIST classification implementation on the ZedBoard FPGA**.

The design combines a previously verified OV7670 camera pipeline with a trained MNIST neural network generated using the ZyNet framework. A physical handwritten or printed digit is captured by the camera, reduced to a 28 × 28 representation, stored in FPGA memory, classified locally by the neural network, and displayed using the ZedBoard LEDs.

This branch represents the original working **local live-classification implementation**, before the design was modified for formal performance measurement or cloud-assisted inference.

## System Overview

The implemented data path is:

```text
OV7670 Camera
      ↓
Camera Capture Logic
      ↓
Image Preprocessing / 28 × 28 Sampling
      ↓
Stored FPGA BRAM
      ↓
ZyNet Neural Network
      ↓
Predicted Digit
      ↓
ZedBoard LEDs
```

The deployed network is a fully connected feed-forward MNIST classifier with the architecture:

```text
784 → 30 → 20 → 10
```

The network uses sigmoid activation and a hardmax/maximum-selection stage for final classification.

Model training and model-generation procedures are documented separately in the MNIST model-development branch.

## Platform

- **Board:** ZedBoard
- **FPGA:** Xilinx Zynq-7020
- **Development environment:** Vivado 2018.1
- **Camera:** OV7670
- **Dataset/model:** MNIST
- **Neural-network framework:** ZyNet

Original ZyNet repository:

https://github.com/dsdnu/zynet

## Source Files

### Camera and Integration Logic

The VHDL source files implement the camera interface, display logic, image capture, image storage, and integration with the local neural-network classifier.

The source includes modules for:

- OV7670 configuration;
- I2C communication;
- camera pixel capture;
- clock generation;
- VGA output;
- push-button debouncing;
- live image storage;
- 28 × 28 image capture and freezing;
- neural-network input sequencing; and
- LED classification output.

The integrated top-level source is:

```text
FZTEBUMILV7T646.vhd
```

This file connects the camera pipeline, image storage, ZyNet classifier, VGA path, and LED result output.
```text
genTestData.py 
```
This file generates fixed-point MNIST test vectors used by the ZyNet behavioral simulation. The script can generate either a single selected test image with supporting visualization/header files or the complete 10,000-image MNIST test set. These generated simulation inputs are treated as data artifacts and are preserved separately from the source code.

## ZyNet Neural-Network RTL

The generated and supporting ZyNet RTL retained in this branch includes:

```text
zynet.v
include.v
Layer_1.v
Layer_2.v
Layer_3.v
neuron.v
Weight_Memory.v
Sig_ROM.v
maxFinder.v
relu.v
axi_lite_wrapper.v
param_loader.v
```

`include.v` records the deployed network structure and fixed-point configuration.

The active network consists of:

```text
784 inputs
30-neuron hidden layer
20-neuron hidden layer
10-neuron output layer
hardmax classification
```

Although generic support files such as `relu.v` are retained, the deployed MNIST model uses sigmoid activation.

## Model Parameters

The FPGA-ready trained model parameters used by the implementation are:

```text
weights.mem
biases.mem
```

These files contain the fixed-point weights and biases used by the FPGA parameter-loading logic.

The original floating-point model, training scripts, conversion scripts, training screenshots, and notebook documentation are maintained separately in the MNIST model-development branch.

Per-neuron `.mif` files generated during the ZyNet workflow are preserved with the associated model/data artifacts rather than in this code branch.

## Stored MNIST Test Package

The branch also contains:

```text
mnist_test_rom_pkg.vhd
```

This package contains a single stored 28 × 28 MNIST test image and its expected label.

The package was retained during development and remains referenced by the historical top-level source. In the live implementation, however, the active classification path uses the **stored camera-derived image** rather than the ROM test vector.

This file is preserved because it is part of the historical source hierarchy and also documents the development path that later evolved into the controlled stored-MNIST measurement implementation.

## Memory IP

The live implementation uses separate Block RAM resources for live and stored image data.

The corresponding Vivado IP configuration files should be retained with the branch:

```text
blk_mem_gen_0.xci
blk_mem_gen_stored.xci
```

These files preserve the BRAM configuration required by the top-level design.

## Constraints

The primary board constraint file is:

```text
F5QMAYQILV7T6TF.xdc
```

This file defines the physical board interfaces used by the implementation, including:

- OV7670 camera signals;
- VGA output;
- board clock;
- LEDs;
- switches; and
- push buttons.

Vivado-generated out-of-context constraint files are not retained because they are build artifacts rather than authored design source.

## Simulation

`top_sim.v` is retained as a simulation/testbench source associated with this implementation.

Simulation outputs, ILA captures, and later formal performance measurements are documented separately from the implementation source.

## Relationship to Other Branches

This repository separates the implementation stages so that the evolution of the FPGA system remains traceable.

This branch contains the original working:

```text
Camera → FPGA preprocessing → local neural network → LED result
```

Later branches contain:

- controlled local FPGA classification and measurement code;
- local FPGA measurement notebooks and data;
- cloud-assisted FPGA classification code;
- cloud-assisted measurement code and data; and
- live camera-to-cloud classification.

This separation preserves the original functional implementation before it was modified specifically for experimental measurement or cloud inference.

## Files Not Included

This branch intentionally excludes:

- MNIST training scripts and notebooks;
- original floating-point training artifacts;
- command-line training screenshots;
- generated `.mif` archives;
- ILA capture data;
- formal latency and throughput results;
- cloud networking software;
- SDK applications;
- Vivado cache and run directories;
- generated synthesis and implementation logs; and
- general Vivado project-state files.

These materials are preserved in the appropriate model, data, measurement, or later implementation branches.

## Purpose

The purpose of this branch is to preserve the source for the first verified **live local FPGA implementation** of the MNIST classifier.

It serves as the baseline hardware implementation from which the later controlled-measurement and cloud-assisted versions were developed.
