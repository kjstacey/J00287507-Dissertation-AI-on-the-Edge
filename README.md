# MNIST Unity Local Quest 3S Code

This branch contains the Meta Quest 3S-specific additions used to extend the local Unity MNIST implementation from the Windows PC environment to the Quest headset.

It is intended to be read together with the **MNIST Unity Local PC Code** branch.

The PC branch contains the shared Unity implementation, including:

- the MNIST ONNX model;
- shared benchmark scripts;
- MNIST test binaries;
- the original PC scene; and
- the baseline camera/inference workflow.

This branch contains only the code and scene changes required for Quest-specific local inference.

## Scope

The Quest implementation preserves the same general local inference pipeline:

```text
Camera Image
    |
    v
28×28 Preprocessing
    |
    v
784-Value Tensor
    |
    v
Unity Inference Engine
    |
    v
GPU Compute
    |
    v
Predicted Digit
```

The main differences from the PC version are:

- use of the Meta Quest passthrough camera API instead of `WebCamTexture`;
- headset-camera permission handling;
- Meta XR SDK scene objects;
- Quest-specific camera preview logic; and
- Android / Quest deployment through the Unity project.

The neural-network model and preprocessing approach remain shared with the PC implementation.

## Files in This Branch

### `QuestCameraMNISTInference.cs`

This is the primary Quest-specific inference script.

It uses:

```csharp
using Meta.XR;
```

and accesses the Quest camera through:

```csharp
PassthroughCameraAccess
```

rather than the PC `WebCamTexture` path.

The script manages:

- live Quest camera access;
- display of the headset camera texture;
- 28×28 preprocessing;
- FPGA-matched ROI mapping;
- grayscale conversion;
- binary thresholding;
- frozen-image classification;
- local GPU Compute inference;
- frozen-image latency benchmarking;
- end-to-end camera benchmarking; and
- live camera throughput.

The local Quest implementation uses:

```csharp
worker = new Worker(
    runtimeModel,
    BackendType.GPUCompute
);
```

The Quest version therefore uses Unity Inference Engine GPU Compute for local model execution.

## Quest Camera Preprocessing

The Quest camera script preserves the same preprocessing geometry used by the final PC and FPGA comparison.

The incoming Quest camera resolution is scaled to the equivalent FPGA coordinate system:

```text
160 × 120
```

The selected region is:

```text
x = 24 through 135
y = 4 through 115
```

with sampling every four source-coordinate units.

This produces:

```text
28 × 28 = 784
```

input values.

Each sampled pixel is converted to grayscale using:

```text
0.299R + 0.587G + 0.114B
```

and thresholded to:

```text
0 or 1
```

before being passed to the MNIST model.

## `QuestCameraPreview.cs`

This script provides the Quest-specific camera preview and headset-camera permission handling.

It requests:

```text
horizonos.permission.HEADSET_CAMERA
```

when needed and waits for permission before attempting to display the camera feed.

The preview script:

- checks headset-camera permission;
- verifies that the camera is active;
- retrieves the Quest passthrough camera texture; and
- displays that texture in a Unity `RawImage`.

This script was useful for validating Quest camera access independently from the full inference pipeline.

## `SecondScene.unity`

This scene contains the Quest-enabled version of the Unity project.

It extends the PC scene with the Meta XR SDK objects required for headset execution.

The scene includes the Quest-specific camera and XR configuration while preserving the shared:

- MNIST benchmark objects;
- Canvas;
- model references;
- processed-image display;
- frozen-image display;
- classification controls; and
- benchmark controls.

The Quest-specific Editor configuration and active object structure are documented in the corresponding **MNIST Unity Local Quest 3S Data and Notebook** branch.

## Unity Package Configuration

### `manifest.json`

The package manifest records the Unity dependencies used by the Quest-enabled project.

Important packages include:

```text
com.meta.xr.sdk.all        207.0.1
com.unity.ai.inference     2.6.1
com.unity.inputsystem      1.20.0
com.unity.xr.openxr        1.16.1
com.unity.render-pipelines.universal 17.3.0
```

The Meta XR SDK provides the Quest-specific camera and XR functionality, while Unity Inference Engine provides local ONNX inference.

The project also includes standard Unity UI, Android, XR, and rendering modules required by the application.

## Relationship to the PC Implementation

This branch is intentionally a **delta branch** rather than a complete duplicate of the Windows PC project.

Shared files are documented in the **MNIST Unity Local PC Code** branch, including:

```text
mnist_model.onnx
mnist_test_binaries.zip
MNISTAccuracyTest.cs
MNISTLatencyTest.cs
MNISTMemoryTest.cs
MNISTModelLoader.cs
MNISTSingleTest.cs
MNISTSustainedInference.cs
MNISTThroughputTest.cs
```

The Quest implementation reuses the same model and benchmark concepts.

The main Quest-specific additions are:

```text
QuestCameraMNISTInference.cs
QuestCameraPreview.cs
SecondScene.unity
manifest.json
```

## Quest Camera Versus PC Camera

The PC implementation accesses the camera through:

```csharp
WebCamTexture
```

The Quest implementation instead uses:

```csharp
PassthroughCameraAccess
```

The remaining camera-processing stages are intentionally similar so that the platform comparison uses comparable image preparation.

Conceptually:

```text
PC:
WebCamTexture
    |
    v
shared preprocessing
    |
    v
MNIST inference

Quest:
PassthroughCameraAccess
    |
    v
shared preprocessing
    |
    v
MNIST inference
```

## Local Inference

This branch documents **local Quest inference**.

The ONNX model executes on the headset through Unity Inference Engine using the GPU Compute backend.

No Google Cloud Run service is required for this configuration.

The cloud-assisted Quest implementation is documented separately in the **MNIST Unity Cloud PC/Quest 3S** branches.

## Build Output

The compiled Quest `.apk` is not included in this repository because it exceeds the upload-size limit used for this archive.

The application can be rebuilt from the Unity project source using the documented:

- Unity version;
- Meta XR SDK version;
- Inference Engine version;
- Quest scene;
- Quest-specific scripts; and
- shared model assets.

The corresponding data/notebook branch documents the Editor-side configuration and deployment process used for the headset.

## Reproducibility

To reproduce the Quest-specific implementation:

1. begin with the shared local PC Unity project;
2. use Unity Editor 6000.3.22f1;
3. install the package dependencies listed in `manifest.json`;
4. add the Quest-specific scripts;
5. open `SecondScene.unity`;
6. configure the Meta XR SDK objects;
7. assign the Quest passthrough camera access component;
8. assign the shared MNIST ONNX model;
9. assign the Canvas displays and controls;
10. configure the project for Android / Meta Quest;
11. allow headset-camera permission; and
12. build and deploy the application to the Quest 3S.

Detailed Editor configuration, device deployment, OVR Metrics Tool setup, and measurement procedures are documented in the corresponding **MNIST Unity Local Quest 3S Data and Notebook** branch.
