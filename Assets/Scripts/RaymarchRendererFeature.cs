using UnityEngine;
using UnityEngine.Rendering.Universal;

public class RaymarchRendererFeature : ScriptableRendererFeature {

    [SerializeField] private RaymarchRenderPass.Settings settings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    private Material material;
    private RaymarchRenderPass renderPass;

    public override void Create() {
        if (shader == null)
            return;

        if (material == null || material.shader != shader) {
            material = new Material(shader);
            renderPass = new RaymarchRenderPass(material, settings) {
                renderPassEvent = renderPassEvent
            };
        }
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
        if (renderPass == null)
            return;

        renderer.EnqueuePass(renderPass);
    }

    protected override void Dispose(bool disposing) {
       renderPass?.Dispose();
       if (disposing && material != null) {
            if (Application.isPlaying) Destroy(material);
            else  DestroyImmediate(material);  
            material = null;
        }
    } 

}