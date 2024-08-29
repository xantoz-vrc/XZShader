Shader "Xantoz/PixelSendCRTGrabPass"
{
    Properties
    {
      
        _V0 ("V0", Float) = 0.0
        _V1 ("V1", Float) = 0.0
        _V2 ("V2", Float) = 0.0
        _V3 ("V3", Float) = 0.0
        _V4 ("V4", Float) = 0.0
        _V5 ("V5", Float) = 0.0
        _V6 ("V6", Float) = 0.0
        _V7 ("V7", Float) = 0.0

        _V8 ("V8", Float) = 0.0
        _V9 ("V9", Float) = 0.0
        _VA ("VA", Float) = 0.0
        _VB ("VB", Float) = 0.0
        _VC ("VC", Float) = 0.0
        _VD ("VD", Float) = 0.0
        _VE ("VE", Float) = 0.0
        _VF ("VF", Float) = 0.0
        
        [ToggleUI]_CLK("Clock Signal (DDR)", Integer) = 0
        [ToggleUI]_Reset("Reset", Integer) = 0
    }
    
    SubShader
    {
	// Tags { "RenderType"="Transparent" "Queue"="Transparent" "DisableBatching"="True" "IgnoreProjector" = "True" }

        // Settings to be on top of everything
        // TODO: Eventually we will want to try to be below everything instead
	Tags {
            // "RenderType"="Transparent"
            // "Queue"="Background-1"
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

        float4 _PixelSendCRTGrabPass_TexelSize;

        // Params
            float _V0;
            float _V1;
            float _V2;
            float _V3;
            float _V4;
            float _V5;
            float _V6;
            float _V7;

            float _V8;
            float _V9;
            float _VA;
            float _VB;
            float _VC;
            float _VD;
            float _VE;
            float _VF;

        uint _CLK;
        uint _Reset;
	ENDCG

	Pass
        {
	    CGPROGRAM

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

                int2 xy = floor((i.grabPos.xy/i.grabPos.w)*_PixelSendCRTGrabPass_TexelSize.zw);
#if UNITY_UV_STARTS_AT_TOP
                xy.y = _PixelSendCRTGrabPass_TexelSize.w - xy.y - 1;
#endif

                const float4x4 m = UNITY_MATRIX_M;

                if (xy.y == 0) {
		    if (xy.x == 0) {
		        col.rgb = uintToHalf3(asuint(_V0));
                    } else if (xy.x == 1) {
		        col.rgb = uintToHalf3(asuint(_V1));
                    } else if (xy.x == 2) {
		        col.rgb = uintToHalf3(asuint(_V2));
                    } else if (xy.x == 3) {
		        col.rgb = uintToHalf3(asuint(_V3));
                    } else if (xy.x == 4) {
		        col.rgb = uintToHalf3(asuint(_V4));
                    } else if (xy.x == 5) {
		        col.rgb = uintToHalf3(asuint(_V5));
                    } else if (xy.x == 6) {
		        col.rgb = uintToHalf3(asuint(_V6));
                    } else if (xy.x == 7) {
		        col.rgb = uintToHalf3(asuint(_V7));

                    } else if (xy.x == 8) {
		        col.rgb = uintToHalf3(asuint(_V8));
                    } else if (xy.x == 9) {
		        col.rgb = uintToHalf3(asuint(_V9));
                    } else if (xy.x == 10) {
		        col.rgb = uintToHalf3(asuint(_VA));
                    } else if (xy.x == 11) {
		        col.rgb = uintToHalf3(asuint(_VB));
                    } else if (xy.x == 12) {
		        col.rgb = uintToHalf3(asuint(_VC));
                    } else if (xy.x == 13) {
		        col.rgb = uintToHalf3(asuint(_VD));
                    } else if (xy.x == 14) {
		        col.rgb = uintToHalf3(asuint(_VE));
                    } else if (xy.x == 15) {
		        col.rgb = uintToHalf3(asuint(_VF));

                    } else {
                        discard;
		    }
                } else if (xy.y == 1) {
		    if (xy.x == 0) {
		        col.rgb = uintToHalf3(_CLK);
		    } else if (xy.x == 1) {
		        col.rgb = uintToHalf3(_Reset);
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

	GrabPass { "_PixelSendCRTGrabPass" }
    }
}
