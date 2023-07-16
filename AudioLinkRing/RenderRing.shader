Shader "Xantoz/AudioLinkRing/RenderRing"
{
    Properties
    {
        [NoScaleOffset]_RingCRTTex ("RenderTexture", 2D) = "black" {}
        // Normal triggers on normal attack, HoldUntilStop is held until "note" stops
        [Enum(Normal,0,HoldUntilStop,1)]_HoldMode ("Hold mode", Int) = 0

        _Tint ("Tint Color", Color) = (1, 1, 1, 1)
        [NoScaleOffset]_Tex ("Cubemap (HDR)", Cube) = "Cube" {}
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 0.5
        [Enum(AudioLinkBandEnum)]_Band ("Band", Int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "DisableBatching"="True" "VRCFallBack"="Hidden" }
        LOD 100
        Cull [_Cull]

        CGINCLUDE
        #include "UnityCG.cginc"
        #include "../cginc/AudioLinkFuncs.cginc"
        #include "../cginc/rotation.cginc"
        ENDCG

        Pass
        {
            Cull Front

            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_fog

            Texture2D<float4> _RingCRTTex;
            int _HoldMode;
            samplerCUBE _Tex;
            float4 _Tex_HDR;
            float4 _Tint;
            float _Exposure;
            uint _Band;

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

                UNITY_FOG_COORDS(6)
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

                // Object space
                o.ray_origin = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                o.vert_position = v.vertex;

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            #define MAX_MARCHING_STEPS 64
            #define MIN_DIST 0.0
            #define MAX_DIST 100.0
            #define EPSILON 0.001

            #define VALUE ((_HoldMode) ? _RingCRTTex[uint2(0,_Band)].a : _RingCRTTex[uint2(0,_Band)].b)

            float4 sdgTorus(float3 p, float ra, float rb)
            {
                float h = length(p.xz);
                return float4(length(float2(h-ra,p.y))-rb,
                    normalize(p*float3(h-ra,h,h-ra)) );
            }

            float sceneSDF(float3 samplePoint) {
                float val = VALUE;

                // return sdgTorus(samplePoint, 0.001, 0.001 + (1.0 - val)/2.0);
                return sdgTorus(samplePoint, 0.04 + (1.0 - val)/3.0, 0.01);

            }

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

            float3 estimateNormal(float3 p) {
                return normalize(float3(
                        sceneSDF(float3(p.x + EPSILON, p.y, p.z)) - sceneSDF(float3(p.x - EPSILON, p.y, p.z)),
                        sceneSDF(float3(p.x, p.y + EPSILON, p.z)) - sceneSDF(float3(p.x, p.y - EPSILON, p.z)),
                        sceneSDF(float3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(float3(p.x, p.y, p.z - EPSILON))
                    ));
            }

            float4 sampleCubeMap(float3 texcoord)
            {
                float4 tex = texCUBE(_Tex, texcoord);
                float3 c = DecodeHDR(tex, _Tex_HDR);
                c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
                c *= _Exposure;
                return float4(c, 1);
            }

            float4 frag (v2f i, out float depth : SV_Depth) : SV_Target
            // float4 frag (v2f i, out float depth : SV_DepthLessEqual) : SV_Target
            // float4 frag (v2f i, out float depth : SV_DepthGreaterEqual) : SV_Target
            {
                float4 col;

                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                if (!AudioLinkIsAvailable() || VALUE <= 0.0) {
                    discard;
                }

                float3 ray_origin = i.ray_origin;
                float3 ray_direction = normalize(i.vert_position - i.ray_origin);
                float3 eye = ray_origin;
                float3 worldDir = ray_direction;
                float dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);

                float4 clip_pos = mul(UNITY_MATRIX_VP, float4(i.worldPos, 1.0));
                float maxDepth = clip_pos.z / clip_pos.w;

                if (dist > MAX_DIST - EPSILON) {
                    discard;
                }

                float3 p = eye + dist * worldDir;
                float3 normal = estimateNormal(p);
                float4 tex = sampleCubeMap(reflect(worldDir, normal));

                col = (tex + (normal.y / 2.0 - 0.2)) * float4(1.0, 0.8, 0.6, 1.0);

                // Output depth{
                clip_pos = UnityObjectToClipPos(p);
                depth = max(clip_pos.z / clip_pos.w, maxDepth);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
