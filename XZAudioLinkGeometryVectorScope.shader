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

        _Amplitude_Scale ("Amplitude Scale", Range(0.0, 2.0)) = 1.0  // Scale amplitude of PCM & DFT data in plots

        [Space(10)]
        [Header(Color Blink)]
        [HDR]_Color2 ("Color 2 (Blink Base Color)", Color) = (1,1,1,1)
        [HDR]_Color_Mul_Band0 ("Color Bass", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band1 ("Color Low Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band2 ("Color High Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band3 ("Color Treble", Color) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "VRCFallback"="Hidden" }
        LOD 100
        Cull Off

        Pass
        {
            ZWrite Off
            Blend SrcAlpha One

            Cull Off
            CGPROGRAM
            #pragma target 5.0

            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            
            #include "UnityCG.cginc"
            #include "cginc/AudioLinkFuncs.cginc"

            float _Amplitude_Scale;

            float4 _Color1;
            float4 _Color2;
            float4 _Color_Mul_Band0;
            float4 _Color_Mul_Band1;
            float4 _Color_Mul_Band2;
            float4 _Color_Mul_Band3;

            struct appdata
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
	        uint vertexID : SV_VertexID;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2g
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                uint2 batchID : TEXCOORD1;

                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            struct g2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;

                UNITY_FOG_COORDS(6)
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
                o.uv = v.uv;

                return o;
            }

            #define SAMPLECNT 8

            // 6 input points * 32 instances * 8 vertexes out = 1536 samples out
	    [maxvertexcount(SAMPLECNT)]
	    [instance(32)]
	    void geom(point v2g IN[1], inout PointStream<g2f> stream,
		uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
	    {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN[0]);

		int batchID = IN[0].batchID;
             	int operationID = geoPrimID * 32 + ( instanceID - batchID );

                g2f o;
                UNITY_INITIALIZE_OUTPUT(g2f, o);
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(IN[0], o);

                o.uv = IN[0].uv;

                for (int i = 0; i < SAMPLECNT; ++i)
                {
                    uint sampleID = i + operationID * SAMPLECNT;
                    float2 pcm_lr = PCMToLR(AudioLinkPCMData(sampleID)*_Amplitude_Scale);
                    float4 pointOut = float4(pcm_lr, 0.0, 1.0);
                    
                    o.vertex = UnityObjectToClipPos(pointOut);
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);
                }
            }

            float4 frag(g2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

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

                float4 col = (_Color1 + _Color2*al_color_mult)/2;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}