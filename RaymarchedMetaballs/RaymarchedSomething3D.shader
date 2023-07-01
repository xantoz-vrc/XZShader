// Based on https://www.shadertoy.com/view/XdBBzR

Shader "Xantoz/RaymarchedSomething3D"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 1
        _Tint ("Tint Color", Color) = (1, 1, 1, 1)
        [NoScaleOffset]_Tex ("Cubemap (HDR)", Cube) = "Cube" {}
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 0.5
        [NoScaleOffset]_MainTex ("Texture", 2D) = "white" {}
        [NoScaleOffset]_MainTex2 ("Texture 2", 2D) = "white" {}
        [IntRange]_InObjectSpace ("Raymarch in Object space rather than world space", Range(0, 1)) = 1
        _SceneScale("Scene scale", Range(0,1)) = 0.04
        _SceneRotationAngle("Scene rotation angle", Range(-180,180)) = 0
        _SceneRotationAxis("Scene rotation axis", Vector) = (1,0,0)
        _SceneOffset("Scene offset", Vector) = (0,0,0)
        _K("k-factor", Float) = 0.7
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "DisableBatching"="True" }
        LOD 100
        Cull [_Cull]

        CGINCLUDE
            #include "UnityCG.cginc"
            #include "../cginc/AudioLinkFuncs.cginc"
            #include "../cginc/rotation.cginc"
        ENDCG

        Pass
        {
            // ZWrite Off
            // ZTest LEqual
            // ZTest Less
            // ZTest GEqual
            // ZTest Greater
            // ZClip false


            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_fog

            samplerCUBE _Tex;
            float4 _Tex_HDR;
            float4 _Tint;
            float _Exposure;
            sampler2D _MainTex;
            sampler2D _MainTex2;
            int _InObjectSpace;
            float _SceneScale;
            float _SceneRotationAngle;
            float3 _SceneRotationAxis;
            float3 _SceneOffset;

            float _K;

            UNITY_DECLARE_TEXCUBE(_RealtimeCubemap);
            // samplerCUBE _RealtimeCubemap;
            // float4 _RealtimeCubemap_HDR;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 ray_origin : TEXCOORD1;
                float3 vert_position : TEXCOORD2;
                float3 worldPos : TEXCOORD3;

                UNITY_FOG_COORDS(2)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert (appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.uv;

                if (_InObjectSpace) {
                    o.ray_origin = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                    o.vert_position = v.vertex;
                } else {
                    o.ray_origin = _WorldSpaceCameraPos;
                    o.vert_position = mul(unity_ObjectToWorld, v.vertex);
                }

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            #define MAX_MARCHING_STEPS 128
            #define MIN_DIST 0.0
            #define MAX_DIST 100.0
            #define EPSILON 0.001


            #define TIME _Time.y
            // #define TIME 1

            float sceneSDF(float3 samplePoint);

            /**
            * Signed distance function for a sphere centered at the origin with radius r.
            */
            float sphereSDF(float3 p, float r) {
                return length(p) - r;
            }

            float udRoundBox(float3 p, float3 b, float r) 
            {
                return length(max(abs(p)-b,0.0))-r;
            }


            // polynomial smooth min (k = 0.1);
            float smin(float a, float b, float k)
            {
                float h = clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
                return lerp(b, a, h) - k*h*(1.0-h);
            }

            // #define BALLMULT 2
            #define BALLMULT 1
            float balls(float3 samplePoint)
            {
                // float t = TIME / 3.0 + 10500.0;
                float t = (AudioLinkGetChronotensity(5, 3)/100000.0 + AudioLinkGetChronotensity(0, 0)/100000.0) / 3.0 + 10500.0;

                float balls = MAX_DIST;
                for (float i = 1.0; i < 4.0*BALLMULT; i += 1.3) {
                    float ballRadius = 1.0*(1+AudioLinkData(uint2(i, 0)).r);
                    for (float j = 1.0; j < 4.0*BALLMULT; j += 1.3) {
                        float cost = cos(t * j);
                        balls = smin(balls, sphereSDF(samplePoint + float3(sin(t * i) * j, cost * i, cost * j)*_SceneScale, ballRadius*_SceneScale), _K*_SceneScale);
                        // balls = min(balls, sphereSDF(samplePoint + float3(sin(t * i) * j, cost * i, cost * j)*_SceneScale, ballRadius*_SceneScale));
                    }
                }

                return balls;
            }

            /**
            * Return the shortest distance from the eyepoint to the scene surface along
            * the marching direction. If no part of the surface is found between start and end,
            * return end.
            *
            * eye: the eye point, acting as the origin of the ray
            * marchingDirection: the normalized direction to march in
            * start: the starting distance away from the eye
            * end: the max distance away from the ey to march before giving up
            */
            float shortestDistanceToSurface(float3 eye, float3 marchingDirection, float start, float end) {
                float depth = start;
                for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
                    float dist = sceneSDF(eye + depth * marchingDirection);
                    if (dist < EPSILON) {
                        return depth;
                    }
                    depth += dist;
                    if (depth >= end) {
                        return end;
                    }
                }
                return end;
            }

            float shortestDistanceToBalls(float3 eye, float3 T, float3 marchingDirection, float start, float end) {
                float depth = start;
                for (int i = 0; i < 8; i++) {
                    float dist = balls(eye + depth * marchingDirection + T);
                    if (dist < EPSILON) {
                        return depth;
                    }
                    depth += dist;
                    if (depth >= end) {
                        return end;
                    }
                }
                return end;
            }

            float3 rayDirection(float fieldOfView, float2 size, float2 fragCoord) {
                float2 xy = fragCoord - size / 2.0;
                float z = size.y / tan(radians(fieldOfView) / 2.0);
                return normalize(float3(xy, -z));
            }

            #define estimateNormal(fn, p) \
            normalize(float3( \
                    fn(float3((p).x + EPSILON, (p).y,           (p).z          )) - fn(float3((p).x - EPSILON, (p).y,           (p).z          )), \
                    fn(float3((p).x,           (p).y + EPSILON, (p).z          )) - fn(float3((p).x,           (p).y - EPSILON, (p).z          )), \
                    fn(float3((p).x,           (p).y,           (p).z + EPSILON)) - fn(float3((p).x,           (p).y,           (p).z - EPSILON)) \
                ));

            float4 sampleCubeMap(float3 texcoord)
            {
                float4 tex = texCUBE(_Tex, texcoord);
                float3 c = DecodeHDR(tex, _Tex_HDR);
                c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
                c *= _Exposure;
                return float4(c, 1);
            }

            float4 sampleReflectionProbe(float3 texcoord)
            {
                // float4 tex = texCUBE(_RealtimeCubemap, texcoord);
                // float3 c = DecodeHDR(tex, _RealtimeCubemap_HDR);
                // c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
                // c *= _Exposure;
                // return float4(c, 1);

                // float3 x = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(_RealtimeCubemap, texcoord, 0.0),
                //                      _RealtimeCubemap_HDR);

                // float3 x = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(UNITY_PASS_TEXCUBE(_RealtimeCubemap), texcoord, 0), _RealtimeCubemap_HDR);
                // float3 x = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(UNITY_PASS_TEXCUBE(_RealtimeCubemap), texcoord, 0), _RealtimeCubemap_HDR);
                // float3 x = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(_RealtimeCubemap, texcoord, 0), _RealtimeCubemap_HDR);

                float3 x = UNITY_SAMPLE_TEXCUBE(_RealtimeCubemap, texcoord);
                return float4(x, 1);
            }

            // from https://gist.github.com/ishikawash/4648390
            // 'p' must be normalized
            float2 getUV(float3 p)
            {
	        // float phi = atan(p.y, p.x);
                float phi = atan2(p.y, p.x);
	        float theta = acos(p.z);
	        float s = phi*rcp(2*UNITY_PI);
	        float t = theta*rcp(UNITY_PI);
	        return float2(s, t);
            }

            #define MOONSCALE 1

            /**
            * Signed distance function describing the scene.
            */
            float sceneSDF(float3 samplePoint)
            {
                float3 metaballsT = float3(_CosTime.z*3,_SinTime.y*10,-10)*_SceneScale;

                float3 sphereT = float3(sin(frac(_Time.x)*2*UNITY_PI), 0, cos(frac(_Time.x)*2*UNITY_PI))*10*_SceneScale*MOONSCALE;

                float3x3 cubeR = AngleAxis3x3(radians(AudioLinkGetChronotensity(0, 0)/1000.0 % 360.0), normalize(float3(1.0,_SinTime.y,_CosTime.y)));
                float2 cubeSize = float2((1+AudioLinkData(uint2(1,0)).r)*_SceneScale, AudioLinkData(uint2(0,0)).r*_SceneScale);

                return
                min(
                    balls(samplePoint+metaballsT),
                    min(
                        sphereSDF(
                            samplePoint + sphereT,
                            1*_SceneScale*MOONSCALE),
                        udRoundBox(mul(samplePoint, cubeR), cubeSize.x, cubeSize.y)));

            }

            float4 shortestDistanceToSurfaceWithColor(float3 eye, float3 marchingDirection, float start, float end)
            {
                float depth = start;

                float3 metaballsT = float3(_CosTime.z*3,_SinTime.y*10,-10)*_SceneScale;

                float3 sphereT = float3(sin(frac(_Time.x)*2*UNITY_PI), 0, cos(frac(_Time.x)*2*UNITY_PI))*10*_SceneScale*MOONSCALE;

                float3x3 cubeR = AngleAxis3x3(radians(AudioLinkGetChronotensity(0, 0)/1000.0 % 360.0), normalize(float3(1.0,_SinTime.y,_CosTime.y)));
                float2 cubeSize = float2((1+AudioLinkData(uint2(1,0)).r)*_SceneScale, AudioLinkData(uint2(0,0)).r*_SceneScale);

                float3 bgCol = sampleCubeMap(marchingDirection).rgb;

                [loop]
                for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
                    float3 samplePoint = eye + depth * marchingDirection;

                    float metaballs = balls(samplePoint+metaballsT);

                    float sphere = sphereSDF(samplePoint + sphereT, MOONSCALE*_SceneScale);

                    float cube = udRoundBox(mul(samplePoint, cubeR), cubeSize.x, cubeSize.y);

                    float dist = min(metaballs, min(sphere, cube));
                    
                    if (dist < EPSILON) {
                        //float3 p = eye + depth*marchingDirection;
                        float3 p = samplePoint + dist*marchingDirection;
                        float3 normal = estimateNormal(sceneSDF, p);

                        // float3 metaballsP = eye + (depth+metaballs) * marchingDirection;
                        float3 metaballsP = (samplePoint+metaballsT) + metaballs*marchingDirection;
                        float3 metaballsNormal = estimateNormal(balls, metaballsP);
                        float4 metaballsTex = sampleCubeMap(reflect(marchingDirection, metaballsNormal));
                        float4 metaballsCol = (metaballsTex  + (metaballsNormal.y / 2.0 - 0.2)) * float4(1.0, 0.8, 0.6, 1.0);

                        // Undo the translation and/or rotation when calculating UV
                        if (dist == cube) {
                            float3 newp = mul(transpose(cubeR), p);
                            // float3 newp = mul(p, transpose(cubeR));
                            float2 uv = getUV(normalize(newp));
                            float4 texel = tex2D(_MainTex, uv);
                            float3 bCol;
                            // if (sign(balls(metaballsP-metaballsT)) == sign(metaballs)) {
                            // if (metaballs >= MAX_DIST - EPSILON) {
                            // if (shortestDistanceToBalls(p, metaballsT, marchingDirection, start, end) >= MAX_DIST - EPSILON) {
                            if (shortestDistanceToBalls(metaballsP-metaballsT, metaballsT, marchingDirection, start, end) >= MAX_DIST - EPSILON) {
                                bCol = sampleCubeMap(mul(marchingDirection, cubeR)).rgb;
                                // bCol = sampleReflectionProbe(mul(marchingDirection, cubeR)).rgb;
                                // bCol = sampleCubeMap(reflect(marchingDirection, normal))
                            } else {
                                bCol = metaballsCol.rgb;
                            }
                            float3 col = (texel.rgb + bCol.rgb*(1 - texel.a)) + (normal.y / 2.0 - 0.2)/4;
                            return float4(col, depth);
                        } else if (dist == metaballs) {
                            p = p + metaballsT;
                            float2 uv = getUV(normalize(p));
                            float4 texel = tex2D(_MainTex, uv);
                            // float3 col = metaballsCol.rgb + texel.rgb*texel.a;
                            float3 col = metaballsCol.rgb + texel.rgb;
                            // float3 col = metaballsCol.rgb;
                            return float4(col, depth);
                        } else {
                            p = p + sphereT;
                            float2 uv = getUV(normalize(p));
                            float4 texel = tex2D(_MainTex, uv);
                            float4 texel2 = tex2D(_MainTex2, uv);
                            float3 col = texel.rgb + (texel2.rgb + (normal.y / 2.0 - 0.2)/2)*(1-texel.a);
                            return float4(col, depth);
                        }
                    }

                    depth += dist;
                    if (depth >= end) {
                        return float4(bgCol, depth);
                    }
                }

                return float4(bgCol, end);
            }
            
            float4 frag(v2f i, out float depth : SV_Depth) : SV_Target
            {
                float4 col = float4(0,0,0,1);

                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 ray_origin = i.ray_origin;
                float3 ray_direction = normalize(i.vert_position - i.ray_origin);

                float3x3 R = AngleAxis3x3(radians(_SceneRotationAngle), normalize(_SceneRotationAxis));
                float3 eye = mul(ray_origin + _SceneOffset, R);
                float3 worldDir = mul(ray_direction, R);

                float4 colorDist = shortestDistanceToSurfaceWithColor(eye, worldDir, MIN_DIST, MAX_DIST);
                col.rgb = colorDist.rgb;
                float dist = colorDist.a;

                // TODO: fold depth calculcation into the raymarching loop as well?
                // Output depth
                float4 clip_pos = mul(UNITY_MATRIX_VP, float4(i.worldPos, 1.0));
                float maxDepth = clip_pos.z / clip_pos.w;
                if (dist > MAX_DIST - EPSILON) {
                    // discard;
                    depth = maxDepth;
                } else {
                    float3 p = eye + dist * worldDir;
                    p = mul(p, transpose(R)) - _SceneOffset; // undo rotation and offset for depth calculation
                    if (_InObjectSpace) {
                        clip_pos = UnityObjectToClipPos(p);
                    } else {
                        clip_pos = mul(UNITY_MATRIX_VP, float4(p, 1.0));
                    }
                    depth = max(clip_pos.z / clip_pos.w, maxDepth);
                }

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }
    }
}
