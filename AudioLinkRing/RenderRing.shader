Shader "Xantoz/AudioLinkRing/RenderRing"
{
    Properties
    {
        [NoScaleOffset]_RingCRTTex ("RenderTexture", 2D) = "black" {}

        _Tint ("Tint Color", Color) = (1, 1, 1, 1)
        [NoScaleOffset]_Tex ("Cubemap (HDR)", Cube) = "Cube" {}
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 0.5

        _InnerRadius ("Radius when smallest", Float) = 0.04
        [Enum(AudioLinkBandEnum)]_Band ("Band", Int) = 0
        [Enum(AudioLinkRingModeEnum)]_HoldMode ("Hold mode", Int) = 0
        [IntRange]_Scene ("Ring look", Range(0,7)) = 7
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
            samplerCUBE _Tex;
            float4 _Tex_HDR;
            float4 _Tint;
            float _Exposure;

            float _InnerRadius;
            uint _HoldMode;
            uint _Band;
            uint _Scene;

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

            float getValue()
            {
                return _RingCRTTex[uint2(_HoldMode,_Band)].g;
            }

            float getHeldCount()
            {
                if (_HoldMode < 1) {
                    return 0.0;
                }
                return _RingCRTTex[uint2(_HoldMode,_Band)].b;
            }

            float getHeldCountMemory()
            {
                if (_HoldMode < 1) {
                    return 0.0;
                }
                return _RingCRTTex[uint2(_HoldMode,_Band)].a;
            }

            float4 sdgTorus(float3 p, float ra, float rb)
            {
                float h = length(p.xz);
                return float4(length(float2(h-ra,p.y))-rb,
                    normalize(p*float3(h-ra,h,h-ra)) );
            }

            float sdBox(float3 p, float3 b)
            {
                float3 q = abs(p) - b;
                return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
            }

            float sdHexPrism(float3 p, float2 h)
            {
                const float3 k = float3(-0.8660254, 0.5, 0.57735);
                p = abs(p);
                p.xy -= 2.0*min(dot(k.xy, p.xy), 0.0)*k.xy;
                float2 d = float2(
                    length(p.xy-float2(clamp(p.x,-k.z*h.x,k.z*h.x), h.x))*sign(p.y-h.x),
                    p.z-h.y );
                return min(max(d.x,d.y),0.0) + length(max(d,0.0));
            }

/*
            // Wonk
            float sceneSDFWonk(float3 samplePoint)
            {
                float val = getValue();
                float count = getHeldCount();

                const int nsamples = 256;
                float angle = atan2(samplePoint.x, samplePoint.z);
                float pcm_val = PCMConditional(
                    AudioLinkPCMLerpWrap(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples, nsamples),
                    0);

                // float3 p = samplePoint;
                float3 p = samplePoint + float3(0,pcm_val/100,0);

                // p = mul(rotateX(radians(90)), p);
                // p = mul(rotateZ(angle), p);
                p = (p+0.1)  - float3(cos(angle), 0, sin(angle))*0.1;


                return min(sdHexPrism(p, float2(0.01 + count/100.0, (1.0 - val)/3.0)), sdgTorus(p, _InnerRadius + (1.0 - val)/3.0, 0.01 + count/100.0));
                // return sdHexPrism(p, float2((1.0 - val)/3.0, 0.01 + count/100.0));
                // return ;
            }
*/

            float sceneSDF0(float3 samplePoint)
            {
                float val = getValue();
                float count = getHeldCount();

                const int nsamples = 256;
                float angle = atan2(samplePoint.x, samplePoint.z);
                float pcm_val = PCMConditional(
                    AudioLinkPCMLerpWrap(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples, nsamples),
                    0);

                float3 p = samplePoint + float3(0,pcm_val/100,0);

                return sdgTorus(p, _InnerRadius + (1.0 - val)/3.0, 0.01 + count/100.0);
            }

            float sceneSDF1(float3 samplePoint)
            {
                float val = getValue();
                float count = getHeldCount();

                const int nsamples = 256;
                float angle = atan2(samplePoint.x, samplePoint.z);
                float pcm_val = PCMConditional(
                    AudioLinkPCMLerpWrap(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples, nsamples),
                    0);
                // float pcm_val = AudioLinkPCMLerpWrap(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples, nsamples).b;

                float radius = _InnerRadius + (1.0 - val)/3.0;

                float3 p = samplePoint;

                p -= float3(sin(angle), 0, cos(angle))*radius;
                p = mul(rotateX(angle*count), p);
                p = mul(rotateZ(angle*pcm_val), p);
                return sdHexPrism(p, float2(0.01+count/200, 0.015));
            }

            float sceneSDF2(float3 samplePoint)
            {
                float val = getValue();
                float count = getHeldCount();

                const int nsamples = 256;
                float angle = atan2(samplePoint.x, samplePoint.z);
                float pcm_val = PCMConditional(
                    AudioLinkPCMLerpWrap(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples, nsamples),
                    0);

                float radius = _InnerRadius + (1.0 - val)/3.0 + ((count > 0.0) ? pcm_val/100 : 0);

                float3 p = samplePoint;

                p -= float3(sin(angle), 0, cos(angle))*radius;
                p = mul(rotateY(angle), p);
                return sdHexPrism(p, float2(0.01, 0.00001));
            }

            float sceneSDF3(float3 samplePoint)
            {
                float val = getValue();
                float count = getHeldCountMemory();

                const int nsamples = 256;
                float angle = atan2(samplePoint.x, samplePoint.z);
                float pcm_val = PCMConditional(
                    AudioLinkPCMLerpWrap(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples, nsamples),
                    0);

                float radius = _InnerRadius + (1.0 - val)/3.0;

                float3 p = samplePoint;
                p = mul(transpose(rotateY(angle)), p - float3(sin(angle), 0.0, cos(angle))*radius);
                p = mul(rotateY(radians(90)), p);
                p = mul(rotateZ(angle+count*2+pcm_val), p);
                return sdHexPrism(p, float2(0.01, 0.01));
            }

            float sceneSDF4(float3 samplePoint)
            {
                float val = getValue();
                float count = getHeldCount();
                float count2 = getHeldCountMemory();

                const int nsamples = 256;
                float angle = atan2(samplePoint.x, samplePoint.z);
                float index = ((angle+UNITY_PI)/(2*UNITY_PI))*nsamples*2;
                float pcm_val = AudioLinkPCMLerpMirrorLR(index, nsamples);

                float radius = _InnerRadius + (1.0 - val)/3.0 + ((count > 0.0) ? pcm_val/200 : 0.0);

                float3 p = samplePoint;
                p = mul(transpose(rotateY(angle)), p - float3(sin(angle), 0.0, cos(angle))*radius);
                p = mul(rotateY(radians(90)), p);
                p = mul(rotateZ(angle*count2*2), p);
                return sdHexPrism(p, float2(0.01, 0.01));
            }

            float sceneSDF5(float3 samplePoint)
            {
                float val = getValue();
                float count = getHeldCount();
                float count2 = getHeldCountMemory();

                const int nsamples = 256;
                float angle = atan2(samplePoint.x, samplePoint.z);
                float index = ((angle+UNITY_PI)/(2*UNITY_PI))*nsamples*2;
                float pcm_val = AudioLinkPCMLerpMirrorLR(index, nsamples);
                float radius = _InnerRadius + (1.0 - val)/3.0 + ((count > 0.0) ? pcm_val/200 : 0.0);

                float3 p = samplePoint;
                p = mul(transpose(rotateY(angle)), p - float3(sin(angle), 0.0, cos(angle))*radius);
                p = mul(rotateY(radians(90)), p);
                p = mul(rotateZ(angle*count2*2), p);
                return sdBox(p, float3(0.01,0.01,0.01));
            }

            float sceneSDF6(float3 samplePoint) 
            {
                float val = getValue();
                float count = getHeldCount();
                float count2 = getHeldCountMemory();

                const int nsamples = 256;
                float angle = atan2(samplePoint.x, samplePoint.z);
                float index = ((angle+UNITY_PI)/(2*UNITY_PI))*nsamples*2;
                float pcm_val = AudioLinkPCMLerpMirrorLR(index, nsamples);

                float radius = _InnerRadius + (1.0 - val)/3.0;

                float3 p = samplePoint;
                p = mul(transpose(rotateY(angle)), p - float3(sin(angle), 0.0, cos(angle))*radius);
                p = mul(rotateZ(pcm_val*2), p);
                return sdBox(p, float3(0.005,0.007,0.005+count2*0.005));
            }

            float sceneSDF7(float3 samplePoint)
            {
                float val = getValue();
                float count = getHeldCount();
                float count2 = getHeldCountMemory();

                const int nsamples = 256;
                float angle = atan2(samplePoint.x, samplePoint.z);
                float index = ((angle+UNITY_PI)/(2*UNITY_PI))*nsamples*2;
                float pcm_val = AudioLinkPCMLerpMirrorLR(index, nsamples);
                float radius = _InnerRadius + (1.0 - val)/3.0;

                float3 p = samplePoint;
                p = mul(transpose(rotateY(angle)), p - float3(sin(angle), 0.0, cos(angle))*radius);
                p = mul(rotateY(radians(90)+count2), p);
                p = mul(rotateZ(angle*3), p);

                return sdBox(p, float3(0.005, 0.007 + ((count > 0.0) ? pcm_val/100 : 0.0), 0.005));
            }

            // A possible optimization here would be to do the branching around
            // shortestDistanceToSurface instead so we do not have as much
            // branching inisde the loops
            float sceneSDF(float3 samplePoint)
            {
                switch (_Scene) {
                    case 0: return sceneSDF0(samplePoint); break;
                    case 1: return sceneSDF1(samplePoint); break;
                    case 2: return sceneSDF2(samplePoint); break;
                    case 3: return sceneSDF3(samplePoint); break;
                    case 4: return sceneSDF4(samplePoint); break;
                    case 5: return sceneSDF5(samplePoint); break;
                    case 6: return sceneSDF6(samplePoint); break;
                    case 7: return sceneSDF7(samplePoint); break;
                }

                return sceneSDF0(samplePoint);
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

                if (!AudioLinkIsAvailable() || getValue() <= 0.0) {
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
