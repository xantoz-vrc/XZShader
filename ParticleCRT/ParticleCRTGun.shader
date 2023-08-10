Shader "Xantoz/ParticleCRT/ParticleCRTGun"
{
    Properties
    {
    }

    CGINCLUDE
    #define ALWAYS_EMIT 1
    #include "particleEmit.cginc"
    #include "../cginc/AudioLinkFuncs.cginc"
    #include "../cginc/rotation.cginc"
    ENDCG

    SubShader
    {
	Tags { }
	ZTest always
	ZWrite Off
        Lighting Off

        Pass
        {
            Name "No-op"
            ColorMask 0
            ZWrite Off
        }

	Pass
	{
	    Name "Emit Particles"

	    CGPROGRAM
            #pragma vertex particle_emit_vert
            #pragma fragment particle_emit_frag
            #pragma geometry geo
            #pragma multi_compile_fog
            #pragma target 5.0


            #define GEOPRIMID_COUNT 2
            [maxvertexcount(128)]
	    void geo(triangle particle_emit_v2g input[3], inout PointStream<particle_emit_g2f> stream, uint geoPrimID : SV_PrimitiveID)
	    {
		particle_emit_g2f o;

                // Split the array in the middle for emission for each thread
                const uint count = _CustomRenderTextureWidth/GEOPRIMID_COUNT;
                const uint start = geoPrimID*count;
                const uint end = start + count;

                emit_context ctx = make_emit_context(start, end);

                float al_beat[4] = {
                    AudioLinkData(uint2(0,0)).r,
                    AudioLinkData(uint2(0,1)).r,
                    AudioLinkData(uint2(0,2)).r,
                    AudioLinkData(uint2(0,3)).r
                };

                emit_parameters p = make_emit_parameters();

                float3 ran = random3(float3(al_beat[1], al_beat[2], al_beat[3]));
                float4 colrandom = float4(0.5*ran, 1);
                if (al_beat[0] > 0.2) {
                    // Splits the loop between the two threads
                    const uint pcount = 16;
                    const uint count = pcount/GEOPRIMID_COUNT;
                    const uint start = geoPrimID*count;
                    const uint end = start + count;

                    p.col = float4(0, 0, .8, 1)*2 + colrandom;
                    for (uint i = start; i < end; ++i) {
                        float angle = float(i) * (2*UNITY_PI/float(pcount));

                        p.ttl = 8; p.type = PARTICLE_TYPE_1;
                        p.pos = part3(cos(angle), sin(angle), 0)*0.05;
                        p.spd = part3(sin(angle), -cos(angle), 0) + part3(0, 0, 2.0);
                        p.acc = -part3(sin(angle), -cos(angle), 0);

                        emit_particle(o, stream, ctx, p);
                    }
                }

                if (al_beat[1] > 0.2) {
                    const uint pcount = 8;
                    const uint count = pcount/GEOPRIMID_COUNT;
                    const uint start = geoPrimID*count;
                    const uint end = start + count;

                    p.col = float4(0, .8, 0, 1)*2 + colrandom;
                    for (uint i = start; i < end; ++i) {
                        float angle = float(i) * (2*UNITY_PI/float(pcount));

                        p.ttl = 4; p.type = PARTICLE_TYPE_1;
                        p.pos = part3(cos(angle), sin(angle), 0)*0.01;
                        p.spd = part3(sin(angle), -cos(angle), 0) + part3(0, 0, 2.0);
                        // p.acc = 0;
                        // p.acc = -part3(sin(angle), -cos(angle), 0)*10;
                        p.acc = -part3(sin(angle)*colrandom.r*5, -cos(angle)*colrandom.g*5, 0)*5;

                        emit_particle(o, stream, ctx, p);
                    }
                }

                if (al_beat[3] > 0.2) {
                    float angle = random(_Time.xy)*UNITY_PI + UNITY_PI*geoPrimID;

                    p.col = float4(.8, 0, 0, 1)*2 + colrandom;
                    p.ttl = 4; p.type = PARTICLE_TYPE_4;
                    p.pos = part3(cos(angle), sin(angle), 0)*0.01;
                    p.spd = part3(0, 0, 2.0);
                    p.acc = part3(0, 0, 0);

                    emit_particle(o, stream, ctx, p);
                }
	    }

	    ENDCG
	}

        Pass
        {
            Name "Update Particles"

            CGPROGRAM
            #pragma vertex DefaultCustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma target 5.0

	    part4 frag(v2f_customrendertexture i) : SV_Target
	    {
                uint x = i.globalTexcoord.x * _CustomRenderTextureWidth;
                uint y = i.globalTexcoord.y * _CustomRenderTextureHeight;

                if (particle_getTTL(x) <= 0.0)  {
                    return float4(0,0,0,0);
                }

                float3 t = float3(
                    AudioLinkGetChronoTime(1, 0),
                    AudioLinkGetChronoTime(2, 2),
                    AudioLinkGetChronoTime(0, 1)
                );

                float al_beat[4] = {
                    AudioLinkData(uint2(0,0)).r,
                    AudioLinkData(uint2(0,1)).r,
                    AudioLinkData(uint2(0,2)).r,
                    AudioLinkData(uint2(0,3)).r
                };

                part4 col = part4(0,0,0,1);
                switch (y) {
                    case ROW_POS_TTL: {
                        // Update position & TTL
                        float3 speed;

                        if (particle_getColor(x).g > .5) {
                            speed = particle_getSpeed(x)*(0.3 + 0.5*al_beat[2]);
                        } else {
                            speed = particle_getSpeed(x)*(0.3 + 0.5*al_beat[0]);
                        }

                        // speed = particle_getSpeed(x)*0.5;

                        col.rgb = particle_getPos(x) + speed*unity_DeltaTime.x;
                        col.a = (particle_getTTL(x) - unity_DeltaTime.x);
                    }
                    break;

                    case ROW_SPEED_TYPE: {
                        // Update speed & Type

                        float3 particlePos = particle_getPos(x);
                        float3 particleSpeed = particle_getSpeed(x);
                        float4 particleCol = particle_getColor(x);
                        float3 acc = particle_getAcc(x);

                        // Attract blue particles towards a line in the centre
                        if (particleCol.b > 1) {
                            float3 attractorPos = float3(0, 0, particlePos.z);
                            float3 attractorDir = attractorPos - particlePos;
                            float attractorScale = (length(attractorDir) == 0.0f) ? 0.0f : (1/sqrt(length(attractorDir)));
                            acc += attractorDir*attractorScale*100*al_beat[0];

                        }

                        // Attract red particles towards a line in the centre
                        if (particleCol.r > 1) {
                            float3 attractorPos = float3(0, 0, particlePos.z);
                            float3 attractorDir = attractorPos - particlePos;
                            float attractorScale = (length(attractorDir) == 0.0f) ? 0.0f : (1/sqrt(length(attractorDir)));
                            acc += attractorDir*attractorScale*100*al_beat[0];
                        }

                        if (particleCol.g > 1) {
                            float3 attractorPos = float3(0, 0, particlePos.z);
                            float3 attractorDir = attractorPos - particlePos;
                            float attractorScale = (length(attractorDir) == 0.0f) ? 0.0f : (1/sqrt(length(attractorDir)));
                            acc += attractorDir*attractorScale*50*(1 - al_beat[3]);
                        }

                        col.rgb = particleSpeed + acc*unity_DeltaTime.x;
                        col.w = col.w; // Type is kept unmodified
                    }
                    break;

                    case ROW_ACC: {
                        // Update Acceleration

                        col.rgb = particle_getAcc(x);

                        part3 add = random3(TIME.xyz+x)*al_beat[1]*unity_DeltaTime.x*10;
                        add.z = 0;
                        col.rgb += add;
                    }
                    break;

                    case ROW_COLOR: {
                        // Update color (just keep the same color)
                        col.rgb = particle_getColor(x);
                    }
                    break;

                    default:
                    break;
                }

                return col;
	    }
	    ENDCG
        }
    }
}
