using UnityEngine;
using System;
//为了给延迟渲染添加雾的效果，我们必须等待所有的光源都被渲染，然后再做一次渲染，以决定雾的效果。由于雾适用于整个场景，它的渲染就像渲染方向光源一样。
//添加到摄像机上
[ExecuteInEditMode]
public class DeferredFogEffect : MonoBehaviour
{

    public Shader deferredFog;
    //不需要序列化，上面shader的材质
    [NonSerialized]
    Material fogMaterial;

    [NonSerialized]
    Camera deferredCamera;

    [NonSerialized]
    Vector3[] frustumCorners;

    [NonSerialized]
    Vector4[] vectorArray;
    //向渲染过程添加额外的全屏渲染通道，请给我们的组件一个OnRenderImage方法。 Unity将检查相机是否具有此方法的组件，并在渲染场景后调用它们。
    //第一个参数是源纹理，其中包含场景的最终颜色，第二个参数是我们必须渲染的目标纹理。
    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (fogMaterial == null)
        {
            deferredCamera = GetComponent<Camera>();
            frustumCorners = new Vector3[4];
            vectorArray = new Vector4[4];
            fogMaterial = new Material(deferredFog);
        }
        deferredCamera.CalculateFrustumCorners(
            new Rect(0f, 0f, 1f, 1f),
            deferredCamera.farClipPlane,
            deferredCamera.stereoActiveEye,
            frustumCorners
        );
        vectorArray[0] = frustumCorners[0];
        vectorArray[1] = frustumCorners[3];
        vectorArray[2] = frustumCorners[1];
        vectorArray[3] = frustumCorners[2];
        fogMaterial.SetVectorArray("_FrustumCorners", vectorArray);
        Graphics.Blit(source, destination, fogMaterial);
    }
}