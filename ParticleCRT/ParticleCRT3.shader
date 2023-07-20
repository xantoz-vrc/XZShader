Shader "Xantoz/ParticleCRT/ParticleCRT3"
{
    Properties
    {
        _Bounds ("Bounding Sphere (particles will get killed if they go outside)", Float) = 10
        _EmitCount ("How many particles to emit at one time", Int) = 5
        [ToggleUI]_AlwaysEmit("Emit particles even when full by way of replacing still live particles", Int) = 1
    }

    CGINCLUDE
    #include "particles.cginc"
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

            int _EmitCount;
            int _AlwaysEmit;

            #define GEOPRIMID_MAX 1
            [maxvertexcount(128)]
	    void geo(triangle particle_emit_v2g input[3], inout PointStream<particle_emit_g2f> stream, uint geoPrimID : SV_PrimitiveID)
	    {
		particle_emit_g2f o;

                float al_beat[4] = {
                    AudioLinkData(uint2(0,0)).r,
                    AudioLinkData(uint2(0,1)).r,
                    AudioLinkData(uint2(0,2)).r,
                    AudioLinkData(uint2(0,3)).r
                };

                part4 col = part4(1,1,1,1);
                float3 ran = random3(float3(al_beat[1], al_beat[2], al_beat[3]));
                float4 colrandom = float4(1*ran, 1);
                // float4 colrandom = float4(0,0,0,0);
                part3 speed, acc;
                uint type;
                bool doEmit = false;
                if (al_beat[3] > 0.2) {
                    col = float4(.8, 0, .2, 1)*2 + colrandom;
                    speed = random3(TIME.xyz)*0.1;
                    acc = part3(0,1,0)*0.0001;
                    type = PARTICLE_TYPE_4;
                    doEmit = true;
                } else if (al_beat[1] > 0.2) {
                    col = float4(.3, 3, .2, 1)*2 + colrandom;
                    speed = random3(TIME.xyz)*0.01;
                    acc = part3(0,-1,0)*0.0001;
                    type = PARTICLE_TYPE_2;
                    doEmit = true;
                } else if (al_beat[0] > 0.4) {
                    col = float4(0, .8, .2, 1) + colrandom;
                    speed = float3(sin(random(TIME.xy)*2*UNITY_PI), 0, cos(random(TIME.xy)*2*UNITY_PI))*0.01;
                    acc = -speed*0.05;
                    speed *= 2;
                    type = PARTICLE_TYPE_1;
                    doEmit = true;
                } else if (al_beat[2] > 0.2) {
                    col = float4(0, .2, .8, 1) + colrandom;
                    speed = float3(sin(random(TIME.xy)*2*UNITY_PI), -0.2, cos(random(TIME.xy)*2*UNITY_PI))*0.01;
                    acc = float3(0,0,0);
                    type = PARTICLE_TYPE_3;
                    doEmit = true;
                }

                if (doEmit) {
                    const uint count = _CustomRenderTextureWidth/(GEOPRIMID_MAX + 1);
                    const uint start = geoPrimID*count;
                    const uint end = start + count;

                    int emitted = 0;

                    // We loop through to find one free slot to write in
		    for (uint i = start; i < end; i++) {
                        if (emitted >= _EmitCount) {
                            break;
                        }

                        // no TTL. This slot is free
                        if (particle_getTTL(i) <= 0) {
                            particle_setPosTTL(o, stream, i, part3(0,0,0), random(TIME.xy)*4);
                            particle_setSpeedType(o, stream, i, speed, type);
                            particle_setAcc(o, stream, i, acc);
                            particle_setColor(o, stream, i, col);

                            emitted++;
                        }
		    }

                    if (_AlwaysEmit && !(emitted >= _EmitCount)) {
                        // We have run out of open particle slots. In this case, we just randomly replace some old particles
                        for (uint i = start; i < end; i++) {
                            if (emitted >= _EmitCount) {
                                break;
                            }

                            particle_setPosTTL(o, stream, i, part3(0,0,0), random(TIME.xy)*4);
                            particle_setSpeedType(o, stream, i, speed, type);
                            particle_setAcc(o, stream, i, acc);
                            particle_setColor(o, stream, i, col);

                            emitted++;
		        }
                    }
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

            float _Bounds;

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
                case ROW_POS_TTL:
                    // Update position & TTL
                    float3 speed;
                    if (particle_getColor(x).g > .5) {
                        speed = particle_getSpeed(x)*(0.3 + 0.5*al_beat[2]);
                    } else {
                        // speed = particle_getSpeed(x)*0.1;
                        speed = particle_getSpeed(x)*(0.3 + 0.5*al_beat[0]);
                    }
                    // speed = particle_getSpeed(x)*0.3;
                    col.rgb = particle_getPos(x) + speed*unity_DeltaTime.x*165;

                    if (length(col.rgb) < _Bounds) {
                        col.a = (particle_getTTL(x) - unity_DeltaTime.x);
                    } else {
                        col.a = 0;
                    }
                    break;
                case ROW_SPEED_TYPE:
                    // Update speed & Type

                    float3 attractorAcc = float3(0,0,0);

                    float3 attractorPos = float3(_SinTime.x,_CosTime.x,_CosTime.y)*frac(TIME.x)*0.5;
                    float3 attractorDir = attractorPos - particle_getPos(x);
                    float attractorScale = (length(attractorDir) == 0.0f) ? 0.0f : (1/sqrt(length(attractorDir)));
                    // attractorAcc = attractorDir*attractorScale*0.003*(1-al_beat[0]*0.3)*0.5;
                    attractorAcc = attractorDir*attractorScale*0.003*(1-al_beat[3]*0.3)*0.5;

                    // if (!(particle_getColor(x).g > .5)) {
                    if (particle_getColor(x).g > .5) {
                        // float attractor2Radius = .2 + .5*al_beat[3];
                        float attractor2Radius = (.2 + .5*al_beat[0]);
                        float3 attractor2Pos = -float3(_SinTime.x,_CosTime.x,_CosTime.y)*frac(TIME.x+0.5)*0.5;;
                        // const float3 attractor2Pos = float3(.5,0,.5);
                        // const float3 attractor2Pos = float3(0.001,0.001,0.001);

                        // float3 attractor2ClosestPoint = attractor2Pos + normalize(particle_getPos(x) - attractor2Pos) * attractor2Radius;
                        // float3 attractor2Dir = attractor2ClosestPoint - particle_getPos(x);
                        // float3 attractor2Length = length(attractor2Dir);
                        // float attractor2Scale = (attractor2Length == 0.0f) ? 0.0f : (1/sqrt(attractor2Length));

                        float attractor2Dist = length(particle_getPos(x)) - attractor2Radius;
                        float3 attractor2Dir = normalize(attractor2Pos - particle_getPos(x))*attractor2Dist;
                        float3 attractor2Length = length(attractor2Dir);
                        float attractor2Scale = (1/sqrt(attractor2Length));

                        // attractoracc = attractor2Dir*attractor2Scale*0.004*(0.5+al_beat[3]);
                        attractorAcc *= 0.5;
                        attractorAcc += attractor2Dir*attractor2Scale*0.004*0.5;
                    }

                    col.rgb = particle_getSpeed(x) + (particle_getAcc(x) + attractorAcc)*unity_DeltaTime.x*165;
                    col.w = col.w; // Type is kept unmodified
                    break;
                case ROW_ACC:
                    // Update Acceleration
                    col.rgb = particle_getAcc(x);
                    col.rgb += random3(TIME.xyz+x)*0.0001*al_beat[1]*unity_DeltaTime.x*165;
                    break;
                case ROW_COLOR:
                    // Update color (just keep the same color)
                    col.rgb = particle_getColor(x);
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
