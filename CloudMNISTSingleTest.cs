using System;
using System.Collections;
using TMPro;
using UnityEngine;
using UnityEngine.Networking;

public class CloudMNISTSingleTest : MonoBehaviour
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

    [Serializable]
    private class PredictionResponse
    {
        public int prediction;
    }

    void Start()
    {
        StartCoroutine(TestFirstImage());
    }

    IEnumerator TestFirstImage()
    {
        if (resultText != null)
        {
            resultText.text =
                "Testing Cloud Run connection...";
        }

        // ----------------------------------------------------
        // Validate input
        // ----------------------------------------------------

        if (imagesFile == null)
        {
            SetResult("ERROR: Images file is not assigned.");
            yield break;
        }

        byte[] sourceBytes =
            imagesFile.bytes;

        int minimumBytes =
            PixelsPerImage *
            BytesPerFloat;

        if (sourceBytes.Length < minimumBytes)
        {
            SetResult(
                "ERROR: MNIST image file is too small."
            );

            yield break;
        }

        // ----------------------------------------------------
        // Convert first Unity MNIST image
        // float32 0..1 -> byte 0..255
        // ----------------------------------------------------

        byte[] imageBody =
            new byte[PixelsPerImage];

        for (int pixel = 0;
             pixel < PixelsPerImage;
             pixel++)
        {
            float value =
                BitConverter.ToSingle(
                    sourceBytes,
                    pixel * BytesPerFloat
                );

            int byteValue =
                Mathf.RoundToInt(
                    Mathf.Clamp01(value) *
                    255f
                );

            imageBody[pixel] =
                (byte)byteValue;
        }

        int expectedDigit = -1;

        if (labelsFile != null &&
            labelsFile.bytes.Length > 0)
        {
            expectedDigit =
                labelsFile.bytes[0];
        }

        // ----------------------------------------------------
        // HTTP request
        // ----------------------------------------------------

        using UnityWebRequest request =
            new UnityWebRequest(
                endpoint,
                UnityWebRequest.kHttpVerbPOST
            );

        request.uploadHandler =
            new UploadHandlerRaw(
                imageBody
            );

        request.downloadHandler =
            new DownloadHandlerBuffer();

        request.SetRequestHeader(
            "Content-Type",
            "application/octet-stream"
        );

        // ----------------------------------------------------
        // Round-trip timing
        //
        // Starts immediately before request transmission.
        // Ends when complete HTTP response is available.
        // ----------------------------------------------------

        System.Diagnostics.Stopwatch stopwatch =
            System.Diagnostics.Stopwatch.StartNew();

        yield return request.SendWebRequest();

        stopwatch.Stop();

        double roundTripMs =
            stopwatch.Elapsed.TotalMilliseconds;

        // ----------------------------------------------------
        // Handle HTTP/network errors
        // ----------------------------------------------------

        if (request.result !=
            UnityWebRequest.Result.Success)
        {
            string error =
                "Cloud Request Failed\n\n" +
                $"HTTP: {request.responseCode}\n" +
                $"Error: {request.error}\n" +
                $"Time: {roundTripMs:F2} ms";

            SetResult(error);

            UnityEngine.Debug.LogError(
                error
            );

            yield break;
        }

        // ----------------------------------------------------
        // Parse JSON response
        // Expected:
        // {"prediction":N}
        // ----------------------------------------------------

        string responseText =
            request.downloadHandler.text;

        PredictionResponse response =
            JsonUtility.FromJson<PredictionResponse>(
                responseText
            );

        if (response == null)
        {
            SetResult(
                "ERROR: Could not parse cloud response.\n" +
                responseText
            );

            yield break;
        }

        bool correct =
            expectedDigit < 0 ||
            response.prediction ==
            expectedDigit;

        // ----------------------------------------------------
        // Display result
        // ----------------------------------------------------

        string results =
            "Cloud MNIST Test\n\n" +
            $"Expected: {expectedDigit}\n" +
            $"Prediction: {response.prediction}\n" +
            $"Correct: {correct}\n" +
            $"Round Trip: {roundTripMs:F2} ms\n" +
            $"HTTP: {request.responseCode}";

        SetResult(results);

        UnityEngine.Debug.Log(
            results
        );

        UnityEngine.Debug.Log(
            "Cloud response: " +
            responseText
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