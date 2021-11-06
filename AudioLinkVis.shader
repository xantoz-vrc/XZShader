// ISC License
//
// Copyright 2021 xantoz
//
// Permission to use, copy, modify, and/or distribute this software
// for any purpose with or without fee is hereby granted, provided
// that the above copyright notice and this permission notice appear
// in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
// WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
// AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
// CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
// OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
// NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
// CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

Shader "Xantoz/AudioLinkVis"
{
    Properties
    {
        _ST ("UV tiling and offset", Vector) = (1,1,0,0)
        
        [HDR]_Color1 ("Color 1", Color) = (1,1,1,1)
        [HDR]_Color2 ("Color 2", Color) = (1,1,1,1)
        [Enum(PCM_Horizontal,0, PCM_Vertical,1, PCM_LR,2, PCM_Circle,3, PCM_Circle_Mirror,4, PCM_Circle_LR,5, PCM_XY_Scatter,6, PCM_XY_Line,7, PCM_Ribbon,8, Spectrum_Circle_Mirror,9, Spectrum_Ribbon,10, Auto,11)] _Mode("Mode", Int) = 0
        // [Enum(PCM_Horizontal,0,  PCM_LR,2, PCM_Circle,3, PCM_Circle_LR,5, PCM_XY_Line,7, Spectrum_Ribbon,10)] _Mode("Mode", Int) = 0

        [HDR]_Color_Mul_Band0 ("Color Bass", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band1 ("Color Low Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band2 ("Color High Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band3 ("Color Treble", Color) = (0,0,0,0)
        
        _Chronotensity_ST_Band0 ("Chronotensity Bass", Vector) = (0,0,0,0)
        _Chronotensity_ST_Band1 ("Chronotensity Low Mid", Vector) = (0,0,0,0)
        _Chronotensity_ST_Band2 ("Chronotensity High Mid", Vector) = (0,0,0,0)
        _Chronotensity_ST_Band3 ("Chronotensity Treble", Vector) = (0,0,0,0)
        
        _Chronotensity_Effect_Band0 ("Chronotensity Effect Bass", Int) = 1
        _Chronotensity_Effect_Band1 ("Chronotensity Effect Low Mid", Int) = 1
        _Chronotensity_Effect_Band2 ("Chronotensity Effect High Mid", Int) = 1
        _Chronotensity_Effect_Band3 ("Chronotensity Effect Treble", Int) = 1

        // When the tiling value goes above these we will wrap around
        // and start shrinking back to starting point again using our
        // custom fmirror function (see below)
        _Chronotensity_Tiling_Wrap_U ("Chronotensity Tiling Wrap U", Float) = 10.0
        _Chronotensity_Tiling_Wrap_V ("Chronotensity Tiling Wrap V", Float) = 10.0

        // Added so we can have a nice slider in ShaderFes 2021 (Normally you would just modify each of _Chronotensity_ST_BandX)
        _Chronotensity_Tiling_Scale ("Chronotensity Tiling Scale (ShaderFes 2021)", Range(0.0, 10.0)) = 0.0
        _Chronotensity_Offset_Scale ("Chronotensity Offset Scale (ShaderFes 2021)", Range(0.0, 10.0)) = 0.0
        _Chronotensity_Scale ("Chronotensity Scale (ShaderFes 2021)", Range(0.0, 1.0)) = 0.0   // This one affects the values as theycome out of AudioLink
        // Also added so we can have a nice slider in ShaderFes 2021 (normally you would just modify _ST)
        _Tiling_Scale ("UV Tiling scale (ShaderFes 2021)", Range(0.0, 10.0)) = 1.0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
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

            float4 _ST;
            Texture2D<float4> _AudioTexture;

            float4 _Color_Mul_Band0;
            float4 _Color_Mul_Band1;
            float4 _Color_Mul_Band2;
            float4 _Color_Mul_Band3;

            float4 _Chronotensity_ST_Band0;
            float4 _Chronotensity_ST_Band1;
            float4 _Chronotensity_ST_Band2;
            float4 _Chronotensity_ST_Band3;
            float _Chronotensity_Effect_Band0;
            float _Chronotensity_Effect_Band1;
            float _Chronotensity_Effect_Band2;
            float _Chronotensity_Effect_Band3;

            float _Chronotensity_Tiling_Wrap_U;
            float _Chronotensity_Tiling_Wrap_V;

            float _Chronotensity_Tiling_Scale;
            float _Chronotensity_Offset_Scale;
            float _Chronotensity_Scale;
            float _Tiling_Scale;

            float4 _Color1;
            float4 _Color2;
            int _Mode;
            #define NUMBER_OF_MODES 10

            #define ALPASS_DFT            uint2(0,4)   //Size: 128, 2
            #define ALPASS_WAVEFORM       uint2(0,6)   //Size: 128, 16
            #define ALPASS_CHRONOTENSITY  uint2(16,28) //Size: 8, 4

            #define AUDIOLINK_WIDTH 128

            #define AUDIOLINK_EXPBINS               24
            #define AUDIOLINK_EXPOCT                10
            #define AUDIOLINK_ETOTALBINS            (AUDIOLINK_EXPBINS * AUDIOLINK_EXPOCT)

            float mod(float x, float y)
            {
                return x - y * floor(x/y);
            }

            bool AudioLinkIsAvailable()
            {
                int width, height;
                _AudioTexture.GetDimensions(width, height);
                return width > 16;
            }

            float4 AudioLinkData(uint2 xycoord)
            { 
                return _AudioTexture[uint2(xycoord.x, xycoord.y)]; 
            }

            uint AudioLinkDecodeDataAsUInt(uint2 indexloc)
            {
                uint4 rpx = AudioLinkData(indexloc);
                return rpx.r + rpx.g*1024 + rpx.b * 1048576 + rpx.a * 1073741824;
            }

            uint AudioLinkGetChronotensity(uint effect, uint band)
            {
                return AudioLinkDecodeDataAsUInt(ALPASS_CHRONOTENSITY + uint2(effect, band));
            }

            float4 AudioLinkLerp(float2 xy)
            {
                return lerp(
                    AudioLinkData(uint2(xy.x, xy.y)),
                    AudioLinkData(uint2(xy.x, xy.y) + uint2(1,0)),
                    frac(xy.x));
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

            float4 AudioLinkLerpMultilineWrap(float2 xy, float wrap) 
            {
                return lerp(
                    AudioLinkDataMultiline(float2(mod(xy.x, wrap), xy.y)),
                    AudioLinkDataMultiline(float2(mod(xy.x + 1, wrap), xy.y)),
                    frac(xy.x));
            }

            float fmirror(float x, float wrap)
            {
                float x_wrap = mod(x, wrap*2);
                return (x_wrap > wrap) ? (wrap*2 - x_wrap) : x_wrap;
            }

            float2 f2mirror(float2 x, float2 wrap)
            {
                // TODO: this could probably be optimized to use vector operations
                return float2(fmirror(x[0], wrap[0]), fmirror(x[1], wrap[1]));
            }

            float4 AudioLinkLerpMultilineMirror(float2 xy, float wrap)
            {
                return lerp(
                    AudioLinkDataMultiline(float2(fmirror(xy.x, wrap), xy.y)),
                    AudioLinkDataMultiline(float2(fmirror(xy.x + 1, wrap), xy.y)),
                    frac(xy.x));
            }

            // Index 0 to 255
            float4 AudioLinkDFTData(uint i)
            {
                return AudioLinkDataMultiline(uint2(i, 4));
            }

            // Index 0 to 255
            float4 AudioLinkDFTLerp(float i)
            {
                return AudioLinkLerpMultiline(float2(i, 4.0));
            }

            float4 AudioLinkDFTLerpWrap(float i, float wrap)
            {
                return AudioLinkLerpMultilineWrap(float2(i, 4.0), wrap);
            }

            float4 AudioLinkDFTLerpMirror(float i, float wrap)
            {
                return AudioLinkLerpMultilineMirror(float2(i, 4.0), wrap);
            }

            // Index 0 to 2047 when using .g
            //       0 to 2045 when using .r and .a
            //       0 to 1022 when using .b
            float4 AudioLinkPCMData(uint i)
            {
                return AudioLinkDataMultiline(uint2(i, 6));
            }

            // Index 0 to 2047 when using .g
            //       0 to 2045 when using .r and .a
            //       0 to 1022 when using .b
            float4 AudioLinkPCMLerp(float i)
            {
                return AudioLinkLerpMultiline(float2(i, 6.0));
            }

            float4 AudioLinkPCMLerpWrap(float i, float wrap)
            {
                return AudioLinkLerpMultilineWrap(float2(i, 6.0), wrap);
            }

            float4 AudioLinkPCMLerpMirror(float i, float wrap)
            {
                return AudioLinkLerpMultilineMirror(float2(i, 6.0), wrap);
            }

            // Pick one of:
            // lr == 0: both channels (24 kHz red)
            // lr == 1: left channel
            // lr == 2: right channel
            float PCMConditional(float4 pcm_value, uint lr)
            {
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

            // This is basically just a helper function for get_value_circle_mirror_lr
            float AudioLinkPCMLerpMirrorLR(float i, float wrap)
            {
                uint lr_1 = (mod(i, wrap*2) > wrap) ? 1 : 2;
                uint lr_2 = (mod(i + 1, wrap*2) > wrap) ? 1 : 2;
                return lerp(
                    PCMConditional(AudioLinkPCMData(fmirror(i, wrap)), lr_1),
                    PCMConditional(AudioLinkPCMData(fmirror(i + 1, wrap)), lr_2),
                    frac(i));
            }

            // From: https://stackoverflow.com/questions/5149544/can-i-generate-a-random-number-inside-a-pixel-shader
            float random(float2 p)
            {
                // We need irrationals for pseudo randomness.
                // Most (all?) known transcendental numbers will (generally) work.
                const float2 r = float2(
                    23.1406926327792690,  // e^pi (Gelfond's constant)
                    2.6651441426902251); // 2^sqrt(2) (Gelfond–Schneider constant)
                return frac(cos(mod(123456789.0, 1e-7 + 256.0 * dot(p,r))));  
            }

            // A random value that should be the same for a few seconds or so.
            // TODO: Write fallback version using Time_T (might be better: this isn't the most lightweight thing to be calling each pixel)
            float get_rarely_changing_random()
            {
                // Get a seed that changes very rarely by getting an int value
                // out of chronotensity that very rarely increments. Why
                // chronotensity? That way when we switch mode is also somewhat
                // random, and also by accident it might be correlated to the
                // music.
                uint2 seed = uint2(
                    AudioLinkGetChronotensity(1, 0) + AudioLinkGetChronotensity(2, 2),
                    AudioLinkGetChronotensity(0, 1) + AudioLinkGetChronotensity(5, 3))/2000000.0;

                return random(seed);
            }

            // --- distance to line segment with caps (From: https://shadertoyunofficial.wordpress.com/2019/01/02/programming-tricks-in-shadertoy-glsl/)
            float dist_to_line(float2 p, float2 a, float2 b)
            {
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
                float dist = (frac(xy.y) - 0.5) - pcm_val*0.5;
                return linefn(dist);
            }

            float get_value_vert_line(float2 xy, uint nsamples, uint lr)
            {
                float4 pcm_val = PCMConditional(AudioLinkPCMLerp(frac(xy.y)*(nsamples-1)), lr);
                float dist = (frac(xy.x) - 0.5) - pcm_val*0.5;
                return linefn(dist);
            }

            float get_value_lr_lines(float2 xy, uint nsamples)
            {
                return get_value_horiz_line(xy, nsamples, 1) + get_value_vert_line(xy, nsamples, 2);
            }

            float get_value_circle(float2 xy, uint nsamples, uint lr)
            {
                float2 cpos = (frac(xy) - float2(0.5,0.5))*2;
                float cdist = length(cpos);
                float angle = atan2(cpos.x, cpos.y);
                float pcm_val = PCMConditional(
                    AudioLinkPCMLerpWrap(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples, nsamples),
                    lr);
                float dist = (cdist - 0.5) - pcm_val*0.25;
                return linefn(dist);
            }

            float get_value_circle_mirror(float2 xy, uint nsamples, uint lr)
            {
                float2 cpos = (frac(xy) - float2(0.5,0.5))*2;
                float cdist = length(cpos);
                float angle = atan2(cpos.x, cpos.y);
                float pcm_val = PCMConditional(
                    AudioLinkPCMLerpMirror(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples*2, nsamples),
                    lr);
                float dist = (cdist - 0.5) - pcm_val*0.25;
                return linefn(dist);
            }

            float get_value_circle_mirror_lr(float2 xy, uint nsamples)
            {
                float2 cpos = (frac(xy) - float2(0.5,0.5))*2;
                float cdist = length(cpos);
                float angle = atan2(cpos.x, cpos.y);
                float index = ((angle+UNITY_PI)/(2*UNITY_PI))*nsamples*2;
                float pcm_val = AudioLinkPCMLerpMirrorLR(index, nsamples);
                float dist = (cdist - 0.5) - pcm_val*0.25;
                return linefn(dist);
            }

            float get_value_spectrum_circle(float2 xy, uint nsamples)
            {
                float2 cpos = (frac(xy) - float2(0.5,0.5))*2;
                float cdist = length(cpos);
                float angle = atan2(cpos.x, cpos.y);
                float4 dft_val = AudioLinkDFTLerpWrap(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples, nsamples);
                dft_val = clamp(dft_val, 0.0, 2);
                float dist = (cdist - 0.5) - dft_val.r*0.25;
                return linefn(dist);
            }

            float get_value_spectrum_circle_mirror(float2 xy)
            {
                float2 cpos = (frac(xy) - float2(0.5,0.5))*2;
                float cdist = length(cpos);
                float angle = atan2(cpos.x, cpos.y);
                float4 dft_val = AudioLinkDFTLerpMirror((angle+UNITY_PI)/(2*UNITY_PI)*255*2, 256);
                dft_val = clamp(dft_val, 0.0, 2);
                float dist = (cdist - 0.5) - dft_val.g*0.25;
                return linefn(dist);
            }

            float get_value_spectrum_fancy(float2 xy, uint nsamples, uint bin)
            {
                float2 cpos = (frac(xy) - float2(0.5,0.5))*2;
                float cdist = length(cpos);
                float angle = atan2(cpos.x, cpos.y);
                float index = ((angle)/(2*UNITY_PI))*nsamples;

                // Quantize our index. Get the angles out, then figure out what xy coords we will have
                float index_1 = floor(index/bin)*bin;
                float index_2 = ceil(index/bin)*bin;

                // calculate the angles backwards from the indices;
                float angle_1 = (index_1/nsamples)*(2*UNITY_PI);
                float angle_2 = (index_2/nsamples)*(2*UNITY_PI);
                float2 sc1 = float2(sin(angle_1), cos(angle_1));
                float2 sc2 = float2(sin(angle_2), cos(angle_2));

                float dft_1 = AudioLinkDFTData(mod(index_1, nsamples - (nsamples % bin))).r*0.25;
                float dft_2 = AudioLinkDFTData(mod(index_2, nsamples - (nsamples % bin))).r*0.25;

                float r1 = clamp(dft_1 + 0.75, 0.0, 1.0);
                float r2 = clamp(dft_2 + 0.75, 0.0, 1.0);
                float r3 = clamp(0.5 - dft_1, 0.0, 1.0);
                float r4 = clamp(0.5 - dft_2, 0.0, 1.0);
                
                float2 p1 = r1*sc1;
                float2 p2 = r2*sc2;
                float2 p3 = r3*sc1;
                float2 p4 = r4*sc2;

                float val = 0.0;
                val += linefn(dist_to_line(cpos, p1, p2));
                val += linefn(dist_to_line(cpos, p3, p4));
                val += linefn(dist_to_line(cpos, p1, p3));
                val += linefn(dist_to_line(cpos, p2, p4));
                return val*0.6;
            }

            float get_value_pcm_fancy(float2 xy, uint nsamples, uint bin)
            {
                float2 cpos = (frac(xy) - float2(0.5,0.5))*2;
                float cdist = length(cpos);
                float angle = atan2(cpos.x, cpos.y);
                float index = ((angle)/(2*UNITY_PI))*nsamples;

                // Quantize our index. Get the angles out, then figure out what xy coords we will have
                float index_1 = floor(index/bin)*bin;
                float index_2 = ceil(index/bin)*bin;

                // calculate the angles backwards from the indices;
                float angle_1 = (index_1/nsamples)*(2*UNITY_PI);
                float angle_2 = (index_2/nsamples)*(2*UNITY_PI);
                float2 sc1 = float2(sin(angle_1), cos(angle_1));
                float2 sc2 = float2(sin(angle_2), cos(angle_2));

                float2 pcm_1 = PCMToLR(AudioLinkPCMData(mod(index_1, nsamples - (nsamples % bin))))*0.2;
                float2 pcm_2 = PCMToLR(AudioLinkPCMData(mod(index_2, nsamples - (nsamples % bin))))*0.2;

                float r1 = clamp(pcm_1.x + 0.75, 0.0, 1.0);
                float r2 = clamp(pcm_2.x + 0.75, 0.0, 1.0);
                float r3 = clamp(0.5 - pcm_1.y, 0.0, 1.0);
                float r4 = clamp(0.5 - pcm_2.y, 0.0, 1.0);
                
                float2 p1 = r1*sc1;
                float2 p2 = r2*sc2;
                float2 p3 = r3*sc1;
                float2 p4 = r4*sc2;

                float val = 0.0;
                val += linefn(dist_to_line(cpos, p1, p2));
                val += linefn(dist_to_line(cpos, p3, p4));
                val += linefn(dist_to_line(cpos, p1, p3));
                val += linefn(dist_to_line(cpos, p2, p4));
                return val*0.6;
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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);

                float4 chronotensity_ST = float4(0,0,0,0);
                if (AudioLinkIsAvailable()) {

                    float chronotensity_scale = _Chronotensity_Scale;
                    // In auto mode, in addition to switching visualization mode, we also randomly switch chronotensity on and off
                    if (_Mode > NUMBER_OF_MODES) {
                        // We need to pass the gotten number again into the random function to
                        // make the current visualization and the decision on whether to use
                        // chronotensity scrolling be non-correlated
                        float seed = get_rarely_changing_random();
                        chronotensity_scale = (random(float2(seed, seed)) > 0.5) ? 1.0 : 0.0;
                    }

                    float chronotensity_band[4] = {
                        // TODO: Maybe these need to loop every once in a while to avoid instability.
                        AudioLinkGetChronotensity(_Chronotensity_Effect_Band0, 0)/1000000.0, 
                        AudioLinkGetChronotensity(_Chronotensity_Effect_Band1, 1)/1000000.0, 
                        AudioLinkGetChronotensity(_Chronotensity_Effect_Band2, 2)/1000000.0, 
                        AudioLinkGetChronotensity(_Chronotensity_Effect_Band3, 3)/1000000.0
                    };
                    float4 chronotensity_ST_band[4] = {
                        _Chronotensity_ST_Band0,
                        _Chronotensity_ST_Band1,
                        _Chronotensity_ST_Band2,
                        _Chronotensity_ST_Band3
                    };
                    for (uint i = 0; i < 4; ++i) {
                        chronotensity_band[i] *= chronotensity_scale;
                        chronotensity_ST_band[i].xy *= _Chronotensity_Tiling_Scale;
                        chronotensity_ST_band[i].zw *= _Chronotensity_Offset_Scale;
                    }
                    chronotensity_ST.xy = f2mirror(
                        chronotensity_band[0]*chronotensity_ST_band[0].xy +
                        chronotensity_band[1]*chronotensity_ST_band[1].xy +
                        chronotensity_band[2]*chronotensity_ST_band[2].xy +
                        chronotensity_band[3]*chronotensity_ST_band[3].xy,
                        float2(_Chronotensity_Tiling_Wrap_U, _Chronotensity_Tiling_Wrap_V));
                    chronotensity_ST.zw = frac(
                        chronotensity_band[0]*chronotensity_ST_band[0].zw +
                        chronotensity_band[1]*chronotensity_ST_band[1].zw +
                        chronotensity_band[2]*chronotensity_ST_band[2].zw +
                        chronotensity_band[3]*chronotensity_ST_band[3].zw);
                }

                float4 new_ST = _ST * float4(_Tiling_Scale, _Tiling_Scale, 1, 1) + chronotensity_ST;
                // o.uv = v.uv*new_ST.xy + new_ST.zw;
                o.uv = (v.uv - float2(0.5, 0.5))*new_ST.xy + float2(0.5, 0.5) + new_ST.zw;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float4 get_color(uint mode, float2 xy)
            {
                float val = 0.0;

                switch (mode) {
                    case 0: val = get_value_horiz_line(xy, 256, 0); break;
                    case 1: val = get_value_vert_line(xy, 256, 0); break;
                    case 2: val = get_value_lr_lines(xy, 256); break;
                    case 3: val = get_value_circle(xy, 128, 0); break;
                    case 4: val = get_value_circle_mirror(xy, 128, 0); break;
                    case 5: val = get_value_circle_mirror_lr(xy, 128); break;
                    case 6: val = get_value_xy_scatter(xy, 512); break;
                    case 7: val = get_value_xy_line(xy, 512); break;
                    case 8: val = get_value_pcm_fancy(xy, 1024, 8); break;
                    case 9: val = get_value_spectrum_circle_mirror(xy); break;
                    case 10: val = get_value_spectrum_fancy(xy, 256, 4); break;
                }

                float al_beat[4] = {
                    AudioLinkData(uint2(0,0)).r,
                    AudioLinkData(uint2(0,1)).r,
                    AudioLinkData(uint2(0,2)).r,
                    AudioLinkData(uint2(0,3)).r
                };
                float4 al_color_mult =
                _Color_Mul_Band0*al_beat[0] +
                _Color_Mul_Band1*al_beat[1] +
                _Color_Mul_Band2*al_beat[2] +
                _Color_Mul_Band3*al_beat[3];

                // TODO: Maybe each function should have a way to
                // tell if they want a certain color in a certain
                // place as well?
                return (_Color1 + _Color2*al_color_mult)*val;
            }
 
            float4 get_color_auto(float2 xy)
            {
                // Get random number and convert to an integer between 0 and 10
                uint mode = ceil(get_rarely_changing_random()*NUMBER_OF_MODES);
                return get_color(mode, xy);
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 col = float4(0,0,0,0);

                if (AudioLinkIsAvailable()) {
                    if (_Mode > NUMBER_OF_MODES) {
                        col = get_color_auto(i.uv.xy);
                    } else {
                        col = get_color(_Mode, i.uv.xy);
                    }
                }

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
