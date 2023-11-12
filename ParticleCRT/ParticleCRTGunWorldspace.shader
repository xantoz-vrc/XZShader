Shader "Xantoz/ParticleCRT/ParticleCRTGunWorldspace"
{
    Properties
    {
        [ToggleUI]_AttractToLine("Particle attraction to center line", Int) = 1
    }

    CGINCLUDE
    #define ALWAYS_EMIT 1
    #include "particleEmit.cginc"
    #include "../cginc/AudioLinkFuncs.cginc"
    #include "../cginc/rotation.cginc"
    #include "uintToHalf3.cginc"

    Texture2D<float4> _XZWorldspaceGrabPass;
    float4 _XZWorldspaceGrabPass_TexelSize;
    #define GRABSIZE _XZWorldspaceGrabPass_TexelSize.w

    float4 GetFromTexture(uint2 coord)
    {
	#if UNITY_UV_STARTS_AT_TOP
	return _XZWorldspaceGrabPass[uint2(coord.x,GRABSIZE-1-coord.y)];
	#else
	return _XZWorldspaceGrabPass[coord];
	#endif
    }

    bool GrabPassIsAvailable()
    {
        int width, height;
        _XZWorldspaceGrabPass.GetDimensions(width, height);
        return width > 16;
    }

    float4x4 GetM()
    {
        float4x4 m;

        m._m00 = asfloat(half3ToUint(GetFromTexture(uint2(0,0))));
        m._m01 = asfloat(half3ToUint(GetFromTexture(uint2(1,0))));
        m._m02 = asfloat(half3ToUint(GetFromTexture(uint2(2,0))));
        m._m03 = asfloat(half3ToUint(GetFromTexture(uint2(3,0))));

        m._m10 = asfloat(half3ToUint(GetFromTexture(uint2(4,0))));
        m._m11 = asfloat(half3ToUint(GetFromTexture(uint2(5,0))));
        m._m12 = asfloat(half3ToUint(GetFromTexture(uint2(6,0))));
        m._m13 = asfloat(half3ToUint(GetFromTexture(uint2(7,0))));

        m._m20 = asfloat(half3ToUint(GetFromTexture(uint2(8,0))));
        m._m21 = asfloat(half3ToUint(GetFromTexture(uint2(9,0))));
        m._m22 = asfloat(half3ToUint(GetFromTexture(uint2(10,0))));
        m._m23 = asfloat(half3ToUint(GetFromTexture(uint2(11,0))));

        m._m30 = asfloat(half3ToUint(GetFromTexture(uint2(12,0))));
        m._m31 = asfloat(half3ToUint(GetFromTexture(uint2(13,0))));
        m._m32 = asfloat(half3ToUint(GetFromTexture(uint2(14,0))));
        m._m33 = asfloat(half3ToUint(GetFromTexture(uint2(15,0))));

        return m;
    }

    float4x4 GetMNoScaling()
    {
        float4x4 m = GetM();
        // Remove scaling
        m._m00_m01_m02 = normalize(m._m00_m01_m02);
	m._m10_m11_m12 = normalize(m._m10_m11_m12);
	m._m20_m21_m22 = normalize(m._m20_m21_m22);
        return m;
    }
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

                if (!GrabPassIsAvailable()) {
                    return;
                }

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
                float4x4 m = GetMNoScaling();
                float3x3 r = m; // This effectively removes the translation as well

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
                        part3 pos = part3(cos(angle), sin(angle), 0)*0.05;
                        p.pos = mul(m, part4(pos, 1));
                        p.spd = mul(r, part3(sin(angle), -cos(angle), 0) + part3(0, 0, 2.0));
                        p.acc = mul(r, -part3(sin(angle), -cos(angle), 0));

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
                        part3 pos = part3(cos(angle), sin(angle), 0)*0.01;
                        p.pos = mul(m, part4(pos, 1));
                        p.spd = mul(r, part3(sin(angle), -cos(angle), 0) + part3(0, 0, 2.0));
                        p.acc = mul(r, -part3(sin(angle)*colrandom.r*5, -cos(angle)*colrandom.g*5, 0)*5);

                        emit_particle(o, stream, ctx, p);
                    }
                }

                if (al_beat[3] > 0.2) {
                    float angle = random(_Time.xy)*UNITY_PI + UNITY_PI*geoPrimID;

                    p.col = float4(.8, 0, 0, 1)*2 + colrandom;
                    p.ttl = 4; p.type = PARTICLE_TYPE_4;
                    part3 pos = part3(cos(angle), sin(angle), 0)*0.01;
                    p.pos = mul(m, part4(pos, 1));
                    p.spd = mul(r, part3(0, 0, 2.0));
                    p.acc = mul(r, part3(0, 0, 0));

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

            int _AttractToLine;

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

                        if (GrabPassIsAvailable() && _AttractToLine > 0) {
                            // Solve a line equation for the attractors

                            float4x4 m = GetMNoScaling();

                            // Describe a line as two points
                            float3 lineA = mul(m, float4(0,0,0,1));
                            float3 lineB = mul(m, float4(0,0,1,1));
                            float3 rNorm = lineB - lineA; // Already a unit vector by definition (no scaling, remember)

                            float rDist = dot(particlePos - lineA, rNorm);
                            float3 attractorPos = lineA + rNorm*rDist;

                            float3 attractorDir = attractorPos - particlePos;
                            float attractorScale = (length(attractorDir) == 0.0f) ? 0.0f : (1/sqrt(length(attractorDir)));
                            attractorScale *= 0.2; // Overall scale down of gravity

                            // Attract blue particles towards a line in the centre
                            if (particleCol.b > 1) {
                                acc += attractorDir*attractorScale*100*al_beat[0];
                            }

                            // Attract red particles towards a line in the centre
                            if (particleCol.r > 1) {
                                acc += attractorDir*attractorScale*100*al_beat[0];
                            }

                            // Green particles are inverted. The force gets weaker on the beat
                            if (particleCol.g > 1) {
                                acc += attractorDir*attractorScale*50*(1 - al_beat[3]);
                            }
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
