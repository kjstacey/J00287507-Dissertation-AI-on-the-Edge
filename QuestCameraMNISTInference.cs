using Meta.XR;
using TMPro;
using Unity.Collections;
using Unity.InferenceEngine;
using UnityEngine;
using UnityEngine.UI;

public class QuestCameraMNISTInference : MonoBehaviour
{
    [Header("Quest Camera")]
    public PassthroughCameraAccess cameraAccess;

    [Header("Displays")]
    public RawImage cameraDisplay;
    public RawImage processedDisplay;
    public RawImage frozenDisplay;
    public TMP_Text predictionText;

    [Header("Model")]
    public ModelAsset modelAsset;

    [Header("Buttons")]
    public Button classifyButton;
    public Button benchmarkButton;
    public Button endToEndBenchmarkButton;
    public Button liveThroughputButton;

    [Header("Preprocessing")]
    [Range(0f, 1f)]
    public float threshold = 0.5f;

    private Model runtimeModel;
    private Worker worker;

    private const int TargetSize = 28;

    private Texture2D processedTexture;
    private Texture2D frozenTexture;

    private readonly float[] latestInputData =
        new float[TargetSize * TargetSize];

    private bool runningLiveThroughput = false;
    private float liveThroughputStartTime;
    private int liveFramesProcessed = 0;

    private const float LiveThroughputDuration = 10f;

    private const int WarmupRuns = 50;
    private const int BenchmarkRuns = 1000;

    private System.DateTime previousCameraTimestamp;

    void Start()
    {
        runtimeModel = ModelLoader.Load(modelAsset);

        worker =
            new Worker(
                runtimeModel,
                BackendType.GPUCompute
            );

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

        if (classifyButton != null)
        {
            classifyButton.onClick.AddListener(
                ClassifyCurrentFrame
            );
        }

        if (benchmarkButton != null)
        {
            benchmarkButton.onClick.AddListener(
                BenchmarkFrozenImage
            );
        }

        if (endToEndBenchmarkButton != null)
        {
            endToEndBenchmarkButton.onClick.AddListener(
                BenchmarkEndToEndCamera
            );
        }

        if (liveThroughputButton != null)
        {
            liveThroughputButton.onClick.AddListener(
                StartLiveThroughputTest
            );
        }
    }

    void Update()
    {
        if (cameraAccess == null)
            return;

        if (!cameraAccess.IsPlaying)
            return;

        // Display live Quest RGB camera texture.
        Texture cameraTexture =
            cameraAccess.GetTexture();

        if (cameraDisplay != null &&
            cameraTexture != null)
        {
            cameraDisplay.texture =
                cameraTexture;
        }

        // Only process when Quest has produced
        // a new camera frame.
        if (!cameraAccess.IsUpdatedThisFrame)
            return;

        UpdateProcessedImage();

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
                    liveFramesProcessed /
                    elapsed;

                string results =
                    "Quest Live Camera GPU Throughput\n" +
                    $"Frames: {liveFramesProcessed}\n" +
                    $"Time: {elapsed:F2} s\n" +
                    $"Throughput: {throughput:F2} predictions/s";

                UnityEngine.Debug.Log(results);

                if (predictionText != null)
                {
                    predictionText.text =
                        results;
                }
            }
        }
    }

    private void UpdateProcessedImage()
    {
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

        // ----------------------------------------------------
        // FPGA source coordinate space:
        // 160 x 120
        //
        // ROI:
        // x = 24..135
        // y = 4..115
        //
        // Sample every 4 FPGA pixels
        // -> 28 x 28
        // ----------------------------------------------------

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

    public void ClassifyCurrentFrame()
    {
        float[] frozenInput =
            new float[
                latestInputData.Length
            ];

        latestInputData.CopyTo(
            frozenInput,
            0
        );

        Color[] frozenPixels =
            new Color[
                TargetSize *
                TargetSize
            ];

        for (int i = 0;
             i < frozenInput.Length;
             i++)
        {
            float value =
                frozenInput[i];

            frozenPixels[i] =
                new Color(
                    value,
                    value,
                    value,
                    1f
                );
        }

        frozenTexture.SetPixels(
            frozenPixels
        );

        frozenTexture.Apply();

        using Tensor<float> inputTensor =
            new Tensor<float>(
                new TensorShape(
                    1,
                    784
                ),
                frozenInput
            );

        System.Diagnostics.Stopwatch stopwatch =
            System.Diagnostics.Stopwatch.StartNew();

        worker.Schedule(
            inputTensor
        );

        using Tensor<float> outputTensor =
            worker
                .PeekOutput()
                .ReadbackAndClone()
                as Tensor<float>;

        stopwatch.Stop();

        double latencyMs =
            stopwatch.Elapsed
                .TotalMilliseconds;

        int predictedDigit = 0;

        float bestValue =
            float.MinValue;

        for (int i = 0;
             i < 10;
             i++)
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

        if (predictionText != null)
        {
            predictionText.text =
                "Quest Prediction: " +
                predictedDigit +
                "\nLatency: " +
                latencyMs.ToString("F4") +
                " ms";
        }

        UnityEngine.Debug.Log(
            $"Quest frozen camera prediction: {predictedDigit} | " +
            $"Inference latency: {latencyMs:F6} ms"
        );
    }

    public void BenchmarkFrozenImage()
    {
        float[] frozenInput =
            new float[
                latestInputData.Length
            ];

        latestInputData.CopyTo(
            frozenInput,
            0
        );

        using Tensor<float> inputTensor =
            new Tensor<float>(
                new TensorShape(
                    1,
                    784
                ),
                frozenInput
            );

        // -------------------------
        // Warm-up
        // -------------------------

        for (int i = 0;
             i < WarmupRuns;
             i++)
        {
            worker.Schedule(
                inputTensor
            );

            using Tensor<float> warmupOutput =
                worker
                    .PeekOutput()
                    .ReadbackAndClone()
                    as Tensor<float>;
        }

        // -------------------------
        // Timed runs
        // -------------------------

        double[] latencyValues =
            new double[
                BenchmarkRuns
            ];

        for (int i = 0;
             i < BenchmarkRuns;
             i++)
        {
            System.Diagnostics.Stopwatch stopwatch =
                System.Diagnostics.Stopwatch.StartNew();

            worker.Schedule(
                inputTensor
            );

            using Tensor<float> outputTensor =
                worker
                    .PeekOutput()
                    .ReadbackAndClone()
                    as Tensor<float>;

            stopwatch.Stop();

            latencyValues[i] =
                stopwatch.Elapsed
                    .TotalMilliseconds;
        }

        CalculateAndDisplayStatistics(
            latencyValues,
            "Quest Frozen Camera GPU Benchmark"
        );
    }

    public void BenchmarkEndToEndCamera()
    {
        if (cameraAccess == null ||
            !cameraAccess.IsPlaying)
        {
            return;
        }

        const int warmupRuns = 50;

        const int benchmarkRuns =
            1000;

        double[] latencyValues =
            new double[
                benchmarkRuns
            ];

        // -------------------------
        // Warm-up
        // -------------------------

        for (int run = 0;
             run < warmupRuns;
             run++)
        {
            RunCameraPipelineOnce();
        }

        // -------------------------
        // Measured runs
        // -------------------------

        for (int run = 0;
             run < benchmarkRuns;
             run++)
        {
            System.Diagnostics.Stopwatch stopwatch =
                System.Diagnostics.Stopwatch.StartNew();

            RunCameraPipelineOnce();

            stopwatch.Stop();

            latencyValues[run] =
                stopwatch.Elapsed
                    .TotalMilliseconds;
        }

        CalculateAndDisplayStatistics(
            latencyValues,
            "Quest End-to-End Camera GPU Benchmark"
        );
    }

    private int RunCameraPipelineOnce()
    {
        NativeArray<Color32> sourcePixels =
            cameraAccess.GetColors();

        Vector2Int resolution =
            cameraAccess.CurrentResolution;

        int sourceWidth =
            resolution.x;

        int sourceHeight =
            resolution.y;

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
            new float[
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
                        x *
                        sampleStepX
                    );

                int sourceY =
                    Mathf.RoundToInt(
                        roiStartY +
                        y *
                        sampleStepY
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

                inputData[index] =
                    gray;
            }
        }

        using Tensor<float> inputTensor =
            new Tensor<float>(
                new TensorShape(
                    1,
                    784
                ),
                inputData
            );

        worker.Schedule(
            inputTensor
        );

        using Tensor<float> outputTensor =
            worker
                .PeekOutput()
                .ReadbackAndClone()
                as Tensor<float>;

        int predictedDigit = 0;

        float bestValue =
            float.MinValue;

        for (int i = 0;
             i < 10;
             i++)
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
        if (cameraAccess == null ||
            !cameraAccess.IsPlaying)
        {
            return;
        }

        liveFramesProcessed = 0;

        liveThroughputStartTime =
            Time.realtimeSinceStartup;

        runningLiveThroughput =
            true;

        if (predictionText != null)
        {
            predictionText.text =
                "Quest live throughput test running...";
        }
    }

    private void CalculateAndDisplayStatistics(
        double[] latencyValues,
        string benchmarkName
    )
    {
        System.Array.Sort(
            latencyValues
        );

        double sum = 0.0;

        for (int i = 0;
             i < latencyValues.Length;
             i++)
        {
            sum += latencyValues[i];
        }

        double mean =
            sum /
            latencyValues.Length;

        double median;

        if (latencyValues.Length % 2 == 0)
        {
            int middle =
                latencyValues.Length / 2;

            median =
                (
                    latencyValues[
                        middle - 1
                    ] +
                    latencyValues[
                        middle
                    ]
                ) / 2.0;
        }
        else
        {
            median =
                latencyValues[
                    latencyValues.Length /
                    2
                ];
        }

        int p95Index =
            Mathf.CeilToInt(
                latencyValues.Length *
                0.95f
            ) - 1;

        double p95 =
            latencyValues[
                p95Index
            ];

        double min =
            latencyValues[0];

        double max =
            latencyValues[
                latencyValues.Length -
                1
            ];

        double varianceSum =
            0.0;

        for (int i = 0;
             i < latencyValues.Length;
             i++)
        {
            double difference =
                latencyValues[i] -
                mean;

            varianceSum +=
                difference *
                difference;
        }

        double standardDeviation =
            System.Math.Sqrt(
                varianceSum /
                latencyValues.Length
            );

        string results =
            benchmarkName + "\n" +
            $"Warm-up: {WarmupRuns}\n" +
            $"Runs: {latencyValues.Length}\n" +
            $"Mean: {mean:F6} ms\n" +
            $"Median: {median:F6} ms\n" +
            $"P95: {p95:F6} ms\n" +
            $"Min: {min:F6} ms\n" +
            $"Max: {max:F6} ms\n" +
            $"Std Dev: {standardDeviation:F6} ms";

        UnityEngine.Debug.Log(
            results
        );

        if (predictionText != null)
        {
            predictionText.text =
                benchmarkName + "\n" +
                $"Mean: {mean:F4} ms\n" +
                $"Median: {median:F4} ms\n" +
                $"P95: {p95:F4} ms";
        }
    }

    void OnDestroy()
    {
        if (classifyButton != null)
        {
            classifyButton.onClick.RemoveListener(
                ClassifyCurrentFrame
            );
        }

        if (benchmarkButton != null)
        {
            benchmarkButton.onClick.RemoveListener(
                BenchmarkFrozenImage
            );
        }

        if (endToEndBenchmarkButton != null)
        {
            endToEndBenchmarkButton.onClick.RemoveListener(
                BenchmarkEndToEndCamera
            );
        }

        if (liveThroughputButton != null)
        {
            liveThroughputButton.onClick.RemoveListener(
                StartLiveThroughputTest
            );
        }

        worker?.Dispose();
    }
}