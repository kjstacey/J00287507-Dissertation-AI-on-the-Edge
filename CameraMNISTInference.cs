using Unity.InferenceEngine;
using UnityEngine;
using UnityEngine.UI;
using static System.Net.Mime.MediaTypeNames;
using TMPro;
using System.Diagnostics;

public class CameraMNISTInference : MonoBehaviour
{
    public RawImage cameraDisplay;
    public RawImage processedDisplay;
    public TMP_Text predictionText;
    public ModelAsset modelAsset;

    private WebCamTexture webcam;
    private Texture2D processedTexture;

    private Model runtimeModel;
    private Worker worker;

    private const int TargetSize = 28;
    public RawImage frozenDisplay;
    public Button classifyButton;

    private Texture2D frozenTexture;
    private float[] latestInputData = new float[784];
    [Range(0f, 1f)]
    public float threshold = 0.5f;
    public Button benchmarkButton;
    public Button endToEndBenchmarkButton;
    public Button liveThroughputButton;

    private bool runningLiveThroughput = false;
    private float liveThroughputStartTime;
    private int liveFramesProcessed = 0;
    private const float LiveThroughputDuration = 10f;

    private const int WarmupRuns = 50;
    private const int BenchmarkRuns = 1000;

    void Start()
    {
        if (benchmarkButton != null)
            benchmarkButton.onClick.AddListener(BenchmarkFrozenImage);
        if (endToEndBenchmarkButton != null)
            endToEndBenchmarkButton.onClick.AddListener(BenchmarkEndToEndCamera);
        if (liveThroughputButton != null)
            liveThroughputButton.onClick.AddListener(StartLiveThroughputTest);
        // Load model
        runtimeModel = ModelLoader.Load(modelAsset);
        // worker = new Worker(runtimeModel, BackendType.CPU);  //this runs from the CPU
        worker = new Worker(runtimeModel, BackendType.CPU);  //this runs from the CPU
        // Start camera
        WebCamDevice[] devices = WebCamTexture.devices;

        if (devices.Length == 0)
        {
            UnityEngine.Debug.LogError("No webcam detected.");
            return;
        }

        webcam = new WebCamTexture(
            devices[0].name,
            640,
            480,
            30
        );

        cameraDisplay.texture = webcam;
        webcam.Play();

        // 28x28 preview texture
        processedTexture = new Texture2D(
            TargetSize,
            TargetSize,
            TextureFormat.RGB24,
            false
        );

        processedTexture.filterMode = FilterMode.Point;
        processedDisplay.texture = processedTexture;
        frozenTexture = new Texture2D(
    TargetSize,
    TargetSize,
    TextureFormat.RGB24,
    false
);

        frozenTexture.filterMode = FilterMode.Point;

        if (frozenDisplay != null)
            frozenDisplay.texture = frozenTexture;

        if (classifyButton != null)
            classifyButton.onClick.AddListener(ClassifyCurrentFrame);
    }

    void Update()
    {
       // if (Input.GetKeyDown(KeyCode.Escape))
       // {
       //     UnityEngine.Application.Quit();
       // }
        if (webcam == null || !webcam.isPlaying)
            return;

        if (!webcam.didUpdateThisFrame)
            return;
        if (runningLiveThroughput)
        {
            RunCameraPipelineOnce();

            liveFramesProcessed++;

            float elapsed =
                Time.realtimeSinceStartup -
                liveThroughputStartTime;

            if (elapsed >= LiveThroughputDuration)
            {
                runningLiveThroughput = false;

                float throughput =
                    liveFramesProcessed / elapsed;

                UnityEngine.Debug.Log(
                    "Live Camera CPU Throughput\n" +
                    $"Processed unique frames: {liveFramesProcessed}\n" +
                    $"Elapsed time: {elapsed:F4} s\n" +
                    $"Throughput: {throughput:F4} predictions/s"
                );

                if (predictionText != null)
                {
                    predictionText.text =
                        "Live Camera CPU Throughput\n" +
                        $"Frames: {liveFramesProcessed}\n" +
                        $"Time: {elapsed:F2} s\n" +
                        $"Throughput: {throughput:F2} predictions/s";
                }
            }
        }

        Color[] sourcePixels = webcam.GetPixels();

        int sourceWidth = webcam.width;
        int sourceHeight = webcam.height;

        if (sourceWidth <= 16 || sourceHeight <= 16)
            return;

        // FPGA source coordinate space: 160 x 120
        // ROI: x = 24..135, y = 4..115
        // Sample every 4 pixels.

        float xScale = sourceWidth / 160f;
        float yScale = sourceHeight / 120f;

        int roiStartX =
            Mathf.RoundToInt(24f * xScale);

        int roiStartY =
            Mathf.RoundToInt(4f * yScale);

        float sampleStepX =
            4f * xScale;

        float sampleStepY =
            4f * yScale;

        Color[] outputPixels =
            new Color[TargetSize * TargetSize];

        for (int y = 0; y < TargetSize; y++)
        {
            for (int x = 0; x < TargetSize; x++)
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

                sourceX = Mathf.Clamp(
                    sourceX,
                    0,
                    sourceWidth - 1
                );

                sourceY = Mathf.Clamp(
                    sourceY,
                    0,
                    sourceHeight - 1
                );

                Color source =
                    sourcePixels[
                        sourceY * sourceWidth +
                        sourceX
                    ];

                float gray =
                    0.299f * source.r +
                    0.587f * source.g +
                    0.114f * source.b;

                gray =
                    gray < threshold ? 0f : 1f;

                int index =
                    y * TargetSize + x;

                latestInputData[index] = gray;

                outputPixels[index] =
                    new Color(
                        gray,
                        gray,
                        gray,
                        1f
                    );
            }
        }

        processedTexture.SetPixels(outputPixels);
        processedTexture.Apply();
    }
        public void ClassifyCurrentFrame()
    {
        float[] frozenInput =
            new float[latestInputData.Length];

        latestInputData.CopyTo(
            frozenInput,
            0
        );

        // ----------------------------------------------------
        // Show exactly what is being classified
        // ----------------------------------------------------

        Color[] frozenPixels =
            new Color[TargetSize * TargetSize];

        for (int i = 0; i < frozenInput.Length; i++)
        {
            float value = frozenInput[i];

            frozenPixels[i] =
                new Color(
                    value,
                    value,
                    value,
                    1f
                );
        }

        frozenTexture.SetPixels(frozenPixels);
        frozenTexture.Apply();

        // ----------------------------------------------------
        // Create tensor from the frozen 28 x 28 image
        // Tensor creation is NOT included in inference timing.
        // ----------------------------------------------------

        using Tensor<float> inputTensor =
            new Tensor<float>(
                new TensorShape(1, 784),
                frozenInput
            );

        // ----------------------------------------------------
        // Measure inference latency
        //
        // Timing begins immediately before scheduling the
        // neural network and ends after the output has been
        // synchronously read back.
        // ----------------------------------------------------

        System.Diagnostics.Stopwatch stopwatch =
            System.Diagnostics.Stopwatch.StartNew();

        worker.Schedule(inputTensor);

        using Tensor<float> outputTensor =
            worker.PeekOutput()
                  .ReadbackAndClone()
                  as Tensor<float>;

        stopwatch.Stop();

        double latencyMs =
            stopwatch.Elapsed.TotalMilliseconds;

        // ----------------------------------------------------
        // Determine predicted digit
        // ----------------------------------------------------

        int predictedDigit = 0;
        float bestValue = float.MinValue;

        for (int i = 0; i < 10; i++)
        {
            float value = outputTensor[i];

            if (value > bestValue)
            {
                bestValue = value;
                predictedDigit = i;
            }
        }

        // ----------------------------------------------------
        // Display prediction
        // ----------------------------------------------------

        if (predictionText != null)
        {
            predictionText.text =
                "Prediction: " +
                predictedDigit +
                "\nLatency: " +
                latencyMs.ToString("F4") +
                " ms";
        }

        // Also write the measurement to the Unity Console.
        UnityEngine.Debug.Log(
            $"Frozen camera prediction: {predictedDigit} | " +
            $"Inference latency: {latencyMs:F6} ms"
        );
    }


    void OnDestroy()
    {
        if (classifyButton != null)
            classifyButton.onClick.RemoveListener(ClassifyCurrentFrame);
        if (benchmarkButton != null)
            benchmarkButton.onClick.RemoveListener(BenchmarkFrozenImage);
        if (webcam != null && webcam.isPlaying)
            webcam.Stop();
        if (endToEndBenchmarkButton != null)
        {
            endToEndBenchmarkButton.onClick.RemoveListener(
                BenchmarkEndToEndCamera
            );
        }
        if (liveThroughputButton != null)
            liveThroughputButton.onClick.RemoveListener(
                StartLiveThroughputTest
            );

        worker?.Dispose();
    }
    public void BenchmarkFrozenImage()
    {
        float[] frozenInput =
            new float[latestInputData.Length];

        latestInputData.CopyTo(
            frozenInput,
            0
        );

        using Tensor<float> inputTensor =
            new Tensor<float>(
                new TensorShape(1, 784),
                frozenInput
            );

        // ----------------------------------------------------
        // Warm-up
        // ----------------------------------------------------

        for (int i = 0; i < WarmupRuns; i++)
        {
            worker.Schedule(inputTensor);

            using Tensor<float> warmupOutput =
                worker.PeekOutput()
                      .ReadbackAndClone()
                      as Tensor<float>;
        }

        // ----------------------------------------------------
        // Timed runs
        // ----------------------------------------------------

        double[] latencyValues =
            new double[BenchmarkRuns];

        for (int i = 0; i < BenchmarkRuns; i++)
        {
            System.Diagnostics.Stopwatch stopwatch =
                System.Diagnostics.Stopwatch.StartNew();

            worker.Schedule(inputTensor);

            using Tensor<float> outputTensor =
                worker.PeekOutput()
                      .ReadbackAndClone()
                      as Tensor<float>;

            stopwatch.Stop();

            latencyValues[i] =
                stopwatch.Elapsed.TotalMilliseconds;
        }

        // ----------------------------------------------------
        // Statistics
        // ----------------------------------------------------

        System.Array.Sort(latencyValues);

        double sum = 0.0;

        for (int i = 0; i < latencyValues.Length; i++)
        {
            sum += latencyValues[i];
        }

        double mean =
            sum / latencyValues.Length;

        double median;

        if (latencyValues.Length % 2 == 0)
        {
            int middle =
                latencyValues.Length / 2;

            median =
                (
                    latencyValues[middle - 1] +
                    latencyValues[middle]
                ) / 2.0;
        }
        else
        {
            median =
                latencyValues[
                    latencyValues.Length / 2
                ];
        }

        int p95Index =
            Mathf.CeilToInt(
                latencyValues.Length * 0.95f
            ) - 1;

        double p95 =
            latencyValues[p95Index];

        double min =
            latencyValues[0];

        double max =
            latencyValues[
                latencyValues.Length - 1
            ];

        // Standard deviation
        double varianceSum = 0.0;

        for (int i = 0; i < latencyValues.Length; i++)
        {
            double difference =
                latencyValues[i] - mean;

            varianceSum +=
                difference * difference;
        }

        double standardDeviation =
            System.Math.Sqrt(
                varianceSum /
                latencyValues.Length
            );

        // ----------------------------------------------------
        // Display results
        // ----------------------------------------------------

        UnityEngine.Debug.Log(
            "Frozen Camera CPU Benchmark\n" +
            $"Warm-up runs: {WarmupRuns}\n" +
            $"Measured runs: {BenchmarkRuns}\n" +
            $"Mean: {mean:F6} ms\n" +
            $"Median: {median:F6} ms\n" +
            $"P95: {p95:F6} ms\n" +
            $"Min: {min:F6} ms\n" +
            $"Max: {max:F6} ms\n" +
            $"Std Dev: {standardDeviation:F6} ms"
        );

        if (predictionText != null)
        {
            predictionText.text =
                "Frozen Camera CPU Benchmark\n" +
                $"Mean: {mean:F4} ms\n" +
                $"Median: {median:F4} ms\n" +
                $"P95: {p95:F4} ms";
        }
    }
    public void BenchmarkEndToEndCamera()
    {
        if (webcam == null || !webcam.isPlaying)
            return;

        const int warmupRuns = 50;
        const int benchmarkRuns = 1000;

        double[] latencyValues =
            new double[benchmarkRuns];

        // ----------------------------------------------------
        // Warm-up
        // ----------------------------------------------------

        for (int run = 0; run < warmupRuns; run++)
        {
            RunCameraPipelineOnce();
        }

        // ----------------------------------------------------
        // Measured runs
        // ----------------------------------------------------

        for (int run = 0; run < benchmarkRuns; run++)
        {
            System.Diagnostics.Stopwatch stopwatch =
                System.Diagnostics.Stopwatch.StartNew();

            RunCameraPipelineOnce();

            stopwatch.Stop();

            latencyValues[run] =
                stopwatch.Elapsed.TotalMilliseconds;
        }

        // ----------------------------------------------------
        // Statistics
        // ----------------------------------------------------

        System.Array.Sort(latencyValues);

        double sum = 0.0;

        for (int i = 0; i < latencyValues.Length; i++)
            sum += latencyValues[i];

        double mean =
            sum / latencyValues.Length;

        double median =
            (
                latencyValues[499] +
                latencyValues[500]
            ) / 2.0;

        int p95Index =
            Mathf.CeilToInt(
                latencyValues.Length * 0.95f
            ) - 1;

        double p95 =
            latencyValues[p95Index];

        double min =
            latencyValues[0];

        double max =
            latencyValues[
                latencyValues.Length - 1
            ];

        double varianceSum = 0.0;

        for (int i = 0; i < latencyValues.Length; i++)
        {
            double difference =
                latencyValues[i] - mean;

            varianceSum +=
                difference * difference;
        }

        double standardDeviation =
            System.Math.Sqrt(
                varianceSum /
                latencyValues.Length
            );

        UnityEngine.Debug.Log(
            "End-to-End Camera CPU Benchmark\n" +
            $"Warm-up runs: {warmupRuns}\n" +
            $"Measured runs: {benchmarkRuns}\n" +
            $"Mean: {mean:F6} ms\n" +
            $"Median: {median:F6} ms\n" +
            $"P95: {p95:F6} ms\n" +
            $"Min: {min:F6} ms\n" +
            $"Max: {max:F6} ms\n" +
            $"Std Dev: {standardDeviation:F6} ms"
        );

        if (predictionText != null)
        {
            predictionText.text =
                "End-to-End Camera CPU\n" +
                $"Mean: {mean:F4} ms\n" +
                $"Median: {median:F4} ms\n" +
                $"P95: {p95:F4} ms";
        }
    }
    private int RunCameraPipelineOnce()
    {
        Color[] sourcePixels =
            webcam.GetPixels();

        int sourceWidth =
            webcam.width;

        int sourceHeight =
            webcam.height;

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

        float[] inputData =
            new float[TargetSize * TargetSize];

        for (int y = 0; y < TargetSize; y++)
        {
            for (int x = 0; x < TargetSize; x++)
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
                        sourceY * sourceWidth +
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
                    y * TargetSize + x;

                inputData[index] =
                    gray;
            }
        }

        using Tensor<float> inputTensor =
            new Tensor<float>(
                new TensorShape(1, 784),
                inputData
            );

        worker.Schedule(inputTensor);

        using Tensor<float> outputTensor =
            worker.PeekOutput()
                  .ReadbackAndClone()
                  as Tensor<float>;

        int predictedDigit = 0;
        float bestValue =
            float.MinValue;

        for (int i = 0; i < 10; i++)
        {
            float value =
                outputTensor[i];

            if (value > bestValue)
            {
                bestValue =
                    value;

                predictedDigit =
                    i;
            }
        }

        return predictedDigit;
    }
    public void StartLiveThroughputTest()
    {
        if (webcam == null || !webcam.isPlaying)
            return;

        liveFramesProcessed = 0;
        liveThroughputStartTime = Time.realtimeSinceStartup;
        runningLiveThroughput = true;

        if (predictionText != null)
        {
            predictionText.text =
                "Live throughput test running...";
        }
    }
}