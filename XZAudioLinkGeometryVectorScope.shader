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

Shader "Xantoz/XZAudioLinkGeometryVectorScope"
{
    Properties
    {
        [HDR]_Color1 ("Color 1 (Base Color)", Color) = (1,1,1,1)

        [IntRange]_3D ("3D effect (move in Z direction as well)", Range(0,1)) = 0

        _PointSize ("Point Size", Float) = 0.1
        _AlphaMultiplier ("Alpha Multiplier (lower makes more transparent)", Range(0.0, 2.0)) = 0.5

        _Amplitude_Scale ("Amplitude Scale", Range(0.0, 2.0)) = 1.0  // Scale amplitude of PCM & DFT data in plots

        [Space(10)]
        [Header(Color Blink)]
        [HDR]_Color2 ("Color 2 (Blink Base Color)", Color) = (1,1,1,1)
        [HDR]_Color_Mul_Band0 ("Color Bass", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band1 ("Color Low Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band2 ("Color High Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band3 ("Color Treble", Color) = (0,0,0,0)
    }

    CGINCLUDE
        #pragma vertex vert
        #pragma fragment frag
        #pragma geometry geom
        #pragma multi_compile_fog
        #pragma multi_compile_instancing
        #pragma target 5.0
        #pragma exclude_renderers gles metal

        #include "UnityCG.cginc"
        #include "cginc/AudioLinkFuncs.cginc"
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
            Blend SrcAlpha One
            // Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM

            float _PointSize;
            float _AlphaMultiplier;

            float _Amplitude_Scale;

            int _3D;

            float4 _Color1;
            float4 _Color2;
            float4 _Color_Mul_Band0;
            float4 _Color_Mul_Band1;
            float4 _Color_Mul_Band2;
            float4 _Color_Mul_Band3;

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
                float3 worldScale : COLOR0;

		UNITY_VERTEX_OUTPUT_STEREO
            };

            struct g2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : POSITION0;

                UNITY_FOG_COORDS(1)
                UNITY_VERTEX_OUTPUT_STEREO
            };

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
                return mul(UNITY_MATRIX_P,
		    mul(UNITY_MATRIX_MV, float4(0.0, 0.0, 0.0, 1.0))
		    + float4(xy, 0.0, 0.0) * float4(scale, 1.0, 1.0)
                );
            }

            // 6 input points * 32 instances * 8 samples per instance = 1536 samples out
            #define SAMPLECNT 8

            // 8 samples * 6 vertices out (quad)
            [maxvertexcount(SAMPLECNT*6)]
	    [instance(32)]
	    void geom(point v2g IN[1], inout TriangleStream<g2f> stream,
		uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN[0]);

		int batchID = IN[0].batchID;
             	int operationID = geoPrimID * 32 + ( instanceID - batchID );

                g2f o;
                UNITY_INITIALIZE_OUTPUT(g2f, o);
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(IN[0], o);

                if (!AudioLinkIsAvailable())
                {
                    return;
                }

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
                    uint sampleID = i + operationID * SAMPLECNT;
                    float4 pcm = AudioLinkPCMData(sampleID)*0.5*_Amplitude_Scale;
                    float2 pcm_lr = PCMToLR(pcm);
                    float3 pointOut = float3(pcm_lr, 0.0);

                    float4 pointTL, pointTR, pointBL, pointBR;
                    if (_3D) {
                        pointOut.z = pcm.g;

                        pointTL = UnityObjectToClipPos(pointOut) + billboard(TL, IN[0].worldScale.xy)*_PointSize;
			pointTR = UnityObjectToClipPos(pointOut) + billboard(TR, IN[0].worldScale.xy)*_PointSize;
			pointBL = UnityObjectToClipPos(pointOut) + billboard(BL, IN[0].worldScale.xy)*_PointSize;
			pointBR = UnityObjectToClipPos(pointOut) + billboard(BR, IN[0].worldScale.xy)*_PointSize;
                    } else {
                        pointTL = UnityObjectToClipPos(pointOut + float3(TL*_PointSize, 0.0));
                        pointTR = UnityObjectToClipPos(pointOut + float3(TR*_PointSize, 0.0));
                        pointBL = UnityObjectToClipPos(pointOut + float3(BL*_PointSize, 0.0));
                        pointBR = UnityObjectToClipPos(pointOut + float3(BR*_PointSize, 0.0));
                    }

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

            float linefn(float a)
            {
                return -clamp((1.0-pow(0.5/abs(a), .1)), -2, 0);
            }

            float4 frag(g2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                if (!AudioLinkIsAvailable())
                {
                    return float4(0,0,0,0);
                }

                float al_beat[4] = {
                    AudioLinkData(uint2(0,0)).r,
                    AudioLinkData(uint2(0,1)).r,
                    AudioLinkData(uint2(0,2)).r,
                    AudioLinkData(uint2(0,3)).r
                };
                float4 al_color_mult =
                    _Color_Mul_Band0*al_beat[0] +
                    _Color_Mul_Band1*al_beat[1] +
                    _Color_Mul_Band2*al_beat[2] +
                    _Color_Mul_Band3*al_beat[3];

                float val = linefn(length((frac(i.uv.xy) - float2(0.5, 0.5))*2));

                float4 col = clamp(val*(_Color1 + _Color2*al_color_mult), 0.0, 1.0);
                col.a *= _AlphaMultiplier;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
