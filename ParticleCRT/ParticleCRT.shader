Shader "Xantoz/ParticleCRT/ParticleCRT"
{
    Properties
    {
        _Bounds ("Bounding Sphere", Float) = 10
    }

    CGINCLUDE
    #include "common.cginc"
    #define CRTTEXTURETYPE TEXTURETYPE
    #include "flexcrt.cginc"


    #include "../cginc/AudioLinkFuncs.cginc"
    #include "../cginc/rotation.cginc"

    part3 particle_getPos(uint idx)
    {
        return _SelfTexture2D[uint2(idx,0)].xyz*POSSCALE;
    }

    part particle_getTTL(uint idx)
    {
        return _SelfTexture2D[uint2(idx,0)].w*TTLSCALE;
    }

    part3 particle_getSpeed(uint idx)
    {
        return _SelfTexture2D[uint2(idx,1)].xyz*POSSCALE;
    }

    uint particle_getType(uint idx)
    {
        return _SelfTexture2D[uint2(idx,1)].w;
    }

    part3 particle_getAcc(uint idx)
    {
        return _SelfTexture2D[uint2(idx,2)].xyz*POSSCALE;
    }

    part4 particle_getColor(uint idx)
    {
        return _SelfTexture2D[uint2(idx,3)];
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
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geo
            #pragma multi_compile_fog
            #pragma target 5.0

	    struct v2g
	    {
		float4 vertex : SV_POSITION;
		uint2 batchID : TEXCOORD0;
	    };

	    struct g2f
	    {
		float4 vertex : SV_POSITION;
		float4 data : COLOR0;
	    };

	    // The vertex shader doesn't really perform much anything.
	    v2g vert( appdata_customrendertexture IN )
	    {
		v2g o;
		o.batchID = IN.vertexID / 6;

		// This is unused, but must be initialized otherwise things get janky.
		o.vertex = 0.;
		return o;
	    }

            void particle_setPosTTL(inout g2f o, inout PointStream<g2f> stream, uint idx, part3 pos, part ttl)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,0));
		o.data = part4(pos/POSSCALE, ttl/TTLSCALE);
		stream.Append(o);
            }

            void particle_setSpeedType(inout g2f o, inout PointStream<g2f> stream, uint idx, part3 speed, uint type)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,1));
		o.data = part4(speed/POSSCALE, type);
		stream.Append(o);
            }

            void particle_setAcc(inout g2f o, inout PointStream<g2f> stream, uint idx, part3 acc)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,2));
		o.data = part4(acc/POSSCALE, 0);
		stream.Append(o);
            }

            void particle_setColor(inout g2f o, inout PointStream<g2f> stream, uint idx, part4 color)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,3));
		o.data = color;
		stream.Append(o);
            }

            // We only emit one particle at once currently, With position&TTL, speed, acceleration & color, that is 4 vertices out
            // [maxvertexcount(4)]
            [maxvertexcount(128)]
	    // void geo(point v2g input[1], inout PointStream<g2f> stream, uint geoPrimID : SV_PrimitiveID)
	    void geo(triangle v2g input[3], inout PointStream<g2f> stream, uint geoPrimID : SV_PrimitiveID)
	    {
                // For now we only want to run the geometry shader once for the entire CRT.
                // Because I cannot currently figure out how to find the free spot with several geometry shader instances at once.

                if (geoPrimID != 0) {
                    return;
                }
                // Perhaps in the future we could utilize instancing + geoPrimID etc. to emit more than one particle at once though?
                // Then each instance (or equivalent) would just need to check free slots in the area it is responsible for

		g2f o;

                // bool doEmit = AudioLinkData(uint2(0,3)).r + AudioLinkData(uint2(0,1)).r > 0.2;
                // bool doEmit = true;

                float al_beat[4] = {
                    AudioLinkData(uint2(0,0)).r,
                    AudioLinkData(uint2(0,1)).r,
                    AudioLinkData(uint2(0,2)).r,
                    AudioLinkData(uint2(0,3)).r
                };

                part4 col = part4(1,1,1,1);
                // float4 colrandom = float4(0.01*random3(float3(al_beat[1], al_beat[2], al_beat[3])), 1);
                float4 colrandom = float4(0,0,0,0);
                part3 speed, acc;
                part type;
                bool doEmit = false;
                if (al_beat[3] > 0.2) {
                    col = float4(.8, 0, .2, 1)*2 + colrandom;
                    speed = random3(_Time.xyz)*0.01;
                    acc = part3(0,1,0)*0.0001;
                    type = 3;
                    doEmit = true;
                } else if (al_beat[0] > 0.4) {
                    col = float4(0, .8, .2, 1) + colrandom;
                    // speed = random3(_Time.xyz)*0.01;
                    speed = float3(sin(random(_Time.xy)*2*UNITY_PI), 0, cos(random(_Time.xy)*2*UNITY_PI))*0.01;
                    acc = -speed*0.05;
                    speed *= 2;
                    // acc = float3(sin(random(_Time.xy)*2*UNITY_PI), 0, cos(random(_Time.xy)*2*UNITY_PI))*0.0001;
                    type = 0;
                    doEmit = true;
                }

                if (doEmit) {
                    // We can have as many active particles as the CRT is wide
                    // We loop through to find one free slot to write in
		    for(int i = 0; i < _CustomRenderTextureWidth; i++ )
		    {
                        // no TTL. This slot is free
                        if (particle_getTTL(i) <= 0)
                        // if (true)
                        {
                            particle_setPosTTL(o, stream, i, part3(0,0,0), random(_Time.xy)*4);
                            // particle_setPosTTL(i,random3(_Time.xyz+i), 1.0);
                            // particle_setPosTTL(i, part3(_SinTime.x*0.5,_CosTime.x*0.5,random(_Time.xy)), 2.0);

                            particle_setSpeedType(o, stream, i, speed, type);
                            particle_setAcc(o, stream, i, acc);

                            particle_setColor(o, stream, i, part4(random3(col), 1.0));

                            // We emitted our particle. Job done!
                            break;
                        }
		    }
                }
	    }

	    part4 frag( g2f IN ) : SV_Target
	    {
		return IN.data;
                // return part4(random3(_Time.xyz), random(_Time.xy));
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
                // uint x = i.globalTexcoord / _CustomRenderTextureWidth;
                // uint y = i.globalTexcoord / _CustomRenderTextureHeight;

                uint x = i.globalTexcoord.x * _CustomRenderTextureWidth;
                uint y = i.globalTexcoord.y * _CustomRenderTextureHeight;

                // uint x = i.localTexcoord.x;
                // uint y = i.localTexcoord.y;

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
                    case 0:
                        // Update position & TTL
                        // col.rgb = particle_getPos(x) + particle_getSpeed(x);
                        col.rgb = particle_getPos(x) + particle_getSpeed(x);
                        col.rgb += al_beat[3]*float3(0,0.04,0);
                        if (length(col.rgb) < _Bounds) {
                           col.a = (particle_getTTL(x) - unity_DeltaTime.x)/TTLSCALE;
                        } else {
                            col.a = 0;
                        }
                        break;
                    case 1:
                        // Update speed
                        col.rgb = particle_getSpeed(x) + particle_getAcc(x);
                        // col.rgb = particle_getSpeed(x) + particle_getAcc(x) + al_beat[3]*float3(0,0.01,0) - AudioLinkData(uint2(127,3)).r*float3(0,0.004,0);
                    break;
                    case 2:
                        // Update Acceleration
                        // col.rgb = particle_getAcc(x);
                    
                        // col.rgb = particle_getAcc(x)  + random3(_Time.xyz)*0.001*al_beat[1];
                        // col.rgb = particle_getAcc(x)  + random3(t)*0.0001;
                        col.rgb = particle_getAcc(x)  + random3(t)*0.001*al_beat[1];


                        // col.rgb = particle_getAcc(x)  + length(particle_getAcc(x))*random3(_Time.xyz)*0.01;

                        // col.rgb = particle_getAcc(x)*simplex3d(particle_getPos(x)*_Time.xyz);
                        // col.rgb = particle_getAcc(x)  + random3(particle_getSpeed(x))*0.0001;
                    break;
                    case 3:
                        // Update color (just keep the same color)
                        col.rgb = particle_getColor(x);
                    break;
                    default:
                        // For now let's just put randomness for debugging
                        // col = random(i.globalTexcoord+_Time.xy);
                    // col = part4(0,1,0,1)*60000;
                    // col = part4(random3(x*y+_Time.xyz), 1);
                    break;
                }
                return col;
	    }
	    ENDCG
        }
    }
}
