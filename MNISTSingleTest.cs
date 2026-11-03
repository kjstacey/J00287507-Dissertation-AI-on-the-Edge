using System;
//using System.Diagnostics;
using Unity.InferenceEngine;
using UnityEngine;

public class MNISTSingleTest : MonoBehaviour
{
    public ModelAsset modelAsset;
    public TextAsset testDataFile;

    private Model runtimeModel;
    private Worker worker;

    void Start()
    {
        runtimeModel = ModelLoader.Load(modelAsset);
        worker = new Worker(runtimeModel, BackendType.CPU);
        //worker = new Worker(runtimeModel, BackendType.CPU);

        string[] lines = testDataFile.text.Split(
            new[] { '\n', '\r' },
            StringSplitOptions.RemoveEmptyEntries
        );

        int expectedDigit = int.Parse(lines[0]);

        string[] pixelStrings = lines[1].Split(',');

        if (pixelStrings.Length != 784)
        {
            Debug.LogError(
                "Expected 784 pixels but found " + pixelStrings.Length
            );
            return;
        }

        float[] inputData = new float[784];

        for (int i = 0; i < 784; i++)
        {
            inputData[i] = float.Parse(
                pixelStrings[i],
                System.Globalization.CultureInfo.InvariantCulture
            );
        }

        using Tensor<float> inputTensor =
            new Tensor<float>(
                new TensorShape(1, 784),
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

            Debug.Log("Output " + i + ": " + value);

            if (value > bestValue)
            {
                bestValue = value;
                predictedDigit = i;
            }
        }

        Debug.Log("Expected digit: " + expectedDigit);
        Debug.Log("Predicted digit: " + predictedDigit);

        if (predictedDigit == expectedDigit)
        {
            Debug.Log("SUCCESS: Prediction is correct.");
        }
        else
        {
            Debug.LogWarning("Prediction does not match expected digit.");
        }
    }

    void OnDestroy()
    {
        worker?.Dispose();
    }
}