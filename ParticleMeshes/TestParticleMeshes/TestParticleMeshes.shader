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

Shader "Xantoz/TestParticleMeshes"
{
    Properties
    {
        _PointSize ("Point Size", Float) = 0.1
        _AlphaMultiplier ("Alpha Multiplier (lower makes more transparent)", Range(0.0, 2.0)) = 0.5

        [KeywordEnum(Point,Line,Triangle)]_Input ("Geometry shader input", Int) = 0
        _In ("In", Int) = 0
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
    ENDCG

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "VRCFallback"="Hidden" }
        LOD 100
        Cull Off
        ZWrite Off

        Pass
        {
            Blend SrcAlpha One
            Blend SrcAlpha OneMinusSrcAlpha
            // Blend One One

            CGPROGRAM
            #pragma multi_compile_local _INPUT_POINT _INPUT_LINE _INPUT_TRIANGLE

            float _PointSize;
            float _AlphaMultiplier;
            uint _In;

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
                uint vertexID : TEXCOORD1_nointerpolation;
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

            v2g vert(appdata v)
            {
                v2g o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2g, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = v.vertex;
                o.vertexID = v.vertexID;
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

	    [instance(4)]
            [maxvertexcount(6)]
#if defined(_INPUT_POINT)
	    void geom(point v2g IN[1], inout TriangleStream<g2f> stream, uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
#elif defined(_INPUT_LINE)
	    void geom(line v2g IN[2], inout TriangleStream<g2f> stream, uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
#else // _INPUT_TRIANGLE
	    void geom(triangle v2g IN[3], inout TriangleStream<g2f> stream, uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
#endif
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN[0]);

		int batchID = IN[_In].batchID;
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

                // uint idx = i + operationID * SAMPLECNT;

                o.color = float4(1,0,IN[_In].vertexID%2,1);

                const float div = 8.0f;
                float pointSize = _PointSize;
                float3 pointOut = float3(float(IN[_In].vertexID) / div, float(instanceID) / div, -float(geoPrimID) / div);

                float4 pointTL, pointTR, pointBL, pointBR;
                pointTL = UnityObjectToClipPos(pointOut + billboard(TL*pointSize, IN[_In].worldScale.xy));
		pointTR = UnityObjectToClipPos(pointOut + billboard(TR*pointSize, IN[_In].worldScale.xy));
		pointBL = UnityObjectToClipPos(pointOut + billboard(BL*pointSize, IN[_In].worldScale.xy));
		pointBR = UnityObjectToClipPos(pointOut + billboard(BR*pointSize, IN[_In].worldScale.xy));

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

            float linefn(float a)
            {
                return -clamp((1.0-pow(0.5/abs(a), .9)), -2, 0);
            }

            float4 frag(g2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);


                float val = linefn(length((frac(i.uv.xy) - float2(0.5, 0.5))*2));
                float4 color_in = i.color;
                float4 col = clamp(val*color_in, 0.0, 4.0);
                col.a *= _AlphaMultiplier;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}

