Shader "Xantoz/ParticleCRT/ParticleCRT"
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
        return _SelfTexture2D[uint2(idx,0)].xyz;
    }

    float particle_getTTL(uint idx)
    {
        return _SelfTexture2D[uint2(idx,0)].w*TTLSCALE;
    }

    float3 particle_getSpeed(uint idx)
    {
        return _SelfTexture2D[uint2(idx,1)].xyz*SPEEDSCALE;
    }

    float3 particle_getAcc(uint idx)
    {
        return _SelfTexture2D[uint2(idx,2)].xyz*SPEEDSCALE;
    }

    float4 particle_getColor(uint idx)
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

            #if 0
            void particle_setPosTTL(inout g2f o, inout PointStream<g2f> stream, uint idx, float3 pos, float ttl)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,0));
		o.color = float4(pos, ttl/SPEEDSCALE);
		stream.Append(o);
            }

            void particle_setSpeed(inout g2f o, inout PointStream<g2f> stream, uint idx, float3 speed)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,1));
		o.color = float4(speed/SPEEDSCALE, 0);
		stream.Append(o);
            }

            void particle_setAcc(inout g2f o, inout PointStream<g2f> stream, uint idx, float3 acc)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,2));
		o.color = float4(acc/SPEEDSCALE, 0);
		stream.Append(o);
            }

            void particle_setColor(inout g2f o, inout PointStream<g2f> stream, uint idx, float4 color)
            {
		o.vertex = FlexCRTCoordinateOut(uint2(idx,3));
		o.color = color;
		stream.Append(o);
            }
            #endif

            #define particle_setPosTTL(idx, pos, ttl)            \
		o.vertex = FlexCRTCoordinateOut(uint2((idx),0)); \
		o.color = float4((pos), (ttl)/SPEEDSCALE);	 \
		stream.Append(o)

            
            #define particle_setSpeed(idx, speed)                \
                o.vertex = FlexCRTCoordinateOut(uint2((idx),1)); \
                o.color = float4((speed)/SPEEDSCALE, 0);         \
                stream.Append(o)

            #define particle_setAcc(idx, acc)                    \
                o.vertex = FlexCRTCoordinateOut(uint2((idx),2)); \
                o.color = float4((acc)/SPEEDSCALE, 0);           \
            	stream.Append(o)

            #define particle_setColor(idx, col)                  \
                o.vertex = FlexCRTCoordinateOut(uint2((idx),3)); \
                o.color = (col);                                 \
                stream.Append(o)

            // // We can emit a max of 128/4 = 32 particles at once
	    // [maxvertexcount(128)]

            // We only emit one particle at once currently, With position&TTL, speed, acceleration & color, that is 4 vertices out
            [maxvertexcount(4)]
	    void geo(point v2g input[1], inout PointStream<g2f> stream, uint geoPrimID : SV_PrimitiveID)
	    {
                // For now we only want to run the geometry shader once for the entire CRT.
                // Because I cannot currently figure out how to find the free spot with several geometry shader instances at once.
                if (geoPrimID != 0) {
                    return;
                }
                // Perhaps in the future we could utilize instancing + geoPrimID etc. to emit more than one particle at once though?
                // Then each instance (or equivalent) would just need to check free slots in the area it is responsible for

		g2f o;

                // Emit when true (TODO: make configurable and other cool things?
                // TODO: make configurable
                // bool doEmit = AudioLinkData(uint2(0,0)).r > 0.8;
                bool doEmit = true;

                if (doEmit) {
                    // We can have as many active particles as the CRT is wide
                    // We loop through to find one free slot to write in
		    for(int i = 0; i < _CustomRenderTextureWidth; i++ )
		    {
                        // no TTL. This slot is free
                        if (particle_getTTL(i) <= 0)
                        {
                            particle_setPosTTL(i, float3(0,1,0), 30.0);
                            particle_setSpeed(i, random3(_Time.xyz+i)*0.001);
                            particle_setAcc(i, random3(_SinTime.xzw+i)*0.01);
                            particle_setColor(i, float4(random3(_CosTime.xyw+i), 1.0));

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
                
                float4 col = float4(0,0,0,0);
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
                    break;
                    default:
                        // For now let's just let it be black
                    col = random(i.globalTexcoord);
                    break;
                }
                return col;
	    }
	    ENDCG
        }
    }
}
