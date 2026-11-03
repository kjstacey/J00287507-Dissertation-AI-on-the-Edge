using UnityEngine;
using UnityEngine.UI;

public class CameraPreprocessTest : MonoBehaviour
{
    public RawImage cameraDisplay;
    public RawImage processedDisplay;

    private WebCamTexture webcam;
    private Texture2D processedTexture;

    private const int TargetSize = 28;

    void Start()
    {
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

        processedTexture = new Texture2D(
            TargetSize,
            TargetSize,
            TextureFormat.RGB24,
            false
        );

        processedTexture.filterMode = FilterMode.Point;

        processedDisplay.texture = processedTexture;
    }

    void Update()
    {
        if (webcam == null || !webcam.isPlaying)
            return;

        if (!webcam.didUpdateThisFrame)
            return;

        Color[] sourcePixels = webcam.GetPixels();

        int sourceWidth = webcam.width;
        int sourceHeight = webcam.height;

        if (sourceWidth <= 16 || sourceHeight <= 16)
            return;

        Color[] outputPixels =
            new Color[TargetSize * TargetSize];

        // Center-crop the camera image to a square.
        int cropSize = Mathf.Min(sourceWidth, sourceHeight);

        int xOffset =
            (sourceWidth - cropSize) / 2;

        int yOffset =
            (sourceHeight - cropSize) / 2;

        for (int y = 0; y < TargetSize; y++)
        {
            for (int x = 0; x < TargetSize; x++)
            {
                int sourceX =
                    xOffset +
                    Mathf.FloorToInt(
                        x * cropSize / (float)TargetSize
                    );

                int sourceY =
                    yOffset +
                    Mathf.FloorToInt(
                        y * cropSize / (float)TargetSize
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

                outputPixels[
                    y * TargetSize + x
                ] = new Color(
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

    void OnDestroy()
    {
        if (webcam != null && webcam.isPlaying)
            webcam.Stop();
    }
}