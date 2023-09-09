Shader "Xantoz/ParticleCRT/WorldspaceGrabPass"
{
    Properties
    {
    }

    
    SubShader
    {
	// Tags { "RenderType"="Transparent" "Queue"="Transparent" "DisableBatching"="True" "IgnoreProjector" = "True" }

        // Settings to be on top of everything
        // TODO: Eventually we will want to try to be below everything instead
	Tags {
            "RenderType"="Transparent"
            "Queue"="Overlay+100" 
            "DisableBatching"="True"
            "IgnoreProjector" = "True"
        }
        LOD 100
        Cull Off
        ZTest Always
        ZWrite Off

	CGINCLUDE
	#pragma target 5.0

	#include "UnityCG.cginc"
        #include "uintToHalf3.cginc"

        float4 _XZWorldspaceGrabPass_TexelSize;
	ENDCG

	Pass {
	    CGPROGRAM

	    #pragma require geometry
	    #pragma vertex vert
	    #pragma fragment frag

	    struct vi
            {
		float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
	    };

	    struct v2f
	    {
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
		float3 worldPos : TEXCOORD2;
                float3 normal : TEXCOORD3;
                float4 grabPos : TEXCOORD4;
	    };

	    uint _Width;

	    v2f vert(vi v)
	    {
		v2f o;
		// o.vertex = v.vertex;
                o.vertex = float4(float2(1,-1)*(v.uv*2-1),0,1);
		o.uv = v.uv;
                o.normal = v.normal;
		// o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz; // TODO: This will vary slightly over frag, we should probably be using a  geometry shader with a single-point mesh or so
                // o.worldPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
                o.worldPos = mul(UNITY_MATRIX_M, float4(0, 0, 0, 1));
                // o.grabPos = ComputeScreenPos(o.vertex);
                o.grabPos = ComputeGrabScreenPos(o.vertex);
                // o.grabPos = ComputeGrabScreenPos(UnityObjectToClipPos(v.vertex));
		return o;
	    }

	    float4 frag (v2f i) : SV_Target 
            {
		float4 col;
                col.a = 1.0;

                // int2 xy = floor((i.grabPos.xy/i.grabPos.w)*_XZWorldspaceGrabPass_TexelSize.xy);
                // int2 xy = floor((i.grabPos.xy/i.grabPos.w)*_XZWorldspaceGrabPass_TexelSize.zw);
                int2 xy = floor((i.grabPos.xy/i.grabPos.w)*_ScreenParams.xy);
#if UNITY_UV_STARTS_AT_TOP
                xy.y = _ScreenParams.y - xy.y - 1;
#endif

                if (true) {
                // if (xy.y <= 200) { 
		    if (xy.x == 0) {
		        col.rgb = uintToHalf3(asuint(i.worldPos.x));
		    } else if (xy.x == 1) {
		        col.rgb = uintToHalf3(asuint(i.worldPos.y));
		    } else if (xy.x == 2) {
		        col.rgb = uintToHalf3(asuint(i.worldPos.z));
		    } else if (xy.x == 3) {
		        col.rgb = uintToHalf3(asuint(i.normal.x));
		    } else if (xy.x == 4) {
		        col.rgb = uintToHalf3(asuint(i.normal.y));
		    } else if (xy.x == 5) {
		        col.rgb = uintToHalf3(asuint(i.normal.z));
                    } else {
                        discard;
		    }
                } else {
                    discard;
                }
		return col;
	    }

	    ENDCG
	}
/*
	Pass {
	    CGPROGRAM

            #define PIXELTYPES 8
            #define PIXELSIZE 1
            #define PIXELWIDTH (PIXELTYPES*PIXELSIZE)
            #define TEXSIZE 16
            #define PIXELHEIGHT PIXELSIZE
            
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
