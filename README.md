# MNIST Unity Local PC Data and Notebook

This branch contains the notebooks, screenshots, photographs, and videos used to document the local Windows PC implementation of the MNIST Unity experiments.

It complements the **MNIST Unity Local PC Code** branch.

The code branch contains the Unity scene, C# scripts, ONNX model, and benchmark input assets. This branch documents:

- Unity project setup;
- camera-pipeline development;
- CPU and GPU Compute configuration;
- benchmark procedures;
- editor and standalone-build validation;
- camera-based inference;
- latency and throughput measurements;
- process and GPU memory observations;
- power measurements; and
- supporting visual evidence.

## Notebooks

Two notebooks divide the local PC workflow into setup and measurement phases.

### `MNIST_Unity_Local_PC_Setup.ipynb`

Documents how the local Unity application was assembled and made functional.

Topics include:

- Unity Editor 6000.3.22f1;
- Unity Inference Engine / Sentis;
- TextMeshPro;
- ONNX model import;
- MNIST test-data import;
- Unity scene construction;
- Canvas layout;
- laptop-camera access;
- 28×28 preprocessing;
- camera-to-inference data flow;
- frozen-image classification;
- functional validation; and
- Windows standalone build creation.

This notebook ends once the PC application can successfully perform local camera-based MNIST inference.

### `MNIST_Unity_Local_PC_Measurements.ipynb`

Documents the measurement workflow after the application was functional.

Topics include:

- switching between CPU and GPU Compute;
- activating the appropriate benchmark scripts;
- accuracy validation;
- controlled latency testing;
- throughput testing;
- sustained inference;
- Windows process-memory measurement;
- GPU-memory observations;
- Unity Editor versus standalone-build execution;
- frozen-camera benchmarks;
- end-to-end camera benchmarks;
- live-camera throughput;
- whole-system power measurement; and
- use of screenshots, photographs, and videos as supporting evidence.

## Local PC Measurement Configurations

The same Unity project was reused for CPU and GPU testing.

The primary inference change was the Unity Inference Engine worker backend.

### CPU

```csharp
worker = new Worker(runtimeModel, BackendType.CPU);
```

### GPU Compute

```csharp
worker = new Worker(runtimeModel, BackendType.GPUCompute);
```

The scene, ONNX model, test binaries, and benchmark logic were otherwise largely shared.

Some source scripts contain later wording associated with Quest testing because the Unity project evolved incrementally. Those wording differences do not indicate a different PC benchmark method.

## Model Validation

The Unity implementation reproduced the expected MNIST model result:

```text
Correct: 9663 / 10000
Accuracy: 96.63%
```

Supporting screenshots include:

```text
pc_cpu_accuracy_validation.png
pc_gpu_accuracy_validation.png
```

These images document that the imported ONNX model produced the expected classification accuracy in Unity.

## Controlled Latency

Controlled latency measurements were performed using a repeated single-image inference procedure.

The benchmark used:

```text
50 warm-up runs
1000 measured runs
```

Supporting screenshots include:

```text
pc_cpu_latency_benchmark.png
pc_gpu_latency_benchmark.png
```

The benchmark reports statistics such as:

- mean;
- median;
- P95;
- minimum; and
- maximum.

## Controlled Throughput

The controlled throughput benchmark uses repeated MNIST test images and measures:

- elapsed time;
- images processed per second; and
- average inference time.

Supporting evidence includes:

```text
pc_gpu_throughput_benchmark.png
```

The same procedure can be executed with either the CPU or GPU Compute backend.

## Camera Pipeline Evidence

The local Unity application was developed incrementally from basic camera access to full camera-based inference.

Supporting screenshots include:

```text
pc_camera_preprocessing_preview.png
pc_camera_classification_result.png
pc_camera_frozen_benchmark_early_test.png
pc_camera_frozen_benchmark_run1.png
pc_camera_frozen_benchmark_run2.png
pc_camera_end_to_end_benchmark.png
pc_camera_live_throughput.png
```

These files document:

- live webcam input;
- processed 28×28 images;
- frozen classification images;
- prediction output;
- frozen-image benchmarking;
- end-to-end camera latency; and
- live camera throughput.

## Windows Standalone Build Evidence

Several measurements were recreated using the Windows standalone build after being tested in the Unity Editor.

This produced intentional overlap between editor and build evidence.

The standalone-build screenshots include files such as:

```text
pc_build_camera_idle_no_digit.png
pc_build_camera_idle_processed_view.png
pc_build_gpu_camera_classification_result.png
pc_build_gpu_camera_frozen_benchmark.png
pc_build_gpu_camera_end_to_end_benchmark.png
pc_build_gpu_camera_live_throughput_run1.png
pc_build_gpu_camera_live_throughput_run2.png
```

The standalone build is useful because it allows the application to be observed outside the Unity Editor and reduces the influence of the Editor on process-level measurements.

## CPU Process-Memory Evidence

Windows Task Manager screenshots document process-memory behavior during CPU execution.

These files include:

```text
pc_cpu_memory_taskmanager_sample1.png
pc_cpu_memory_taskmanager_sample2.png
pc_cpu_memory_taskmanager_sample3.png
pc_cpu_memory_taskmanager_sample4.png
pc_cpu_memory_taskmanager_sample5.png
```

These screenshots are measurement observations from different points during execution and are not treated as interchangeable duplicates.

## GPU Process-Memory Evidence

GPU testing includes several Task Manager screenshot groups.

General process-memory evidence includes:

```text
pc_gpu_memory_taskmanager_sample1.png
pc_gpu_memory_taskmanager_sample2.png
```

Additional screenshots expose GPU-related Task Manager columns such as:

- dedicated GPU memory;
- shared GPU memory;
- GPU engine;
- GPU utilization;
- working set; and
- peak working set.

These files are stored with names beginning with:

```text
pc_build_gpu_memory_with_gpu_columns_
```

The additional GPU-memory views help document that the GPU Compute backend was actively using GPU resources.

## Camera Memory Observations

The standalone GPU camera tests include a sequence of Task Manager observations:

```text
pc_build_gpu_camera_memory_sample1.png
pc_build_gpu_camera_memory_sample2.png
pc_build_gpu_camera_memory_sample3.png
pc_build_gpu_camera_memory_sample4.png
pc_build_gpu_camera_memory_sample5.png
pc_build_gpu_camera_memory_sample6.png
pc_build_gpu_camera_memory_sample7.png
pc_build_gpu_camera_memory_sample8.png
pc_build_gpu_camera_memory_sample9.png
pc_build_gpu_camera_memory_sample10.png
```

Additional camera-state memory screenshots are also included.

These images document the Windows process and GPU-memory state during camera-based GPU execution.

## Photographic Evidence

The branch includes photographs taken during the experiments.

### CPU Camera Benchmark

```text
Unity_CPU_Benchmark.jpg
```

Shows the local Unity camera application during the frozen-image CPU benchmark.

### CPU Throughput

```text
Unity_CPU_Throughput.jpg
```

Documents the live camera CPU throughput result.

### CPU End-to-End Benchmark

```text
Unity_End_End_CPU.jpg
```

Shows the end-to-end CPU camera benchmark running on the PC.

### Live Inference

```text
Unity_Live_inference.jpg
Unity_Live_Inference_Overview.jpg
```

These photographs document the live camera classification application and the physical workstation setup.

## Power Measurement Evidence

PC power was measured externally with a **P4400 Kill A Watt** meter.

The Kill A Watt measures whole-system AC power rather than CPU-package or GPU-package power.

### CPU Power

```text
Unity_CPU_Power.jpg
```

Documents the external meter during CPU inference.

### GPU Power

```text
Unity_GPU_Power.jpg
```

Documents the external meter during GPU Compute inference.

The meter manual is stored separately in the Manuals and Specifications branch.

## Video Evidence

The branch contains video documentation of the experimental workflow.

### Power

```text
Gpu Power Unity10-26-202608-25.mp4
Pc Idle Power10-21-202614-16.mp4
Pc Power App Continuous10-22-202611-32.mp4
```

These videos document:

- GPU inference power;
- idle system power; and
- power during continuous inference.

### Camera Performance

```text
Live Pc Latency10-22-202611-49.mp4
Pc End End Latency10-22-202609-53.mp4
Pc Throughput Live10-22-202606-40.mp4
```

These videos document:

- live-camera latency;
- end-to-end camera latency; and
- live camera throughput.

### Functional Validation

```text
Pc Live Unity10-22-202610-05.mp4
Pc No Internet Unity Editor10-22-202606-31.mp4
Unity Live Pc Inference10-26-202608-02.mp4
```

These provide evidence of:

- live Unity camera inference;
- local inference operating without Internet access; and
- application-level PC inference behavior.

The offline validation is particularly important because it demonstrates that the local PC implementation does not depend on the cloud inference service.

## Editor Versus Standalone Execution

Some experiments were first performed in the Unity Editor and then recreated in the Windows standalone application.

These two execution contexts serve different documentation purposes.

### Unity Editor

Used for:

- validating scripts;
- viewing Console output;
- confirming model accuracy;
- checking component activation;
- inspecting the scene; and
- debugging camera processing.

### Windows Standalone Build

Used for:

- observing deployed application behavior;
- measuring `MNISTUnity.exe`;
- monitoring Windows process memory;
- observing dedicated and shared GPU memory;
- camera-based application tests; and
- external power measurement.

Apparent duplication between screenshots can therefore represent the same test performed in different execution contexts rather than redundant evidence.

## Measurement Scope

The branch documents five main local PC measurement categories:

```text
Model correctness
    → single-image validation
    → 10,000-image accuracy

Controlled inference
    → latency
    → throughput

Resource use
    → process memory
    → GPU-memory observations

Camera application performance
    → frozen-image inference
    → end-to-end latency
    → live throughput

Whole-system power
    → idle
    → CPU inference
    → GPU Compute inference
```

## Relationship to the Code Branch

Use the **MNIST Unity Local PC Code** branch for:

- `FirstScene.unity`;
- C# scripts;
- `mnist_model.onnx`;
- Unity metadata files; and
- `mnist_test_binaries.zip`.

Use this **Data and Notebook** branch for:

- setup documentation;
- measurement documentation;
- screenshots;
- Task Manager evidence;
- photographs;
- videos; and
- reproducibility notes.

Together, the two branches document both the implementation and the experimental process used for the local PC MNIST evaluation.

## Compiled Build

The complete Windows standalone build is not stored in the repository because the executable and its required generated Unity data/runtime files exceed the repository upload limit used for this archive.

The application can be rebuilt from the source assets documented in the corresponding code branch using Unity Editor 6000.3.22f1.
