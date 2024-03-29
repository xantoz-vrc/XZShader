// Based on https://www.shadertoy.com/view/XdBBzR

Shader "Xantoz/XZAudioLinkBlob"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 1
        _Tint ("Tint Color", Color) = (1, 1, 1, 1)
        [NoScaleOffset]_Tex ("Cubemap (HDR)", Cube) = "Cube" {}
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 0.5
        [IntRange]_InObjectSpace ("Raymarch in Object space rather than world space", Range(0, 1)) = 1
        _SceneScale("Scene scale", Float) = 0.03
        _SceneRotationAngle("Scene rotation angle", Range(-180,180)) = 0
        _SceneRotationAxis("Scene rotation axis", Vector) = (1,0,0)
        _SceneOffset("Scene offset", Vector) = (0,0,0)
        _K("k-factor", Float) = 2.5
        [ToggleUI]_Discard("Discard", Int) = 1

        [Space(10)]
        [Header(Audiolink)]
        _Amplitude_Scale ("AudioLink PCM Amplitude Scale", Range(0.0, 2.0)) = 1.0  // Scale amplitude of PCM
    }

    CGINCLUDE
    #pragma target 5.0
    #pragma multi_compile_fog
    #pragma multi_compile_instancing

    #include "UnityCG.cginc"
    #include "../cginc/rotation.cginc"
    #include "../cginc/AudioLinkFuncs.cginc"

    // Number of samples to turn into metaballs
    #define SAMPLECNT 64
    // Use every n'th sample
    #define STEP 16
    
    // #define MAX_MARCHING_STEPS 64
    #define MAX_MARCHING_STEPS 32
    #define MIN_DIST 0.0
    // #define MAX_DIST 100.0
    // #define EPSILON 0.001
    #define MAX_DIST 50.0
    #define EPSILON 0.002

    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" "DisableBatching"="True" }
        LOD 100
        Cull [_Cull]

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            samplerCUBE _Tex;
            float4 _Tex_HDR;
            float4 _Tint;
            float _Exposure;
            int _InObjectSpace;
            float _SceneScale;
            float _SceneRotationAngle;
            float3 _SceneRotationAxis;
            float3 _SceneOffset;
            float _K;

            int _Discard;
            float _Amplitude_Scale;

            static float3 ball_pos[SAMPLECNT];

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

            v2f vert(appdata v)
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

            /**
            * Signed distance function for a sphere centered at the origin with radius r.
            */
            float sphereSDF(float3 p, float r) {
                return length(p) - r;
            }

            // polynomial smooth min (k = 0.1);
            float smin(float a, float b, float k)
            {
                float h = clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
                return lerp(b, a, h) - k*h*(1.0-h);
            }

            /**
            * Signed distance function describing the scene.
            */
            float sceneSDF(float3 samplePoint) {
                float ballRadius = 1.0;
                float balls = MAX_DIST;
                for (uint i = 0; i < SAMPLECNT; ++i) {
                    balls = smin(balls, sphereSDF(samplePoint + ball_pos[i], ballRadius*_SceneScale), _K*_SceneScale);
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

            float3 rayDirection(float fieldOfView, float2 size, float2 fragCoord) {
                float2 xy = fragCoord - size / 2.0;
                float z = size.y / tan(radians(fieldOfView) / 2.0);
                return normalize(float3(xy, -z));
            }

            /**
            * Using the gradient of the SDF, estimate the normal on the surface at point p.
            */
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

            void set_ball_positions(void)
            {
                for (uint i = 0; i < SAMPLECNT; ++i) {
                    float4 pcm = AudioLinkPCMData(i*STEP)*0.5*_Amplitude_Scale;
                    float2 pcm_lr = PCMToLR(pcm);
                    ball_pos[i] = float3(pcm_lr.x, pcm_lr.y, pcm.g);
                }
            }

            float4 frag (v2f i, out float depth : SV_Depth) : SV_Target
            {
                float4 col = 0.0f;

                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                set_ball_positions();

                float3 ray_direction = normalize(i.vert_position - i.ray_origin);

                float3x3 R = AngleAxis3x3(radians(_SceneRotationAngle), normalize(_SceneRotationAxis));
                float3 eye = mul(i.ray_origin + _SceneOffset, R);
                float3 worldDir = mul(ray_direction, R);
                float dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);

                float4 clip_pos = mul(UNITY_MATRIX_VP, float4(i.worldPos, 1.0));
                float maxDepth = clip_pos.z / clip_pos.w;

                if (dist > MAX_DIST - EPSILON) {
                    if (_Discard) {
                        discard;
                    } else {
                        col = sampleCubeMap(worldDir);
                        depth = maxDepth;
                        return col;
                    }
                }

                float3 p = eye + dist * worldDir;
                float3 normal = estimateNormal(p);
                float4 tex = sampleCubeMap(reflect(worldDir, normal));

                col = (tex + (normal.y / 2.0 - 0.2)) * float4(1.0, 0.8, 0.6, 1.0);

                // undo rotation and offset for depth calculation
                p = mul(p, transpose(R)) - _SceneOffset;
                if (_InObjectSpace) {
                    clip_pos = UnityObjectToClipPos(p);
                } else {
                    clip_pos = mul(UNITY_MATRIX_VP, float4(p, 1.0));
                }
                depth = max(clip_pos.z / clip_pos.w, maxDepth);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
