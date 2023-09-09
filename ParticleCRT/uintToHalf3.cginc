#ifndef UINTTTOHALF3_CGINC
#define UINTTTOHALF3_CGINC

//Merlin. For details see https://github.com/pema99/shader-knowledge/blob/main/tips-and-tricks.md#encoding-and-decoding-data-in-a-grabpass
float uint14ToFloat(uint input)
{
    precise float output = (f16tof32((input & 0x00003fff)));
    return output;
}

uint floatToUint14(precise float input)
{
    uint output = (f32tof16(input)) & 0x00003fff;
    return output;
}

// Encodes a 32 bit uint into 3 half precision floats
float3 uintToHalf3(uint input)
{
    precise float3 output = float3(uint14ToFloat(input), uint14ToFloat(input >> 14), uint14ToFloat((input >> 28) & 0x0000000f));
    return output;
}

uint half3ToUint(precise float3 input)
{
    return floatToUint14(input.x) | (floatToUint14(input.y) << 14) | ((floatToUint14(input.z) & 0x0000000f) << 28);
}

#endif /* UINTTTOHALF3_CGINC */
