# MNIST FPGA Live Classification — Notebook and Data

This branch contains the notebook, development evidence, Vivado reports, generated data artifacts, and functional-validation media associated with the first working **live local MNIST classification implementation on the ZedBoard FPGA**.

The corresponding source code is maintained in the related live-classification code branch.

This branch documents the progression from a verified OV7670 camera feed to a working implementation that:

```text
captures a physical digit
        ↓
samples a 28 × 28 image
        ↓
freezes the completed camera-derived image in BRAM
        ↓
feeds the stored image to the local ZyNet neural network
        ↓
displays the predicted digit on the ZedBoard LEDs
```

Formal latency, throughput, and controlled-dataset accuracy experiments were performed later and are documented in separate measurement branches.

## Implementation Notebook

The primary notebook is:

```text
MNIST_FPGA_Live_Classification.ipynb
```

The notebook documents:

- bringing the generated ZyNet neural network into the working OV7670 camera project;
- verifying the neural network through behavioral simulation;
- generating simulation inputs with `genTestData.py`;
- sampling the camera image to obtain a 28 × 28 input;
- debugging incomplete and incorrectly frozen camera frames;
- delaying the freeze operation until a complete sampled ROI had been written;
- synchronizing the frozen-frame state between clock domains;
- sharing the stored BRAM between VGA display and neural-network input;
- scanning the 784 stored pixels into ZyNet;
- capturing the neural-network output; and
- displaying the final classification using the ZedBoard LEDs.

The notebook references the image and video files in this branch using relative filenames.

## Development Images

The photographs document the progression of the live camera implementation.

```text
01_live_camera_feed_setup.jpg
02_early_frozen_image_strip_artifact.jpg
03_early_frozen_image_capture_artifact.jpg
04_live_roi_digit_capture.jpg
05_improved_frozen_digit_roi.jpg
06_zedboard_ov7670_hardware_setup.jpg
07_live_classification_system_setup.jpg
08_frame_timing_issue.jpg
09_resolving_frozen_frame_retrieval.jpg
10_working_live_digit_roi.jpg
11_final_live_setup.jpg
12_preclassification_1.jpg
13_frozen_1_thumbnail.jpg
14_classified_1.jpg
15_classified_5.jpg
```

These images show the progression from the initial live camera feed through frame-timing and frozen-image problems to successful local classification.

### Functional Classification Examples

The final photographs include successful classifications of physical MNIST-style digits:

```text
14_classified_1.jpg
15_classified_5.jpg
```

These are functional demonstrations rather than formal accuracy measurements.

## Live Demonstration Videos

Two videos show the completed live-classification workflow:

```text
classifying_1_live.mp4
classifying_5_live.mp4
```

The videos document successful local FPGA classification of physical digits 1 and 5 using the OV7670 camera and ZedBoard.

## Generated Neural-Network Memory Files

The archive:

```text
mif files.zip
```

contains the generated `.mif` files used by the ZyNet implementation.

These files contain fixed-point memory initialization data associated with the trained MNIST model and are kept here as generated model/deployment artifacts rather than source code.

## Behavioral Simulation Data

Simulation-related files include:

```text
test_data_0000.txt
test_data_1000.zip
```

These files contain MNIST test vectors generated for behavioral simulation.

The corresponding Python generator, `genTestData.py`, is maintained with the implementation source because it is part of the reproducible simulation workflow.

## Final FPGA Bitstream

The programmed FPGA configuration is preserved as:

```text
design_1_wrapper.bit
```

This bitstream represents the complete implemented hardware design, including the camera pipeline, image buffering, ZyNet neural network, and board-level interfaces.

The bitstream should not be interpreted as the neural-network model alone; it represents the complete FPGA configuration.

## Vivado Implementation Reports

### Resource Utilization

```text
design_1_wrapper_utilization_synth.rpt
design_1_wrapper_utilization_placed.rpt
```

The placed utilization report provides the most useful resource measurements for this live implementation.

The implementation used approximately:

```text
Slice LUTs:  8,511
Registers:   4,075
Block RAM:   20 tiles
DSPs:        0
```

These values describe this specific historical live build and should remain separate from the later controlled-measurement implementation.

### Timing

```text
design_1_wrapper_timing_summary_routed.rpt
timing_1.rpx
timing_1imp.rpx
```

These files preserve Vivado timing-analysis results for the design.

The routed timing report is included as implementation evidence. Some paths in this historical project were not fully constrained, so these reports should not be interpreted as proof that every interface met a complete timing constraint set.

### Power

```text
design_1_wrapper_power_routed.rpt
power_power_1.pwr
power_power_1imp.pwr
```

The routed Vivado power estimate for this implementation was approximately:

```text
Total on-chip power: 1.758 W
Dynamic power:       1.609 W
Static power:        0.149 W
```

These are Vivado-estimated values rather than direct wall-power measurements.

### Routing

```text
design_1_wrapper_route_status.rpt
```

The route-status report confirms completion of routing for the implemented design.

### Implemented Schematic

```text
schematicimp.pdf
```

This file preserves the implemented Vivado schematic for the completed live-classification design.

## Relationship to Other Branches

The project is separated into branches so that each stage of development and experimentation remains distinguishable.

This branch documents:

```text
Live camera
    ↓
camera-derived frozen image
    ↓
local FPGA neural-network inference
    ↓
LED classification
```

Separate branches contain:

- the source code for this live implementation;
- MNIST model training and model-generation materials;
- controlled local FPGA measurement code and data;
- cloud-assisted FPGA implementation and measurement materials; and
- final live camera-to-cloud validation.

## Scope

This branch documents **development and functional validation** of the live local FPGA classifier.

It does not contain the formal results for:

- controlled 1,000-image FPGA accuracy;
- 1,646-cycle inference latency;
- throughput measurements;
- repeated controlled MNIST benchmarking;
- cloud-assisted inference latency;
- cloud-assisted throughput; or
- cloud communication reliability.

Those measurements belong to the later experimental branches.

## Purpose

The purpose of this branch is to preserve the evidence and documentation for the transition from a working OV7670 camera project to a complete live local MNIST classifier running on the ZedBoard.

Together, the notebook, photographs, videos, generated test/model data, bitstream, and Vivado reports provide a reproducible record of the first successful camera-to-FPGA classification implementation.
