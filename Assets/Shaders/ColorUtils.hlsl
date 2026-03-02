#ifndef COLOR_UTILS
#define COLOR_UTILS
// from: https://stackoverflow.com/questions/15095909/from-rgb-to-hsv-in-opengl-glsl

float3 RGBtoHSV(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 HSVtoRGB(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

float3 LerpHSV(float3 rgbA, float3 rgbB, float t) {
    float3 hsvA = RGBtoHSV(rgbA);
    float3 hsvB = RGBtoHSV(rgbB);

    float hue;
    float d = hsvB.x - hsvA.x;
    
    if (hsvA.x > hsvB.x) {
        float temp = hsvB.x;
        hsvB.x = hsvA.x;
        hsvA.x = temp;
        d = -d;
        t = 1.0 - t;
    }

    if (d > 0.5) {
        hsvA.x = hsvA.x + 1.0;
        hue = frac(lerp(hsvA.x, hsvB.x, t));
    } else {
        hue = lerp(hsvA.x, hsvB.x, t);
    }

    float sat = lerp(hsvA.y, hsvB.y, t);
    float val = lerp(hsvA.z, hsvB.z, t);

    return HSVtoRGB(float3(hue, sat, val));
}

#endif