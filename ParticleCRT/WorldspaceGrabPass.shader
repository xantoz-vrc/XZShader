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
            "Queue"="Background-1"
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
        #include "../cginc/uintToHalf3.cginc"

        float4 _XZWorldspaceGrabPass_TexelSize;
	ENDCG

	Pass
        {
	    CGPROGRAM

	    #pragma require geometry
	    #pragma vertex vert
	    #pragma fragment frag

	    struct vi
            {
		float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
	    };

	    struct v2f
	    {
		float4 vertex : SV_POSITION;
                float4 grabPos : TEXCOORD4;
	    };

	    v2f vert(vi v)
	    {
		v2f o;
                o.vertex = float4(float2(1,-1)*(v.uv*2-1),0,1);
                o.grabPos = ComputeGrabScreenPos(o.vertex);
		return o;
	    }

	    float4 frag (v2f i) : SV_Target
            {
		float4 col;
                col.a = 1.0;

                int2 xy = floor((i.grabPos.xy/i.grabPos.w)*_XZWorldspaceGrabPass_TexelSize.zw);
#if UNITY_UV_STARTS_AT_TOP
                xy.y = _XZWorldspaceGrabPass_TexelSize.w - xy.y - 1;
#endif

                const float4x4 m = UNITY_MATRIX_M;

                if (true) {
                // if (xy.y <= 1) {
		    if (xy.x == 0) {
		        col.rgb = uintToHalf3(asuint(m._m00));
		    } else if (xy.x == 1) {
		        col.rgb = uintToHalf3(asuint(m._m01));
		    } else if (xy.x == 2) {
		        col.rgb = uintToHalf3(asuint(m._m02));
		    } else if (xy.x == 3) {
		        col.rgb = uintToHalf3(asuint(m._m03));

		    } else if (xy.x == 4) {
		        col.rgb = uintToHalf3(asuint(m._m10));
		    } else if (xy.x == 5) {
		        col.rgb = uintToHalf3(asuint(m._m11));
                    } else if (xy.x == 6) {
		        col.rgb = uintToHalf3(asuint(m._m12));
                    } else if (xy.x == 7) {
		        col.rgb = uintToHalf3(asuint(m._m13));

		    } else if (xy.x == 8) {
		        col.rgb = uintToHalf3(asuint(m._m20));
		    } else if (xy.x == 9) {
		        col.rgb = uintToHalf3(asuint(m._m21));
                    } else if (xy.x == 10) {
		        col.rgb = uintToHalf3(asuint(m._m22));
                    } else if (xy.x == 11) {
		        col.rgb = uintToHalf3(asuint(m._m23));

		    } else if (xy.x == 12) {
		        col.rgb = uintToHalf3(asuint(m._m30));
		    } else if (xy.x == 13) {
		        col.rgb = uintToHalf3(asuint(m._m31));
                    } else if (xy.x == 14) {
		        col.rgb = uintToHalf3(asuint(m._m32));
                    } else if (xy.x == 15) {
		        col.rgb = uintToHalf3(asuint(m._m33));

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

	GrabPass { "_XZWorldspaceGrabPass" }
    }
}
