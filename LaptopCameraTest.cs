using System.Diagnostics;
using UnityEngine;
using UnityEngine.UI;

public class LaptopCameraTest : MonoBehaviour
{
    public RawImage cameraDisplay;

    private WebCamTexture webcam;

    void Start()
    {
        WebCamDevice[] devices = WebCamTexture.devices;

        if (devices.Length == 0)
        {
            UnityEngine.Debug.LogError("No webcam detected.");
            return;
        }

        UnityEngine.Debug.Log("Using camera: " + devices[0].name);

        webcam = new WebCamTexture(
            devices[0].name,
            640,
            480,
            30
        );

        cameraDisplay.texture = webcam;
        webcam.Play();
    }

    void OnDestroy()
    {
        if (webcam != null && webcam.isPlaying)
            webcam.Stop();
    }
}
