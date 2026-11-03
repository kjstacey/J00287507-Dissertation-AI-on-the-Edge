using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using TMPro;
using UnityEngine;
using Unity.InferenceEngine;

public class MNISTThroughputTest : MonoBehaviour
{
    public ModelAsset modelAsset;
    public TextAsset imagesFile;

    [Header("Quest UI")]
    public TMP_Text resultText;

    private Model runtimeModel;
    private Worker worker;

    void Start()
    {
        if (resultText != null)
        {
            resultText.text += "Running Quest GPU throughput test...\n\n";
        }

        runtimeModel = ModelLoader.Load(modelAsset);
        worker = new Worker(runtimeModel, BackendType.GPUCompute);

        byte[] imageBytes = imagesFile.bytes;

        const int pixelsPerImage = 784;
        const int bytesPerFloat = 4;
        const int imageCount = 10000;

        const int warmupRuns = 50;
        const int measuredRuns = 10000;

        int expectedImageBytes =
            imageCount * pixelsPerImage * bytesPerFloat;

        if (imageBytes.Length != expectedImageBytes)
        {
            string errorMessage =
                $"Throughput Error\n" +
                $"Expected: {expectedImageBytes} bytes\n" +
                $"Found: {imageBytes.Length} bytes";

            UnityEngine.Debug.LogError(errorMessage);

            if (resultText != null)
            {
                resultText.text += errorMessage;
            }

            return;
        }

        float[] inputData = new float[pixelsPerImage];

        // -------------------------
        // Warm-up
        // -------------------------
        for (int i = 0; i < warmupRuns; i++)
        {
            int imageIndex = i % imageCount;

            int byteOffset =
                imageIndex * pixelsPerImage * bytesPerFloat;

            for (int pixel = 0; pixel < pixelsPerImage; pixel++)
            {
                inputData[pixel] = BitConverter.ToSingle(
                    imageBytes,
                    byteOffset + pixel * bytesPerFloat
                );
            }

            using Tensor<float> inputTensor =
                new Tensor<float>(
                    new TensorShape(1, pixelsPerImage),
                    inputData
                );

            worker.Schedule(inputTensor);

            using Tensor<float> outputTensor =
                worker.PeekOutput().ReadbackAndClone() as Tensor<float>;
        }

        // -------------------------
        // Throughput measurement
        // -------------------------
        Stopwatch stopwatch = new Stopwatch();

        stopwatch.Start();

        for (int i = 0; i < measuredRuns; i++)
        {
            int imageIndex = i % imageCount;

            int byteOffset =
                imageIndex * pixelsPerImage * bytesPerFloat;

            for (int pixel = 0; pixel < pixelsPerImage; pixel++)
            {
                inputData[pixel] = BitConverter.ToSingle(
                    imageBytes,
                    byteOffset + pixel * bytesPerFloat
                );
            }

            using Tensor<float> inputTensor =
                new Tensor<float>(
                    new TensorShape(1, pixelsPerImage),
                    inputData
                );

            worker.Schedule(inputTensor);

            using Tensor<float> outputTensor =
                worker.PeekOutput().ReadbackAndClone() as Tensor<float>;
        }

        stopwatch.Stop();

        double elapsedSeconds =
            stopwatch.Elapsed.TotalSeconds;

        double throughput =
            measuredRuns / elapsedSeconds;

        double averageTimePerInferenceMs =
            (elapsedSeconds / measuredRuns) * 1000.0;

        // -------------------------
        // CSV
        // -------------------------
        string timestamp =
            DateTime.Now.ToString("yyyyMMdd_HHmmss");

        string fileName =
            $"mnist_throughput_GPU_{timestamp}.csv";

        string filePath =
            Path.Combine(
                UnityEngine.Application.persistentDataPath,
                fileName
            );

        using (StreamWriter writer = new StreamWriter(filePath))
        {
            writer.WriteLine("MNIST Throughput Benchmark");
            writer.WriteLine("Platform,Meta Quest 3");
            writer.WriteLine("Backend,GPU");
            writer.WriteLine($"Warmup Runs,{warmupRuns}");
            writer.WriteLine($"Measured Runs,{measuredRuns}");
            writer.WriteLine();

            writer.WriteLine("Metric,Value");

            writer.WriteLine(
                $"Elapsed Seconds,{elapsedSeconds.ToString("F6", CultureInfo.InvariantCulture)}"
            );

            writer.WriteLine(
                $"Throughput Images/sec,{throughput.ToString("F3", CultureInfo.InvariantCulture)}"
            );

            writer.WriteLine(
                $"Average Time Per Inference ms,{averageTimePerInferenceMs.ToString("F6", CultureInfo.InvariantCulture)}"
            );
        }

        // -------------------------
        // Quest UI
        // -------------------------
        string results =
            "Quest 3 GPU Throughput\n\n" +
            $"Runs: {measuredRuns}\n" +
            $"Elapsed: {elapsedSeconds:F6} s\n" +
            $"Throughput: {throughput:F3} img/s\n" +
            $"Avg: {averageTimePerInferenceMs:F6} ms/image";

        if (resultText != null)
        {
            resultText.text += results + "\n\n";
        }

        // -------------------------
        // Console
        // -------------------------
        UnityEngine.Debug.Log(results);
        UnityEngine.Debug.Log("CSV saved to: " + filePath);
    }

    void OnDestroy()
    {
        worker?.Dispose();
    }
}