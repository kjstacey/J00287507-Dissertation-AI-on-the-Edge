using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using TMPro;
using UnityEngine;
using UnityEngine.Networking;
using UnityEngine.UI;

public class CloudCameraMNISTInference : MonoBehaviour
{
    [Header("Displays")]
    public RawImage cameraDisplay;
    public RawImage processedDisplay;
    public RawImage frozenDisplay;
    public TMP_Text predictionText;

    [Header("Cloud Run")]
    public string endpoint =
        "https://mnist-cloud-inference-221036165238.us-east1.run.app/predict";

    [Header("Preprocessing")]
    [Range(0f, 1f)]
    public float threshold = 0.5f;

    private WebCamTexture webcam;

    private Texture2D processedTexture;
    private Texture2D frozenTexture;

    private const int TargetSize = 28;
    private const int PixelCount = 784;

    private readonly float[] latestInputData =
        new float[PixelCount];

    // Cloud camera benchmarks
    private const int WarmupRuns = 2;
    private const int BenchmarkRuns = 100;

    // Live throughput
    private bool runningLiveThroughput = false;
    private bool cloudRequestInFlight = false;

    private float liveThroughputStartTime;
    private int liveFramesProcessed = 0;

    private const float LiveThroughputDuration = 10f;
    private int cameraFrameVersion = 0;
    private int lastCloudFrameVersion = -1;
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
        // -----------------------------------------------------
        // Start desktop webcam
        // -----------------------------------------------------

        WebCamDevice[] devices =
            WebCamTexture.devices;

        if (devices.Length == 0)
        {
            UnityEngine.Debug.LogError(
                "No webcam detected."
            );

            if (predictionText != null)
            {
                predictionText.text =
                    "ERROR: No webcam detected.";
            }

            return;
        }

        webcam =
            new WebCamTexture(
                devices[0].name,
                640,
                480,
                30
            );

        if (cameraDisplay != null)
        {
            cameraDisplay.texture =
                webcam;
        }

        webcam.Play();

        // -----------------------------------------------------
        // 28 x 28 processed preview
        // -----------------------------------------------------

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

        // -----------------------------------------------------
        // Frozen image preview
        // -----------------------------------------------------

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
                "Cloud camera ready.";
        }

        UnityEngine.Debug.Log(
            "Cloud camera initialized."
        );
    }

    // =========================================================
    // UPDATE
    // =========================================================

    void Update()
    {
        if (webcam == null ||
            !webcam.isPlaying)
        {
            return;
        }

        if (!webcam.didUpdateThisFrame)
        {
            return;
        }

        UpdateProcessedImage();

        cameraFrameVersion++;
    }
    // =========================================================
    // CAMERA PREPROCESSING
    // =========================================================

    private void UpdateProcessedImage()
    {
        if (webcam == null ||
            !webcam.isPlaying)
        {
            return;
        }

        Color[] sourcePixels =
            webcam.GetPixels();

        int sourceWidth =
            webcam.width;

        int sourceHeight =
            webcam.height;

        if (sourceWidth <= 16 ||
            sourceHeight <= 16)
        {
            return;
        }

        // FPGA reference coordinate space:
        // 160 x 120
        //
        // ROI:
        // x = 24..135
        // y = 4..115
        //
        // Sample every fourth reference-space pixel
        // -> 28 x 28

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
            new Color[
                TargetSize *
                TargetSize
            ];

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

                Color source =
                    sourcePixels[
                        sourceY *
                        sourceWidth +
                        sourceX
                    ];

                float gray =
                    0.299f * source.r +
                    0.587f * source.g +
                    0.114f * source.b;

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
    // CLASSIFY CURRENT FRAME
    // =========================================================

    public void ClassifyCurrentFrame()
    {
        UnityEngine.Debug.Log(
            "Cloud Classify button pressed."
        );

        if (cloudRequestInFlight)
        {
            UnityEngine.Debug.Log(
                "Cloud request already in flight."
            );

            if (predictionText != null)
            {
                predictionText.text =
                    "Cloud request already running...";
            }

            return;
        }

        if (webcam == null ||
            !webcam.isPlaying)
        {
            UnityEngine.Debug.LogError(
                "Webcam is not running."
            );

            if (predictionText != null)
            {
                predictionText.text =
                    "ERROR: Webcam is not running.";
            }

            return;
        }

        // Make sure newest frame is used.
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

        if (predictionText != null)
        {
            predictionText.text =
                "Sending image to Cloud Run...";
        }

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

        UnityEngine.Debug.Log(
            "Starting cloud camera request."
        );

        Stopwatch stopwatch =
            Stopwatch.StartNew();

        using UnityWebRequest request =
            CreateRequest(body);

        yield return request.SendWebRequest();

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
            "Cloud Camera Prediction\n" +
            $"Prediction: {predictedDigit}\n" +
            $"Round Trip: {latencyMs:F2} ms";

        if (predictionText != null)
        {
            predictionText.text =
                results;
        }

        UnityEngine.Debug.Log(
            results
        );
    }

    // =========================================================
    // FROZEN IMAGE CLOUD BENCHMARK
    // =========================================================

    public void StartFrozenBenchmark()
    {
        UnityEngine.Debug.Log(
            "Frozen cloud benchmark button pressed."
        );

        if (cloudRequestInFlight)
        {
            if (predictionText != null)
            {
                predictionText.text =
                    "Cloud request already running...";
            }

            return;
        }

        if (webcam == null ||
            !webcam.isPlaying)
        {
            if (predictionText != null)
            {
                predictionText.text =
                    "ERROR: Webcam is not running.";
            }

            return;
        }

        UpdateProcessedImage();

        StartCoroutine(
            BenchmarkFrozenImage()
        );
    }

    private IEnumerator BenchmarkFrozenImage()
    {
        cloudRequestInFlight = true;

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

        // -----------------------------------------------------
        // Warm-up requests
        // -----------------------------------------------------

        for (int i = 0;
             i < WarmupRuns;
             i++)
        {
            using UnityWebRequest warmup =
                CreateRequest(body);

            yield return
                warmup.SendWebRequest();
        }

        // -----------------------------------------------------
        // Measured requests
        // -----------------------------------------------------

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

            if (predictionText != null)
            {
                predictionText.text =
                    "Frozen Cloud Benchmark\n" +
                    $"{i + 1}/{BenchmarkRuns}";
            }
        }

        cloudRequestInFlight = false;

        DisplayStatistics(
            latencies,
            "Frozen Camera Cloud Benchmark"
        );
    }

    // =========================================================
    // END-TO-END CAMERA -> CLOUD BENCHMARK
    // =========================================================

    public void StartEndToEndBenchmark()
    {
        UnityEngine.Debug.Log(
            "End-to-end cloud benchmark button pressed."
        );

        if (cloudRequestInFlight)
        {
            if (predictionText != null)
            {
                predictionText.text =
                    "Cloud request already running...";
            }

            return;
        }

        if (webcam == null ||
            !webcam.isPlaying)
        {
            if (predictionText != null)
            {
                predictionText.text =
                    "ERROR: Webcam is not running.";
            }

            return;
        }

        StartCoroutine(
            BenchmarkEndToEndCamera()
        );
    }

    private IEnumerator BenchmarkEndToEndCamera()
    {
        cloudRequestInFlight = true;

        // -----------------------------------------------------
        // Warm-up
        // -----------------------------------------------------

        for (int i = 0;
             i < WarmupRuns;
             i++)
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

        // -----------------------------------------------------
        // Measured runs
        // -----------------------------------------------------

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

            // Included in timing:
            // webcam GetPixels
            // ROI extraction
            // grayscale
            // thresholding
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

            if (predictionText != null)
            {
                predictionText.text =
                    "End-to-End Cloud Benchmark\n" +
                    $"{run + 1}/{BenchmarkRuns}";
            }
        }

        cloudRequestInFlight = false;

        DisplayStatistics(
            latencies,
            "End-to-End Camera Cloud"
        );
    }

    // =========================================================
    // LIVE CAMERA CLOUD THROUGHPUT
    // =========================================================
    public void StartLiveThroughputTest()
    {
        if (webcam == null ||
            !webcam.isPlaying)
        {
            if (predictionText != null)
            {
                predictionText.text =
                    "ERROR: Webcam is not running.";
            }

            return;
        }

        if (runningLiveThroughput)
        {
            return;
        }

        liveFramesProcessed = 0;

        liveThroughputStartTime =
            Time.realtimeSinceStartup;

        lastCloudFrameVersion = -1;

        runningLiveThroughput = true;

        if (predictionText != null)
        {
            predictionText.text =
                "Live cloud throughput running...";
        }

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

            if (elapsed >= LiveThroughputDuration)
            {
                break;
            }

            // Wait until the camera has supplied
            // a frame we have not already sent.
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
                    $"Live cloud request {liveFramesProcessed}: " +
                    $"{stopwatch.Elapsed.TotalMilliseconds:F2} ms"
                );
            }
            else
            {
                UnityEngine.Debug.LogError(
                    $"Live cloud request failed: " +
                    $"{request.error}"
                );
            }
        }

        runningLiveThroughput = false;

        FinishLiveThroughputTest();
    }

    private void FinishLiveThroughputTest()
    {
        runningLiveThroughput =
            false;

        float elapsed =
            Time.realtimeSinceStartup -
            liveThroughputStartTime;

        float throughput =
            elapsed > 0f
                ? liveFramesProcessed /
                  elapsed
                : 0f;

        string results =
            "Live Camera Cloud Throughput\n" +
            $"Completed requests: {liveFramesProcessed}\n" +
            $"Time: {elapsed:F2} s\n" +
            $"Throughput: {throughput:F2} predictions/s";

        if (predictionText != null)
        {
            predictionText.text =
                results;
        }

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
                "Cloud request failed\n" +
                $"HTTP: {request.responseCode}\n" +
                $"Error: {request.error}";

            if (predictionText != null)
            {
                predictionText.text =
                    error;
            }

            UnityEngine.Debug.LogError(
                error
            );

            return false;
        }

        string responseText =
            request.downloadHandler.text;

        UnityEngine.Debug.Log(
            "Cloud response: " +
            responseText
        );

        PredictionResponse response =
            JsonUtility.FromJson<PredictionResponse>(
                responseText
            );

        if (response == null)
        {
            if (predictionText != null)
            {
                predictionText.text =
                    "ERROR: Could not parse cloud response.";
            }

            return false;
        }

        prediction =
            response.prediction;

        return true;
    }

    // =========================================================
    // IMAGE CONVERSION
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
        {
            return;
        }

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
            if (predictionText != null)
            {
                predictionText.text =
                    title +
                    "\nNo successful requests.";
            }

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

        for (int i = 0;
             i < values.Count;
             i++)
        {
            double difference =
                values[i] -
                mean;

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

        if (predictionText != null)
        {
            predictionText.text =
                results;
        }

        UnityEngine.Debug.Log(
            results
        );
    }

    // =========================================================
    // CLEANUP
    // =========================================================

    void OnDestroy()
    {
        if (webcam != null &&
            webcam.isPlaying)
        {
            webcam.Stop();
        }
    }
}