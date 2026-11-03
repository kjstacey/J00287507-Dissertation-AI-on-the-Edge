using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using TMPro;
using UnityEngine;
using UnityEngine.Networking;

public class CloudMNISTBenchmark : MonoBehaviour
{
    [Header("MNIST Data")]
    public TextAsset imagesFile;
    public TextAsset labelsFile;

    [Header("UI")]
    public TMP_Text resultText;

    [Header("Cloud Run")]
    public string endpoint =
        "https://mnist-cloud-inference-221036165238.us-east1.run.app/predict";

    private const int PixelsPerImage = 784;
    private const int BytesPerFloat = 4;
    private const int TestImageCount = 1000;

    [Serializable]
    private class PredictionResponse
    {
        public int prediction;
    }

    void Start()
    {
        StartCoroutine(RunBenchmark());
    }

    IEnumerator RunBenchmark()
    {
        if (resultText != null)
        {
            resultText.text = "Running 1000-image cloud benchmark...";
        }

        byte[] imageBytes = imagesFile.bytes;
        byte[] labelBytes = labelsFile.bytes;

        int requiredImageBytes =
            TestImageCount *
            PixelsPerImage *
            BytesPerFloat;

        if (imageBytes.Length < requiredImageBytes)
        {
            SetResult(
                "ERROR: MNIST image file does not contain 1000 images."
            );
            yield break;
        }

        if (labelBytes.Length < TestImageCount)
        {
            SetResult(
                "ERROR: MNIST label file does not contain 1000 labels."
            );
            yield break;
        }

        List<double> latencies =
            new List<double>(TestImageCount);

        List<int> predictions =
            new List<int>(TestImageCount);

        int correct = 0;
        int errors = 0;

        Stopwatch totalStopwatch =
            Stopwatch.StartNew();

        for (int imageIndex = 0;
             imageIndex < TestImageCount;
             imageIndex++)
        {
            byte[] requestBody =
                new byte[PixelsPerImage];

            int imageByteOffset =
                imageIndex *
                PixelsPerImage *
                BytesPerFloat;

            for (int pixel = 0;
                 pixel < PixelsPerImage;
                 pixel++)
            {
                float value =
                    BitConverter.ToSingle(
                        imageBytes,
                        imageByteOffset +
                        pixel *
                        BytesPerFloat
                    );

                int byteValue =
                    Mathf.RoundToInt(
                        Mathf.Clamp01(value) *
                        255f
                    );

                requestBody[pixel] =
                    (byte)byteValue;
            }

            using UnityWebRequest request =
                new UnityWebRequest(
                    endpoint,
                    UnityWebRequest.kHttpVerbPOST
                );

            request.uploadHandler =
                new UploadHandlerRaw(
                    requestBody
                );

            request.downloadHandler =
                new DownloadHandlerBuffer();

            request.SetRequestHeader(
                "Content-Type",
                "application/octet-stream"
            );

            Stopwatch requestStopwatch =
                Stopwatch.StartNew();

            yield return request.SendWebRequest();

            requestStopwatch.Stop();

            double latencyMs =
                requestStopwatch.Elapsed.TotalMilliseconds;

            latencies.Add(
                latencyMs
            );

            if (request.result !=
                UnityWebRequest.Result.Success)
            {
                errors++;
                predictions.Add(-1);

                UnityEngine.Debug.LogError(
                    $"Image {imageIndex}: " +
                    $"HTTP {request.responseCode} " +
                    $"{request.error}"
                );

                continue;
            }

            string responseText =
                request.downloadHandler.text;

            PredictionResponse response =
                JsonUtility.FromJson<PredictionResponse>(
                    responseText
                );

            if (response == null)
            {
                errors++;
                predictions.Add(-1);
                continue;
            }

            int predictedDigit =
                response.prediction;

            int expectedDigit =
                labelBytes[imageIndex];

            predictions.Add(
                predictedDigit
            );

            if (predictedDigit ==
                expectedDigit)
            {
                correct++;
            }

            if (resultText != null)
            {
                resultText.text =
                    "Running Cloud Benchmark\n" +
                    $"Image: {imageIndex + 1}/{TestImageCount}\n" +
                    $"Correct: {correct}\n" +
                    $"Errors: {errors}\n" +
                    $"Last latency: {latencyMs:F2} ms";
            }
        }

        totalStopwatch.Stop();

        double totalSeconds =
            totalStopwatch.Elapsed.TotalSeconds;

        double accuracy =
            (double)correct /
            TestImageCount *
            100.0;

        double throughput =
            TestImageCount /
            totalSeconds;

        List<double> sorted =
            new List<double>(latencies);

        sorted.Sort();

        double sum = 0.0;

        foreach (double latency in latencies)
        {
            sum += latency;
        }

        double mean =
            sum / latencies.Count;

        double median;

        if (sorted.Count % 2 == 0)
        {
            int middle =
                sorted.Count / 2;

            median =
                (
                    sorted[middle - 1] +
                    sorted[middle]
                ) / 2.0;
        }
        else
        {
            median =
                sorted[
                    sorted.Count / 2
                ];
        }

        int p95Index =
            Mathf.CeilToInt(
                sorted.Count *
                0.95f
            ) - 1;

        double p95 =
            sorted[p95Index];

        double min =
            sorted[0];

        double max =
            sorted[
                sorted.Count - 1
            ];

        string results =
            "Cloud MNIST Benchmark\n\n" +
            $"Images: {TestImageCount}\n" +
            $"Correct: {correct}\n" +
            $"Errors: {errors}\n" +
            $"Accuracy: {accuracy:F2}%\n\n" +
            $"Mean: {mean:F2} ms\n" +
            $"Median: {median:F2} ms\n" +
            $"P95: {p95:F2} ms\n" +
            $"Min: {min:F2} ms\n" +
            $"Max: {max:F2} ms\n\n" +
            $"Total: {totalSeconds:F2} s\n" +
            $"Throughput: {throughput:F2} req/s";

        SetResult(
            results
        );

        UnityEngine.Debug.Log(
            results
        );

        SaveCsv(
            latencies,
            predictions,
            labelBytes,
            correct,
            errors,
            accuracy,
            mean,
            median,
            p95,
            min,
            max,
            totalSeconds,
            throughput
        );
    }

    private void SaveCsv(
        List<double> latencies,
        List<int> predictions,
        byte[] labels,
        int correct,
        int errors,
        double accuracy,
        double mean,
        double median,
        double p95,
        double min,
        double max,
        double totalSeconds,
        double throughput
    )
    {
        string timestamp =
            DateTime.Now.ToString(
                "yyyyMMdd_HHmmss"
            );

        string fileName =
            $"cloud_mnist_1000_{timestamp}.csv";

        string filePath =
            Path.Combine(
                UnityEngine.Application.persistentDataPath,
                fileName
            );

        using StreamWriter writer =
            new StreamWriter(
                filePath
            );

        writer.WriteLine(
            "Cloud MNIST 1000-Image Benchmark"
        );

        writer.WriteLine(
            "Endpoint," +
            endpoint
        );

        writer.WriteLine(
            $"Images,{TestImageCount}"
        );

        writer.WriteLine(
            $"Correct,{correct}"
        );

        writer.WriteLine(
            $"Errors,{errors}"
        );

        writer.WriteLine(
            $"Accuracy,{accuracy.ToString("F2", CultureInfo.InvariantCulture)}"
        );

        writer.WriteLine(
            $"Mean Latency ms,{mean.ToString("F6", CultureInfo.InvariantCulture)}"
        );

        writer.WriteLine(
            $"Median Latency ms,{median.ToString("F6", CultureInfo.InvariantCulture)}"
        );

        writer.WriteLine(
            $"P95 Latency ms,{p95.ToString("F6", CultureInfo.InvariantCulture)}"
        );

        writer.WriteLine(
            $"Min Latency ms,{min.ToString("F6", CultureInfo.InvariantCulture)}"
        );

        writer.WriteLine(
            $"Max Latency ms,{max.ToString("F6", CultureInfo.InvariantCulture)}"
        );

        writer.WriteLine(
            $"Total Seconds,{totalSeconds.ToString("F6", CultureInfo.InvariantCulture)}"
        );

        writer.WriteLine(
            $"Throughput req/sec,{throughput.ToString("F6", CultureInfo.InvariantCulture)}"
        );

        writer.WriteLine();

        writer.WriteLine(
            "Image,Expected,Predicted,Latency_ms"
        );

        for (int i = 0;
             i < latencies.Count;
             i++)
        {
            writer.WriteLine(
                $"{i}," +
                $"{labels[i]}," +
                $"{predictions[i]}," +
                latencies[i].ToString(
                    "F6",
                    CultureInfo.InvariantCulture
                )
            );
        }

        UnityEngine.Debug.Log(
            "Cloud benchmark CSV saved to: " +
            filePath
        );
    }

    private void SetResult(
        string message
    )
    {
        if (resultText != null)
        {
            resultText.text =
                message;
        }
    }
}