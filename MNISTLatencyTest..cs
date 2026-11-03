using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using TMPro;
using Unity.InferenceEngine;
using UnityEngine;

public class MNISTLatencyTest : MonoBehaviour
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
            resultText.text += "Running Quest GPU latency test...\n\n";
        }

        runtimeModel = ModelLoader.Load(modelAsset);
        worker = new Worker(runtimeModel, BackendType.GPUCompute);

        byte[] imageBytes = imagesFile.bytes;

        const int pixelsPerImage = 784;
        const int bytesPerFloat = 4;

        const int warmupRuns = 50;
        const int measuredRuns = 1000;

        // Make sure at least one complete image is present.
        int expectedMinimumBytes =
            pixelsPerImage * bytesPerFloat;

        if (imageBytes.Length < expectedMinimumBytes)
        {
            string errorMessage =
                "Latency Test Error\n" +
                $"Expected at least: {expectedMinimumBytes} bytes\n" +
                $"Found: {imageBytes.Length} bytes";

            UnityEngine.Debug.LogError(errorMessage);

            if (resultText != null)
            {
                resultText.text += errorMessage;
            }

            return;
        }

        float[] inputData = new float[pixelsPerImage];

        // Use the first MNIST test image for every latency trial.
        for (int pixel = 0; pixel < pixelsPerImage; pixel++)
        {
            inputData[pixel] = BitConverter.ToSingle(
                imageBytes,
                pixel * bytesPerFloat
            );
        }

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

        // -------------------------
        // Measured runs
        // -------------------------
        List<double> latencies =
            new List<double>(measuredRuns);

        Stopwatch stopwatch = new Stopwatch();

        for (int i = 0; i < measuredRuns; i++)
        {
            using Tensor<float> inputTensor =
                new Tensor<float>(
                    new TensorShape(1, pixelsPerImage),
                    inputData
                );

            stopwatch.Restart();

            worker.Schedule(inputTensor);

            using Tensor<float> outputTensor =
                worker.PeekOutput().ReadbackAndClone() as Tensor<float>;

            stopwatch.Stop();

            latencies.Add(
                stopwatch.Elapsed.TotalMilliseconds
            );
        }

        // -------------------------
        // Summary statistics
        // -------------------------
        List<double> sortedLatencies =
            new List<double>(latencies);

        sortedLatencies.Sort();

        double sum = 0.0;

        foreach (double latency in latencies)
        {
            sum += latency;
        }

        double mean =
            sum / latencies.Count;

        double median =
            sortedLatencies[sortedLatencies.Count / 2];

        double min =
            sortedLatencies[0];

        double max =
            sortedLatencies[sortedLatencies.Count - 1];

        int p95Index =
            (int)Math.Ceiling(
                sortedLatencies.Count * 0.95
            ) - 1;

        double p95 =
            sortedLatencies[p95Index];

        // -------------------------
        // CSV output path
        // -------------------------
        string timestamp =
            DateTime.Now.ToString("yyyyMMdd_HHmmss");

        string fileName =
            $"mnist_latency_GPU_{timestamp}.csv";

        string filePath =
            Path.Combine(
                UnityEngine.Application.persistentDataPath,
                fileName
            );

        // -------------------------
        // Write CSV
        // -------------------------
        using (StreamWriter writer = new StreamWriter(filePath))
        {
            writer.WriteLine("MNIST Latency Benchmark");
            writer.WriteLine("Platform,Meta Quest 3");
            writer.WriteLine("Backend,GPU");
            writer.WriteLine($"Warmup Runs,{warmupRuns}");
            writer.WriteLine($"Measured Runs,{measuredRuns}");
            writer.WriteLine();

            writer.WriteLine("Summary");
            writer.WriteLine("Metric,Milliseconds");

            writer.WriteLine(
                $"Mean,{mean.ToString("F6", CultureInfo.InvariantCulture)}"
            );

            writer.WriteLine(
                $"Median,{median.ToString("F6", CultureInfo.InvariantCulture)}"
            );

            writer.WriteLine(
                $"P95,{p95.ToString("F6", CultureInfo.InvariantCulture)}"
            );

            writer.WriteLine(
                $"Min,{min.ToString("F6", CultureInfo.InvariantCulture)}"
            );

            writer.WriteLine(
                $"Max,{max.ToString("F6", CultureInfo.InvariantCulture)}"
            );

            writer.WriteLine();
            writer.WriteLine("Trial,Latency_ms");

            for (int i = 0; i < latencies.Count; i++)
            {
                writer.WriteLine(
                    $"{i + 1}," +
                    latencies[i].ToString(
                        "F6",
                        CultureInfo.InvariantCulture
                    )
                );
            }
        }

        // -------------------------
        // Quest UI
        // -------------------------
        string results =
            "Quest 3 GPU Latency\n\n" +
            $"Runs: {measuredRuns}\n" +
            $"Mean: {mean:F6} ms\n" +
            $"Median: {median:F6} ms\n" +
            $"P95: {p95:F6} ms\n" +
            $"Min: {min:F6} ms\n" +
            $"Max: {max:F6} ms";

        if (resultText != null)
        {
            resultText.text += results + "\n\n";
        }

        // -------------------------
        // Console
        // -------------------------
        UnityEngine.Debug.Log(results);

        UnityEngine.Debug.Log(
            "CSV saved to: " + filePath
        );
    }

    void OnDestroy()
    {
        worker?.Dispose();
    }
}