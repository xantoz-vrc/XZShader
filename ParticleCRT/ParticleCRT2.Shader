Shader "Xantoz/ParticleCRT/ParticleCRT2"
{
    Properties
    {
        _Bounds ("Bounding Sphere", Float) = 10
        _EmitCount ("How many particles to emit at one time", Int) = 10
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

            [maxvertexcount(128)]
	    void geo(triangle particle_emit_v2g input[3], inout PointStream<particle_emit_g2f> stream, uint geoPrimID : SV_PrimitiveID)
	    {
                // For now we only want to run the geometry shader once for the entire CRT.
                // Because I cannot currently figure out how to find the free spot with several geometry shader instances at once.

                if (geoPrimID != 0) {
                    return;
                }
                // Perhaps in the future we could utilize instancing + geoPrimID etc. to emit more than one particle at once though?
                // Then each instance (or equivalent) would just need to check free slots in the area it is responsible for

		particle_emit_g2f o;

                float al_beat[4] = {
                    AudioLinkData(uint2(0,0)).r,
                    AudioLinkData(uint2(0,1)).r,
                    AudioLinkData(uint2(0,2)).r,
                    AudioLinkData(uint2(0,3)).r
                };

                part4 col = part4(1,1,1,1);
                float3 ran = random3(float3(al_beat[1], al_beat[2], al_beat[3]));
                float4 colrandom = float4(0.1*ran, 1);
                part3 speed, acc;
                uint type;
                bool doEmit = false;
                if (al_beat[3] > 0.2) {
                    col = float4(.8, 0, .2, 1)*2 + colrandom;
                    speed = random3(TIME.xyz)*0.01;
                    acc = part3(0,1,0)*0.0001;
                    type = PARTICLE_TYPE_4;
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

                int emitted = 0;
                if (doEmit) {
                    // We can have as many active particles as the CRT is wide
                    // We loop through to find one free slot to write in
		    for(int i = 0; i < _CustomRenderTextureWidth; i++ )
		    {
                        if (emitted >= _EmitCount) {
                            break;
                        }

                        // no TTL. This slot is free
                        if (particle_getTTL(i) <= 0)
                        {
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
                    col.rgb = particle_getPos(x) + particle_getSpeed(x)*(0.3 + al_beat[0])*unity_DeltaTime.x*60;
                    if (length(col.rgb) < _Bounds) {
                        col.a = (particle_getTTL(x) - unity_DeltaTime.x);
                    } else {
                        col.a = 0;
                    }
                    break;
                case ROW_SPEED_TYPE:
                    // Update speed & Type
                    col.rgb = particle_getSpeed(x) + particle_getAcc(x)*unity_DeltaTime.x*60;
                    col.w = col.w; // Type is kept unmodified
                    break;
                case ROW_ACC:
                    // Update Acceleration
                    col.rgb = particle_getAcc(x);
                    col.rgb += random3(TIME.xyz+x)*0.001*al_beat[1]*unity_DeltaTime.x*60;
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
