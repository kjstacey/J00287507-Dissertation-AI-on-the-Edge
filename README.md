# MNIST Unity Cloud PC/Quest 3S Code

This branch contains the **cloud-specific Unity source files** used to extend the existing MNIST PC and Meta Quest 3S applications from local inference to **Google Cloud Run inference**.

It is intended to be read together with the existing local Unity branches:

- **MNIST Unity Local PC Code**
- **MNIST Unity Local Quest 3S Code**

The cloud implementation reused those existing scenes and shared assets. No separate cloud-specific Unity scenes were created.

Instead, the primary implementation change was replacing local Unity Inference Engine execution with HTTP requests to the deployed Cloud Run inference service.

## Scope

The cloud version preserves the existing input and user-interface structure while changing where inference occurs.

### Local PC

```text
Webcam / MNIST Test Image
    ↓
Preprocessing
    ↓
Unity Inference Engine
    ↓
Local CPU or GPU
    ↓
Prediction
```

### Cloud PC

```text
Webcam / MNIST Test Image
    ↓
Preprocessing
    ↓
HTTP Request
    ↓
Google Cloud Run
    ↓
Prediction Response
```

### Local Quest 3S

```text
Quest Passthrough Camera
    ↓
Preprocessing
    ↓
Unity Inference Engine
    ↓
Quest CPU or GPU
    ↓
Prediction
```

### Cloud Quest 3S

```text
Quest Passthrough Camera
    ↓
Preprocessing
    ↓
HTTP Request
    ↓
Google Cloud Run
    ↓
Prediction Response
```

The trained MNIST model and input representation remain consistent across the implementations.

## Files in This Branch

The branch contains four cloud-specific scripts and their Unity `.meta` files:

```text
CloudMNISTSingleTest.cs
CloudMNISTSingleTest.cs.meta

CloudMNISTBenchmark.cs
CloudMNISTBenchmark.cs.meta

CloudCameraMNISTInference.cs
CloudCameraMNISTInference.cs.meta

QuestCloudCameraMNISTInference.cs
QuestCloudCameraMNISTInference.cs.meta
```

These files represent the main code differences between the local and cloud-assisted Unity versions.

## `CloudMNISTSingleTest.cs`

This script performs a basic Cloud Run connectivity and correctness test using the first MNIST test image.

It:

- reads one 784-value MNIST image;
- converts the Unity float representation from `0..1` to byte values from `0..255`;
- sends the image to the Cloud Run endpoint using an HTTP `POST`;
- receives the returned prediction;
- compares the prediction with the expected label; and
- measures round-trip request time.

The request uses:

```text
Content-Type: application/octet-stream
```

The expected response format is:

```json
{"prediction":N}
```

This script is useful for validating the cloud connection before running larger benchmarks.

## `CloudMNISTBenchmark.cs`

This script performs the controlled cloud benchmark using MNIST test-set data.

The benchmark sends:

```text
1000 MNIST images
```

to the Cloud Run service one at a time.

For each request, the script records:

- round-trip latency;
- returned prediction;
- expected label; and
- request success or error state.

After the benchmark completes, it calculates:

- accuracy;
- mean latency;
- median latency;
- P95 latency;
- minimum latency;
- maximum latency;
- total elapsed time;
- throughput in requests per second; and
- request errors.

The benchmark also writes a CSV file containing the summary and per-image results.

This replaces the local Unity Inference Engine benchmark path with network round-trip inference.

## `CloudCameraMNISTInference.cs`

This script provides the **PC webcam-to-cloud** implementation.

It replaces the local PC inference worker with HTTP requests while preserving the webcam and preprocessing pipeline.

The script uses:

```text
WebCamTexture
```

for PC camera input.

The camera image is processed using the same comparison-oriented preprocessing approach:

```text
Source geometry mapped to 160 × 120
ROI: x = 24..135
ROI: y = 4..115
Sample every 4 reference pixels
28 × 28 output
Grayscale conversion
Binary threshold
```

The resulting 784-value image is converted to bytes and sent to the Cloud Run endpoint.

The script supports:

- cloud classification of the current camera frame;
- frozen-camera cloud benchmarking;
- end-to-end camera cloud benchmarking; and
- live cloud camera throughput.

Because inference is remote, the reported timing reflects communication with the Cloud Run service rather than only local neural-network execution.

## `QuestCloudCameraMNISTInference.cs`

This script provides the **Quest passthrough-camera-to-cloud** implementation.

It performs the same general function as `CloudCameraMNISTInference.cs`, but uses the Meta Quest camera source:

```text
PassthroughCameraAccess
```

instead of the PC:

```text
WebCamTexture
```

The script preserves the same image-processing geometry used by the local Quest implementation:

```text
160 × 120 reference coordinate space
ROI: x = 24..135
ROI: y = 4..115
4-pixel reference sampling
28 × 28 output
grayscale conversion
binary threshold
```

The processed image is then converted to the byte representation expected by the Cloud Run endpoint and transmitted over HTTP.

The script supports:

- single-frame Quest cloud classification;
- frozen-camera cloud benchmarking;
- end-to-end Quest camera cloud benchmarking; and
- live camera cloud throughput.

## Cloud Run Endpoint

The archived Unity scripts reference the deployed endpoint:

```text
https://mnist-cloud-inference-221036165238.us-east1.run.app/predict
```

The Unity clients send a 784-byte image body to the `/predict` endpoint.

The response is expected to contain a JSON prediction:

```json
{"prediction":N}
```

The endpoint address is exposed as a public Unity script field and can be changed if the Cloud Run service is redeployed.

## Input Conversion

The local Unity test binaries store each MNIST pixel as a 32-bit floating-point value.

For cloud requests, the Unity scripts convert each value from:

```text
0.0–1.0 float
```

to:

```text
0–255 byte
```

before transmission.

The Cloud Run service therefore receives a compact:

```text
784-byte image
```

rather than the original 3,136-byte float array.

Camera-derived binary images are sent using the same request format.

## Relationship to Existing Scenes

No separate cloud-specific Unity scenes were created.

The cloud scripts were used with the same existing scene structures from the local implementations.

### PC

The cloud PC version reused the existing PC scene and UI.

The principal change was replacing the local camera/inference component with:

```text
CloudCameraMNISTInference
```

and using the cloud benchmark scripts where appropriate.

### Quest 3S

The cloud Quest version reused:

```text
SecondScene.unity
```

from the local Quest implementation.

The Meta XR rig, Quest camera access, Canvas, poke/ray interaction, and other Quest-specific scene configuration remained the same.

The primary cloud-specific change was using:

```text
QuestCloudCameraMNISTInference
```

instead of the local Quest inference component.

## Shared Assets

The cloud branch does not duplicate the shared Unity assets already documented in the local branches.

These include items such as:

```text
mnist_test_images.bin
mnist_test_labels.bin
PC scene
Quest SecondScene
QuestCameraPreview.cs
LaptopCameraTest.cs
CameraPreprocessTest.cs
```

The cloud implementation builds on those existing assets.

The local ONNX model is not used by the cloud client for inference, because model execution occurs on the Cloud Run service.

## Local Versus Cloud Timing

Timing boundaries differ between the local and cloud implementations.

### Local Inference

Local timing measures execution within the Unity application, typically including:

```text
worker.Schedule()
    ↓
synchronous output readback
```

### Cloud Inference

Cloud timing measures the request round trip:

```text
request transmission
    ↓
network communication
    ↓
Cloud Run processing
    ↓
HTTP response
```

For camera benchmarks, end-to-end cloud measurements may also include the local camera-processing work performed before the request.

These timing categories should therefore be compared according to their documented measurement boundaries.

## Benchmark Differences

The cloud benchmarks intentionally use fewer repeated requests than the local inference benchmarks.

For example:

```text
Controlled cloud benchmark:
1000 images

Camera cloud benchmark:
2 warm-up requests
100 measured requests
```

This reflects the much larger cost of performing network requests compared with local inference calls.

The exact benchmark procedures are documented in the corresponding cloud data/notebook branch.

## Error Handling

The cloud scripts include explicit handling for:

- missing input assets;
- unavailable cameras;
- failed HTTP requests;
- non-success HTTP response codes;
- response parsing errors; and
- overlapping cloud requests.

This is important because the cloud implementation introduces failure modes that are not present in fully local inference.

## Reproducibility

To reproduce the cloud Unity clients:

```text
[ ] Begin with the existing local PC or Quest Unity project
[ ] Use the corresponding existing scene
[ ] Add the required cloud script
[ ] Assign the MNIST test data where required
[ ] Assign the existing UI components
[ ] Configure the Cloud Run endpoint
[ ] Confirm Internet access
[ ] Run CloudMNISTSingleTest
[ ] Verify a successful prediction response
[ ] Run CloudMNISTBenchmark
[ ] Configure CloudCameraMNISTInference for PC camera testing
[ ] Configure QuestCloudCameraMNISTInference for Quest testing
[ ] Run the corresponding cloud camera benchmarks
```

No separate cloud scene is required.

## Relationship to the Data and Notebook Branch

Use this branch for the cloud-specific Unity source code.

Use the corresponding **MNIST Unity Cloud PC/Quest 3S Data and Notebook** branch for:

- Cloud Run deployment documentation;
- client configuration;
- benchmark procedures;
- result screenshots;
- CSV benchmark output;
- PC cloud results;
- Quest cloud results;
- network-dependent measurements; and
- reproducibility notes.

## Scope of This Branch

This branch documents only the **Unity client-side code changes required to move inference from the local device to Cloud Run**.

It does not contain:

- the local PC implementation;
- the local Quest implementation;
- duplicated scenes;
- the server-side Cloud Run application;
- Cloud Run deployment configuration; or
- benchmark result data.

Those components are documented in their corresponding repository branches.
