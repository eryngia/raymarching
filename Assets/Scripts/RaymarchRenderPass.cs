using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Vector4 = UnityEngine.Vector4;
using Vector3 = UnityEngine.Vector3;

public class RaymarchRenderPass : ScriptableRenderPass {
    
    [Serializable]
    public class Settings {
        public float shadowHardness = 8.0f;
        public float ambientLighting = 0.1f;
        public Color backgroundColor = Color.black;
    }

    private Material material;
    private Settings settings;
    private RTHandle tempTarget;
    private ComputeBuffer shapeBuffer;
    private RaymarchShapeData[] shapeData = new RaymarchShapeData[100];

    public RaymarchRenderPass(Material material, Settings settings) {
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
            FindShapes();
            ApplySettings();

            Blitter.BlitCameraTexture(cmd, colorTarget, tempTarget, material, 0);
            Blitter.BlitCameraTexture(cmd, tempTarget, colorTarget);
        }

        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }

    struct RaymarchShapeData {
        public Vector3 position;
        public float size;
        public Vector3 color;
        public int shapeType;
        public float blendStrength;
        public int tiled;
        public float tileSize;
    }

    private void FindShapes() {
        if (shapeBuffer == null)
            shapeBuffer = new ComputeBuffer(100, sizeof(float) * 9 + sizeof(int) * 2);

        RaymarchShape[] shapes = UnityEngine.Object.FindObjectsByType<RaymarchShape>(FindObjectsSortMode.None);
        int shapeCount = Mathf.Min(shapes.Length, 100);
        
        for (int i = 0; i < shapeCount; i++) {
            shapeData[i] = new RaymarchShapeData {
                position = shapes[i].transform.position,
                size = shapes[i].transform.localScale.x * 0.5f,
                color = new Vector3(shapes[i].color.r, shapes[i].color.g, shapes[i].color.b),
                shapeType = (int) shapes[i].shapeType,
                blendStrength = shapes[i].blendStrength,
                tiled = shapes[i].tiled ? 1 : 0,
                tileSize = shapes[i].tileSize
            };
        }
        
        shapeBuffer.SetData(shapeData);
        material.SetInt("_ShapeCount", shapeCount);
        material.SetBuffer("_Shapes", shapeBuffer);
    }

    private void ApplySettings() {
        material.SetFloat("_ShadowHardness", settings.shadowHardness);
        material.SetVector("_BackgroundColor", new Vector4(settings.backgroundColor.r, settings.backgroundColor.g, settings.backgroundColor.b, 1.0f));
        material.SetFloat("_AmbientLighting", settings.ambientLighting);
    }

    public void Dispose() {
        shapeBuffer?.Release();
        tempTarget?.Release();
    }

}