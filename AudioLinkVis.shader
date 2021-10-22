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

                float4 AudioLinkLerp(float2 xy)
                {
                    return lerp(_AudioTexture[int2(xy.x, xy.y)], _AudioTexture[int2(xy.x, xy.y) + int2(1,0)], frac(xy.x));
                }

                float4 frag (v2f i) : SV_Target
                {
                    //float2 cdist = i.uv.xy - float2(0.5,0.5);
                    //float dist = sqrt(cdist.x*cdist.x + cdist.y*cdist.y);

                    //float4 pcm_value = _AudioTexture[int2(frac(i.uv.x)*128, 6)];
                    float4 pcm_value = AudioLinkLerp(float2(frac(i.uv.x)*127, 6));

                    //fixed4 col = float4(0,0,0,0);
                    //if (abs(frac(i.uv.y)-0.5 - pcm_value.g) < 0.01) {
                    //    col = fixed4(1,1,1,1);
                    //}

                    //float val = 1.0-pow(clamp(abs(frac(i.uv.y)-0.5 - pcm_value.g), 0, 1.0),0.25);
                    //float val = 1.0-pow(1.0/abs(frac(i.uv.y)-0.5 - pcm_value.g), .25);
                    //float val = 1.0-pow(1.0/abs(frac(i.uv.y)-0.5 - pcm_value.g), .1);
                    //float val = 1.0-pow(0.1/abs(frac(i.uv.y)-0.5 - pcm_value.r), .1);
                    //float val = abs(1.0-pow(0.1/abs(frac(i.uv.y)-0.5 - pcm_value.r), .1));
                    float val = clamp((1.0-pow(0.1/abs(frac(i.uv.y)-0.5 - pcm_value.r), .1)), -200, 0);
                    float4 col = float4(1,1,1,1)*val;

                    //fixed4 col = pcm_value;
                    

                    // apply fog
                    UNITY_APPLY_FOG(i.fogCoord, col);
                    return col;
                }
                ENDCG
            }
        }
    }
