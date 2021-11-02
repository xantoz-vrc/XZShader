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
                return _AudioTexture[uint2(
                        xycoord.x % AUDIOLINK_WIDTH,
                        xycoord.y + xycoord.x/AUDIOLINK_WIDTH)]; 
            }

            float4 AudioLinkLerpMultiline(float2 xy) 
            {
                return lerp(
                    AudioLinkDataMultiline(xy),
                    AudioLinkDataMultiline(xy + float2(1, 0)),
                    frac(xy.x)); 
            }

            float4 AudioLinkLerp(float2 xy)
            {
                return lerp(
                    AudioLinkData(uint2(xy.x, xy.y)),
                    AudioLinkData(uint2(xy.x, xy.y) + uint2(1,0)),
                    frac(xy.x));
            }

            // Index 0 to 2048
            float4 AudioLinkPCMData(uint i)
            {
                return AudioLinkDataMultiline(uint2(i, 6));
            }

            // Index 0 to 2048
            float4 AudioLinkPCMLerp(float i)
            {
                return AudioLinkLerpMultiline(float2(i, 6.0));
            }

            // Pick one of:
            // lr == 0: both channels (24 kHz red)
            // lr == 1: left channel
            // lr == 2: right channel
            float PCMConditional(float4 pcm_value, uint lr) {
                float result = pcm_value.r;
                if (lr == 1) {
                    result = pcm_value.r + pcm_value.a;
                } else if (lr == 2) {
                    result = pcm_value.r - pcm_value.a;
                }
                return result;
            }

            float2 PCMToLR(float4 pcm_value)
            {
                return float2(pcm_value.r + pcm_value.a, pcm_value.r - pcm_value.a);
            }

            // --- distance to line segment with caps (From: https://shadertoyunofficial.wordpress.com/2019/01/02/programming-tricks-in-shadertoy-glsl/)
            float dist_to_line(float2 p, float2 a, float2 b) {
                p -= a, b -= a;
                float h = clamp(dot(p, b) / dot(b, b), 0.0, 1.0); // proj coord on line
                return length(p - b * h);                        // dist to segment
            }

            // Converts a distance to a color value. Use to plot linee by putting in the distance from UV to your line in question.
            // Note: Currently outputs negative values because I have no idea what I'm doing, and negative values actually end up looking pretty good with our blending mode of choice.
            // TODO: Fix the above (might need changing what blending mode we use)
            float linefn(float a)
            {
                return clamp((1.0-pow(0.1/abs(a), .1)), -200, 0);
            }

            float get_value_horiz_line(float2 xy, uint nsamples, uint lr)
            {
                float pcm_val = PCMConditional(AudioLinkPCMLerp(frac(xy.x)*(nsamples-1)), lr);
                float dist = (frac(xy.y) - 0.5) - pcm_val;
                return linefn(dist);
            }

            float get_value_circle(float2 xy, float nsamples)
            float get_value_circle(float2 xy, float nsamples, uint lr)
            {
                float2 cpos = (frac(xy) - float2(0.5,0.5))*2;
                float cdist = length(cpos);
                float angle = atan2(cpos.x, cpos.y);
                float pcm_val = PCMConditional(
                    AudioLinkPCMLerp(frac((angle+UNITY_PI)/(2*UNITY_PI))*(nsamples-1)),
                    lr);
                float dist = (cdist - 0.5) - pcm_val*0.5;
                return linefn(dist);
            }

            float get_value_xy_scatter(float2 xy, uint nsamples)
            {
                float2 cpos = (frac(xy) - float2(0.5, 0.5))*2;
                float dist = 1.0/0.0;  // Inf
                for (uint i = 0; i < nsamples; ++i)
                {
                    float2 pcm_lr = PCMToLR(AudioLinkPCMData(i));
                    float ndist = length(pcm_lr - cpos)*0.5;
                    dist = min(dist, ndist);
                }

                return linefn(dist);
            }

            float get_value_xy_line(float2 xy, uint nsamples)
            {
                float2 cpos = (frac(xy) - float2(0.5, 0.5))*2;
                float dist = 1.0/0.0;  // Inf
                float2 pcm_lr_a = PCMToLR(AudioLinkPCMData(0));
                for (uint i = 1; i < nsamples; ++i)
                {
                    float2 pcm_lr_b = PCMToLR(AudioLinkPCMData(i));
                    float ndist = dist_to_line(cpos, pcm_lr_a, pcm_lr_b)*0.5;
                    dist = min(dist, ndist);
                    pcm_lr_a = pcm_lr_b;
                }

                return linefn(dist);
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 col = float4(0,0,0,0);

                uint w, h;
                _AudioTexture.GetDimensions(w,h);
                if (w > 16)
                {
                    float val = get_value_circle(i.uv.xy, 128, 0);
                    // float val = get_value_xy_scatter(i.uv.xy, 256);
                    // float val = get_value_xy_line(i.uv.xy, 512);
                    //float val = get_value_xy3(i.uv.xy);
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
