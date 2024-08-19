Shader "Xantoz/PixelSendCRT"
{
    Properties
    {
        _V ("Gray scale value", Float) = 0.0
        [ToggleUI]_WR("Write", Integer) = 0
        [ToggleUI]_Reset("Reset", Integer) = 0
    }

    CGINCLUDE
    #define CRTTEXTURETYPE float4
    #include "../cginc/flexcrt.cginc"
    
    #define POS_PIXEL uint2(0,0)
    #define WR_PIXEL uint2(1,0)

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

            float _V;
            int _WR;
            int _Reset;
 
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

            int get_prev_WR()
            {
                return int(get_pixel(WR_PIXEL).x);
            }

            #define set_wr(value) set_pixel(WR_PIXEL, float4((value), (value), (value), (value)))

            [maxvertexcount(128)]
	    void geom(triangle v2g input[3], inout PointStream<g2f> stream, uint geoPrimID : SV_PrimitiveID)
	    {
                // We only run once as it stands now, we only run once
                if (geoPrimID != 0) {
                    return;
                }

                g2f o;

                int prevWR = get_prev_WR();

                if (_Reset != 0) {
                    uint2 pos = uint2(0,0);
                    set_pos_noscale(pos);
                } else if (prevWR != _WR)  {
                    uint2 pos = get_pos_noscale();
                    float4 value = float4(_V,_V,_V,_V);
                    uint2 paint_pos = pos + uint2(0,1);
                    set_pixel(paint_pos, value);

                    if (pos.x >= uint(WIDTH)) {
                        if (pos.y < uint(HEIGHT)) {
                            pos.y += 1;
                            pos.x = 0;
                        }
                    } else {
                        pos.x += 1;
                    }

                    set_pos_noscale(pos);
                }

                set_wr(_WR);
	    }
	    ENDCG
	}
    }
}
