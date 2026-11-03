using Meta.XR;
using UnityEngine;
using UnityEngine.Android;
using UnityEngine.UI;

public class QuestCameraPreview : MonoBehaviour
{
    public PassthroughCameraAccess cameraAccess;
    public RawImage previewImage;

    private const string HeadsetCameraPermission =
        "horizonos.permission.HEADSET_CAMERA";

    void Start()
    {
        if (!Permission.HasUserAuthorizedPermission(
                HeadsetCameraPermission))
        {
            Permission.RequestUserPermission(
                HeadsetCameraPermission);
        }
    }

    void Update()
    {
        if (cameraAccess == null || previewImage == null)
            return;

        if (!Permission.HasUserAuthorizedPermission(
                HeadsetCameraPermission))
            return;

        if (!cameraAccess.IsPlaying)
            return;

        Texture cameraTexture =
            cameraAccess.GetTexture();

        if (cameraTexture != null)
        {
            previewImage.texture = cameraTexture;
        }
    }
}