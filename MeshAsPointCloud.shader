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

Shader "Xantoz/MeshAsPointCloud"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

        _PointSize ("Point Size", Float) = 0.1
        _AlphaMultiplier ("Alpha Multiplier (lower makes more transparent)", Range(0.0, 2.0)) = 0.5

        [Toggle(ENABLE_CLONES)] _EnableClones("Enable clones (silly effect)", Float) = 0
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
        // ZTest always

        Pass
        {
            Blend SrcAlpha One
            // Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma multi_compile_local __ ENABLE_CLONES

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float _PointSize;
            float _AlphaMultiplier;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 vertexColor : COLOR;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

	    struct v2g
	    {
		float4 vertex : POSITION0;
                float2 uv : TEXCOORD0;
                float3 worldScale : COLOR0;
                float4 vertexColor : COLOR1;

		UNITY_VERTEX_OUTPUT_STEREO
            };

            struct g2f
            {
                float2 uv : TEXCOORD0;
                float2 origUV : TEXCOORD1;
                float4 vertex : POSITION0;
                float4 vertexColor : COLOR1;
#ifdef ENABLE_CLONES
                uint instanceID : COLOR3;
#endif

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
                o.uv = v.uv;

                o.vertexColor = v.vertexColor;

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

            // TODO: add hull stages and so so we can artificially make a denser point cloud?

            [maxvertexcount(6)]
#ifdef ENABLE_CLONES
            [instance(3)]
#endif
	    void geom(point v2g IN[1], inout TriangleStream<g2f> stream,
		uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN[0]);

                g2f o;
                UNITY_INITIALIZE_OUTPUT(g2f, o);
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(IN[0], o);

                o.vertexColor = IN[0].vertexColor;
                o.origUV = IN[0].uv;

                const float2 TL = float2(-1.0,-1.0);
		const float2 TR = float2(-1.0, 1.0);
		const float2 BL = float2( 1.0,-1.0);
		const float2 BR = float2( 1.0, 1.0);

                const float2 uvTL = (TL + float2(1.0, 1.0))/2;
		const float2 uvTR = (TR + float2(1.0, 1.0))/2;
		const float2 uvBL = (BL + float2(1.0, 1.0))/2;
		const float2 uvBR = (BR + float2(1.0, 1.0))/2;

                float3 pointOut = IN[0].vertex;

                float4 pointTL, pointTR, pointBL, pointBR;

#ifdef ENABLE_CLONES
                if (instanceID == 2) {
                    pointOut.x -= 1.5;
                } else {
                    pointOut.x += instanceID*1.5;
                }
                o.instanceID = instanceID;
#endif

                // TODO: seems like the billboarding version is not quite scale-correct
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

            float linefn(float a)
            {
                return -clamp((1.0-pow(0.5/abs(a), .1)), -2, 0);
            }

            float4 frag(g2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float val = linefn(length((frac(i.uv.xy) - float2(0.5, 0.5))*2));

                float4 texCol = tex2D(_MainTex, i.origUV);
#ifdef ENABLE_CLONES
                if (i.instanceID == 1) {
                    texCol.rgb = float3(texCol.b, texCol.r, texCol.g);
                } else if (i.instanceID == 2) {
                    texCol.rgb = float3(texCol.g, texCol.b, texCol.r);
                }
#endif

                float4 col = val*texCol;
                col.a *= _AlphaMultiplier;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
