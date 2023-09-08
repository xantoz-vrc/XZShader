Shader "Xantoz/ParticleCRT/ParticleCRTGun"
{
    Properties
    {
    }

    CGINCLUDE
    #include "../cginc/flexcrt.cginc"
    ENDCG

    SubShader
    {
	Tags { }
	ZTest always
	ZWrite Off
        Lighting Off

	Pass
	{
	    Name "Receive pixels"

	    CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geo
            #pragma multi_compile_fog
            #pragma target 5.0

            struct v2g
            {
                float4 vertex : SV_POSITION;
                uint2 batchID : TEXCOORD0;
            };

	    v2g vert(appdata_customrendertexture IN)
	    {
		v2g o;
		o.batchID = IN.vertexID / 6;

		// This is unused, but must be initialized otherwise things get janky.
		o.vertex = 0.;
		return o;
	    }

            #define GEOPRIMID_COUNT 2
            [maxvertexcount(128)]
            void geo(point v2g input[1], inout PointStream<g2f> stream, uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
	    {
		int batchID = input[0].batchID;
            }

	    uint4 frag( g2f IN ) : SV_Target
	    {
		return IN.color;
	    }
	    ENDCG
	}
    }
}
