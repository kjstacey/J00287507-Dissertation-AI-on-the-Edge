# MNIST Unity Local PC Code

This branch contains the Unity source files used for the local PC implementation of the MNIST experiments.

The Unity project was developed incrementally and later adapted for Meta Quest testing. The scripts in this branch therefore represent the shared implementation used across multiple local configurations. In most cases, moving between PC CPU, PC GPU, and later Quest testing required only:

- changing the Unity Inference Engine backend;
- activating or deactivating the appropriate scripts and assets in the Unity Editor; and
- changing output labels so the recorded results identified the correct platform and backend.

The Unity Editor configuration used for each experimental version is documented separately in the corresponding **Data and Notebook** branches.

## Branch Scope

This branch documents the **local PC implementation** used for:

- CPU inference;
- GPU Compute inference;
- MNIST accuracy validation;
- latency testing;
- throughput testing;
- memory measurement;
- sustained inference;
- laptop-camera testing;
- camera preprocessing; and
- camera-based MNIST inference.

Cloud-assisted inference and Meta Quest-specific camera functionality are documented in separate branches.

## Software Environment

The Unity implementation used:

- **Unity Editor 6000.3.22f1**
- **Unity Inference Engine / Sentis**
- Windows standalone execution
- the shared MNIST ONNX model

The model architecture and model-generation process are documented separately in the MNIST model branches.

## Files in This Branch

### Unity Scene

- `FirstScene.unity`
- `FirstScene.unity.meta`

`FirstScene.unity` contains the PC-side Unity scene used for the local implementation.

Quest-specific objects were removed from this copy so that the branch represents the PC implementation rather than the later shared PC/Quest scene.

The detailed Unity Editor configuration, including which scripts and objects were active for individual experiments, is documented in the corresponding notebook/data branch.

### MNIST Model

- `mnist_model.onnx`
- `mnist_model.onnx.meta`

The ONNX model is included so that the Unity source can be reconstructed and executed without requiring the model to be retrieved from another branch.

The original model-generation workflow and validation are documented separately.

## Source Scripts

### `MNISTModelLoader.cs`

Loads the ONNX model through Unity Inference Engine and creates the inference worker.

The backend is selected when the worker is created.

For GPU Compute:

```csharp
worker = new Worker(runtimeModel, BackendType.GPUCompute);
```

For CPU:

```csharp
worker = new Worker(runtimeModel, BackendType.CPU);
```

The same basic change applies to the benchmark scripts described below.

### `MNISTSingleTest.cs`

Runs inference on a single MNIST test image.

This script was used as an early functional check to confirm that:

- the ONNX model loaded correctly;
- the 784 input values were accepted;
- inference completed; and
- the predicted digit matched the expected label.

The backend can be changed between CPU and GPU Compute by modifying the `Worker` constructor.

### `MNISTAccuracyTest.cs`

Evaluates classification accuracy using the full MNIST test set.

The script reads:

- 10,000 images;
- 784 float values per image; and
- one label per image.

To run the PC CPU version, use:

```csharp
worker = new Worker(runtimeModel, BackendType.CPU);
```

To run the PC GPU version, use:

```csharp
worker = new Worker(runtimeModel, BackendType.GPUCompute);
```

Some current output strings may refer to a later Quest configuration. These labels can be changed without altering the benchmark procedure.

For PC CPU testing, labels should identify:

```text
Platform: Windows PC
Backend: CPU
```

For PC GPU testing:

```text
Platform: Windows PC
Backend: GPU Compute
```

## `MNISTLatencyTest.cs`

Measures inference latency using:

- 50 warm-up runs; and
- 1,000 measured runs.

The script records individual inference latency values and calculates summary statistics such as:

- mean;
- median;
- P95;
- minimum; and
- maximum.

To reproduce the PC CPU or GPU test, change the worker backend and update the platform/backend text written to the CSV and Unity output.

### PC CPU

```csharp
worker = new Worker(runtimeModel, BackendType.CPU);
```

CSV/output labels should identify:

```text
Platform,Windows PC
Backend,CPU
```

### PC GPU

```csharp
worker = new Worker(runtimeModel, BackendType.GPUCompute);
```

CSV/output labels should identify:

```text
Platform,Windows PC
Backend,GPU
```

Any Quest-oriented wording currently present in the script reflects later reuse of the same benchmark code.

## `MNISTThroughputTest.cs`

Measures sustained classification throughput across repeated MNIST inputs.

The benchmark uses:

- 50 warm-up runs; and
- 10,000 measured inferences.

The resulting measurements include:

- total elapsed time;
- images processed per second; and
- average time per inference.

As with the latency test, the backend is changed using the `Worker` constructor.

### CPU

```csharp
worker = new Worker(runtimeModel, BackendType.CPU);
```

### GPU Compute

```csharp
worker = new Worker(runtimeModel, BackendType.GPUCompute);
```

Platform and backend strings in the CSV and console output should also be changed to match the experimental configuration.

## `MNISTMemoryTest.cs`

Measures process memory before and after model loading and during repeated inference.

The script records:

- baseline working set;
- model-loaded working set;
- peak working set;
- baseline private memory;
- model-loaded private memory;
- peak private memory; and
- incremental memory usage.

The current script identifies the platform as Windows standalone and can be used for either CPU or GPU testing by changing the inference backend.

### CPU

```csharp
worker = new Worker(runtimeModel, BackendType.CPU);
```

### GPU Compute

```csharp
worker = new Worker(runtimeModel, BackendType.GPUCompute);
```

The output filename and backend labels should be changed to correspond to the selected backend.

## `MNISTSustainedInference.cs`

Runs repeated inference continuously until manually stopped.

This script was used to maintain an active inference workload for longer-duration observations.

The current script uses:

```csharp
BackendType.GPUCompute
```

For CPU testing, change this to:

```csharp
BackendType.CPU
```

Some UI and console wording may reference later Quest testing. Those strings do not affect the inference procedure.

## Camera Scripts

### `LaptopCameraTest.cs`

Provides the initial PC webcam test.

The script:

- detects available webcams;
- selects the first available camera;
- requests a 640×480 stream at 30 FPS; and
- displays the camera image in the Unity UI.

This script was used to confirm basic webcam access before preprocessing or classification was added.

### `CameraPreprocessTest.cs`

Tests the image-processing path independently of neural-network inference.

The script:

- captures the webcam image;
- crops the image;
- downsamples it to 28×28; and
- converts the image to grayscale.

This stage was used to validate the PC-side camera preprocessing before classification was introduced.

### `CameraMNISTInference.cs`

Combines:

- live PC webcam input;
- MNIST-oriented preprocessing;
- ONNX inference;
- classification display;
- frozen-image benchmarking;
- end-to-end camera benchmarking; and
- live-camera throughput testing.

The script reproduces the FPGA-oriented image-processing geometry by mapping the camera image to the equivalent 160×120 coordinate space and sampling the same region used by the FPGA implementation.

The preprocessing path produces a 28×28 binary image containing 784 input values.

The worker backend can be changed between:

```csharp
BackendType.CPU
```

and:

```csharp
BackendType.GPUCompute
```

Output strings such as:

```text
Frozen Camera CPU Benchmark
End-to-End Camera CPU Benchmark
Live Camera CPU Throughput
```

should be changed when running the GPU configuration so the recorded results accurately identify the selected backend.

## Backend Changes Across Experimental Versions

The same Unity benchmark scripts were reused across several configurations.

The primary source-code change between CPU and GPU experiments was the worker backend.

### CPU

```csharp
worker = new Worker(runtimeModel, BackendType.CPU);
```

### GPU Compute

```csharp
worker = new Worker(runtimeModel, BackendType.GPUCompute);
```

The corresponding output strings and CSV metadata were changed to identify the selected configuration.

Later Meta Quest testing reused much of the same benchmark logic. Some source files in this branch therefore contain Quest-oriented comments, UI fields, or output strings from the later development stage.

These later labels do not indicate a different benchmark methodology.

For reproduction, the important changes are:

1. select the appropriate `Worker` backend;
2. update the platform/backend output labels;
3. activate the appropriate scripts and assets in the Unity Editor; and
4. run the corresponding benchmark.

The Unity Editor-side setup for each experimental configuration is documented in the notebook/data branches rather than repeated here.

## Unity Metadata Files

Each Unity asset is accompanied by its `.meta` file.

These files preserve Unity asset identifiers and references and should remain with the corresponding:

- scripts;
- scene;
- and ONNX model.

## Compiled Application Build

The Windows standalone executable is **not included in this branch**.

A complete Unity Windows build requires the executable together with its generated `*_Data` directory and supporting runtime files. The resulting build package exceeds the file-size limit used for this repository archive.

The compiled application can instead be recreated from the supplied Unity scene, scripts, model, and project configuration using Unity Editor 6000.3.22f1.

The same limitation applies to the compiled Meta Quest `.apk` files documented in later branches.

## Relationship to Other Branches

This branch contains the implementation source for the local PC experiments.

The corresponding **MNIST Unity Local PC Data and Notebook** branch documents:

- Unity Editor configuration;
- active scene objects and scripts;
- CPU and GPU test configurations;
- collected CSV files;
- benchmark results;
- camera-test results;
- power measurements;
- memory measurements; and
- reproducibility notes.

The later Quest and cloud branches document the platform-specific extensions of this shared Unity implementation.
