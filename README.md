# EMNIST FPGA Local Classification — Measurements and Code

This branch contains the implementation code, Vivado reports, controlled test data, ILA capture, photographs, videos, and bitstreams associated with the **local FPGA EMNIST Balanced performance measurements** conducted for the dissertation:

**Machine Learning on the Edge: Performance and Security Evaluation of Artificial Neural Network Implementations in Embedded Systems**

The experiments were performed after the compact EMNIST CNN had been integrated with the OV7670 camera and functionally validated on the ZedBoard Rev E.

Separate copies of the working Vivado 2018.1 project were used for baseline characterization, controlled classification accuracy, latency and throughput, and continuous inference.

The four configurations were:

```text
Baseline
    Live OV7670 camera
    → compact EMNIST CNN
    → resource, memory, and power measurements

Accuracy
    Controlled EMNIST test ROM
    → 47-class CNN
    → expected-label comparison
    → correct / total counts

Speed
    Controlled EMNIST test ROM
    → CNN and cycle counters
    → latency and throughput measurements

Continuous
    Frozen camera-derived image
    → repeated CNN inference
    → sustained-operation power observations
```

The existing CNN arithmetic, trained model parameters, and camera components were preserved from the original implementation.

The source files for those shared components are maintained in `EMNIST-FPGA-Live-Classification-Code`.

---

## Measurement Scope

The experiments evaluated:

- Classification accuracy using 1,000 EMNIST Balanced test images;
- Per-image inference latency;
- Total execution time for a 100-image batch;
- Effective classification throughput;
- FPGA resource and BRAM utilization;
- Routed timing status;
- Vivado-estimated on-chip power;
- Physical AC power consumption; and
- Sustained continuous-inference behavior.

Controlled accuracy and speed measurements used dataset images stored in FPGA ROM rather than live camera inputs.

Continuous inference used a frozen camera-derived image, allowing the same image to be classified repeatedly.

---

# Implementation Configurations

## Baseline

The baseline configuration used the previously verified live-camera implementation without accuracy-testing or speed-measurement instrumentation.

Files:

```text
ov7670_top_base.vhd
ov7670_top_base.bit
```

This configuration established the resource, memory, and power baseline before introducing the 100-image test ROM.

## Accuracy

The accuracy configuration replaced the camera-derived CNN input with controlled EMNIST Balanced test images.

Files:

```text
ov7670_top_accuracy.vhd
ov7670_top_accuracy.bit
```

The design sequentially loaded each image into the CNN input memory, initiated inference, compared the predicted class against the expected label, and incremented the correct-classification counter.

LEDs 0–6 displayed the binary correct count, while LED7 indicated completion of the 100-image batch.

## Speed

The speed configuration retained the controlled test ROM and added hardware cycle counters.

Files:

```text
ov7670_top_speed.vhd
ov7670_top_speed.bit
```

The counters recorded:

- Per-image latency including image loading;
- CNN execution interval; and
- Total execution time for the 100-image sequence.

The measured signals were captured using Vivado's Integrated Logic Analyzer (ILA).

## Continuous Inference

The continuous configuration returned to the live-camera input path.

Files:

```text
ov7670_top_cont.vhd
ov7670_top_cont.bit
```

The controller repeatedly classified the same frozen 28×28 camera image.

This created a sustained inference workload for physical power observations without requiring repeated manual button presses.

The continuous configuration did not use the controlled 100-image test ROM.

---

# Controlled Accuracy Measurement

The first 1,000 images from the EMNIST Balanced test set were evaluated in ten sequential batches containing 100 images each.

Every image contained 784 eight-bit grayscale pixel values and an expected class label from 0 through 46.

The batch-generation script was:

`memGenTestEMNISTMultiImage_IDX.py`

The script read the EMNIST Balanced test-image and test-label IDX files, applied the required orientation transformation, and generated the FPGA-compatible data.

For each batch, it produced:

- A `.coe` file containing 78,400 pixel values;
- A VHDL package containing 100 six-bit expected class labels; and
- A CSV file identifying the test indices and expected labels.

The original dataset order was preserved.

## Accuracy Test Procedure

For each batch:

1. Generate the 100-image COE file and corresponding label package.
2. Select the new COE file in the Vivado Block Memory Generator.
3. Update `emnist_test_rom_pkg.vhd` with the labels for the selected batch.
4. Regenerate the memory IP output products.
5. Rerun synthesis and implementation and generate the bitstream.
6. Program the ZedBoard.
7. Initiate the accuracy test.
8. Read the correct-classification count from the LEDs.
9. Record the result and preserve the photographic or video evidence.

The same procedure was repeated for all ten batches.

## Accuracy Results

| Test images | Correct | Accuracy |
|---|---:|---:|
| 0–99 | 86 / 100 | 86% |
| 100–199 | 83 / 100 | 83% |
| 200–299 | 83 / 100 | 83% |
| 300–399 | 83 / 100 | 83% |
| 400–499 | 89 / 100 | 89% |
| 500–599 | 86 / 100 | 86% |
| 600–699 | 91 / 100 | 91% |
| 700–799 | 87 / 100 | 87% |
| 800–899 | 93 / 100 | 93% |
| 900–999 | 91 / 100 | 91% |
| **Total** | **872 / 1,000** | **87.2%** |

The controlled FPGA accuracy was **87.2%**, corresponding to 872 correct and 128 incorrect classifications.

The trained compact CNN previously achieved 86.85% accuracy on the full 18,800-image EMNIST Balanced test set using PyTorch.

The FPGA experiment evaluated a smaller subset. The difference between the reported percentages therefore does not establish an accuracy improvement attributable to FPGA implementation.

The results demonstrate classification performance consistent with the trained reference model.

---

# Accuracy Test Data

The repository preserves all ten COE files:

```text
emnist_test_pixels_0000.coe
emnist_test_pixels_0100.coe
emnist_test_pixels_0200.coe
emnist_test_pixels_0300.coe
emnist_test_pixels_0400.coe
emnist_test_pixels_0500.coe
emnist_test_pixels_0600.coe
emnist_test_pixels_0700.coe
emnist_test_pixels_0800.coe
emnist_test_pixels_0900.coe
```

The corresponding labels are preserved in:

```text
emnist_test_labels_0000.csv
emnist_test_labels_0100.csv
emnist_test_labels_0200.csv
emnist_test_labels_0300.csv
emnist_test_labels_0400.csv
emnist_test_labels_0500.csv
emnist_test_labels_0600.csv
emnist_test_labels_0700.csv
emnist_test_labels_0800.csv
emnist_test_labels_0900.csv
```

The active Vivado label package is:

`emnist_test_rom_pkg.vhd`

The VHDL package was regenerated for each 100-image batch. Its filename remained constant while the expected labels changed.

The repository retains the generator and CSV files so the appropriate package can be recreated for any batch.

The Block Memory Generator configuration is preserved in:

`blk_mem_gen_1.xci`

The test ROM uses eight-bit data and a depth of 78,400 words.

---

# Latency and Throughput Measurement

The speed configuration used the same controlled 100-image ROM mechanism but added cycle-counting instrumentation to the FPGA controller.

The CNN clock was 25 MHz, corresponding to 40 ns per cycle.

The measurement intervals were:

```text
Image latency
    first image-loading cycle
    → completion of CNN inference

CNN execution interval
    CNN start sequence
    → detection of completion

Batch execution
    beginning of first image
    → completion of image 100
```

## ILA Evidence

The captured hardware measurement is preserved as:

`emnist_fpga_speed.ila`

The ILA capture contains the following recorded values:

```text
Processed images:       100
Correct classifications: 91

Last image cycles:      4,002,970
Last CNN cycles:        3,999,832
Total batch cycles:   400,297,099
```

The 91 correct classifications correspond to the final accuracy batch, images 900–999.

## Latency Results

| Measurement | Result |
|---|---:|
| Last-image latency | 4,002,970 cycles |
| Last-image latency | 160.119 ms |
| CNN execution interval | 3,999,832 cycles |
| CNN execution interval | 159.993 ms |
| Image-loading and controller difference | 3,138 cycles |
| Difference in time | 0.126 ms |

The captured last-image latency includes loading the 784 pixels into CNN input memory and completing inference.

The CNN-only interval was measured separately using the start and completion conditions defined in the speed controller.

The ILA result directly documents the final image's latency. It does not independently establish the distribution of individual latency values over all 100 images.

## Throughput Results

The full batch required:

```text
100 images
400,297,099 cycles
16.011884 seconds
```

The effective throughput was approximately:

**6.245 classifications per second.**

This throughput includes image loading and controller overhead in addition to CNN execution.

The sequential convolution implementation accounted for most of the observed per-image execution interval.

---

# FPGA Resource and Memory Utilization

Post-placement Vivado 2018.1 reports were preserved for each implementation.

## Resource Comparison

| Resource | Baseline | Accuracy | Speed | Continuous |
|---|---:|---:|---:|---:|
| Slice LUTs | 2,714 | 2,844 | 4,411 | 2,714 |
| Slice registers | 738 | 784 | 3,526 | 743 |
| BRAM tiles | 30.5 | 50.0 | 53.5 | 30.5 |
| DSP slices | 14 | 15 | 15 | 14 |

The target device was the Zynq-7000 XC7Z020 on the ZedBoard Rev E.

The available resources were 53,200 LUTs, 106,400 slice registers, 140 BRAM tiles, and 220 DSP slices.

## Interpretation

The original live-camera configuration used 30.5 BRAM tiles, equivalent to approximately 1,098 KiB of allocated nominal BRAM capacity.

The accuracy configuration increased BRAM allocation to 50 tiles due primarily to the controlled 100-image ROM.

The speed configuration used 53.5 BRAM tiles and additional LUTs and registers, reflecting the test ROM and measurement/debug instrumentation.

The continuous configuration used the same 30.5 BRAM tiles as the baseline, with only a small change in register usage.

These figures describe complete implemented configurations, not isolated CNN resource consumption.

Allocated BRAM capacity should not be interpreted as the exact number of bytes actively occupied by model parameters or intermediate data.

---

# Vivado Timing Verification

The projects included explicit clock constraints for the ZedBoard system clock and OV7670 pixel clock.

Vivado automatically derived the MMCM-generated clocks.

The resulting clock configuration included:

```text
System input:        100 MHz
MMCM output 0:        50 MHz
MMCM output 1:        25 MHz
Camera pixel clock:   25 MHz (constrained assumption)
```

The camera PCLK constraint specified the assumed camera operating frequency; its presence in the report does not independently measure the physical signal.

## Routed Timing Results

| Configuration | WNS | WHS | TNS | THS |
|---|---:|---:|---:|---:|
| Baseline | +6.039 ns | +0.069 ns | 0 | 0 |
| Accuracy | +6.086 ns | +0.074 ns | 0 | 0 |
| Speed | +6.166 ns | +0.028 ns | 0 | 0 |
| Continuous | +5.970 ns | +0.101 ns | 0 | 0 |

All four routed implementations met their user-specified timing constraints.

These results apply to the analyzed constrained paths. External camera/VGA interface timing was not fully characterized with complete input/output delay constraints.

---

# Vivado-Estimated Power

Routed Vivado power reports were preserved for all four configurations.

| Configuration | Dynamic power | Static power | Total on-chip power |
|---|---:|---:|---:|
| Baseline | 0.131 W | 0.110 W | 0.240 W |
| Accuracy | 0.133 W | 0.111 W | 0.244 W |
| Speed | 0.138 W | 0.111 W | 0.249 W |
| Continuous | 0.131 W | 0.110 W | 0.240 W |

The displayed component values are rounded independently by Vivado.

All four reports identified the overall estimation confidence as **low**, reflecting limitations in the available switching-activity information.

The estimates are included for implementation documentation but are not treated as measured system power consumption.

---

# Physical Power Measurement

Physical AC power was measured using the P4400 Kill A Watt meter connected to the ZedBoard power supply.

The measurements were collected under different operating conditions before and after programming the FPGA.

## Baseline Power Observations

| Operating condition | Observed AC power |
|---|---:|
| Not programmed, USB disconnected | 2.6–2.7 W |
| Not programmed, USB connected | 2.8–3.0 W |
| Programmed, USB connected | 2.8–3.1 W |
| Programmed, USB disconnected | 2.7–2.8 W |
| Individual inference, USB disconnected | 2.7–2.8 W |

The physical measurements represent AC input power for the metered system rather than isolated FPGA logic power.

No distinguishable increase was observed during individual inference button presses at the meter's display resolution and update rate.

## Continuous-Inference Power Observations

| Operating condition | Observed AC power |
|---|---:|
| Continuous inference, USB connected | 3.0–3.1 W |
| Continuous inference, USB disconnected | 2.7–2.8 W |

The continuous configuration repeatedly classified a frozen image, providing a sustained inference workload.

Without USB connectivity, the observed 2.7–2.8 W range matched the programmed baseline.

With USB connected, the observed 3.0–3.1 W range fell within the upper portion of the previously recorded programmed-board range.

The meter did not resolve a distinct additional power requirement attributable solely to CNN inference.

This result does not indicate that inference consumed no energy. The external measurement included the board and power-conversion overhead and could not isolate individual inference operations.

---

# Accuracy and Power Evidence

The repository contains photographs for all ten accuracy batches using filenames in the following form:

```text
emnist_fpga_accuracy_000.JPG
emnist_fpga_accuracy_100.JPG
emnist_fpga_accuracy_200.JPG
...
emnist_fpga_accuracy_900.JPG
```

It also includes photographs associated with the baseline and continuous power measurements, including:

```text
emnist_fpga_power_cont_nousb.JPG
emnist_fpga_power_cont_usb.JPG
```

The video recordings document the accuracy-test outputs and the observed Kill A Watt readings during programmed and continuous operation.

The original video recordings were converted to compressed MP4 format for GitHub storage.

The MP4 filenames preserve descriptive labels, a `v` suffix, and recording timestamps.

The photographs and videos are supporting evidence for the observations recorded above. They should be interpreted together with the operating-condition descriptions rather than as complete statistical measurement records.

---

# Vivado Reports

The repository preserves utilization, timing, and power reports for all four configurations.

## Baseline

```text
ov7670_top_utilization_placed_base.rpt
ov7670_top_timing_summary_routed_base.rpt
ov7670_top_power_routed_base.rpt
```

## Accuracy

```text
ov7670_top_utilization_placed_accuracy.rpt
ov7670_top_timing_summary_routed_accuracy.rpt
ov7670_top_power_routed_accuracy.rpt
```

## Speed

```text
ov7670_top_utilization_placed_speed.rpt
ov7670_top_timing_summary_routed_speed.rpt
ov7670_top_power_routed_speed.rpt
```

## Continuous

```text
ov7670_top_utilization_placed_cont.rpt
ov7670_top_timing_summary_routed_cont.rpt
ov7670_top_power_routed_cont.rpt
```

The baseline, accuracy, speed, and continuous configurations were independently synthesized and implemented.

The reports therefore describe the actual hardware configurations used for their respective experiments.

Resource differences between configurations should not be attributed solely to changes in CNN computation because the measurement infrastructure also changed.

---

# Reproducing the Measurements

The EMNIST measurement projects were derived from the working live-camera implementation.

Reconstruction requires the shared CNN and camera RTL, model parameter memories, camera IP, and constraints from the original EMNIST implementation, together with the measurement-specific files provided here.

## Accuracy Reproduction

Use the appropriate COE file and regenerate `emnist_test_rom_pkg.vhd` for the corresponding batch.

The original compressed EMNIST Balanced test-image and test-label files are the source data for the Python generator.

The active 100-image ROM and expected-label package must refer to the same batch.

Rebuild and reprogram the FPGA for each batch, then record the correct count displayed by the LEDs.

## Speed Reproduction

Use the speed top-level module, the controlled test ROM, and the retained cycle counters.

The ILA should be clocked at 25 MHz and triggered using the batch-completion signal.

The recorded cycle counts can be converted to time using the 40 ns clock period.

The final ILA capture is retained for independent inspection of the recorded values.

## Continuous Reproduction

Use the continuous-inference top-level module and the original live-camera configuration.

Capture and freeze a physical character. Confirm repeated inference activity and observe the external power meter during sustained operation.

The continuous configuration does not require the accuracy-test COE files.

---

# Scope and Limitations

This branch documents local FPGA measurements only.

It does not include cloud-assisted inference, Cloud Run communication, TLS/network analysis, or remote FPGA execution.

The accuracy experiment used 1,000 of the 18,800 EMNIST Balanced test images.

The latency capture directly records the last image and the total 100-image batch, not a complete distribution of individual per-image latency measurements.

Vivado resource measurements represent the complete hardware configurations, including camera and experimental infrastructure.

Vivado power reports provide low-confidence estimates based on switching-activity assumptions.

Physical power readings represent metered AC input power for the system and cannot isolate CNN power or energy per classification.

The continuous workload was used to observe sustained system power rather than to establish classification accuracy or per-image latency.

---

# Related Branches

## `EMNIST-Models`

Contains the selected trained EMNIST compact CNN.

## `EMNIST-Models-Code`

Contains the Python training and model-development source.

## `EMNIST-Models-Data-and-Notebook`

Contains the training and model-selection reproducibility evidence.

## `EMNIST-FPGA-Live-Classification-Code`

Contains the shared FPGA CNN implementation, camera source, trained model memories, IP configurations, and original live-classification bitstream.

## `EMNIST-FPGA-Live-Classification-Data-and-Notebook`

Contains the incremental Vivado development records, standalone CNN verification evidence, and live-camera functional-validation demonstrations.

---

# Dissertation Context

This branch preserves the implementation and measurement evidence associated with local FPGA execution of the compact EMNIST Balanced CNN.

The experiments established controlled classification accuracy, measured inference latency and throughput, documented FPGA resource and memory requirements, and characterized physical AC power under baseline and continuous-inference conditions.

The separate measurement configurations preserved the verified CNN while allowing controlled inputs, hardware timing counters, and sustained workloads to be introduced without modifying the original live-camera demonstration.

Together, the source files, bitstreams, test data, Vivado reports, ILA capture, photographs, and videos support reproducibility of the local FPGA performance evaluation.
