# J00287507-Dissertation-AI-on-the-Edge
# Machine Learning on the Edge: CNN Benchmarking Framework

## Overview
This repository contains the implementation, experiments, and documentation for a research study evaluating the performance and security trade-offs of Convolutional Neural Networks (CNNs) across heterogeneous computing platforms.

The project focuses on edge and hybrid deployments, comparing execution on:
- CPU
- GPU
- FPGA
- NPU (when available)
- VR/mobile platforms (e.g., Meta Quest)

The goal is to provide a portable, reproducible methodology for benchmarking machine learning systems across embedded and cloud-adjacent environments.

---

## Research Objectives

This work investigates:

- Performance trade-offs:
  - Latency
  - Throughput
  - Energy consumption
  - Memory footprint
  - Accuracy (precision, recall, F1, specificity)

- Platform comparisons:
  - Embedded vs. cloud-adjacent execution
  - Hardware accelerators vs. general-purpose processors

- Security considerations:
  - Threat surface analysis
  - Platform-specific vulnerabilities
  - Impact of mitigation strategies on performance

---

## Repository Structure

~~~text
ml-edge-benchmark/
├── docs/
├── data/
├── notebooks/
├── src/
├── platforms/
├── experiments/
├── results/
├── tests/
└── scripts/
~~~

---

## Methodology Summary

The experimental workflow follows a consistent pipeline:

1. **Model Development**  
   CNN architectures are implemented and trained using standardized datasets.

2. **Model Conversion**  
   Models are exported to deployment formats such as TensorFlow Lite for FPGA deployment.

3. **Deployment**  
   Models are executed across multiple platforms including CPU, GPU, FPGA, NPU, and VR/mobile devices.

4. **Benchmarking**  
   Metrics collected include:
   - Latency
   - Throughput
   - Memory usage
   - Energy (estimated or measured)
   - Accuracy metrics

5. **Security Assessment**  
   This includes threat surface mapping, vulnerability identification, and mitigation analysis.

6. **Analysis**  
   Results are aggregated for cross-platform comparison and statistical evaluation.

---

## Datasets

The following datasets are used for benchmarking:

- MNIST
- EMNIST
- SVHN
- CIFAR-10

Datasets are not stored in this repository due to size constraints. Scripts for downloading and preprocessing are provided in `src/data/`.

---

## Platforms Evaluated

- CPU (general-purpose processing)
- GPU (parallel acceleration)
- FPGA (custom hardware acceleration)
- NPU (when available)
- VR/mobile devices (embedded inference environments)

Each platform includes configuration notes and deployment instructions in the `platforms/` directory.

---

## Reproducibility

To support reproducibility:

- All experiments are logged in `experiments/`
- Results are stored in `results/`
- Environment configurations are provided in:
  - `requirements.txt`
  - `environment.yml`

### Setup

~~~bash
git clone https://github.com/<your-username>/ml-edge-benchmark.git
cd ml-edge-benchmark
pip install -r requirements.txt
~~~


## Experiment Tracking

All experiments are recorded in:

~~~text
experiments/experiment_registry.csv
~~~

Each entry should include:
- Dataset
- Model configuration
- Platform
- Performance metrics
- Execution notes

---

## Results

Results are organized in:

~~~text
results/
├── raw_logs/
├── cleaned_results/
├── summary_tables/
├── figures/
~~~

These outputs support:
- Dissertation tables
- Performance comparisons
- Visualization figures

---

## Security Analysis

Security evaluation includes:

- Platform-specific vulnerabilities such as side-channel attacks and data exposure
- Threat modeling across deployment environments
- Trade-offs between security measures and performance

Relevant code and documentation are located in:
- `src/security/`
- `docs/methodology/`

---

## Current Status

- [ ] CNN baseline implementation complete
- [ ] Dataset preprocessing pipeline complete
- [ ] CPU benchmarking complete
- [ ] GPU benchmarking complete
- [ ] FPGA deployment complete
- [ ] VR/mobile deployment complete
- [ ] Security assessment complete
- [ ] Final analysis complete

---

## Contributions

This repository provides:

1. A reproducible benchmarking framework for CNN deployment  
2. Cross-platform performance comparisons  
3. A structured methodology for evaluating security-performance trade-offs  
4. A foundation for future decision-support tools in ML deployment  

---

## Future Work

- Automated decision-support system
- Additional datasets and model architectures
- Expanded hardware platform evaluation

---

## Citation

Stacey, Krista J. *Machine Learning on the Edge: Performance and Security Evaluation of CNN Implementations in Embedded Systems.* Dissertation, University of South Alabama, 2027.

---

## License

CC-NC-BY

---

## Acknowledgments

This work supports research in embedded machine learning, heterogeneous computing, and secure system design. It is in fufillment of the requirements of the PhD in Computing at the University of South Alabama.  
