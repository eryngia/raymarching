#ifndef RAYMARCH_COMMON
#define RAYMARCH_COMMON

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "ColorUtils.hlsl"

struct PointResult {
    float distance;
    float3 color;
};

// based on: https://iquilezles.org/articles/smin/
float2 SmoothMin(float a, float b, float k) {
    float h = saturate(0.5 + 0.5 * (b - a) / k);
    float d = lerp(b, a, h) - k * h * (1.0 - h);
    return float2(d, h);
}

PointResult SmoothCombine(PointResult a, PointResult b, float k) {
    float2 result = SmoothMin(a.distance, b.distance, k);
    float min = result.x;
    float blend = result.y;

    PointResult combined = {min, LerpHSV(b.color, a.color, blend)};
    return combined;
}

#endif