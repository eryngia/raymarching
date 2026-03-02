Shader "Custom/RaymarchShader"
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

            struct Shape {
                float3 position;
                float size;
                float3 color;
                int shapeType;
                float blendStrength;
                int tiled;
                float tileSize;
            };

            StructuredBuffer<Shape> _Shapes;
            int _ShapeCount;
            float _ShadowHardness;
            float4 _BackgroundColor;
            float _AmbientLighting;
            
            #define MAX_STEPS 100
            #define MAX_DISTANCE 100.0
            #define HIT_THRESHOLD 0.001

            float SphereSDF(float3 p, float3 center, float radius) {
                return length(p - center) - radius;
            }

            float CubeSDF(float3 p, float3 center, float size) {
                float3 d = abs(p - center) - size;
                return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
            }

            float GetDistance(float3 p, Shape shape) {
                if (shape.tiled == 1) {
                    p = (abs(p) % shape.tileSize) - (shape.tileSize * 0.5);
                }
                if (shape.shapeType == 0) {
                    return SphereSDF(p, shape.position, shape.size);
                } else if (shape.shapeType == 1) {
                    return CubeSDF(p, shape.position, shape.size);
                } else {
                    return 0;
                }
            }

            float GetSceneDistance(float3 p) {
                float minDistance = GetDistance(p, _Shapes[0]);
                for (int i = 1; i < _ShapeCount; i++) {
                    Shape shape = _Shapes[i];
                    float distance = GetDistance(p, shape);
                    minDistance = SmoothMin(minDistance, distance, shape.blendStrength).x;
                }
                return minDistance;
            }
            
            float3 EstimateNormal(float3 p) {
                const float epsilon = 0.001;
                
                float x = GetSceneDistance(float3(p.x + epsilon, p.y, p.z)) - GetSceneDistance(float3(p.x - epsilon, p.y, p.z));
                float y = GetSceneDistance(float3(p.x, p.y + epsilon, p.z)) - GetSceneDistance(float3(p.x, p.y - epsilon, p.z));
                float z = GetSceneDistance(float3(p.x, p.y, p.z + epsilon)) - GetSceneDistance(float3(p.x, p.y, p.z - epsilon));
                
                return normalize(float3(x, y, z));
            }

            PointResult MapScene(float3 p) {
                PointResult result = {GetDistance(p, _Shapes[0]), _Shapes[0].color};
                
                for (int i = 1; i < _ShapeCount; i++) {
                    Shape shape = _Shapes[i];
                    PointResult currentResult = {GetDistance(p, shape), shape.color};
                    result = SmoothCombine(result, currentResult, shape.blendStrength);
                }

                return result;
            }

            float CalculateShadow(float3 p, float3 normal) {                
                float3 rayOrigin = p + normal * HIT_THRESHOLD * 2.0;
                float3 rayDirection = GetMainLight().direction;
                float totalDistance = 0.001;
                float brightness = 1.0;

                for (int i = 0; i < MAX_STEPS; i++) {
                    float3 currentPoint = rayOrigin + totalDistance * rayDirection;
                    float distance = GetSceneDistance(currentPoint);

                    if (distance < HIT_THRESHOLD) {
                        return 0.0;
                    }

                    brightness = min(brightness, (distance * _ShadowHardness) / totalDistance);

                    totalDistance += distance;
                    if (totalDistance > MAX_DISTANCE) {
                        break;
                    }
                }

                return saturate(brightness);
            }

            float3 CalculateDiffuseLighting(float3 p, float3 normal) {
                Light mainLight = GetMainLight();
                float diffuse = saturate(dot(normal, mainLight.direction));
                return mainLight.color * diffuse;
            }

            float4 CalculateColor(float3 p, PointResult pointResult) {
                float3 normal = EstimateNormal(p);
                float3 diffuse = CalculateDiffuseLighting(p, normal);
                float shadow = CalculateShadow(p, normal);
                return float4(pointResult.color * (diffuse * shadow + _AmbientLighting), 1.0);
            }

            float4 Frag(Varyings input) : SV_Target {

                if (_ShapeCount <= 0) {
                    return _BackgroundColor;
                }

                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(ComputeWorldSpacePosition(input.texcoord, 0.5, UNITY_MATRIX_I_VP).xyz - rayOrigin);

                float totalDistance = 0.0;
                for (int i = 0; i < MAX_STEPS; i++) {
                    float3 currentPoint = rayOrigin + totalDistance * rayDirection;
                    PointResult pointResult = MapScene(currentPoint);
                    
                    if (pointResult.distance < HIT_THRESHOLD) {
                        return CalculateColor(currentPoint, pointResult);
                    }
                    
                    totalDistance += pointResult.distance;
                    if (totalDistance > MAX_DISTANCE) {
                        break;
                    }
                }
                
                return _BackgroundColor;
            }

            ENDHLSL
        }
    }
}