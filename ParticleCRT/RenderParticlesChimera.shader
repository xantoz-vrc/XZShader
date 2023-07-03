// ISC License
//
// Copyright 2023 xantoz
//
// Permission to use, copy, modify, and/or distribute this software
// for any purpose with or without fee is hereby granted, provided
// that the above copyright notice and this permission notice appear
// in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
// WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
// AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
// CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
// OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
// NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
// CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

Shader "Xantoz/ParticleCRT/RenderParticlesChimera"
{
    Properties
    {
        [NoScale]_ParticleCRT ("Texture", 2D) = "white" {}

        _PointSize ("Point Size", Float) = 0.1
        _AlphaMultiplier ("Alpha Multiplier (lower makes more transparent)", Range(0.0, 2.0)) = 0.5

        [Header(XZAlVis)]
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 0
        // Default to Blend SrcAlpha One
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendMode("Src Blend Mode", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlendMode("Dst Blend Mode", Float) = 1

        [Header(Basic Setings)]
        [Enum(XZAudioLinkVisualizerMode)] _Mode("Visualizer Mode", Int) = 0
        [HDR]_Color1 ("Color 1 (Base Color)", Color) = (1,1,1,1)

        _ST0 ("UV tiling and offset global", Vector) = (1,1,0,0) // (happens before _ST and _Tiling_Scale and any of the chronotensity scroll and scaling effects). Also affects the vignette)
        _ST ("UV tiling and offset", Vector) = (1,1,0,0)
        _Tiling_Scale ("UV Tiling scale", Range(0.1, 10.0)) = 1.0 // First added so we could have a nice slider in ShaderFes 2021 (normally you could also just modify _ST)

        _Rotation ("Rotation", Range(-360,360)) = 0.0
        // When enabled should randomly reverse the direction of rotation at times
        [IntRange]_Rotation_Reversing ("[Experimental] Random Rotation Reversing (Chronotensity)", Range(0,1)) = 0

        _Amplitude_Scale ("Amplitude Scale", Range(0.0, 2.0)) = 1.0  // Scale amplitude of PCM & DFT data in plots

        [Space(10)]
        [Header(Vignette)]
        _Vignette_Intensity ("Vignette Intensity", Range(0.0,1.0)) = 1.0
        _Vignette_Inner_Radius ("Vignette Inner Radius", Range(0.0, 1.41421356237)) = 0.85
        _Vignette_Outer_Radius ("Vignette Outer Radius", Range(0.0, 1.41421356237)) = 1.0
        [Enum(Circle,0, Diamond,1, Box,2)] _Vignette_Type("Vignette Type", Int) = 0

        [Space(10)]
        [Header(Color Blink)]
        [HDR]_Color2 ("Color 2 (Blink Base Color)", Color) = (1,1,1,1)
        [HDR]_Color_Mul_Band0 ("Color Bass", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band1 ("Color Low Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band2 ("Color High Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band3 ("Color Treble", Color) = (0,0,0,0)

        [Space(10)]
        [Header(Chronotensity Scroll (Tiling and Offset))]
        // This one affects the values as they come out of AudioLink. Can be used to toggle chronotensity scroll.
        _Chronotensity_Scale ("Chronotensity Scroll Scale (Toggle Scroll)", Range(-1.0, 1.0)) = 1.0

        [Enum(AudioLinkChronotensityEnum)]_Chronotensity_Effect_Band0 ("Chronotensity Scroll Type, Bass", Int) = 1
        _Chronotensity_ST_Band0 ("Chronotensity Scroll, Bass", Vector) = (0,0,0,0)
        [Enum(AudioLinkChronotensityEnum)]_Chronotensity_Effect_Band1 ("Chronotensity Scroll Type, Low Mid", Int) = 1
        _Chronotensity_ST_Band1 ("Chronotensity Scroll, Low Mid", Vector) = (0,0,0,0)
        [Enum(AudioLinkChronotensityEnum)]_Chronotensity_Effect_Band2 ("Chronotensity Scroll Type, High Mid", Int) = 1
        _Chronotensity_ST_Band2 ("Chronotensity Scroll, High Mid", Vector) = (0,0,0,0)
        [Enum(AudioLinkChronotensityEnum)]_Chronotensity_Effect_Band3 ("Chronotensity Scroll Type, Treble", Int) = 1
        _Chronotensity_ST_Band3 ("Chronotensity Scroll, Treble", Vector) = (0,0,0,0)

        _Chronotensity_Tiling_Scale ("Chronotensity Tiling Scale", Range(0.0, 10.0)) = 1.0
        _Chronotensity_Offset_Scale ("Chronotensity Offset Scale", Range(0.0, 10.0)) = 1.0

        // When the tiling value goes above these we will wrap around
        // and start shrinking back to starting point again using our
        // custom fmirror function (see below)
        _Chronotensity_Tiling_Wrap_U ("Chronotensity Tiling Wrap U", Float) = 3.0
        _Chronotensity_Tiling_Wrap_V ("Chronotensity Tiling Wrap V", Float) = 3.0


        [Space(10)]
        [Header(Chronotensity Rotation)]
        // Can be used to toggle chronotensity rotation on/off, and to reverse it
        _ChronoRot_Scale ("Chronotensity Rotation Scale", Range(-1.0, 1.0)) = 1.0

        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band0 ("Chronotensity Rotation Type, Bass", Int) = 1
        _ChronoRot_Band0 ("Chronotensity Rotation, Bass", Float) = 0.0
        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band1 ("Chronotensity Rotation Type, Low Mid", Int) = 1
        _ChronoRot_Band1 ("Chronotensity Rotation, Low Mid", Float) = 0.0
        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band2 ("Chronotensity Rotation Type, High Mid", Int) = 1
        _ChronoRot_Band2 ("Chronotensity Rotation, High Mid", Float) = 0.0
        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band3 ("Chronotensity Rotation Type, Treble", Int) = 1
        _ChronoRot_Band3 ("Chronotensity Rotation, Treble", Float) = 0.0
    }

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma geometry geom
    #pragma multi_compile_fog
    #pragma multi_compile_instancing
    #pragma target 5.0
    #pragma exclude_renderers gles metal

    #include "common.cginc"

    #include "UnityCG.cginc"
    // #include "../cginc/AudioLinkFuncs.cginc"
    #include "../XZAudioLinkVisualizer/cginc/XZAudioLinkVisualizer.cginc"


    ENDCG

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "VRCFallback"="Hidden" }
        LOD 100
        Cull Off
        ZWrite Off
        // ZTest always

        Pass
        {
            // Blend SrcAlpha One
            // Blend SrcAlpha OneMinusSrcAlpha
            Blend [_SrcBlendMode] [_DstBlendMode]

            CGPROGRAM
            #pragma multi_compile_local _OUTMODE_QUAD _OUTMODE_POINT _OUTMODE_LINE

            float _PointSize;
            float _AlphaMultiplier;

            struct appdata
            {
                float4 vertex : POSITION;
	        uint vertexID : SV_VertexID;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

	    struct v2g
	    {
		float4 vertex : POSITION0;
		uint2 batchID : TEXCOORD0;
                float3 worldScale : COLOR0_nointerpolation;

		UNITY_VERTEX_OUTPUT_STEREO
            };

            struct g2f
            {
                float2 uv : TEXCOORD0;
                float4 color : COLOR1;
                float4 vertex : POSITION0;

                UNITY_FOG_COORDS(1)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Texture2D<TEXTURETYPE> _ParticleCRT;
            SamplerState sampler_ParticleCRT;
            float _ParticleCRT_HDR;

            part3 particle_getPos(uint idx)
            {
                return _ParticleCRT[uint2(idx,0)].xyz*POSSCALE;
            }

            part particle_getTTL(uint idx)
            {
                return _ParticleCRT[uint2(idx,0)].w*TTLSCALE;
            }

            part3 particle_getSpeed(uint idx)
            {
                return _ParticleCRT[uint2(idx,1)].xyz*POSSCALE;
            }

            part3 particle_getAcc(uint idx)
            {
                return _ParticleCRT[uint2(idx,2)].xyz*POSSCALE;
            }

            float4 particle_getColor(uint idx)
            {
                return _ParticleCRT[uint2(idx,3)];
            }

            v2g vert(appdata v)
            {
                v2g o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2g, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = v.vertex;
                o.batchID = v.vertexID / 6; // Assumes we get a quad

                o.worldScale = float3(
                    length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)), // scale x axis
                    length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)), // scale y axis
                    length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z))  // scale z axis
                );

                return o;
            }

            float4 billboard(float2 xy, float2 scale)
            {
                return mul(transpose(UNITY_MATRIX_IT_MV),
		    mul(UNITY_MATRIX_MV, float4(0.0, 0.0, 0.0, 1.0))
		    + float4(xy, 0.0, 0.0) * float4(scale, 1.0, 1.0)
                );
            }

            // 6 input points * 32 instances * 6 samples per instance = 1152 samples out
            #define SAMPLECNT 6

	    [instance(32)]
            // 8 samples * 6 vertices out (quad)
            [maxvertexcount(SAMPLECNT*6)]
	    void geom(point v2g IN[1], inout TriangleStream<g2f> stream, uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN[0]);

		int batchID = IN[0].batchID;
             	int operationID = geoPrimID * 32 + ( instanceID - batchID );

                g2f o;
                UNITY_INITIALIZE_OUTPUT(g2f, o);
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(IN[0], o);

                const float2 TL = float2(-1.0,-1.0);
		const float2 TR = float2(-1.0, 1.0);
		const float2 BL = float2( 1.0,-1.0);
		const float2 BR = float2( 1.0, 1.0);

                const float2 uvTL = (TL + float2(1.0, 1.0))/2;
		const float2 uvTR = (TR + float2(1.0, 1.0))/2;
		const float2 uvBL = (BL + float2(1.0, 1.0))/2;
		const float2 uvBR = (BR + float2(1.0, 1.0))/2;

                for (int i = 0; i < SAMPLECNT; ++i)
                {
                    uint idx = i + operationID * SAMPLECNT;

                    if (idx > 1024) {
                        break;
                    }

                    float ttl = particle_getTTL(idx);
                    if (ttl <= 0) {
                        continue;
                    }

                    // float3 pointOut = random3(_Time.xyz + i);
                    part3 pointOut = particle_getPos(idx);
                    float4 color = particle_getColor(idx);
                    o.color = color;

                    float4 pointTL, pointTR, pointBL, pointBR;
                    pointTL = UnityObjectToClipPos(pointOut + billboard(TL*_PointSize, IN[0].worldScale.xy));
		    pointTR = UnityObjectToClipPos(pointOut + billboard(TR*_PointSize, IN[0].worldScale.xy));
		    pointBL = UnityObjectToClipPos(pointOut + billboard(BL*_PointSize, IN[0].worldScale.xy));
		    pointBR = UnityObjectToClipPos(pointOut + billboard(BR*_PointSize, IN[0].worldScale.xy));

                    o.vertex = pointTL; o.uv = uvTL;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);
                    o.vertex = pointTR; o.uv = uvTR;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);
                    o.vertex = pointBL; o.uv = uvBL;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);

                    o.vertex = pointBL; o.uv = uvBL;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);
                    o.vertex = pointBR; o.uv = uvBR;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);
                    o.vertex = pointTR; o.uv = uvTR;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);

                    stream.RestartStrip();
                }
            }

/*
            float linefn(float a)
            {
                return -clamp((1.0-pow(0.5/abs(a), .9)), -2, 0);
            }
*/
            float4 frag(g2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);


/*                
                float val = linefn(length((frac(i.uv.xy) - float2(0.5, 0.5))*2));
                float4 col = clamp(val*i.color, 0.0, 4.0);
                col.a *= _AlphaMultiplier;
                
                // float4 col = float4(1,1,0,1);
                // float4 col = i.color;
*/
                
                float4 col = get_frag(get_uv(i.uv), i.uv);
                col *= i.color+1;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}

