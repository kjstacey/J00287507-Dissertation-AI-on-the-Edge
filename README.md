# MNIST Unity Local Quest 3S Data and Notebook

This branch contains the notebooks, screenshots, and OVR Metrics logs used to document and reproduce the **local Meta Quest 3S MNIST implementation and benchmark process**.

It complements the **MNIST Unity Local Quest 3S Code** branch.

The code branch contains the Quest-specific scene, scripts, and package configuration. This branch documents:

- conversion of the working PC Unity project to Meta Quest 3S;
- Android and Meta XR configuration;
- Quest scene and Canvas changes;
- local Quest camera access;
- headset deployment through Meta Quest Developer Hub (MQDH);
- GPU and CPU benchmark procedures;
- tethered and untethered test conditions;
- controlled MNIST benchmarks;
- sustained inference;
- camera-based benchmarks; and
- device telemetry collected with OVR Metrics.

## Notebooks

Two notebooks separate the Quest workflow into setup and benchmarking phases.

### `MNIST_Unity_Quest3S_Setup_Notebook.ipynb`

Documents the transition from the working Windows PC Unity project to the Meta Quest 3S implementation.

Topics include:

- switching the Unity build target to Android;
- installing the Meta XR SDK;
- enabling Quest/OpenXR support;
- creating the Quest-specific scene;
- adding the Meta XR rig;
- disabling the original desktop `Main Camera`;
- adding `PassthroughCameraAccess`;
- configuring headset-camera permission;
- replacing the PC `WebCamTexture` camera path;
- preserving the shared 28×28 MNIST preprocessing;
- adapting the Canvas for XR use;
- adding poke and ray interaction;
- connecting the Quest camera and inference scripts;
- configuring Android player settings;
- building the APK; and
- installing and launching the application through MQDH.

This notebook ends once the Quest application is functional and capable of performing local MNIST inference.

### `MNIST_Unity_Local_Quest3S_Benchmarking.ipynb`

Documents the Quest benchmarking procedure and maps the benchmark results to the supporting screenshots and OVR Metrics sessions.

Topics include:

- GPU and CPU backend configuration;
- tethered and untethered testing;
- controlled accuracy, latency, and throughput;
- sustained inference;
- frozen-camera latency;
- end-to-end camera processing;
- live camera classification;
- live camera throughput; and
- OVR Metrics telemetry.

## Experimental Sequence

The Quest benchmarking was performed in the following order:

```text
1. GPU — tethered
2. GPU — untethered
3. CPU — tethered
4. CPU — untethered
```

Repeated screenshots of the same benchmark therefore document different connection conditions rather than unnecessary duplicate captures.

For tests with paired GPU or CPU screenshots:

```text
first capture  → tethered
second capture → untethered
```

Where more than two screenshots exist, the first half correspond to the tethered period and the second half correspond to the untethered period.

## OVR Metrics Sessions

Nine OVR Metrics CSV logs are included.

### GPU Sessions

```text
quest3s_ovrmetrics_session1_camera_benchmarks.csv
quest3s_ovrmetrics_session2.csv
quest3s_ovrmetrics_session3.csv
quest3s_ovrmetrics_session4.csv
quest3s_ovrmetrics_session5.csv
quest3s_ovrmetrics_session6.csv
quest3s_ovrmetrics_session7.csv
```

Sessions **1–7** document GPU setup and GPU benchmark activity.

The session numbers follow the actual experimental collection sequence rather than the timestamps embedded in the original device-generated filenames.

### CPU Sessions

```text
quest3s_ovrmetrics_session8.csv
quest3s_ovrmetrics_session9.csv
```

Sessions **8–9** document the CPU benchmark period.

The screenshot sequence is used together with these logs to identify the associated benchmark and tethering condition.

## Backend Configuration

The local Quest application was tested with two Unity Inference Engine backends.

### GPU

```csharp
BackendType.GPUCompute
```

### CPU

```csharp
BackendType.CPU
```

The same MNIST ONNX model and benchmark procedures were used for both configurations.

The backend change therefore compares two local execution paths on the same Quest 3S hardware.

## Controlled MNIST Benchmarks

The controlled benchmark uses the shared MNIST test-set binaries rather than live camera input.

It includes:

- classification accuracy;
- repeated single-image latency; and
- repeated inference throughput.

The expected model accuracy is:

```text
9663 / 10000
96.63%
```

### GPU Evidence

```text
quest3s_gpu_accuracy_latency_throughput.jpg
quest3s_gpu_accuracy_latency_throughput2.jpg
```

These represent:

```text
first  → GPU tethered
second → GPU untethered
```

### CPU Evidence

```text
quest3s_cpu_accuracy_latency_throughput.jpg
quest3s_cpu_accuracy_latency_throughput2.jpg
quest3s_cpu_accuracy_latency_throughput3.jpg
quest3s_cpu_accuracy_latency_throughput4.jpg
```

The first half document the tethered CPU period and the second half document the untethered CPU period.

## Sustained Inference

Sustained inference repeatedly executes the MNIST model for an extended period.

This workload provides evidence of:

- sustained inference rate;
- behavior under continuous model execution;
- runtime stability; and
- device telemetry during a longer workload.

### GPU Evidence

```text
quest3s_gpu_sustained_inference.jpg
quest3s_gpu_sustained_inference2.jpg
quest3s_gpu_sustained_inference3.jpg
quest3_gpu_sustained_inference4.jpg
```

The first half correspond to GPU tethered execution and the second half to GPU untethered execution.

### CPU Evidence

```text
quest3s_cpu_sustained_inference_running.png
```

This image documents the CPU sustained-inference workload while active.

## Frozen-Camera Benchmark

The frozen-camera benchmark uses the current camera-derived 28×28 image as a fixed input.

The benchmark performs:

```text
50 warm-up runs
1000 measured runs
```

Because preprocessing has already occurred, this benchmark primarily measures repeated inference and synchronous result retrieval on a camera-derived tensor.

### GPU Evidence

```text
quest3s_gpu_frozen_camera_benchmark.jpg
quest3s_gpu_frozen_camera_benchmark2.jpg
```

These represent GPU tethered and GPU untethered runs.

### CPU Evidence

```text
quest3s_cpu_frozen_camera_benchmark.jpg
quest3s_cpu_frozen_camera_benchmark2.jpg
quest3s_cpu_frozen_camera_benchmark3.jpg
```

These span the tethered and untethered CPU benchmark periods.

## End-to-End Camera Benchmark

The end-to-end camera benchmark measures the full local processing pipeline:

```text
Quest camera
    ↓
camera pixel access
    ↓
source-coordinate mapping
    ↓
28×28 sampling
    ↓
grayscale conversion
    ↓
binary threshold
    ↓
tensor creation
    ↓
local inference
    ↓
output readback
```

This measurement therefore includes considerably more work than the frozen-camera benchmark.

### GPU Evidence

```text
quest3s_gpu_end_to_end_camera_benchmark.jpg
quest3s_gpu_end_to_end_camera_benchmark2.jpg
```

These represent GPU tethered and GPU untethered runs.

### CPU Evidence

```text
quest3s_cpu_end_to_end_camera_benchmark.jpg
quest3s_cpu_end_to_end_camera_benchmark2.jpg
```

These represent CPU tethered and CPU untethered runs.

## Live Camera Classification

Live classification verifies the complete Quest application workflow:

```text
Passthrough camera
    ↓
28×28 preprocessing
    ↓
local inference
    ↓
predicted digit
    ↓
XR Canvas output
```

### GPU Evidence

```text
quest3s_gpu_live_camera_classification.jpg
quest3s_gpu_live_camera_classification_2.jpg
```

These represent tethered and untethered GPU operation.

### CPU Evidence

```text
quest3s_cpu_live_classification.png
```

This provides the CPU live-classification evidence.

## Live Camera Throughput

Live camera throughput measures predictions from newly arriving camera frames over elapsed real time.

This is distinct from the controlled MNIST throughput benchmark because it includes the practical camera-frame processing rate.

### GPU Evidence

```text
quest3s_gpu_live_throughput_camera_run1.jpg
quest3s_gpu_live_throughput_camera_run2.jpg
```

These represent:

```text
run1 → GPU tethered
run2 → GPU untethered
```

### CPU Evidence

```text
quest3s_cpu_live_throughput_camera.png
quest3s_cpu_live_throughput_camera2.png
```

These represent CPU tethered and CPU untethered execution.

## Pre-Benchmark Device-State Evidence

Several screenshots document the Quest state before or between benchmark runs.

These include:

```text
quest3_prelaunch_metrics.png
quest3_prelaunch_metrics2.png
quest3s_preclassification_metrics.jpg
```

These images are contextual evidence rather than benchmark-result screenshots.

They help document the OVR Metrics state and device conditions around the benchmark periods.

## OVR Metrics Data

The CSV logs contain device-side telemetry collected during the Quest experiments.

Depending on the session, available metrics include fields related to:

- application frame rate;
- CPU utilization;
- GPU utilization;
- application memory;
- GPU memory;
- CPU/GPU performance levels;
- battery/device state;
- frame timing;
- thermal or throttling indicators; and
- other runtime statistics exposed by OVR Metrics.

Not every available field is required for dissertation analysis.

The logs should be used to extract only metrics relevant to the stated performance and resource-use questions.

## Screenshots and Logs Serve Different Roles

The Unity screenshots document the benchmark results produced by the application itself.

These are the primary evidence for:

- classification accuracy;
- inference latency;
- throughput;
- frozen-camera timing;
- end-to-end camera timing; and
- live camera throughput.

The OVR Metrics CSV files provide supporting device-level information during the corresponding benchmark periods.

The two forms of evidence should therefore be interpreted together rather than treated as interchangeable measurements.

## Tethering as an Experimental Condition

Tethered and untethered Quest execution are documented separately because connection state may affect device behavior.

The repository therefore preserves both conditions for GPU and CPU testing:

```text
GPU tethered
GPU untethered
CPU tethered
CPU untethered
```

The connection condition should be identified whenever Quest results are reported or compared.

## Relationship to the Code Branch

Use the **MNIST Unity Local Quest 3S Code** branch for:

```text
QuestCameraMNISTInference.cs
QuestCameraPreview.cs
SecondScene.unity
manifest.json
```

Use this **Data and Notebook** branch for:

- Quest setup documentation;
- benchmark documentation;
- result screenshots;
- tethered/untethered evidence;
- OVR Metrics CSV logs; and
- reproducibility notes.

The Quest-specific code branch is intentionally a delta from the broader local PC Unity project rather than a duplicate of the complete project.

## Relationship to the PC Implementation

The Quest implementation uses the same:

- trained MNIST model;
- ONNX representation;
- 28×28 input dimensions;
- binary preprocessing approach;
- controlled benchmark concepts; and
- general camera benchmark structure

as the local PC implementation.

The important platform changes are:

```text
PC webcam
    → Quest passthrough camera

desktop camera
    → Meta XR rig

mouse UI
    → poke and ray XR interaction

Windows build
    → Android APK

PC CPU/GPU
    → Quest CPU/GPU
```

This allows the Quest results to be compared with the PC results while preserving a consistent model and benchmark design.

## Reproducibility

To reproduce the Quest benchmark workflow:

```text
[ ] Complete the Quest setup notebook
[ ] Install the APK on the Quest 3S
[ ] Launch the local inference application
[ ] Select the required CPU or GPU backend
[ ] Connect or disconnect the development tether as required
[ ] Start the appropriate OVR Metrics recording
[ ] Run controlled accuracy/latency/throughput
[ ] Run sustained inference
[ ] Validate live camera classification
[ ] Run frozen-camera benchmark
[ ] Run end-to-end camera benchmark
[ ] Run live-camera throughput
[ ] Save the OVR Metrics log
[ ] Capture the benchmark result
[ ] Repeat for the next backend/connection condition
```

Each result should be associated with:

```text
Backend
Connection condition
Benchmark type
Screenshot
OVR Metrics session
```

## Scope

This branch documents **how the local Quest 3S experiments were configured, executed, and recorded**.

It does not provide the final interpretation of why one backend or platform performed better than another.

Those comparisons are handled in the dissertation results and discussion alongside:

- local PC CPU;
- local PC GPU;
- FPGA;
- cloud-assisted execution; and
- the other evaluated datasets and platforms.
