ACCShader "Xantoz/ParticleCRT/ParticleCRT"
{
    Properties
    {
    }

    CGINCLUDE
    // #define CRTTEXTURETYPE uint4
    #define CRTTEXTURETYPE float4
    #include "flexcrt.cginc"

    #include "../cginc/AudioLinkFuncs.cginc"

    #define TTLSCALE 60 // Largest TTL is expected to be 60 seconds
    #define SPEEDSCALE 4

    float3 particle_getPos(uint idx)
    {
        return _SelfTexture2D[idx,0].xyz;
    }

    float particle_getTTL(uint idx)
    {
        return _SelfTexture2D[idx,0].w*TTLSCALE;
    }

    float3 particle_getSpeed(uint idx)
    {
        return _SelfTexture2D[idx,1].xyz*SPEEDSCALE;
    }

    float3 particle_getAcc(uint idx)
    {
        return _SelfTexture2D[idx,2].xyz*SPEEDSCALE;
    }

    float4 particle_getColor(uint idx)
    {
        return _SelfTexture2D[idx,3];
    }

    // From: https://stackoverflow.com/questions/5149544/can-i-generate-a-random-number-inside-a-pixel-shader
    float rand(float2 p)
    {
        // We need irrationals for pseudo randomness.
        // Most (all?) known transcendental numbers will (generally) work.
        const float2 r = float2(
            23.1406926327792690,  // e^pi (Gelfond's constant)
            2.6651441426902251); // 2^sqrt(2) (Gelfond–Schneider constant)
        return frac(cos(mod(123456789.0, 1e-7 + 256.0 * dot(p,r))));
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
	    Name "Emit Particles"
	    
	    CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geo
            #pragma multi_compile_fog
            #pragma target 5.0

            void particle_setPosTTL(inout PointStream<g2f> stream, uint idx, float3 pos, float ttl)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,0));
		o.color = float4(pos, ttl/SPEEDSCALE);
		stream.Append(o);
            }

            void particle_setSpeed(inout PointStream<g2f> stream, uint idx, float3 speed)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,1));
		o.color = float4(speed/SPEEDSCALE, 0);
		stream.Append(o);
            }

            void particle_setAcc(inout PointStream<g2f> stream, uint idx, float3 acc)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,2));
		o.color = float4(acc/SPEEDSCALE, 0);
		stream.Append(o);
            }

            void particle_setColor(inout PointStream<g2f> stream, uint idx, float4 color)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,3));
		o.color = color;
		stream.Append(o);
            }

	    struct v2g
	    {
		float4 vertex : SV_POSITION;
		uint2 batchID : TEXCOORD0;
	    };

	    struct g2f
	    {
		float4 vertex		   : SV_POSITION;
		uint4 color			: TEXCOORD0;
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

            // // We can emit a max of 128/4 = 32 particles at once
	    // [maxvertexcount(128)]

            // We only emit one particle at once currently, With position&TTL, speed, acceleration & color, that is 4 vertices out
            [maxvertexcount(4)]
	    void geo(triangle v2g input[3], inout PointStream<g2f> stream, uint geoPrimID : SV_PrimitiveID)
	    {
                // For now we only want to run the geometry shader once for the entire CRT.
                // Because I cannot currently figure out how to find the free spot with several geometry shader instances at once.
                if (geoPrimId != 0) {
                    return;
                }
                // Perhaps in the future we could utilize instancing + geoPrimID etc. to emit more than one particle at once though?
                // Then each instance (or equivalent) would just need to check free slots in the area it is responsible for

		g2f o;

                // Emit when true (TODO: make configurable and other cool things?
                // TODO: make configurable
                bool doEmit = AudioLinkData(uint2(0,0)).r > 0.8;

                if (doEmit) {
                    // We can have as many active particles as the CRT is wide
                    // We loop through to find one free slot to write in
		    for(int i = 0; i < _CustomRenderTextureWidth; i++ )
		    {
                        // no TTL. This slot is free
                        if (particle_getTTL(i) <= 0)
                        {
                            particle_setPosTTL(float3(0,0,0), 30);
                            particle_setSpeed(float3(random(_Time.xy),float3(random())));
                            particle_setAcc(random(_SinTime.zw)*0.1);
                            particle_setColor(random(_CosTime.xy));

                            // We emitted our particle. Job done!
                            break;
                        }
		    }
                }
	    }

	    float4 frag( g2f IN ) : SV_Target
	    {
		return IN.color;
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

	    float4 frag(v2f_customrendertexture i) : SV_Target
	    {
                uint x = i.globalTexcoord / _CustomRenderTextureWidth;
                uint y = i.globalTexcoord / _CustomRenderTextureHeight;
                
                float4 col;
                switch (y) {
                    case 0:
                    // Update position & TTL
                    col.rgb = particle_getPos(x) + particle_getSpeed(x);
                    col.a = (particle_getTTL(x) - 1)/TTLSCALE;
                    break;
                    case 1:
                    // Update speed
                    break;
                    case 2:
                    // Update Acceleration (do nothing currently)
                    col.rgb = particle_getAcc(x);
                    break;
                    case 3:
                    // Update color (just keep the same color)x
                    col.rgb = particle_getAcc(x);
                    default:
                    // For now let's just let it be black
                    break;
                }
	    }
	    ENDCG
        }
    }
}
