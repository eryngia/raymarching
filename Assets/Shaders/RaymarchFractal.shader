Shader "Custom/RaymarchFractalShader"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Name "RaymarchPass"

            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "RaymarchCommon.hlsl"

            float4 _BackgroundColor;
            float3 _LightColor;
            float3 _IterationColor;
            float3 _TrapColor;
            float _Power;
            float _OcclusionIntensity;
            
            #define MAX_STEPS 100
            #define MAX_DISTANCE 100.0
            #define HIT_THRESHOLD 0.001
            #define MAX_ITERATIONS 16

            // based on: https://iquilezles.org/articles/mandelbulb/
            float2 MandelbulbSDF(float3 p, float power) {
                float3 z = p;
                float dr = 1.0;
                float r = 0.0;
                int iterations = 0;

                for (int i = 0; i < MAX_ITERATIONS; i++) {
                    iterations++;
                    r = length(z);
                    if (r > 2.0) break;

                    float theta = acos(z.z / r);
                    float phi = atan2(z.y, z.x);
                    dr = pow(r, power - 1.0) * power * dr + 1.0;

                    float zr = pow(r, power);
                    theta *= power;
                    phi *= power;

                    z = zr * float3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta));
                    z += p;
                }
                return float2(0.5 * log(r) * r / dr, iterations);
            }
            
            float3 EstimateNormal(float3 p) {
                const float epsilon = 0.001;
                
                float x = MandelbulbSDF(float3(p.x + epsilon, p.y, p.z), _Power).x - MandelbulbSDF(float3(p.x - epsilon, p.y, p.z), _Power).x;
                float y = MandelbulbSDF(float3(p.x, p.y + epsilon, p.z), _Power).x - MandelbulbSDF(float3(p.x, p.y - epsilon, p.z), _Power).x;
                float z = MandelbulbSDF(float3(p.x, p.y, p.z + epsilon), _Power).x - MandelbulbSDF(float3(p.x, p.y, p.z - epsilon), _Power).x;
                
                return normalize(float3(x, y, z));
            }

            float4 CalculateColor(float3 p, int iterations) {
                float3 normal = EstimateNormal(p);
                float3 lightColor = _LightColor * saturate(dot(normal * 0.5 + 0.5, GetMainLight().direction));
                float3 iterationColor = _IterationColor * saturate((float)iterations / MAX_ITERATIONS);
                return float4(saturate(lightColor + iterationColor), 1.0);
            }

            float4 Frag(Varyings input) : SV_Target {
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(ComputeWorldSpacePosition(input.texcoord, 0.5, UNITY_MATRIX_I_VP).xyz - rayOrigin);

                float totalDistance = 0.0;
                int steps = 0;
                float4 result = _BackgroundColor;

                while (steps < MAX_STEPS && totalDistance < MAX_DISTANCE) {
                    float3 currentPoint = rayOrigin + totalDistance * rayDirection;
                    
                    float2 pointResult = MandelbulbSDF(currentPoint, _Power);
                    float distance = pointResult.x;
                    float iterations = pointResult.y;

                    if (pointResult.x < HIT_THRESHOLD) {
                        result = CalculateColor(currentPoint, iterations);
                        break;
                    }
                    
                    totalDistance += distance;
                    steps++;
                }
                
                float occlusion = steps / _OcclusionIntensity;
                return float4(result.rgb * occlusion, 1.0);
            }

            ENDHLSL
        }
    }
}