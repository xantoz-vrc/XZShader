#include "../../cginc/AudioLinkFuncs.cginc"

float4 _ST;

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

float _Amplitude_Scale;

float _Chronotensity_Tiling_Scale;
float _Chronotensity_Offset_Scale;
float _Chronotensity_Scale;
float _Tiling_Scale;

float4 _Color1;
float4 _Color2;
int _Mode;
#define MAX_MODE 10

float _Rotation;
int _Rotation_Reversing;

float _Vignette_Intensity;
float _Vignette_Inner_Radius;
float _Vignette_Outer_Radius;
int _Vignette_Type;

float _ChronoRot_Scale;
float _ChronoRot_Band0;
float _ChronoRot_Band1;
float _ChronoRot_Band2;
float _ChronoRot_Band3;
float _ChronoRot_Effect_Band0;
float _ChronoRot_Effect_Band1;
float _ChronoRot_Effect_Band2;
float _ChronoRot_Effect_Band3;

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

// Smoothly switches between an old random value and a new one at some point in time
// Or at least that's the idea, but this still needs some work.
float get_rarely_changing_random_smooth()
{
    float seed_base =
    AudioLinkGetChronotensity(1, 0) + AudioLinkGetChronotensity(2, 2) +
    AudioLinkGetChronotensity(0, 1) + AudioLinkGetChronotensity(5, 3);
    // float seed_base = AudioLinkGetChronotensity(5, 0);

    const float fdivisor = 3000000.0;
    const float next = fdivisor/60000.0;
    // const float next = fdivisor/6000.0;
    // const float next = 5.0;
    // const float next = fdivisor/60.0;

    // float seed_base1 = seed_base - next;
    float seed_base1 = seed_base;
    float seed_base2 = seed_base + next;
    float seed1 = floor(seed_base1/fdivisor);
    float seed2 = ceil(seed_base2/fdivisor);

    float now = seed1*fdivisor;
    float future = seed2*fdivisor;
    float factor = (future - seed_base)/(future - now);
    // float factor = (future - seed_base)/next;
    // float factor = frac(seed_base/fdivisor);

    // TODO: maybe use a different random algorithm to ensure we are more independent from get_rarely_changing_random
    float random1 = random(float2(seed1, seed1))*2 - 1;
    float random2 = random(float2(seed2, seed2))*2 - 1;
    // float random1 = step(random(float2(seed1, seed1)), 0.5)*2 - 1;
    // float random2 = step(random(float2(seed2, seed2)), 0.5)*2 - 1;

    return lerp(random1, random2, factor);
}

// --- distance to line segment with caps (From: https://shadertoyunofficial.wordpress.com/2019/01/02/programming-tricks-in-shadertoy-glsl/)
float dist_to_line(float2 p, float2 a, float2 b)
{
    p -= a, b -= a;
    float h = clamp(dot(p, b) / dot(b, b), 0.0, 1.0); // proj coord on line
    return length(p - b * h);                        // dist to segment
}

float sqdist_to_line(float2 p, float2 a, float2 b)
{
    p -= a, b -= a;
    float h = clamp(dot(p, b) / dot(b, b), 0.0, 1.0); // proj coord on line
    float2 x = (p - b * h);
    return dot(x, x);   // distance squared to segment
}

// Converts a distance to a color value. Use to plot linee by putting in the distance from UV to your line in question.
float linefn(float a)
{
    return -clamp((1.0-pow(0.1/abs(a), .1)), -2, 0);
}

float get_value_horiz_line(float2 xy, uint nsamples, uint lr)
{
    float pcm_val = PCMConditional(AudioLinkPCMLerp(frac(xy.x)*(nsamples-1))*_Amplitude_Scale, lr);
    float dist = (frac(xy.y) - 0.5) - pcm_val*0.5;
    return linefn(dist);
}

float get_value_vert_line(float2 xy, uint nsamples, uint lr)
{
    float4 pcm_val = PCMConditional(AudioLinkPCMLerp(frac(xy.y)*(nsamples-1))*_Amplitude_Scale, lr);
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
        AudioLinkPCMLerpWrap(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples, nsamples)*_Amplitude_Scale,
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
        AudioLinkPCMLerpMirror(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples*2, nsamples)*_Amplitude_Scale,
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
    float pcm_val = AudioLinkPCMLerpMirrorLR(index, nsamples)*_Amplitude_Scale;
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

    float2 pcm_1 = PCMToLR(AudioLinkPCMData(mod(index_1, nsamples - (nsamples % bin)))*_Amplitude_Scale)*0.2;
    float2 pcm_2 = PCMToLR(AudioLinkPCMData(mod(index_2, nsamples - (nsamples % bin)))*_Amplitude_Scale)*0.2;

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

float sqdist_to_pcm_lr(float2 cpos, uint i)
{
    float2 pcm_lr = PCMToLR(AudioLinkPCMData(i)*_Amplitude_Scale);
    float2 x = (pcm_lr - cpos);
    return dot(x, x);
}

float get_value_xy_scatter(float2 xy)
{
    float2 cpos = (frac(xy) - float2(0.5, 0.5))*2;
    float4 dist4 = float4(1.#INF, 1.#INF, 1.#INF, 1.#INF);
    // TODO: optimize further by using matrices?
    for (uint i = 0; i < 256; i += 4)
    {
        float4 ndist4 = float4(
            sqdist_to_pcm_lr(cpos, i),
            sqdist_to_pcm_lr(cpos, i+1),
            sqdist_to_pcm_lr(cpos, i+2),
            sqdist_to_pcm_lr(cpos, i+3));
        dist4 = min(dist4, ndist4);
    }

    float dist = sqrt(min(min(dist4.x, dist4.y), min(dist4.z, dist4.w)))*0.5;

    return linefn(dist);
}

float get_value_xy_line(float2 xy)
{
    const float2 cpos = (frac(xy) - float2(0.5, 0.5))*2;
    float4 dist4_0 = float4(1.#INF, 1.#INF, 1.#INF, 1.#INF);
    float4 dist4_1 = float4(1.#INF, 1.#INF, 1.#INF, 1.#INF);
    // TODO: optimize further by making matrix versions of dist_to_line and all that
    float2 pcm_lr_a = PCMToLR(AudioLinkPCMData(0)*_Amplitude_Scale);
    for (uint i = 0; i < 384; i += 8)
    {
        float2 pcm_lr_b = PCMToLR(AudioLinkPCMData(i+1)*_Amplitude_Scale);
        float2 pcm_lr_c = PCMToLR(AudioLinkPCMData(i+2)*_Amplitude_Scale);
        float2 pcm_lr_d = PCMToLR(AudioLinkPCMData(i+3)*_Amplitude_Scale);
        float2 pcm_lr_e = PCMToLR(AudioLinkPCMData(i+4)*_Amplitude_Scale);
        float2 pcm_lr_f = PCMToLR(AudioLinkPCMData(i+5)*_Amplitude_Scale);
        float2 pcm_lr_g = PCMToLR(AudioLinkPCMData(i+6)*_Amplitude_Scale);
        float2 pcm_lr_h = PCMToLR(AudioLinkPCMData(i+7)*_Amplitude_Scale);
        float2 pcm_lr_i = PCMToLR(AudioLinkPCMData((i+8)%384)*_Amplitude_Scale);
        float4 ndist4_0 = float4(
            sqdist_to_line(cpos, pcm_lr_a, pcm_lr_b),
            sqdist_to_line(cpos, pcm_lr_b, pcm_lr_c),
            sqdist_to_line(cpos, pcm_lr_c, pcm_lr_d),
            sqdist_to_line(cpos, pcm_lr_d, pcm_lr_e));
        float4 ndist4_1 = float4(
            sqdist_to_line(cpos, pcm_lr_e, pcm_lr_f),
            sqdist_to_line(cpos, pcm_lr_f, pcm_lr_g),
            sqdist_to_line(cpos, pcm_lr_g, pcm_lr_h),
            sqdist_to_line(cpos, pcm_lr_h, pcm_lr_i));

        dist4_0 = min(dist4_0, ndist4_0);
        dist4_1 = min(dist4_1, ndist4_1);

        pcm_lr_a = pcm_lr_i;
    }

    float4 dist4 = min(dist4_0, dist4_1);
    float dist = sqrt(min(min(dist4.x, dist4.y), min(dist4.z, dist4.w)))*0.5;

    return linefn(dist);
}

float2 get_uv(float2 uv_in)
{
    float4 chronotensity_ST = float4(0,0,0,0);
    float rot = _Rotation;
    if (AudioLinkIsAvailable()) {

        float chronotensity_scale = _Chronotensity_Scale;
        float chronorot_scale = _ChronoRot_Scale;

        // In auto mode, in addition to switching visualization mode, we also randomly switch chronotensity on and off
        if (_Mode > MAX_MODE) {
            float seed = get_rarely_changing_random();

            // We need to pass the gotten number again into the random function to
            // make the current visualization and the decision on whether to use
            // chronotensity scrolling be non-correlated.
            float random_scroll = random(float2(seed, seed));
            chronotensity_scale = (random_scroll > 0.7) ? -1.0 :
            (random_scroll > 0.4) ?  1.0 : 0.0;

            // Some more mixing up to decouple this
            float random_rot = random(float2(seed*seed, 2*seed));
            chronorot_scale = (random_rot > 0.666) ?  1.0 :
            (random_rot > 0.333) ? -1.0 : 0.0;
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

        float4 chronorot_band = float4(
            _ChronoRot_Band0 * AudioLinkGetChronotensity(_ChronoRot_Effect_Band0, 0)/1000000.0,
            _ChronoRot_Band1 * AudioLinkGetChronotensity(_ChronoRot_Effect_Band1, 1)/1000000.0,
            _ChronoRot_Band2 * AudioLinkGetChronotensity(_ChronoRot_Effect_Band2, 2)/1000000.0,
            _ChronoRot_Band3 * AudioLinkGetChronotensity(_ChronoRot_Effect_Band3, 3)/1000000.0
        );
        rot += chronorot_scale * frac(dot(chronorot_band, float4(1,1,1,1))) * 360.0;

        if (_Rotation_Reversing != 0) {
            rot *= get_rarely_changing_random_smooth();
        }
    }

    float4 new_ST = _ST * float4(_Tiling_Scale, _Tiling_Scale, 1, 1) + chronotensity_ST;
    float2 centered_uv = (uv_in - float2(0.5, 0.5))*new_ST.xy;

    float sinX = sin(radians(rot));
    float cosX = cos(radians(rot));
    float sinY = sin(radians(rot));
    float2x2 rotationMatrix = float2x2(cosX, -sinX, sinY, cosX);
    return mul(centered_uv, rotationMatrix) + float2(0.5, 0.5) + new_ST.zw;
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
        case 6: val = get_value_xy_scatter(xy); break;
        case 7: val = get_value_xy_line(xy); break;
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

    // Emergency clamp added to temper any blinding flicker bugs that might be left.
    return clamp((_Color1 + _Color2*al_color_mult)*val, -3.0, 3.0);
}

float get_vignette(float2 xy)
{
    float2 cpos = (frac(xy) - float2(0.5,0.5))*2;
    float cdist =
      (_Vignette_Type == 0) ? length(cpos) :                  // Circle
      (_Vignette_Type == 1) ? abs(cpos.x) + abs(cpos.y) :     // Diamond
    max(abs(cpos.x), abs(cpos.y));  // Box

    float inner_radius = _Vignette_Inner_Radius;
    float outer_radius = _Vignette_Outer_Radius;
    float intensity = _Vignette_Intensity;

    return (1.0 - smoothstep(inner_radius, outer_radius, cdist) * intensity);
}

float4 get_frag2(float2 xy, float2 vignette_xy, int mode_add)
{
    float4 col = float4(0,0,0,0);

    if (AudioLinkIsAvailable()) {
        uint mode = _Mode;

        if (_Mode > MAX_MODE) {
            // Auto mode
            // Get random number and convert to an integer between 0 and MAX_MODE
            mode = ceil(get_rarely_changing_random()*MAX_MODE);
            mode = (mode + mode_add) % (MAX_MODE+1);

            if (_Mode > MAX_MODE + 1) {
                // Auto2 mode: replace modes 6 and 7 with something else
                if (mode == 7) mode = 2; // XY line plot replace with LR lines
                if (mode == 6) mode = 8; // XY scatter plot replace with PCM ribbon
            }
        }

        col = get_color(mode, xy);
        col.a *= get_vignette(vignette_xy);
    }

    return col;
}

float4 get_frag(float2 xy, float2 vignette_xy)
{
    return get_frag2(xy, vignette_xy, 0);
}
