    Shader "Xantoz/AudioLinkVis"
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

                #define AUDIOLINK_WIDTH 128

                float4 AudioLinkData(uint2 xycoord)
                { 
                    return _AudioTexture[uint2(xycoord.x, xycoord.y)]; 
                }

                float4 AudioLinkDataMultiline(uint2 xycoord)
                { 
                    return _AudioTexture[uint2(xycoord.x % AUDIOLINK_WIDTH, xycoord.y + xycoord.x/AUDIOLINK_WIDTH)]; 
                }

                float4 AudioLinkLerpMultiline(float2 xy) 
                {
                    return lerp(AudioLinkDataMultiline(xy), AudioLinkDataMultiline(xy+float2(1,0)), frac(xy.x)); 
                }

                float4 AudioLinkLerp(float2 xy)
                {
                    return lerp(AudioLinkData(uint2(xy.x, xy.y)), AudioLinkData(uint2(xy.x, xy.y) + uint2(1,0)), frac(xy.x));
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
                    float2 cdist = (xy - float2(0.5,0.5))*2;
                    float index = xy.x + xy,y;

                    //float4 pcm_value = AudioLinkLerp(float2(frac(index*0.5)*127, 6));
                    float4 pcm_value = AudioLinkLerpMultiline(float2(frac(index*0.5)*2045, 6)); 
                    float l = pcm_value.r + pcm_value.a;
                    float r = pcm_value.r - pcm_value.a;
                    float distx = cdist.x - l;
                    float disty = cdist.y - r;

                    float dist = sqrt(distx*distx + disty*disty);

                    return dist_to_line(dist*0.25, 0);
                }

                float4 frag (v2f i) : SV_Target
                {
                    float4 col = float4(0,0,0,0);

                    uint w, h;
                    _AudioTexture.GetDimensions(w,h);
                    if (w > 16)
                    {
                        float val = get_value_circle(i.uv.xy);
                        //float val = get_value_xy(i.uv.xy);
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
