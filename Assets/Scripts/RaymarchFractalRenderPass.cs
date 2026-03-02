using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Vector3 = UnityEngine.Vector3;

public class RaymarchFractalRenderPass : ScriptableRenderPass {
    
    [Serializable]
    public class Settings {
        public Color lightColor = Color.blue;
        public Color iterationColor = Color.red;
        public float power = 8.0f;
        public Color backgroundColor = Color.black;
        public float occlusionIntensity = 10.0f;
        public float animationRange = 2.0f;
        public float animationSpeed = 0.1f;
    }

    private Material material;
    private Settings settings;
    private RTHandle tempTarget;

    public RaymarchFractalRenderPass(Material material, Settings settings) {
        this.material = material;
        this.settings = settings;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
        var descriptor = renderingData.cameraData.cameraTargetDescriptor;
        descriptor.depthBufferBits = 0;
        
        RenderingUtils.ReAllocateIfNeeded(ref tempTarget, descriptor, name: "_TempTarget");
    
        ConfigureTarget(renderingData.cameraData.renderer.cameraColorTargetHandle);
        ConfigureClear(ClearFlag.None, Color.clear);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
        RTHandle colorTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;
        
        if (material == null || colorTarget?.rt == null || tempTarget?.rt == null)
            return;

        CommandBuffer cmd = CommandBufferPool.Get("Raymarch Pass");

        using (new ProfilingScope(cmd, new ProfilingSampler("Raymarch"))) {
            ApplySettings();

            Blitter.BlitCameraTexture(cmd, colorTarget, tempTarget, material, 0);
            Blitter.BlitCameraTexture(cmd, tempTarget, colorTarget);
        }

        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }

    private void ApplySettings() {
        material.SetColor("_BackgroundColor", settings.backgroundColor);
        material.SetColor("_LightColor", settings.lightColor);
        material.SetColor("_IterationColor", settings.iterationColor);
        material.SetFloat("_OcclusionIntensity", settings.occlusionIntensity);
        
        float animatedPower = settings.power + Mathf.Sin(Time.time * settings.animationSpeed) * settings.animationRange;
        material.SetFloat("_Power", Application.isPlaying ? animatedPower : settings.power);
    }

    public void Dispose() {
        tempTarget?.Release();
    }

}