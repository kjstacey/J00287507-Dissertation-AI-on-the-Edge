using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using Meta.XR;
using TMPro;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Networking;
using UnityEngine.UI;

public class QuestCloudCameraMNISTInference : MonoBehaviour
{
    // =========================================================
    // QUEST CAMERA
    // =========================================================

    [Header("Quest Camera")]
    public PassthroughCameraAccess cameraAccess;

    // =========================================================
    // DISPLAYS
    // =========================================================

    [Header("Displays")]
    public RawImage cameraDisplay;
    public RawImage processedDisplay;
    public RawImage frozenDisplay;
    public TMP_Text predictionText;

    // =========================================================
    // CLOUD
    // =========================================================

    [Header("Cloud Run")]
    public string endpoint =
        "https://mnist-cloud-inference-221036165238.us-east1.run.app/predict";

    // =========================================================
    // PREPROCESSING
    // =========================================================

    [Header("Preprocessing")]
    [Range(0f, 1f)]
    public float threshold = 0.5f;

    private const int TargetSize = 28;
    private const int PixelCount = 784;

    private Texture2D processedTexture;
    private Texture2D frozenTexture;

    private readonly float[] latestInputData =
        new float[PixelCount];

    // =========================================================
    // CLOUD BENCHMARK SETTINGS
    // =========================================================

    private const int WarmupRuns = 2;
    private const int BenchmarkRuns = 100;

    private bool cloudRequestInFlight = false;
    private bool benchmarkRunning = false;

    // =========================================================
    // LIVE THROUGHPUT
    // =========================================================

    private bool runningLiveThroughput = false;

    private float liveThroughputStartTime;
    private int liveFramesProcessed = 0;

    private const float LiveThroughputDuration = 10f;

    // Used to ensure each cloud request corresponds
    // to a new Quest camera frame.
    private int cameraFrameVersion = 0;
    private int lastCloudFrameVersion = -1;

    // =========================================================
    // CLOUD RESPONSE
    // =========================================================

    [Serializable]
    private class PredictionResponse
    {
        public int prediction;
    }

    // =========================================================
    // START
    // =========================================================

    void Start()
    {
        processedTexture =
            new Texture2D(
                TargetSize,
                TargetSize,
                TextureFormat.RGB24,
                false
            );

        processedTexture.filterMode =
            FilterMode.Point;

        if (processedDisplay != null)
        {
            processedDisplay.texture =
                processedTexture;
        }

        frozenTexture =
            new Texture2D(
                TargetSize,
                TargetSize,
                TextureFormat.RGB24,
                false
            );

        frozenTexture.filterMode =
            FilterMode.Point;

        if (frozenDisplay != null)
        {
            frozenDisplay.texture =
                frozenTexture;
        }

        if (predictionText != null)
        {
            predictionText.text =
                "Quest Cloud Camera: Ready";
        }

        UnityEngine.Debug.Log(
            "Quest cloud camera initialized."
        );
    }

    // =========================================================
    // UPDATE
    // =========================================================

    void Update()
    {
        if (cameraAccess == null)
            return;

        if (!cameraAccess.IsPlaying)
            return;

        // ---------------------------------------------
        // Display live RGB Quest camera texture.
        // ---------------------------------------------

        Texture cameraTexture =
            cameraAccess.GetTexture();

        if (cameraDisplay != null &&
            cameraTexture != null)
        {
            cameraDisplay.texture =
                cameraTexture;
        }

        // ---------------------------------------------
        // Only process a newly available camera frame.
        // ---------------------------------------------

        if (!cameraAccess.IsUpdatedThisFrame)
            return;

        UpdateProcessedImage();

        cameraFrameVersion++;
    }

    // =========================================================
    // QUEST CAMERA PREPROCESSING
    // =========================================================

    private void UpdateProcessedImage()
    {
        if (cameraAccess == null ||
            !cameraAccess.IsPlaying)
        {
            return;
        }

        NativeArray<Color32> sourcePixels =
            cameraAccess.GetColors();

        Vector2Int resolution =
            cameraAccess.CurrentResolution;

        int sourceWidth =
            resolution.x;

        int sourceHeight =
            resolution.y;

        if (sourceWidth <= 16 ||
            sourceHeight <= 16)
        {
            return;
        }

        // -----------------------------------------------------
        // FPGA reference coordinate space:
        // 160 x 120
        //
        // ROI:
        // x = 24..135
        // y = 4..115
        //
        // Sample every 4 FPGA-reference pixels
        // -> 28 x 28 = 784
        // -----------------------------------------------------

        float xScale =
            sourceWidth / 160f;

        float yScale =
            sourceHeight / 120f;

        int roiStartX =
            Mathf.RoundToInt(
                24f * xScale
            );

        int roiStartY =
            Mathf.RoundToInt(
                4f * yScale
            );

        float sampleStepX =
            4f * xScale;

        float sampleStepY =
            4f * yScale;

        Color[] outputPixels =
            new Color[PixelCount];

        for (int y = 0;
             y < TargetSize;
             y++)
        {
            for (int x = 0;
                 x < TargetSize;
                 x++)
            {
                int sourceX =
                    Mathf.RoundToInt(
                        roiStartX +
                        x * sampleStepX
                    );

                int sourceY =
                    Mathf.RoundToInt(
                        roiStartY +
                        y * sampleStepY
                    );

                sourceX =
                    Mathf.Clamp(
                        sourceX,
                        0,
                        sourceWidth - 1
                    );

                sourceY =
                    Mathf.Clamp(
                        sourceY,
                        0,
                        sourceHeight - 1
                    );

                Color32 pixel =
                    sourcePixels[
                        sourceY *
                        sourceWidth +
                        sourceX
                    ];

                float r =
                    pixel.r / 255f;

                float g =
                    pixel.g / 255f;

                float b =
                    pixel.b / 255f;

                float gray =
                    0.299f * r +
                    0.587f * g +
                    0.114f * b;

                gray =
                    gray < threshold
                        ? 0f
                        : 1f;

                int index =
                    y *
                    TargetSize +
                    x;

                latestInputData[index] =
                    gray;

                outputPixels[index] =
                    new Color(
                        gray,
                        gray,
                        gray,
                        1f
                    );
            }
        }

        processedTexture.SetPixels(
            outputPixels
        );

        processedTexture.Apply();
    }

    // =========================================================
    // CLASSIFY CURRENT QUEST CAMERA FRAME
    // =========================================================

    public void ClassifyCurrentFrame()
    {
        if (cloudRequestInFlight ||
            benchmarkRunning ||
            runningLiveThroughput)
        {
            SetText(
                "Cloud request already running..."
            );

            return;
        }

        if (cameraAccess == null ||
            !cameraAccess.IsPlaying)
        {
            SetText(
                "ERROR: Quest camera is not running."
            );

            return;
        }

        // Make sure latest pixels are used.
        UpdateProcessedImage();

        float[] frozenInput =
            new float[
                latestInputData.Length
            ];

        latestInputData.CopyTo(
            frozenInput,
            0
        );

        ShowFrozenImage(
            frozenInput
        );

        byte[] body =
            ConvertFloatImageToBytes(
                frozenInput
            );

        SetText(
            "Sending Quest image to Cloud Run..."
        );

        StartCoroutine(
            ClassifyFrozenCoroutine(
                body
            )
        );
    }

    private IEnumerator ClassifyFrozenCoroutine(
        byte[] body
    )
    {
        cloudRequestInFlight = true;

        Stopwatch stopwatch =
            Stopwatch.StartNew();

        using UnityWebRequest request =
            CreateRequest(body);

        yield return
            request.SendWebRequest();

        stopwatch.Stop();

        cloudRequestInFlight = false;

        double latencyMs =
            stopwatch.Elapsed
                .TotalMilliseconds;

        if (!TryGetPrediction(
                request,
                out int predictedDigit))
        {
            yield break;
        }

        string results =
            "Quest Cloud Prediction\n" +
            $"Prediction: {predictedDigit}\n" +
            $"Round Trip: {latencyMs:F2} ms";

        SetText(results);

        UnityEngine.Debug.Log(
            results
        );
    }

    // =========================================================
    // FROZEN CAMERA CLOUD BENCHMARK
    // =========================================================

    public void BenchmarkFrozenImage()
    {
        if (cloudRequestInFlight ||
            benchmarkRunning ||
            runningLiveThroughput)
        {
            SetText(
                "Cloud benchmark already running..."
            );

            return;
        }

        if (cameraAccess == null ||
            !cameraAccess.IsPlaying)
        {
            SetText(
                "ERROR: Quest camera is not running."
            );

            return;
        }

        UpdateProcessedImage();

        StartCoroutine(
            BenchmarkFrozenImageCoroutine()
        );
    }

    private IEnumerator BenchmarkFrozenImageCoroutine()
    {
        benchmarkRunning = true;

        float[] frozenInput =
            new float[
                latestInputData.Length
            ];

        latestInputData.CopyTo(
            frozenInput,
            0
        );

        ShowFrozenImage(
            frozenInput
        );

        byte[] body =
            ConvertFloatImageToBytes(
                frozenInput
            );

        // ---------------------------------------------
        // Warm-up cloud requests
        // ---------------------------------------------

        for (int i = 0;
             i < WarmupRuns;
             i++)
        {
            using UnityWebRequest warmup =
                CreateRequest(body);

            yield return
                warmup.SendWebRequest();
        }

        // ---------------------------------------------
        // Measured cloud requests
        // ---------------------------------------------

        List<double> latencies =
            new List<double>(
                BenchmarkRuns
            );

        for (int i = 0;
             i < BenchmarkRuns;
             i++)
        {
            Stopwatch stopwatch =
                Stopwatch.StartNew();

            using UnityWebRequest request =
                CreateRequest(body);

            yield return
                request.SendWebRequest();

            stopwatch.Stop();

            if (request.result ==
                UnityWebRequest.Result.Success)
            {
                latencies.Add(
                    stopwatch.Elapsed
                        .TotalMilliseconds
                );
            }

            SetText(
                "Quest Frozen Cloud Benchmark\n" +
                $"{i + 1}/{BenchmarkRuns}"
            );
        }

        benchmarkRunning = false;

        DisplayStatistics(
            latencies,
            "Quest Frozen Camera Cloud Benchmark"
        );
    }

    // =========================================================
    // END-TO-END QUEST CAMERA -> CLOUD BENCHMARK
    // =========================================================

    public void BenchmarkEndToEndCamera()
    {
        if (cloudRequestInFlight ||
            benchmarkRunning ||
            runningLiveThroughput)
        {
            SetText(
                "Cloud benchmark already running..."
            );

            return;
        }

        if (cameraAccess == null ||
            !cameraAccess.IsPlaying)
        {
            SetText(
                "ERROR: Quest camera is not running."
            );

            return;
        }

        StartCoroutine(
            BenchmarkEndToEndCameraCoroutine()
        );
    }

    private IEnumerator BenchmarkEndToEndCameraCoroutine()
    {
        benchmarkRunning = true;

        // ---------------------------------------------
        // Warm-up
        // ---------------------------------------------

        for (int run = 0;
             run < WarmupRuns;
             run++)
        {
            UpdateProcessedImage();

            byte[] warmupBody =
                ConvertCurrentImageToBytes();

            using UnityWebRequest request =
                CreateRequest(
                    warmupBody
                );

            yield return
                request.SendWebRequest();
        }

        // ---------------------------------------------
        // Measured end-to-end runs
        //
        // Includes:
        // Quest camera CPU pixel retrieval
        // ROI sampling
        // grayscale
        // threshold
        // 784-byte conversion
        // HTTPS request
        // cloud inference
        // HTTP response
        // ---------------------------------------------

        List<double> latencies =
            new List<double>(
                BenchmarkRuns
            );

        for (int run = 0;
             run < BenchmarkRuns;
             run++)
        {
            Stopwatch stopwatch =
                Stopwatch.StartNew();

            UpdateProcessedImage();

            byte[] body =
                ConvertCurrentImageToBytes();

            using UnityWebRequest request =
                CreateRequest(body);

            yield return
                request.SendWebRequest();

            stopwatch.Stop();

            if (request.result ==
                UnityWebRequest.Result.Success)
            {
                latencies.Add(
                    stopwatch.Elapsed
                        .TotalMilliseconds
                );
            }

            SetText(
                "Quest End-to-End Cloud Benchmark\n" +
                $"{run + 1}/{BenchmarkRuns}"
            );
        }

        benchmarkRunning = false;

        DisplayStatistics(
            latencies,
            "Quest End-to-End Camera Cloud"
        );
    }

    // =========================================================
    // LIVE QUEST CAMERA -> CLOUD THROUGHPUT
    // =========================================================

    public void StartLiveThroughputTest()
    {
        if (cloudRequestInFlight ||
            benchmarkRunning ||
            runningLiveThroughput)
        {
            return;
        }

        if (cameraAccess == null ||
            !cameraAccess.IsPlaying)
        {
            SetText(
                "ERROR: Quest camera is not running."
            );

            return;
        }

        liveFramesProcessed = 0;

        liveThroughputStartTime =
            Time.realtimeSinceStartup;

        lastCloudFrameVersion = -1;

        runningLiveThroughput =
            true;

        SetText(
            "Quest live cloud throughput running..."
        );

        StartCoroutine(
            RunLiveCloudThroughput()
        );
    }

    private IEnumerator RunLiveCloudThroughput()
    {
        while (runningLiveThroughput)
        {
            float elapsed =
                Time.realtimeSinceStartup -
                liveThroughputStartTime;

            if (elapsed >=
                LiveThroughputDuration)
            {
                break;
            }

            // -----------------------------------------
            // Wait for a NEW Quest camera frame.
            // -----------------------------------------

            while (cameraFrameVersion ==
                   lastCloudFrameVersion)
            {
                elapsed =
                    Time.realtimeSinceStartup -
                    liveThroughputStartTime;

                if (elapsed >=
                    LiveThroughputDuration)
                {
                    runningLiveThroughput =
                        false;

                    FinishLiveThroughputTest();

                    yield break;
                }

                yield return null;
            }

            lastCloudFrameVersion =
                cameraFrameVersion;

            byte[] body =
                ConvertCurrentImageToBytes();

            Stopwatch stopwatch =
                Stopwatch.StartNew();

            using UnityWebRequest request =
                CreateRequest(body);

            yield return
                request.SendWebRequest();

            stopwatch.Stop();

            if (request.result ==
                UnityWebRequest.Result.Success)
            {
                liveFramesProcessed++;

                UnityEngine.Debug.Log(
                    $"Quest cloud request {liveFramesProcessed}: " +
                    $"{stopwatch.Elapsed.TotalMilliseconds:F2} ms"
                );
            }
            else
            {
                UnityEngine.Debug.LogError(
                    "Quest cloud request failed: " +
                    request.error
                );
            }
        }

        runningLiveThroughput =
            false;

        FinishLiveThroughputTest();
    }

    private void FinishLiveThroughputTest()
    {
        float elapsed =
            Time.realtimeSinceStartup -
            liveThroughputStartTime;

        float throughput =
            elapsed > 0f
                ? liveFramesProcessed /
                  elapsed
                : 0f;

        string results =
            "Quest Live Camera Cloud Throughput\n" +
            $"Completed requests: {liveFramesProcessed}\n" +
            $"Time: {elapsed:F2} s\n" +
            $"Throughput: {throughput:F2} predictions/s";

        SetText(results);

        UnityEngine.Debug.Log(
            results
        );
    }

    // =========================================================
    // CLOUD REQUEST
    // =========================================================

    private UnityWebRequest CreateRequest(
        byte[] body
    )
    {
        UnityWebRequest request =
            new UnityWebRequest(
                endpoint,
                UnityWebRequest.kHttpVerbPOST
            );

        request.uploadHandler =
            new UploadHandlerRaw(
                body
            );

        request.downloadHandler =
            new DownloadHandlerBuffer();

        request.SetRequestHeader(
            "Content-Type",
            "application/octet-stream"
        );

        return request;
    }

    // =========================================================
    // RESPONSE PARSING
    // =========================================================

    private bool TryGetPrediction(
        UnityWebRequest request,
        out int prediction
    )
    {
        prediction = -1;

        if (request.result !=
            UnityWebRequest.Result.Success)
        {
            string error =
                "Quest cloud request failed\n" +
                $"HTTP: {request.responseCode}\n" +
                $"Error: {request.error}";

            SetText(error);

            UnityEngine.Debug.LogError(
                error
            );

            return false;
        }

        string responseText =
            request.downloadHandler.text;

        PredictionResponse response =
            JsonUtility.FromJson<PredictionResponse>(
                responseText
            );

        if (response == null)
        {
            SetText(
                "ERROR: Could not parse cloud response."
            );

            return false;
        }

        prediction =
            response.prediction;

        return true;
    }

    // =========================================================
    // CONVERT 0/1 IMAGE TO 784-BYTE CLOUD PAYLOAD
    // =========================================================

    private byte[] ConvertCurrentImageToBytes()
    {
        return ConvertFloatImageToBytes(
            latestInputData
        );
    }

    private byte[] ConvertFloatImageToBytes(
        float[] input
    )
    {
        byte[] body =
            new byte[PixelCount];

        for (int i = 0;
             i < PixelCount;
             i++)
        {
            body[i] =
                (byte)Mathf.RoundToInt(
                    Mathf.Clamp01(
                        input[i]
                    ) * 255f
                );
        }

        return body;
    }

    // =========================================================
    // FROZEN IMAGE DISPLAY
    // =========================================================

    private void ShowFrozenImage(
        float[] input
    )
    {
        if (frozenTexture == null)
            return;

        Color[] pixels =
            new Color[PixelCount];

        for (int i = 0;
             i < input.Length;
             i++)
        {
            float value =
                input[i];

            pixels[i] =
                new Color(
                    value,
                    value,
                    value,
                    1f
                );
        }

        frozenTexture.SetPixels(
            pixels
        );

        frozenTexture.Apply();
    }

    // =========================================================
    // STATISTICS
    // =========================================================

    private void DisplayStatistics(
        List<double> values,
        string title
    )
    {
        if (values == null ||
            values.Count == 0)
        {
            SetText(
                title +
                "\nNo successful requests."
            );

            return;
        }

        values.Sort();

        double sum = 0.0;

        foreach (double value in values)
        {
            sum += value;
        }

        double mean =
            sum / values.Count;

        double median;

        if (values.Count % 2 == 0)
        {
            int middle =
                values.Count / 2;

            median =
                (
                    values[middle - 1] +
                    values[middle]
                ) / 2.0;
        }
        else
        {
            median =
                values[
                    values.Count / 2
                ];
        }

        int p95Index =
            Mathf.CeilToInt(
                values.Count *
                0.95f
            ) - 1;

        double p95 =
            values[p95Index];

        double min =
            values[0];

        double max =
            values[
                values.Count - 1
            ];

        double varianceSum =
            0.0;

        foreach (double value in values)
        {
            double difference =
                value - mean;

            varianceSum +=
                difference *
                difference;
        }

        double standardDeviation =
            Math.Sqrt(
                varianceSum /
                values.Count
            );

        string results =
            title + "\n" +
            $"Runs: {values.Count}\n" +
            $"Mean: {mean:F2} ms\n" +
            $"Median: {median:F2} ms\n" +
            $"P95: {p95:F2} ms\n" +
            $"Min: {min:F2} ms\n" +
            $"Max: {max:F2} ms\n" +
            $"Std Dev: {standardDeviation:F2} ms";

        SetText(results);

        UnityEngine.Debug.Log(
            results
        );
    }

    // =========================================================
    // UI
    // =========================================================

    private void SetText(
        string message
    )
    {
        if (predictionText != null)
        {
            predictionText.text =
                message;
        }
    }
}