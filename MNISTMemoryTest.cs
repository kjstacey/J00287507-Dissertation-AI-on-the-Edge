using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using UnityEngine;
using Unity.InferenceEngine;

public class MNISTMemoryTest : MonoBehaviour
{
    public ModelAsset modelAsset;
    public TextAsset imagesFile;

    private Model runtimeModel;
    private Worker worker;

    void Start()
    {
        const int pixelsPerImage = 784;
        const int warmupRuns = 50;
        const int measuredRuns = 1000;

        byte[] imageBytes = imagesFile.bytes;
        float[] inputData = new float[pixelsPerImage];

        for (int pixel = 0; pixel < pixelsPerImage; pixel++)
        {
            inputData[pixel] = BitConverter.ToSingle(
                imageBytes,
                pixel * 4
            );
        }

        Process process = Process.GetCurrentProcess();

        // -------------------------
        // Baseline
        // -------------------------
        process.Refresh();

        long baselineWorkingSet = process.WorkingSet64;
        long baselinePrivate = process.PrivateMemorySize64;

        // -------------------------
        // Load model
        // -------------------------
        runtimeModel = ModelLoader.Load(modelAsset);
        worker = new Worker(runtimeModel, BackendType.GPUCompute);
        //worker = new Worker(runtimeModel, BackendType.GPU);

        process.Refresh();

        long modelLoadedWorkingSet = process.WorkingSet64;
        long modelLoadedPrivate = process.PrivateMemorySize64;

        // -------------------------
        // Warm-up
        // -------------------------
        for (int i = 0; i < warmupRuns; i++)
        {
            using Tensor<float> inputTensor =
                new Tensor<float>(
                    new TensorShape(1, pixelsPerImage),
                    inputData
                );

            worker.Schedule(inputTensor);

            using Tensor<float> outputTensor =
                worker.PeekOutput().ReadbackAndClone() as Tensor<float>;
        }

        // Start peak tracking after warm-up
        process.Refresh();

        long peakWorkingSet = process.WorkingSet64;
        long peakPrivate = process.PrivateMemorySize64;

        // -------------------------
        // Repeated inference
        // -------------------------
        for (int i = 0; i < measuredRuns; i++)
        {
            using Tensor<float> inputTensor =
                new Tensor<float>(
                    new TensorShape(1, pixelsPerImage),
                    inputData
                );

            worker.Schedule(inputTensor);

            using Tensor<float> outputTensor =
                worker.PeekOutput().ReadbackAndClone() as Tensor<float>;

            process.Refresh();

            if (process.WorkingSet64 > peakWorkingSet)
                peakWorkingSet = process.WorkingSet64;

            if (process.PrivateMemorySize64 > peakPrivate)
                peakPrivate = process.PrivateMemorySize64;
        }

        // -------------------------
        // Save CSV
        // -------------------------
        string timestamp =
            DateTime.Now.ToString("yyyyMMdd_HHmmss");

        string fileName =
            $"mnist_memory_GPU_{timestamp}.csv";
            //$"mnist_memory_GPU_{timestamp}.csv";

        string filePath =
            Path.Combine(
                UnityEngine.Application.persistentDataPath,
                fileName
            );

        using (StreamWriter writer = new StreamWriter(filePath))
        {
            writer.WriteLine("MNIST Memory Benchmark");
            writer.WriteLine("Backend,GPU");
            writer.WriteLine("Platform,Windows Standalone");
            writer.WriteLine();

            writer.WriteLine("Metric,Bytes,MB");

            WriteRow(
                writer,
                "Baseline Working Set",
                baselineWorkingSet
            );

            WriteRow(
                writer,
                "Model Loaded Working Set",
                modelLoadedWorkingSet
            );

            WriteRow(
                writer,
                "Peak Working Set",
                peakWorkingSet
            );

            WriteRow(
                writer,
                "Baseline Private Memory",
                baselinePrivate
            );

            WriteRow(
                writer,
                "Model Loaded Private Memory",
                modelLoadedPrivate
            );

            WriteRow(
                writer,
                "Peak Private Memory",
                peakPrivate
            );

            writer.WriteLine();

            WriteRow(
                writer,
                "Model Increment Working Set",
                modelLoadedWorkingSet - baselineWorkingSet
            );

            WriteRow(
                writer,
                "Peak Increment Working Set",
                peakWorkingSet - baselineWorkingSet
            );

            WriteRow(
                writer,
                "Model Increment Private Memory",
                modelLoadedPrivate - baselinePrivate
            );

            WriteRow(
                writer,
                "Peak Increment Private Memory",
                peakPrivate - baselinePrivate
            );
        }

        UnityEngine.Debug.Log(
            "Memory CSV saved to: " + filePath
        );
    }

    void WriteRow(
        StreamWriter writer,
        string metric,
        long bytes
    )
    {
        double mb = bytes / (1024.0 * 1024.0);

        writer.WriteLine(
            $"{metric},{bytes}," +
            mb.ToString("F3", CultureInfo.InvariantCulture)
        );
    }

    void OnDestroy()
    {
        worker?.Dispose();
    }
}