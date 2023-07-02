Shader "Xantoz/ParticleCRT/RenderParticles"
{
    Properties
    {
        [NoScale]_ParticleCRT ("Texture", 2D) = "white" {}

        _PointSize ("Point Size", Float) = 0.1
        _AlphaMultiplier ("Alpha Multiplier (lower makes more transparent)", Range(0.0, 2.0)) = 0.5
    }

    CGINCLUDE
    #include "UnityCG.cginc"

    Texture2D<float4> _ParticleCRT;
    SamplerState sampler_ParticleCRT;

    #define TTLSCALE 60 // Largest TTL is expected to be 60 seconds
    #define SPEEDSCALE 4
    float3 particle_getPos(uint idx)
    {
        return _ParticleCRT[uint2(idx,0)].xyz;
    }

    float particle_getTTL(uint idx)
    {
        return _ParticleCRT[uint2(idx,0)].w*TTLSCALE;
    }

    float3 particle_getSpeed(uint idx)
    {
        return _ParticleCRT[uint2(idx,1)].xyz*SPEEDSCALE;
    }

    float3 particle_getAcc(uint idx)
    {
        return _ParticleCRT[uint2(idx,2)].xyz*SPEEDSCALE;
    }

    float4 particle_getColor(uint idx)
    {
        return _ParticleCRT[uint2(idx,3)];
    }
    ENDCG

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "VRCFallback"="Hidden" }
        LOD 100
        Cull Off
        ZWrite Off

        Pass
        {
            Blend SrcAlpha One
            // Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma target 5.0
            #pragma exclude_renderers gles metal

            float _PointSize;
            float _AlphaMultiplier;

            struct appdata
            {
                float4 vertex : POSITION;
	        uint vertexID : SV_VertexID;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

	    struct v2g
	    {
		float4 vertex : POSITION0;
		uint2 batchID : TEXCOORD0;
                float3 worldScale : COLOR0_nointerpolation;

		UNITY_VERTEX_OUTPUT_STEREO
            };

            struct g2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : POSITION0;
                float4 color : COLOR0;

                UNITY_FOG_COORDS(1)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2g vert(appdata v)
            {
                v2g o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2g, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = v.vertex;
                o.batchID = v.vertexID / 6; // Assumes we get a quad

                o.worldScale = float3(
                    length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)), // scale x axis
                    length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)), // scale y axis
                    length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z))  // scale z axis
                );

                return o;
            }

            float4 billboard(float2 xy, float2 scale)
            {
                return mul(transpose(UNITY_MATRIX_IT_MV),
		    mul(UNITY_MATRIX_MV, float4(0.0, 0.0, 0.0, 1.0))
		    + float4(xy, 0.0, 0.0) * float4(scale, 1.0, 1.0)
                );
            }

            // 6 input points * 32 instances * 5 samples per instance = 1152 particles out (in practice will be 1024 or so)
            #define SAMPLECNT 6

            [maxvertexcount(SAMPLECNT*6)]
	    [instance(32)]
	    void geom(point v2g IN[1], inout TriangleStream<g2f> stream,
		uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN[0]);

		int batchID = IN[0].batchID;
             	int operationID = geoPrimID * 32 + ( instanceID - batchID );

                g2f o;
                UNITY_INITIALIZE_OUTPUT(g2f, o);
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(IN[0], o);

                const float2 TL = float2(-1.0,-1.0);
		const float2 TR = float2(-1.0, 1.0);
		const float2 BL = float2( 1.0,-1.0);
		const float2 BR = float2( 1.0, 1.0);

                const float2 uvTL = (TL + float2(1.0, 1.0))/2;
		const float2 uvTR = (TR + float2(1.0, 1.0))/2;
		const float2 uvBL = (BL + float2(1.0, 1.0))/2;
		const float2 uvBR = (BR + float2(1.0, 1.0))/2;

                int width, height;
                _ParticleCRT.GetDimensions(width, height);

                for (int i = 0; i < SAMPLECNT; ++i)
                {
                    uint idx = i + operationID * SAMPLECNT;
                    if (idx > width) { // This is esentially just manual clamp I guess. But it is needed since it isn't really possible to get a multiple of 6 (=2*3) to line up perfect with a power of two
                        break;
                    }

                    float3 pointOut = particle_getPos(idx);
                    float4 color = particle_getColor(idx);

                    float4 pointTL, pointTR, pointBL, pointBR;
                    pointTL = UnityObjectToClipPos(pointOut + billboard(TL*_PointSize, IN[0].worldScale.xy));
		    pointTR = UnityObjectToClipPos(pointOut + billboard(TR*_PointSize, IN[0].worldScale.xy));
		    pointBL = UnityObjectToClipPos(pointOut + billboard(BL*_PointSize, IN[0].worldScale.xy));
		    pointBR = UnityObjectToClipPos(pointOut + billboard(BR*_PointSize, IN[0].worldScale.xy));
                    
                    o.vertex = pointTL; o.uv = uvTL;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);
                    o.vertex = pointTR; o.uv = uvTR;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);
                    o.vertex = pointBL; o.uv = uvBL;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);

                    o.vertex = pointBL; o.uv = uvBL;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);
                    o.vertex = pointBR; o.uv = uvBR;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);
                    o.vertex = pointTR; o.uv = uvTR;
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);

                    stream.RestartStrip();
                }
            }

            float linefn(float a)
            {
                return -clamp((1.0-pow(0.5/abs(a), .1)), -2, 0);
            }

            float4 frag(g2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float val = linefn(length((frac(i.uv.xy) - float2(0.5, 0.5))*2));

                float4 col = clamp(val*i.color, 0.0, 1.0);
                col.a *= _AlphaMultiplier;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
