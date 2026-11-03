# MNIST Unity Cloud PC/Quest 3S Data and Notebook

This branch contains the notebooks, screenshots, OVR Metrics logs, memory observations, and videos used to document the **cloud-assisted MNIST inference experiments** for both the Windows PC and Meta Quest 3S Unity applications.

It complements the **MNIST Unity Cloud PC/Quest 3S Code** branch.

The code branch contains the cloud-specific Unity client scripts. This branch documents:

- the shared Cloud Run request format;
- PC cloud validation and benchmarks;
- Quest cloud tethered testing;
- Quest cloud untethered testing;
- camera-based cloud benchmarks;
- OVR Metrics telemetry;
- Windows memory observations;
- whole-system PC power evidence;
- Internet-dependency evidence; and
- reproducibility notes.

## Notebook

### `MNIST_Unity_Cloud_PC_Quest3S_Data_Benchmarking.ipynb`

This notebook documents the complete cloud-assisted benchmark workflow for the PC and Quest 3S clients.

Topics include:

- relationship to the existing local PC and Quest implementations;
- the four cloud-specific Unity scripts;
- Cloud Run endpoint configuration;
- request-body conversion;
- round-trip latency boundaries;
- controlled 1,000-image cloud benchmarking;
- PC editor and standalone-build evidence;
- PC camera benchmarks;
- PC memory observations;
- Quest tethered testing;
- Quest untethered testing;
- OVR Metrics logs;
- power and Internet validation videos; and
- reproduction sequences for both platforms.

## Cloud Architecture

The cloud implementation reuses the existing local Unity applications but replaces local model execution with HTTP requests to the deployed Cloud Run service.

### PC

```text
Laptop Webcam / MNIST Test Image
    ↓
Preprocessing
    ↓
HTTP Request
    ↓
Google Cloud Run
    ↓
Prediction Response
```

### Quest 3S

```text
Quest Passthrough Camera / MNIST Test Image
    ↓
Preprocessing
    ↓
HTTP Request
    ↓
Google Cloud Run
    ↓
Prediction Response
```

No separate cloud-specific Unity scenes were created.

## Cloud Run Endpoint

The archived Unity clients reference:

```text
https://mnist-cloud-inference-221036165238.us-east1.run.app/predict
```

Requests use:

```text
Content-Type: application/octet-stream
```

The expected response format is:

```json
{"prediction":N}
```

## Request Representation

The Unity MNIST test binaries store each image pixel as a 32-bit floating-point value in the range:

```text
0.0–1.0
```

Before transmission, each pixel is converted to a single byte:

```text
0–255
```

A cloud request therefore sends:

```text
784 bytes
```

for one 28×28 image.

This same request format is also used for camera-derived images after preprocessing.

## Timing Boundary

Cloud timing measures the complete request round trip.

```text
Unity request start
    ↓
network transmission
    ↓
Cloud Run processing
    ↓
response transmission
    ↓
Unity receives response
```

This differs from local inference timing, which measures execution within Unity Inference Engine.

Cloud latency therefore includes network and server-side effects in addition to inference.

## Controlled Cloud Benchmark

The controlled cloud benchmark evaluates:

```text
1000 MNIST test images
```

Each image is sent individually to Cloud Run.

The benchmark records:

- returned prediction;
- expected label;
- request latency;
- request errors; and
- benchmark progress.

At completion, it calculates:

- accuracy;
- mean latency;
- median latency;
- P95 latency;
- minimum latency;
- maximum latency;
- total elapsed time; and
- throughput in requests per second.

The observed cloud benchmark accuracy was:

```text
957 / 1000
95.70%
```

This is the observed accuracy for the tested 1,000-image cloud subset and should remain distinct from the 10,000-image local validation result.

## Camera Cloud Benchmarks

The PC and Quest cloud camera scripts use:

```text
2 warm-up requests
100 measured requests
```

The camera tests include:

- frozen-camera cloud benchmark;
- end-to-end camera cloud benchmark; and
- live camera throughput.

### Frozen Camera

Uses an already processed 28×28 camera image and repeatedly sends that same image to Cloud Run.

### End-to-End Camera

Includes:

```text
camera acquisition
    ↓
coordinate mapping
    ↓
28×28 sampling
    ↓
grayscale conversion
    ↓
binary threshold
    ↓
request-body creation
    ↓
Cloud Run request
    ↓
prediction response
```

### Live Camera Throughput

Processes newly available camera frames and reports completed cloud predictions over elapsed real time.

## PC Cloud Evidence

The PC evidence includes both Unity Editor and Windows standalone-build captures.

### Controlled Benchmark

```text
cloud_pc_accuracy_latency_throughput.png
cloud_pc_accuracy_latency_throughput2.png
cloud_pc_Accuracy_latency_throughput_build.png
```

### Single Classification

```text
cloud_pc_classification.png
```

### Frozen Camera

```text
cloud_pc_frozen_benchmark.png
cloud_pc_frozen_benchmark_build.png
```

### End-to-End Camera

```text
cloud_pc_end_to_end.png
cloud_pc_end_to_end_build.png
```

### Live Classification

```text
cloud_pc_live_classification.png
cloud_pc_live_classification_build.png
```

### Live Throughput

```text
cloud_pc_live_throughput.png
cloud_pc_live_throughput_build.png
```

Editor and standalone-build screenshots are kept separately because they document different execution contexts.

## PC Memory Evidence

The branch contains Windows resource screenshots:

```text
cloud_pc_memory1.png
cloud_pc_memory2.png
cloud_pc_memory3.png
cloud_pc_memory4.png
cloud_pc_memory5.png
cloud_pc_memory6.png
cloud_pc_memory7.png
```

These document process/resource behavior during cloud-client operation.

Because inference occurs remotely, these screenshots characterize the Unity application, camera pipeline, network activity, and client-side resource use rather than local neural-network execution.

## PC Power Evidence

The branch contains:

```text
Cloud Power Unity10-22-202606-36.mp4
Cloud Power 2 Unity10-26-202608-11.mp4
```

These videos document whole-system PC power observations during cloud-assisted Unity execution.

The power boundary is the PC system as measured externally rather than CPU- or GPU-package power.

## Internet-Dependency Evidence

The branch also contains:

```text
Unity Cloud Internet10-22-202610-13.mp4
```

This documents the network-dependent nature of the cloud configuration.

Unlike the local PC and local Quest implementations, the cloud clients require access to the Cloud Run endpoint in order to complete inference.

## Quest Cloud Test Conditions

Quest cloud testing was performed under two conditions:

```text
tethered
untethered
```

The distinction is preserved because the cloud implementation depends on network communication and device connection state may affect observed behavior.

### Tethered Quest Evidence

The Quest `.png` screenshots were captured through casting and therefore correspond to the tethered condition.

### Untethered Quest Evidence

The Quest `.jpg` screenshots correspond to untethered execution.

## Quest Cloud — Tethered Controlled Benchmark

Primary controlled benchmark evidence:

```text
quest_cloud_accuracy_latency_throughput.png
quest_cloud_accuracy_latency_throughput2.png
```

Additional progress captures:

```text
quest_cloud_benchmark.png
quest_cloud_benchmark2.png
quest_cloud_benchmark3.png
quest_cloud_benchmark4.png
```

The final benchmark images are the primary evidence, while the progress images document the benchmark while it was running.

Representative tethered results include:

```text
Images:   1000
Correct:  957
Errors:   0
Accuracy: 95.70%
```

## Quest Cloud — Tethered Classification

```text
quest_cloud_frozen_classification.png
quest_cloud_live_classification.png
```

These show successful Quest camera-to-cloud predictions and round-trip timing.

## Quest Cloud — Tethered Frozen Camera

```text
quest_cloud_frozen_benchmark.png
```

Representative result:

```text
Runs:   100
Mean:   ~53.26 ms
Median: ~48.10 ms
P95:    ~73.52 ms
```

## Quest Cloud — Tethered End-to-End Camera

```text
quest_cloud_end_to_end.png
quest_cloud_end_to_end2.png
```

Representative final result:

```text
Runs:   100
Mean:   ~79.20 ms
Median: ~76.92 ms
P95:    ~93.01 ms
```

## Quest Cloud — Tethered Live Throughput

```text
quest_cloud_live_throughput.png
quest_cloud_live_throughput2.png
```

Representative completed result:

```text
Completed requests: 182
Time:               ~10.02 s
Throughput:         ~18.16 predictions/s
```

## Quest Cloud — Tethered OVR Metrics

```text
quest_cloud_ovrmetrics.csv
quest_cloud_ovrmetrics2.csv
quest_cloud_ovrmetrics3.csv
quest_cloud_ovrmetrics4.csv
```

These logs document Quest device telemetry during the tethered/casting cloud benchmark period.

## Quest Cloud — Untethered Controlled Benchmark

```text
quest_cloud_untet_accuracy_latency_throughput.jpg
```

Progress evidence:

```text
quest_cloud_untet_benchmark.jpg
```

Representative result:

```text
Images:     1000
Correct:    957
Errors:     0
Accuracy:   95.70%

Mean:       ~49.44 ms
Median:     ~46.10 ms
P95:        ~66.14 ms
Throughput: ~20.13 req/s
```

## Quest Cloud — Untethered Live Classification

```text
quest_cloud_untet_live_classification.jpg
```

This confirms that the cloud client continued to operate without the tether/casting connection.

## Quest Cloud — Untethered Frozen Camera

```text
quest_cloud_untet_frozen_benchmark.jpg
```

Representative result:

```text
Runs:   100
Mean:   ~47.54 ms
Median: ~45.99 ms
P95:    ~61.43 ms
```

## Quest Cloud — Untethered End-to-End Camera

```text
quest_cloud_untet_end_to_end.jpg
```

Representative result:

```text
Runs:   100
Mean:   ~70.09 ms
Median: ~72.36 ms
P95:    ~75.90 ms
```

## Quest Cloud — Untethered Live Throughput

```text
quest_cloud_untet_live_throughput.jpg
```

Representative result:

```text
Completed requests: 192
Time:               ~10.03 s
Throughput:         ~19.15 predictions/s
```

## Quest Cloud — Untethered OVR Metrics

```text
quest_cloud_untet_overmetrics.csv
quest_cloud_untet_ovrmetrics2.csv
quest_cloud_untet_ovrmetrics3.csv
```

These logs cover longer untethered benchmark periods.

The first filename preserves the original repository spelling of `overmetrics`.

## OVR Metrics Data

The Quest CSV files contain device-side telemetry collected during the cloud experiments.

Relevant fields may include:

- application frame rate;
- CPU utilization;
- GPU utilization;
- CPU performance level;
- GPU performance level;
- application memory;
- available memory;
- GPU memory;
- battery percentage;
- battery temperature;
- frame timing;
- thermal/performance indicators; and
- available device power telemetry.

Not every logged field is required for the dissertation.

Only metrics relevant to the performance and resource-use analysis should be extracted.

## Interpreting Quest Power Telemetry

Power-related fields in OVR Metrics should be interpreted with care.

Values may vary with:

- tethered versus untethered state;
- charging state;
- battery condition;
- measurement sign convention;
- active workload; and
- logging conditions.

The raw CSV files are preserved so that any final reported values can be traced back to the original device telemetry.

## Evidence Types

Different branch files serve different purposes.

### Unity Screenshots

Primary evidence for:

- cloud accuracy;
- cloud latency;
- request throughput;
- camera benchmark timing; and
- tethered/untethered execution.

### OVR Metrics Logs

Supporting Quest device telemetry.

### Windows Memory Screenshots

Supporting PC client resource evidence.

### Videos

Supporting evidence for:

- PC cloud power; and
- cloud Internet dependence.

These evidence types should be interpreted together rather than treated as interchangeable measurements.

## Relationship to the Code Branch

Use the **MNIST Unity Cloud PC/Quest 3S Code** branch for:

```text
CloudMNISTSingleTest.cs
CloudMNISTBenchmark.cs
CloudCameraMNISTInference.cs
QuestCloudCameraMNISTInference.cs
```

Use this **Data and Notebook** branch for:

- cloud benchmark documentation;
- PC screenshots;
- Quest tethered screenshots;
- Quest untethered screenshots;
- OVR Metrics CSV files;
- PC memory evidence;
- power videos;
- Internet-dependency video; and
- reproducibility documentation.

## Relationship to the Local Branches

The cloud implementation depends on the existing local Unity structures.

### Local PC

Provides:

- the PC scene;
- webcam setup;
- Canvas;
- shared MNIST test assets; and
- baseline camera preprocessing.

### Local Quest 3S

Provides:

- `SecondScene.unity`;
- Meta XR rig;
- `PassthroughCameraAccess`;
- XR Canvas;
- poke and ray interaction; and
- Quest deployment configuration.

The cloud branch therefore documents the **inference-path change**, not a separate Unity application architecture.

## Reproduction — PC Cloud

```text
[ ] Start with the existing local PC Unity project
[ ] Configure the Cloud Run endpoint
[ ] Run CloudMNISTSingleTest
[ ] Verify a successful prediction
[ ] Run CloudMNISTBenchmark
[ ] Configure CloudCameraMNISTInference
[ ] Validate live cloud classification
[ ] Run frozen-camera cloud benchmark
[ ] Run end-to-end cloud benchmark
[ ] Run live cloud throughput
[ ] Repeat key tests in the Windows build
[ ] Capture memory/resource evidence
[ ] Record whole-system power if required
```

## Reproduction — Quest Cloud

```text
[ ] Start with the existing local Quest 3S project
[ ] Use SecondScene
[ ] Configure QuestCloudCameraMNISTInference
[ ] Configure the Cloud Run endpoint
[ ] Build and install the APK
[ ] Confirm Internet access
[ ] Run the tethered/casting condition
[ ] Record OVR Metrics
[ ] Run the controlled benchmark
[ ] Validate live classification
[ ] Run frozen-camera benchmark
[ ] Run end-to-end benchmark
[ ] Run live throughput
[ ] Save tethered logs
[ ] Repeat without tether/casting
[ ] Save untethered screenshots and logs
```

## Scope

This branch documents **how the cloud-assisted PC and Quest 3S experiments were executed and recorded**.

It does not provide the final interpretation of why cloud, local PC, local Quest, or FPGA execution performed differently.

Those comparisons are handled in the dissertation results and discussion.
