using Unity.InferenceEngine;
using UnityEngine;

public class MNISTModelLoader : MonoBehaviour
{
    public ModelAsset modelAsset;

    private Model runtimeModel;
    private Worker worker;

    void Start()
    {
        runtimeModel = ModelLoader.Load(modelAsset);

        worker = new Worker(runtimeModel, BackendType.GPUCompute);

        Debug.Log("MNIST model loaded successfully using GPU backend.");
    }

    void OnDestroy()
    {
        worker?.Dispose();
    }
}