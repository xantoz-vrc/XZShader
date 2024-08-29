Shader "Xantoz/PixelSendCRT"
{
    Properties
    {
        [KeywordEnum(Params,GrabPass)]_Input ("Input mode", Integer) = 0

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

    CGINCLUDE
    #pragma multi_compile_local _INPUT_PARAMS _INPUT_GRABPASS

    #define CRTTEXTURETYPE float4
    #include "../cginc/flexcrt.cginc"
    
    #define POS_PIXEL uint2(0,0)
    #define CLK_PIXEL uint2(1,0)

    #define WIDTH _CustomRenderTextureWidth
    #define HEIGHT (_CustomRenderTextureHeight - 1)
    // #define WIDTH 64
    // #define HEIGHT 64

#if defined(_INPUT_PARAMS)
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

    void GetValues(inout float values[16])
    {
       values[0]  = _V0;
       values[1]  = _V1;
       values[2]  = _V2;
       values[3]  = _V3;
       values[4]  = _V4;
       values[5]  = _V5;
       values[6]  = _V6;
       values[7]  = _V7;
       values[8]  = _V8;
       values[9]  = _V9;
       values[10] = _VA;
       values[11] = _VB;
       values[12] = _VC;
       values[13] = _VD;
       values[14] = _VE;
       values[15] = _VF;
    }

    uint GetCLK()
    {
        return _CLK;
    }

    uint GetReset()
    {
        return _Reset;
    }
#endif

#if defined(_INPUT_GRABPASS)
    #include "../cginc/uintToHalf3.cginc"

    Texture2D<float4> _PixelSendCRTGrabPass;
    float4 _PixelSendCRTGrabPass_TexelSize;
    #define GRABSIZE _PixelSendCRTGrabPass_TexelSize.w

    float4 GetFromGrabPass(uint2 coord)
    {
	#if UNITY_UV_STARTS_AT_TOP
	return _PixelSendCRTGrabPass[uint2(coord.x,GRABSIZE-1-coord.y)];
	#else
	return _PixelSendCRTGrabPass[coord];
	#endif
    }

    bool GrabPassIsAvailable()
    {
        int width, height;
        _PixelSendCRTGrabPass.GetDimensions(width, height);
        return width > 16;
    }

    void GetValues(inout float values[16])
    {
        for (uint i = 0; i < 16; ++i) {
            values[i] = asfloat(half3ToUint(GetFromGrabPass(uint2(i, 0))));
        }
    }

    uint GetCLK()   { return half3ToUint(GetFromGrabPass(uint2(0,1))); }
    uint GetReset() { return half3ToUint(GetFromGrabPass(uint2(1,1))); }

#endif
    ENDCG

    SubShader
    {
	Tags { }
	ZTest always
	ZWrite Off
        Lighting Off

	Pass
	{
	    Name "Update"
	    
	    CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
            #pragma multi_compile_fog
            #pragma target 5.0
 
            struct v2g
            {
                float4 vertex : SV_POSITION;
                uint2 batchID : TEXCOORD0;
            };

            struct g2f
            {
                float4 vertex : SV_POSITION;
                float4 data : COLOR0;
            };

            // The vertex shader doesn't really perform much anything.
            v2g vert(appdata_customrendertexture IN)
            {
                v2g o;
                o.batchID = IN.vertexID / 6;

                // This is unused, but must be initialized otherwise things get janky.
                o.vertex = 0.;
                return o;
            }

            float4 frag(g2f IN) : SV_Target
            {
                return IN.data;
            }

            float4 get_pixel(uint2 pos)
            {
                return _SelfTexture2D[pos];
            }

            #define set_pixel(pos, value) \
            [unroll] \
            do { \
                o.vertex = FlexCRTCoordinateOut((pos)); \
                o.data = (value); \
                stream.Append(o); \
            } while (0)

            uint2 get_pos_noscale()
            {
                float4 pos_raw = get_pixel(POS_PIXEL);
                uint2 pos = uint2(pos_raw.xy);
                return pos;
            }

            #define set_pos_noscale(value) set_pixel(POS_PIXEL, float4((value).x, (value).y, 0.0, 0.0))

            uint get_prev_CLK()
            {
                return uint(get_pixel(CLK_PIXEL).x);
            }

            #define set_CLK(value) set_pixel(CLK_PIXEL, float4((value), (value), (value), (value)))

            void incrementPos(inout uint2 pos)
            {
                if (pos.x >= uint(WIDTH)) {
                    if (pos.y < uint(HEIGHT)) {
                        pos.y += 1;
                        pos.x = 0;
                    }
                } else {
                    pos.x += 1;
                }
            }

            [maxvertexcount(128)]
	    void geom(triangle v2g input[3], inout PointStream<g2f> stream, uint geoPrimID : SV_PrimitiveID)
	    {
                // We only run once as it stands now, we only run once
                if (geoPrimID != 0) {
                    return;
                }

                g2f o;

                uint prevCLK = get_prev_CLK();

                if (GetReset() != 0) {
                    uint2 pos = uint2(0,0);
                    set_pos_noscale(pos);
                } else if (prevCLK != GetCLK()) {
                    uint2 pos = get_pos_noscale();

                    float raw_value[16];
                    GetValues(raw_value);

                    for (uint i = 0; i < 16; ++i) {
                        float4 value = float4(raw_value[i], raw_value[i], raw_value[i], raw_value[i]);
                        uint2 paint_pos = pos + uint2(0,1);
                        set_pixel(paint_pos, value);
                        incrementPos(pos);
                    }

                    set_pos_noscale(pos);
                }

                set_CLK(GetCLK());
	    }
	    ENDCG
	}
    }
}
