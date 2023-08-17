Shader "Xantoz/ParticleCRT/WorldspaceGrabPass"
{
    Properties
    {
    }

    
    SubShader
    {
	Tags { "RenderType"="Transparent" "Queue"="Transparent" "DisableBatching"="True" "IgnoreProjector" = "True" }

	CGINCLUDE
	#pragma target 5.0

	#include "UnityCG.cginc"
	#include "Common.cginc"

        #define PIXELTYPES 8
        #define PIXELSIZE 1
        #define PIXELWIDTH (PIXELTYPES*PIXELSIZE)
        #define TEXSIZE 16
        #define PIXELHEIGHT PIXELSIZE

        //Merlin. For details see https://github.com/pema99/shader-knowledge/blob/main/tips-and-tricks.md#encoding-and-decoding-data-in-a-grabpass
        float uint14ToFloat(uint input)
        {
	    precise float output = (f16tof32((input & 0x00003fff)));
	    return output;
        }

        uint floatToUint14(precise float input)
        {
	    uint output = (f32tof16(input)) & 0x00003fff;
	    return output;
        }

        // Encodes a 32 bit uint into 3 half precision floats
        float3 uintToHalf3(uint input)
        {
	    precise float3 output = float3(uint14ToFloat(input), uint14ToFloat(input >> 14), uint14ToFloat((input >> 28) & 0x0000000f));
	    return output;
        }

        uint half3ToUint(precise float3 input)
        {
	    return floatToUint14(input.x) | (floatToUint14(input.y) << 14) | ((floatToUint14(input.z) & 0x0000000f) << 28);
        }
	ENDCG

	Pass {
	    CGPROGRAM

	    #pragma require geometry
	    #pragma vertex vert
	    #pragma fragment frag
	    #pragma geometry geom

	    struct vi
            {
		float4 vertex : POSITION;
                float3 normal : NORMAL;
	    };

	    struct v2f
	    {
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
		float3 worldPos : TEXCOORD2;
                float3 normal : TEXCOORD3;
	    };

	    uint _Width;

	    v2g vert(vi v)
	    {
		v2g o;
		o.vertex = v.vertex;
		o.uv = v.uv;
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
		    col.rgb = uintToHalf3(asuint(i.direction.x));
		} else if( id == 4) {
		    col.rgb = uintToHalf3(asuint(i.direction.y));
		} else if( id == 5) {
		    col.rgb = uintToHalf3(asuint(i.direction.z));
                } else {
		    col.rgb = 0.;
		}
		return col;

	    }

	    ENDCG
	}
/*
	Pass {
	    CGPROGRAM

	    #pragma require geometry
	    #pragma vertex vert
	    #pragma fragment frag
	    #pragma geometry geom

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
		float3 worldPos : TEXCOORD2;
                float3 direction : TEXCOORD3;
	    };

	    uint _Width;

	    v2g vert(vi v)
	    {
		v2g o;
		o.vertex = v.vertex;
		o.uv = v.uv;
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
		    col.rgb = uintToHalf3(asuint(i.direction.x));
		} else if( id == 4) {
		    col.rgb = uintToHalf3(asuint(i.direction.y));
		} else if( id == 5) {
		    col.rgb = uintToHalf3(asuint(i.direction.z));
                } else {
		    col.rgb = 0.;
		}
		return col;

	    }

	    ENDCG
	}
*/
	GrabPass { "_XZWorldspaceGrabPass" }
    }
}
