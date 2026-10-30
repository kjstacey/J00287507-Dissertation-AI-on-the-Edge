# MNIST Model Development

This branch contains the model-development files used for the MNIST experiments in this research.

Its purpose is to document and preserve the **training, model-generation, conversion, and supporting notes** for the MNIST models used in both:

- the **FPGA/ZyNet implementation**, and
- the **Unity/ONNX implementation**.

This branch does **not** contain the full FPGA hardware project, Vivado implementation files, cloud networking code, or platform performance benchmarks. Those materials are maintained separately.

## Model Overview

The MNIST classifier used for the FPGA implementation is a fully connected feed-forward neural network with the following architecture:

784 -> 30 -> 20 -> 10

The 28 × 28 MNIST image is flattened into 784 input values. The network contains two hidden layers with 30 and 20 neurons and produces 10 output values corresponding to the digits 0 through 9.

The same trained MNIST model is also used as the basis for the Unity implementation after conversion to ONNX format.

## Contents of This Branch

The files in this branch may include:

- Python scripts used to load MNIST data;
- neural-network training scripts;
- model-definition code;
- scripts used to export trained weights and biases;
- ZyNet-compatible weight and bias files;
- scripts used during model conversion;
- the trained model files;
- ONNX conversion files for Unity;
- Jupyter notebooks documenting the model-creation process;
- command-prompt screenshots showing training results;
- notes documenting model settings, conversion steps, and validation results.

Files associated only with FPGA implementation, Vivado synthesis, ILA capture, hardware benchmarking, cloud communication, or power measurement are not part of this branch.

## FPGA / ZyNet Model

The FPGA implementation is based on the open-source **ZyNet** project.

Original ZyNet repository:

https://github.com/dsdnu/zynet

The FPGA notebook documents the process used to:

1. load the MNIST dataset;
2. define the 784 → 30 → 20 → 10 network;
3. train and evaluate the model;
4. save the trained weights and biases;
5. convert the trained parameters into the format required by ZyNet; and
6. generate the memory files used by the FPGA implementation.

Relevant generated artifacts may include:

WeigntsAndBiases.txt
weights.mem
biases.mem

The filename `WeigntsAndBiases.txt` is intentionally retained because it matches the file used by the working implementation.

## Unity / ONNX Model

A separate notebook documents the conversion of the trained MNIST model into the ONNX format used by the Unity implementation.

This allows the same trained network to be traced from its original Python implementation into both FPGA and Unity deployment environments while keeping the conversion steps reproducible.

The Unity notebook will document:

- model reconstruction or loading;
- conversion to ONNX;
- input and output formatting;
- any preprocessing requirements;
- validation of the converted model; and
- the final ONNX model used by Unity.

## Jupyter Notebooks

The planned notebooks for this branch are:

MNIST_ZyNet_Model_Creation.ipynb
MNIST_Unity_ONNX_Conversion.ipynb

The first notebook documents training and FPGA/ZyNet model preparation.

The second notebook documents conversion of the trained MNIST model for Unity.

## MNIST Dataset

The MNIST handwritten-digit dataset is used for model training and evaluation.

Original MNIST dataset site:

https://yann.lecun.com/exdb/mnist/

The notebooks document how the dataset is loaded and used rather than treating the dataset itself as original project material.

## Training Evidence

Screenshots or text output from the command prompt may be included to preserve representative training results associated with the saved model.

These files are intended as supporting evidence of the training process and should correspond to the model artifacts stored in this branch.

## Reproducibility

The goal of this branch is to make the MNIST model-development workflow reproducible.

A reader should be able to follow the notebooks and scripts to understand:

- how the MNIST model was trained;
- what architecture was used;
- how the trained parameters were saved;
- how the FPGA-compatible files were generated;
- how the model was converted to ONNX; and
- which resulting model files were used in the later platform experiments.

Platform-specific performance results are intentionally kept separate from the model-development materials in this branch.
