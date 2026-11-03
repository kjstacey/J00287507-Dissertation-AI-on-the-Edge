using System;
using TMPro;
using Unity.InferenceEngine;
using UnityEngine;

public class MNISTAccuracyTest : MonoBehaviour
{
    public ModelAsset modelAsset;
    public TextAsset imagesFile;
    public TextAsset labelsFile;

    [Header("Quest UI")]
    public TMP_Text resultText;

    private Model runtimeModel;
    private Worker worker;

    void Start()
    {
        if (resultText != null)
        {
            resultText.text += "Running Quest GPU accuracy test...\n";
        }

        runtimeModel = ModelLoader.Load(modelAsset);
        worker = new Worker(runtimeModel, BackendType.GPUCompute);

        byte[] imageBytes = imagesFile.bytes;
        byte[] labelBytes = labelsFile.bytes;

        const int imageCount = 10000;
        const int pixelsPerImage = 784;
        const int bytesPerFloat = 4;

        int expectedImageBytes =
            imageCount * pixelsPerImage * bytesPerFloat;

        if (imageBytes.Length != expectedImageBytes)
        {
            string errorMessage =
                $"Unexpected image file size.\n" +
                $"Expected: {expectedImageBytes} bytes\n" +
                $"Found: {imageBytes.Length} bytes";

            UnityEngine.Debug.LogError(errorMessage);

            if (resultText != null)
            {
                resultText.text += errorMessage;
            }

            return;
        }

        if (labelBytes.Length != imageCount)
        {
            string errorMessage =
                $"Unexpected label file size.\n" +
                $"Expected: {imageCount} bytes\n" +
                $"Found: {labelBytes.Length} bytes";

            UnityEngine.Debug.LogError(errorMessage);

            if (resultText != null)
            {
                resultText.text += errorMessage;
            }

            return;
        }

        int correct = 0;

        float[] inputData = new float[pixelsPerImage];

        for (int imageIndex = 0; imageIndex < imageCount; imageIndex++)
        {
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

            int expectedDigit = labelBytes[imageIndex];

            if (predictedDigit == expectedDigit)
            {
                correct++;
            }
        }

        float accuracy =
            (float)correct / imageCount * 100f;

        string results =
            "Quest 3 GPU Accuracy\n\n" +
            $"Correct: {correct} / {imageCount}\n" +
            $"Accuracy: {accuracy:F2}%";

        UnityEngine.Debug.Log(results);

        if (resultText != null)
        {
            resultText.text += results + "\n\n";
        }
    }

    void OnDestroy()
    {
        worker?.Dispose();
    }
}