Shader "Xantoz/PixelSendCRT"
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

    CGINCLUDE
    #define CRTTEXTURETYPE float4
    #include "../cginc/flexcrt.cginc"
    
    #define POS_PIXEL uint2(0,0)
    #define CLK_PIXEL uint2(1,0)

    #define WIDTH _CustomRenderTextureWidth
    #define HEIGHT (_CustomRenderTextureHeight - 1)
    // #define WIDTH 64
    // #define HEIGHT 64
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

                if (_Reset != 0) {
                    uint2 pos = uint2(0,0);
                    set_pos_noscale(pos);
                } else if (prevCLK != _CLK)  {
                    uint2 pos = get_pos_noscale();
                    float raw_value[16] = {
                        _V0, _V1, _V2, _V3, _V4, _V5, _V6, _V7,
                        _V8, _V9, _VA, _VB, _VC, _VD, _VE, _VF,
                    };

                    for (uint i = 0; i < 16; ++i) {
                        float4 value = float4(raw_value[i], raw_value[i], raw_value[i], raw_value[i]);
                        uint2 paint_pos = pos + uint2(0,1);
                        set_pixel(paint_pos, value);
                        incrementPos(pos);
                    }

                    set_pos_noscale(pos);
                }

                set_CLK(_CLK);
	    }
	    ENDCG
	}
    }
}
