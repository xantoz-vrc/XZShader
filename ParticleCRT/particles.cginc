#ifndef _PARTICLES_CGINC
#define _PARTICLES_CGINC

// Workaround for instabilities when _Time gets too large
#define TIME (_Time % (float4(3600/20, 3600, 3600*2, 3600*3)))

#define part float

#define append(a,b) a##b
#define part1 append(part,1)
#define part2 append(part,2)
#define part3 append(part,3)
#define part4 append(part,4)

#define TEXTURETYPE float4

#ifdef RENDER_PARTICLES
  Texture2D<TEXTURETYPE> _ParticleCRT;
  SamplerState sampler_ParticleCRT;
  #define ParticleTexture2D _ParticleCRT
#else
  #define CRTTEXTURETYPE TEXTURETYPE
  #include "flexcrt.cginc"
  #define ParticleTexture2D _SelfTexture2D
#endif

#define ROW_POS_TTL 0
#define ROW_SPEED_TYPE 1
#define ROW_ACC 2
#define ROW_COLOR 3

#define PARTICLE_TYPE_1 uint(0x01)
#define PARTICLE_TYPE_2 uint(0x02)
#define PARTICLE_TYPE_3 uint(0x04)
#define PARTICLE_TYPE_4 uint(0x08)
#define PARTICLE_TYPE_ALL uint(0xff)

part3 particle_getPos(uint idx)
{
    return ParticleTexture2D[uint2(idx,ROW_POS_TTL)].xyz;
}

part particle_getTTL(uint idx)
{
    return ParticleTexture2D[uint2(idx,ROW_POS_TTL)].w;
}

part3 particle_getSpeed(uint idx)
{
    return ParticleTexture2D[uint2(idx,ROW_SPEED_TYPE)].xyz;
}

uint particle_getType(uint idx)
{
    return ParticleTexture2D[uint2(idx,ROW_SPEED_TYPE)].w;
}

part3 particle_getAcc(uint idx)
{
    return ParticleTexture2D[uint2(idx,ROW_ACC)].xyz;
}

part4 particle_getColor(uint idx)
{
    return ParticleTexture2D[uint2(idx,ROW_COLOR)];
}

#ifndef RENDER_PARTICLES
struct particle_emit_v2g
{
    float4 vertex : SV_POSITION;
    uint2 batchID : TEXCOORD0;
};

struct particle_emit_g2f
{
    float4 vertex : SV_POSITION;
    part4 data : COLOR0;
};

// The vertex shader doesn't really perform much anything.
particle_emit_v2g particle_emit_vert(appdata_customrendertexture IN)
{
    particle_emit_v2g o;
    o.batchID = IN.vertexID / 6;

    // This is unused, but must be initialized otherwise things get janky.
    o.vertex = 0.;
    return o;
}

part4 particle_emit_frag(particle_emit_g2f IN) : SV_Target
{
    return IN.data;
}

void particle_setPosTTL(inout particle_emit_g2f o, inout PointStream<particle_emit_g2f> stream, uint idx, part3 pos, part ttl)
{
    o.vertex = FlexCRTCoordinateOut(uint2(idx,0));
    o.data = part4(pos, ttl);
    stream.Append(o);
}

void particle_setSpeedType(inout particle_emit_g2f o, inout PointStream<particle_emit_g2f> stream, uint idx, part3 speed, uint type)
{
    o.vertex = FlexCRTCoordinateOut(uint2(idx,1));
    o.data = part4(speed, type);
    stream.Append(o);
}

void particle_setAcc(inout particle_emit_g2f o, inout PointStream<particle_emit_g2f> stream, uint idx, part3 acc)
{
    o.vertex = FlexCRTCoordinateOut(uint2(idx,2));
    o.data = part4(acc, 0);
    stream.Append(o);
}

void particle_setColor(inout particle_emit_g2f o, inout PointStream<particle_emit_g2f> stream, uint idx, part4 color)
{
    o.vertex = FlexCRTCoordinateOut(uint2(idx,3));
    o.data = color;
    stream.Append(o);
}
#endif

#endif /* _PARTICLES_CGINC */
