# Cloud Run Inference Service

This branch documents the **Google Cloud Run inference service** used by the dissertation’s cross-platform machine-learning experiments.

The cloud service is documented independently from any specific client implementation. FPGA and Unity clients connect to the same remote inference service but maintain their own networking, request handling, timing, and measurement code in separate branches.

The first deployment documented here is the MNIST inference service.

## MNIST Cloud Run Service

The MNIST model was deployed as:

```text
Service:  mnist-cloud-inference
Project:  mnist-cloud-fpga
Region:   us-east1
Endpoint: /predict
```

The service URL used during testing was:

```text
https://mnist-cloud-inference-221036165238.us-east1.run.app
```

Inference requests were sent using:

```text
POST /predict
```

The service hostname was used rather than a fixed IP address because Cloud Run frontend addresses can change.

## Notebook

The main documentation notebook is:

```text
Cloud_Run_Inference_Service_Setup_MNIST.ipynb
```

The notebook describes:

- creation of the Cloud Run service;
- service region and endpoint;
- deployed source files;
- Python dependencies;
- MNIST request and response format;
- model loading and inference flow;
- service revisions;
- access configuration;
- encryption configuration;
- Cloud Run observability;
- request logs; and
- the separation between the cloud service and client-specific FPGA or Unity implementations.

The notebook also includes a template for documenting changes required for later datasets and models.

## MNIST Service Source

The MNIST deployment used the following Cloud Run source files:

```text
main.py
network2.py
requirements.txt
WeigntsAndBiases.txt
```

The service used:

```text
Flask==3.0.3
gunicorn==23.0.0
numpy==1.26.4
```

The deployed model used the same trained MNIST neural network evaluated by the local implementations.

The network architecture was:

```text
784 → 30 → 20 → 10
```

## Request Processing

The MNIST service accepts one image as 784 raw byte values.

The server-side path is:

```text
784-byte request
        ↓
NumPy conversion
        ↓
float64 conversion
        ↓
normalization by 128.0
        ↓
reshape to 784 × 1
        ↓
neural-network feedforward
        ↓
predicted digit
        ↓
JSON response
```

A prediction response has the form:

```json
{"prediction": 7}
```

## Cloud Run Screenshots

The branch includes screenshots documenting the deployed MNIST service.

### Scaling

```text
Cloud_MNIST_Scaling.png
```

This image documents the deployed service and Cloud Run scaling activity.

### Source

```text
Cloud_MNIST_Sources.png
```

This image shows the deployed source files and Python dependencies.

### Security

```text
Cloud_MNIST_Security.png
```

This image documents the Cloud Run authentication and encryption configuration.

During the experimental deployment, IAM controls were enabled while the service was also publicly callable because `allUsers` had service access.

The service used a Google-managed encryption key.

### Metrics

```text
Cloud_MNIST_Metrics.png
```

This image documents Cloud Run observability metrics including:

- request count;
- request latency;
- end-to-end request latency; and
- latency breakdown.

### Errors

```text
Cloud_MNIST_Errors.png
```

This image documents the Cloud Run error dashboard for the experimental period.

## Exported Cloud Run Logs

The branch includes:

```text
Cloud_MNIST_logs.json
```

The exported logs provide Cloud Run-side evidence of requests sent to the service.

The logs include information such as:

```text
request method
request URL
request size
response size
HTTP status
protocol
Cloud Run request latency
timestamp
service name
revision
region
client user agent
```

Successful MNIST requests returned HTTP status `200`.

The logs also identify requests sent by Unity through the `UnityPlayer` user agent.

Cloud Run request latency should not be interpreted as the same measurement as FPGA-side or Unity-side end-to-end latency. Client branches define and record their own timing boundaries.

## Relationship to Client Branches

This branch documents only the **remote inference service**.

### FPGA cloud branches

The FPGA-specific branches document:

- Ethernet communication;
- lwIP;
- DNS;
- TCP;
- TLS;
- FPGA/PS mailbox communication;
- image transmission;
- returned predictions;
- FPGA-side latency and throughput;
- FPGA memory/resource measurements; and
- physical power measurements.

### Unity cloud branches

The Unity-specific branches document:

- UnityWebRequest;
- dataset or camera input preparation;
- request construction;
- response handling;
- PC and Quest deployment; and
- client-side latency and throughput.

This separation allows the same cloud service to be evaluated from multiple client platforms.

## Future Dataset Deployments

This branch will also document Cloud Run changes required for later datasets and models.

For each new deployment, record:

```text
Dataset
Service name
Region
Model file
Model architecture
Input dimensions
Input data type
Input normalization
Request format
Response format
main.py changes
Model-loading changes
requirements.txt changes
Endpoint changes
Cloud Run revision
Deployment date
Validation performed
```

If the same Cloud Run service is updated rather than creating a new service, the associated revision should be recorded so that each dataset/model configuration can be identified.

## Current Files

The current MNIST cloud documentation includes:

```text
Cloud_Run_Inference_Service_Setup_MNIST.ipynb
Cloud_MNIST_Scaling.png
Cloud_MNIST_Sources.png
Cloud_MNIST_Security.png
Cloud_MNIST_Metrics.png
Cloud_MNIST_Errors.png
Cloud_MNIST_logs.json
```

## Purpose

The purpose of this branch is to preserve the setup and configuration of the remote inference environment used by the dissertation experiments.

The branch will expand as additional datasets are deployed, while FPGA- and Unity-specific communication and performance measurements remain in their respective implementation branches.
