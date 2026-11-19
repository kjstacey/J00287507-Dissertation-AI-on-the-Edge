# Cloud Run Inference Service

This branch documents the **Google Cloud Run inference services** used in the dissertation's cross-platform machine-learning experiments.

The cloud services are documented independently from their FPGA and Unity clients. Each client maintains its own networking, request handling, timing, and measurement code in separate repository branches.

The branch currently documents two deployments:

- **MNIST:** Fully connected neural network for handwritten digit classification.
- **EMNIST Balanced:** Convolutional neural network (CNN) for 47-class handwritten character classification.

## Cloud Run Deployments

| Configuration | MNIST | EMNIST Balanced |
|---|---|---|
| Service | `mnist-cloud-inference` | `emnist-cloud-inference` |
| Project | `mnist-cloud-fpga` | `mnist-cloud-fpga` |
| Region | `us-east1` | `us-east1` |
| Endpoint | `/predict` | `/predict` |
| Input | 784 raw image bytes | 784 raw image bytes |
| Output | 10 classes | 47 classes |
| Model | Fully connected NN | Compact CNN |

### Service URLs

**MNIST**
```text
https://mnist-cloud-inference-221036165238.us-east1.run.app
```

**EMNIST**
```text
https://emnist-cloud-inference-221036165238.us-east1.run.app
```

Both services accept classification requests through `POST /predict` and return JSON predictions.

## Documentation Notebooks

### MNIST

[Cloud Run Inference Service Setup — MNIST](Cloud_Run_Inference_Service_Setup_MNIST.ipynb)

Documents service creation, source files, dependencies, model loading, request processing, security configuration, observability, and exported logs.

### EMNIST

[Cloud Run Inference Service Setup — EMNIST](EMNIST_Cloud_Run_Inference_Service_Setup.ipynb)

Documents the adaptation of the MNIST cloud workflow to the EMNIST Balanced CNN, deployment, request validation, service configuration, and monitoring evidence.

## Service Source Files

### MNIST

The MNIST deployment used:

```text
main.py
network2.py
requirements.txt
WeigntsAndBiases.txt
```

The model used a fully connected architecture:

```text
784 → 30 → 20 → 10
```

The service converted incoming image bytes to floating-point values, normalized them by 128.0, executed the trained network, and returned the predicted digit.

### EMNIST

The EMNIST deployment source is preserved in:

[EMNIST Cloud Run Service Archive](EMNIST_Cloud_Run_Service.zip)

The archive contains:

```text
main.py
best_cnn_checkpoint.pt
Dockerfile
requirements.txt
README.md
```

The deployed compact CNN uses three convolutional layers followed by global average pooling and a 47-class output layer.

Both deployments preserve the 28 × 28 grayscale image format established by MNIST.

The EMNIST branch also includes the [diagnostic test archive](EMNIST_Cloud_Test_Batch_0900.zip), used to validate remote predictions against known EMNIST test images.

## Service Validation

### MNIST

The MNIST service was validated using FPGA and Unity clients. Successful inference requests returned HTTP status `200`, with predictions provided in JSON format.

### EMNIST

The EMNIST deployment was validated through Cloud Shell using HTTP requests and known EMNIST images.

The service successfully accepted 784-byte image requests and returned classifications within the expected 47-class range.

A diagnostic test using EMNIST images 900–999 produced **91 correct classifications out of 100 (91%)**.

This diagnostic test verified the deployed service independently of the FPGA client. Formal FPGA classification accuracy, latency, and throughput measurements are documented separately.

## Cloud Run Configuration and Monitoring

### MNIST Evidence

| File | Description |
|---|---|
| `Cloud_MNIST_Sources.png` | Deployed service source |
| `Cloud_MNIST_Scaling.png` | Scaling configuration and activity |
| `Cloud_MNIST_Security.png` | Authentication and encryption |
| `Cloud_MNIST_Metrics.png` | Request and latency metrics |
| `Cloud_MNIST_Errors.png` | Error monitoring |
| `Cloud_MNIST_logs.json` | Exported service logs |

### EMNIST Evidence

| File | Description |
|---|---|
| `emnist_cloud_run_source.png` | Deployed source and CNN architecture |
| `emnist_cloud_run_networking.png` | Ingress and endpoint configuration |
| `emnist_cloud_run_security.png` | Authentication and encryption settings |
| `emnist_cloud_run_metrics1.png` | Request counts and latency metrics |
| `emnist_cloud_run_metrics2.png` | Container instances, CPU, and memory utilization |
| `emnist_cloud_service.png` | Service deployment and endpoint verification |
| `emnist_cloud_service_tes100.png` | Diagnostic classification results |
| `emnist_cloud_local_test1.png` | Initial endpoint testing |
| `emnist_cloud_local_test5.png` | Additional classification validation |

The accompanying notebooks provide detailed interpretation of these files.

### Security Configuration

The experimental services used HTTPS and Google-managed encryption keys.

The EMNIST networking configuration permitted internet ingress. Although the security interface displayed an authentication requirement, the service remained publicly accessible because `allUsers` had been granted access.

These settings describe the experimental deployment rather than a production-secure configuration.

## Relationship to Client Implementations

This branch documents the **remote inference services only**.

FPGA client branches preserve Ethernet communication, lwIP, TCP/TLS handling, shared BRAM transfers, returned classifications, FPGA utilization, power measurements, and client-observed latency and throughput.

Unity client branches preserve image preparation, UnityWebRequest communication, response processing, and PC and Meta Quest 3S performance measurements.

Cloud Run observability metrics represent measurements from the remote service and should not be treated as equivalent to client-side end-to-end request latency.

## Purpose

This branch preserves the source configurations, deployment procedures, validation evidence, and Cloud Run monitoring information required to reproduce and analyze the remote inference environment.

The MNIST and EMNIST deployments provide the cloud-processing components used to compare local and cloud-assisted machine-learning execution across the dissertation's computational platforms.
