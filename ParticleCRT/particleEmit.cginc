// Some helper functions for writing a particle emitter more easily

#ifndef _PARTICLEEMIT_CGINC
#define _PARTICLEEMIT_CGINC

#include "../cginc/common.cginc"

#if RENDER_PARTICLES
#error "particleEmit.cginc should not be included with RENDER_PARTICLES defined"
#endif
#include "particles.cginc"

// When set we emit particles even when full by way of replacing still live particles
#ifndef ALWAYS_EMIT
#define ALWAYS_EMIT 1
#endif

#if ALWAYS_EMIT != 0
#define IF_ALWAYS_EMIT(x) x
#else
#define IF_ALWAYS_EMIT(x)
#endif

struct emit_context
{
    uint idx;
    IF_ALWAYS_EMIT(uint start;)
    uint end;
    IF_ALWAYS_EMIT(bool outOfSlots;)
};

emit_context make_emit_context(uint start, uint end)
{
#if ALWAYS_EMIT != 0
    emit_context ctx = {
        start,
        start,
        end,
        false,
    };
#else
    emit_context ctx = {
        start,
        end,
    };
#endif
    return ctx;
}

struct emit_parameters
{
    part3 pos; part ttl;
    part3 spd; uint type;
    part3 acc;
    part4 col;
};

emit_parameters make_emit_parameters()
{
    emit_parameters p;
    p.ttl = 0; p.type = 0;
    p.pos = 0; p.spd = 0; p.acc = 0; p.col = 0;
    return p;
}

void emit_particle(
    inout particle_emit_g2f o,
    inout PointStream<particle_emit_g2f> stream,
    inout emit_context ctx,
    emit_parameters p)
{
    while (ctx.idx < ctx.end) {
        // emit if particle slot is open or overwrite if the outOfSlots flag has been set
        if (IF_ALWAYS_EMIT(ctx.outOfSlots ||) particle_getTTL(ctx.idx) <= 0) {
            particle_setPosTTL(o, stream, ctx.idx, p.pos, p.ttl);
            particle_setSpeedType(o, stream, ctx.idx, p.spd, p.type);
            particle_setAcc(o, stream, ctx.idx, p.acc);
            particle_setColor(o, stream, ctx.idx, p.col);

            // Make sure next emit_particle call does not clobber this particle (_SelfTexture2D doesn't change until next buffer swap)
            ++ctx.idx;
            return;
        }
        ++ctx.idx;
    }

#if ALWAYS_EMIT == 1
    // If program flow reaches here we were unable to emit a particle.
    // If _AlwaysEmit is enabled we force emitting by overwriting particles.
    // Sets the outOfSlots flags so that subsequent calls to emit_particle will overwrite an existing particle
    ctx.outOfSlots = true;
    // Randomize starting point
    ctx.idx = ctx.start + uint(random(float2(_Time.x, unity_DeltaTime.x)) * (ctx.start - ctx.end));

    // Overwrites the first particle directly here
    particle_setPosTTL(o, stream, ctx.idx, p.pos, p.ttl);
    particle_setSpeedType(o, stream, ctx.idx, p.spd, p.type);
    particle_setAcc(o, stream, ctx.idx, p.acc);
    particle_setColor(o, stream, ctx.idx, p.col);

    ++ctx.idx;
#endif
}

#endif // _PARTICLEEMIT_CGINC
