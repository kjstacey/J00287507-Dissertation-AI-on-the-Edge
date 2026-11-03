using System;
using System.Collections;
using TMPro;
using Unity.InferenceEngine;
using UnityEngine;

public class MNISTSustainedInference : MonoBehaviour
{
    public ModelAsset modelAsset;
    public TextAsset imagesFile;

    [Header("Quest UI")]
    public TMP_Text statusText;

    private Model runtimeModel;
    private Worker worker;

    private const int PixelsPerImage = 784;
    private const int BytesPerFloat = 4;
    private const int ImageCount = 10000;

    private bool isRunning = false;
    private Coroutine sustainedCoroutine;

    private byte[] imageBytes;
    private float[] inputData;

    void Start()
    {
        runtimeModel = ModelLoader.Load(modelAsset);
        worker = new Worker(runtimeModel, BackendType.GPUCompute);

        imageBytes = imagesFile.bytes;
        inputData = new float[PixelsPerImage];

        if (statusText != null)
        {
            statusText.text += "Sustained GPU: Ready\n\n";
        }

        UnityEngine.Debug.Log("Sustained GPU inference ready.");
    }

    // Assign this method to the Quest UI button.
    public void ToggleSustainedInference()
    {
        if (!isRunning)
        {
            StartSustainedInference();
        }
        else
        {
            StopSustainedInference();
        }
    }

    public void StartSustainedInference()
    {
        if (isRunning)
            return;

        isRunning = true;

        sustainedCoroutine =
            StartCoroutine(RunSustainedInference());

        if (statusText != null)
        {
            statusText.text =
                "Sustained GPU: RUNNING";
        }

        UnityEngine.Debug.Log(
            "Sustained GPU inference started."
        );
    }

    public void StopSustainedInference()
    {
        if (!isRunning)
            return;

        isRunning = false;

        if (statusText != null)
        {
            statusText.text =
                "Sustained GPU: Stopping...";
        }

        UnityEngine.Debug.Log(
            "Sustained GPU inference stop requested."
        );
    }

    IEnumerator RunSustainedInference()
    {
        double startTime =
            Time.realtimeSinceStartupAsDouble;

        int inferenceCount = 0;

        while (isRunning)
        {
            int imageIndex =
                inferenceCount % ImageCount;

            int byteOffset =
                imageIndex *
                PixelsPerImage *
                BytesPerFloat;

            for (int pixel = 0;
                 pixel < PixelsPerImage;
                 pixel++)
            {
                inputData[pixel] =
                    BitConverter.ToSingle(
                        imageBytes,
                        byteOffset +
                        pixel * BytesPerFloat
                    );
            }

            using Tensor<float> inputTensor =
                new Tensor<float>(
                    new TensorShape(
                        1,
                        PixelsPerImage
                    ),
                    inputData
                );

            worker.Schedule(inputTensor);

            using Tensor<float> outputTensor =
                worker
                    .PeekOutput()
                    .ReadbackAndClone()
                    as Tensor<float>;

            inferenceCount++;

            // Keep Quest/Unity responsive.
            if (inferenceCount % 100 == 0)
            {
                double elapsed =
                    Time.realtimeSinceStartupAsDouble -
                    startTime;

                if (statusText != null)
                {
                    statusText.text =
                        "Sustained GPU: RUNNING\n" +
                        $"Inferences: {inferenceCount}\n" +
                        $"Elapsed: {elapsed:F1} s";
                }

                yield return null;
            }
        }

        double totalElapsed =
            Time.realtimeSinceStartupAsDouble -
            startTime;

        double throughput =
            totalElapsed > 0
                ? inferenceCount / totalElapsed
                : 0.0;

        string results =
            "Sustained GPU: STOPPED\n" +
            $"Inferences: {inferenceCount}\n" +
            $"Elapsed: {totalElapsed:F2} s\n" +
            $"Rate: {throughput:F2} img/s";

        if (statusText != null)
        {
            statusText.text = results + "\n\n";
        }

        UnityEngine.Debug.Log(results);

        sustainedCoroutine = null;
    }

    void OnDestroy()
    {
        if (sustainedCoroutine != null)
        {
            StopCoroutine(sustainedCoroutine);
        }

        worker?.Dispose();
    }
}