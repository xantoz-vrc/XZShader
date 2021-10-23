﻿    Shader "Xantoz/AudioLinkVis"
    {
        Properties
        {
            _MainTex ("Texture", 2D) = "white" {}
        }
        SubShader
        {
            Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
            //Tags { "RenderType"="Opaque" }
            LOD 100

            Pass
            {
                ZWrite Off
                Blend SrcAlpha OneMinusSrcAlpha
                Cull Off
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                // make fog work
                #pragma multi_compile_fog
                
                #include "UnityCG.cginc"

                struct appdata
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float2 uv : TEXCOORD0;
                    UNITY_FOG_COORDS(1)
                    float4 vertex : SV_POSITION;
                };

                sampler2D _MainTex;
                float4 _MainTex_ST;
                Texture2D<float4> _AudioTexture;

                v2f vert (appdata v)
                {
                    v2f o;
                    o.vertex = UnityObjectToClipPos(v.vertex);
                    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                    UNITY_TRANSFER_FOG(o,o.vertex);
                    return o;
                }

                float4 AudioLinkLerp(float2 xy)
                {
                    return lerp(_AudioTexture[int2(xy.x, xy.y)], _AudioTexture[int2(xy.x, xy.y) + int2(1,0)], frac(xy.x));
                }

                float dist_to_line(float a, float b)
                {
                    return clamp((1.0-pow(0.1/abs(a - b), .1)), -200, 0);
                }

                float get_value_horiz_line(float2 xy)
                {
                    float4 pcm_value = AudioLinkLerp(float2(frac(xy.x)*127, 6));
                    float dist = xy.y;

                    return dist_to_line(dist - 0.5, pcm_value.r);
                }

                float get_value_circle(float2 xy)
                {
                    float2 cdist = (xy - float2(0.5,0.5))*2;
                    float dist = sqrt(cdist.x*cdist.x + cdist.y*cdist.y);
                    float angle = atan2(cdist.x, cdist.y);

                    float4 pcm_value = AudioLinkLerp(float2(frac((angle+UNITY_PI)/(2*UNITY_PI))*127, 6));       

                    return dist_to_line(dist - 0.5, pcm_value.r*0.5);
                }

                float get_value_xy(float2 xy)
                {
                    // TODO
                    return 0.0;
                }

                float4 frag (v2f i) : SV_Target
                {
                    float4 col = float4(0,0,0,0);

                    uint w, h;
                    _AudioTexture.GetDimensions(w,h);
                    if (w > 16)
                    {
                        float val = get_value_circle(i.uv.xy);
                        col = float4(1,1,1,1)*val;
                    }

                    // apply fog
                    UNITY_APPLY_FOG(i.fogCoord, col);
                    return col;
                }
                ENDCG
            }
        }
    }
