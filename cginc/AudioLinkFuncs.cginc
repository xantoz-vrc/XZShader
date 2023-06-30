#pragma once

#include "common.cginc"

#define ALPASS_DFT            uint2(0,4)   //Size: 128, 2
#define ALPASS_WAVEFORM       uint2(0,6)   //Size: 128, 16
#define ALPASS_CHRONOTENSITY  uint2(16,28) //Size: 8, 4

#define AUDIOLINK_WIDTH 128

#define AUDIOLINK_EXPBINS               24
#define AUDIOLINK_EXPOCT                10
#define AUDIOLINK_ETOTALBINS            (AUDIOLINK_EXPBINS * AUDIOLINK_EXPOCT)


#ifdef SHADER_TARGET_SURFACE_ANALYSIS
#define AUDIOLINK_STANDARD_INDEXING
#endif

// Mechanism to index into texture.
#ifdef AUDIOLINK_STANDARD_INDEXING
    sampler2D _AudioTexture;
    uniform float4 _AudioTexture_TexelSize;
    #define AudioLinkData(xycoord) tex2Dlod(_AudioTexture, float4(uint2(xycoord) * _AudioTexture_TexelSize.xy, 0, 0))
#else
    uniform Texture2D<float4> _AudioTexture;
    #define AudioLinkData(xycoord) _AudioTexture[uint2(xycoord)]
#endif

bool AudioLinkIsAvailable()
{
    #if !defined(AUDIOLINK_STANDARD_INDEXING)
        int width, height;
        _AudioTexture.GetDimensions(width, height);
        return width > 16;
    #else
        return _AudioTexture_TexelSize.z > 16;
    #endif
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
    return AudioLinkData(uint2(
            xycoord.x % AUDIOLINK_WIDTH,
            xycoord.y + xycoord.x/AUDIOLINK_WIDTH));
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

