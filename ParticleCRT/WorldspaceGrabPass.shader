Shader "Xantoz/ParticleCRT/WorldspaceGrabPass"
{

    SubShader
    {
	Tags { "RenderType"="Transparent" "Queue"="Transparent" "DisableBatching"="True" "IgnoreProjector" = "True" }

	CGINCLUDE
	#pragma target 5.0
        #define PIXELTYPES 2
        #define PIXELSIZE 1
        #define PIXELWIDTH (PIXELTYPSE*PIXELSIZE)
        #define TEXSIZE 2
	ENDCG

	Pass {
	    CGPROGRAM

	    #pragma require geometry
	    #pragma vertex vert
	    #pragma fragment frag
	    #pragma geometry geom
	    #define USE_GRABPASS 1

	    #include "UnityCG.cginc"
	    #include "Common.cginc"


	    struct vi
            {
		float4 vertex : POSITION;
                float3 normal : NORMAL;
	    };

	    struct v2g
	    {
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
		float3 worldPos : TEXCOORD2;
                float3 normal : TEXCOORD3;
	    };

	    struct g2f
	    {
		float4 vertex : SV_POSITION;
		float3 color : TEXCOORD1;
		float3 worldPos : TEXCOORD2;
                float3 normal : TEXCOORD3;
	    };

	    uint _Width;

	    v2g vert(vi v)
	    {
		v2g o;
		o.vertex = v.vertex;
		o.uv = v.uv;
		if(o.rh.y > _HeightFactor) {
		    v.vertex.xyz = mul(unity_WorldToObject, float4(o.rh.x, _HeightFactor , o.rh.z, o.rh.w)).xyz;
		}

		o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
		return o;
	    }

	    [maxvertexcount(12)]
	    void geom(triangle v2g input[3], uint pid: SV_PrimitiveID, inout TriangleStream<g2f> triStream)
            {
		g2f o;
		uint width = uint2(TEXSIZE / PIXELWIDTH, 0.);

		for (int i = 0; i < 3; i++) {
		    uint id = pid * 3 + i;

		    o.uv = input[i].uv;
		    o.worldPos = input[i].worldPos;
                    o.normal = input[i].normal;

		    float4 sscale = float4( 2. / _ScreenParams.xy, 1,1);
		    float4 soffset = float4( -_ScreenParams.xy/2,0,0);
		    soffset += float4(  id % width * PIXELWIDTH, id / width * PIXELHEIGHT, 0, 0 );

		    o.vertex = ( float4(PIXELWIDTH,PIXELHEIGHT,1,1) + soffset ) * sscale;
		    o.uv = float2(PIXELTYPES,0);
		    triStream.Append(o);

		    o.vertex = ( float4(0,PIXELHEIGHT,1,1) + soffset ) * sscale;
		    o.uv = float2(0,0);
		    triStream.Append(o);

		    o.vertex = ( float4(PIXELWIDTH,0,1,1) + soffset ) * sscale;
		    o.uv = float2(PIXELTYPES,0);
		    triStream.Append(o);

		    o.vertex = ( float4(0,0,1,1) + soffset ) * sscale;
		    o.uv = float2(0,0);
		    triStream.Append(o);
		    triStream.RestartStrip();
		}
	    }

	    float4 frag (g2f i) : SV_Target 
            {
		float4 col;
		int id = floor(i.uv.x);
		if( id == 0 ) {
		    col.rgb = uintToHalf3(asuint(i.worldPos.x));
		} else if( id == 1) {
		    col.rgb = uintToHalf3(asuint(i.worldPos.y));
		} else if( id == 2) {
		    col.rgb = uintToHalf3(asuint(i.worldPos.z));
		} else if( id == 3) {
		    col.rgb = uintToHalf3(asuint(i.rh.x));
		} else if( id == 4) {
		    col.rgb = uintToHalf3(asuint(i.rh.y));
		} else if( id == 5) {
		    col.rgb = uintToHalf3(asuint(i.rh.z));
		} else if( id == 6) {
		    col.rgb = uintToHalf3(asuint(i.rh.w));
		}
		else if( id == 7) {
		    col.rgb = uintToHalf3(asuint(i.up));
		}
		else {
		    col.rgb = 0.;
		}
		return col;

	    }

	    ENDCG
	}

	GrabPass { "_XZWorldspaceGrabPass" }
    }
}
