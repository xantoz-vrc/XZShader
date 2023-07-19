// ISC License
//
// Copyright 2023 xantoz
//
// Permission to use, copy, modify, and/or distribute this software
// for any purpose with or without fee is hereby granted, provided
// that the above copyright notice and this permission notice appear
// in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
// WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
// AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
// CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
// OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
// NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
// CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

Shader "Xantoz/ParticleCRT/RenderParticles"
{
    Properties
    {
        [NoScale]_ParticleCRT ("Texture", 2D) = "white" {}

        _PointSize ("Point Size", Float) = 0.1
        _AlphaMultiplier ("Alpha Multiplier (lower makes more transparent)", Range(0.0, 2.0)) = 0.5
        _Bounds ("Bounding Sphere (particles will not be shown but not killed)", Float) = 2.0

        // Can be of use when the colors from the ParticleCRT are too dark
        _ColorAdd ("Additive color to all particles", Color) = (0, 0, 0, 0)

        [Enum(Quads,0,QuadLines,1)]_ParticleType("Particle type", Int) = 0
        _LengthScale("How much to scale speed by when in QuadLines mode", Range(1,10)) = 5

        // Particle Type blinks based on particle type (set by the CRT, but currently it is broken)
        [Enum(Bass,0,LowMid,1,HighMid,2,Treble,3,ParticleType,4)] _BlinkMode ("Blink on which band", Int) = 0

        [Header(Chronotensity Rotation)]
        // Can be used to toggle chronotensity rotation on/off, and to reverse it
        _ChronoRot_Scale ("Chronotensity Rotation Scale", Range(-1.0, 1.0)) = 1.0

        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band0 ("Chronotensity Rotation Type, Bass", Int) = 1
        _ChronoRot_Band0 ("Chronotensity Rotation, Bass", Float) = 0.0
        _ChronoRot_Axis_Band0 ("Chronotensity Rotation Axis, Bass", Vector) = (1,0,0,0)

        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band1 ("Chronotensity Rotation Type, Low Mid", Int) = 1
        _ChronoRot_Band1 ("Chronotensity Rotation, Low Mid", Float) = 0.0
        _ChronoRot_Axis_Band1 ("Chronotensity Rotation Axis, Low Mid", Vector) = (1,0,0,0)

        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band2 ("Chronotensity Rotation Type, High Mid", Int) = 1
        _ChronoRot_Band2 ("Chronotensity Rotation, High Mid", Float) = 0.0
        _ChronoRot_Axis_Band2 ("Chronotensity Rotation Axis, High Mid", Vector) = (1,0,0,0)

        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band3 ("Chronotensity Rotation Type, Treble", Int) = 1
        _ChronoRot_Band3 ("Chronotensity Rotation, Treble", Float) = 0.0
        _ChronoRot_Axis_Band3 ("Chronotensity Rotation Axis, Treble", Vector) = (1,0,0,0)

        [Header(Order to apply rotations above (optimally each number should only be present once))]
        [Enum(Bass,0, Low Mid,1, High Mid,2, Treble,3)]_ChronoRot_Order_0 ("Rotation to apply first",  Int) = 0
        [Enum(Bass,0, Low Mid,1, High Mid,2, Treble,3)]_ChronoRot_Order_1 ("Rotation to apply second", Int) = 1
        [Enum(Bass,0, Low Mid,1, High Mid,2, Treble,3)]_ChronoRot_Order_2 ("Rotation to apply third",  Int) = 2
        [Enum(Bass,0, Low Mid,1, High Mid,2, Treble,3)]_ChronoRot_Order_3 ("Rotation to apply fourth", Int) = 3

        [ToggleUI]_RotateAxis("Let the rotation affect the other axis of rotation", Int) = 0
    }

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma geometry geom
    #pragma multi_compile_fog
    #pragma multi_compile_instancing
    #pragma target 5.0
    #pragma exclude_renderers gles metal

    #include "UnityCG.cginc"
    #include "../cginc/AudioLinkFuncs.cginc"
    #include "../cginc/rotation.cginc"

    #define RENDER_PARTICLES
    #include "particles.cginc"
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

            CGPROGRAM
            float _PointSize;
            float _AlphaMultiplier;
            float _Bounds;

            float4 _ColorAdd;

            int _ParticleType;
            float _LengthScale;
            int _BlinkMode;

            float _ChronoRot_Scale;
            float _ChronoRot_Band0;
            float _ChronoRot_Band1;
            float _ChronoRot_Band2;
            float _ChronoRot_Band3;
            float _ChronoRot_Effect_Band0;
            float _ChronoRot_Effect_Band1;
            float _ChronoRot_Effect_Band2;
            float _ChronoRot_Effect_Band3;
            float3 _ChronoRot_Axis_Band0;
            float3 _ChronoRot_Axis_Band1;
            float3 _ChronoRot_Axis_Band2;
            float3 _ChronoRot_Axis_Band3;
            uint _ChronoRot_Order_0;
	    uint _ChronoRot_Order_1;
	    uint _ChronoRot_Order_2;
	    uint _ChronoRot_Order_3;
            int _RotateAxis;

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
                float4 color : COLOR1;
                float4 vertex : POSITION0;

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

            float3 rotate(float3 pos)
            {
                float chronorot_band[4] = {
                    _ChronoRot_Band0 * AudioLinkGetChronotensity(_ChronoRot_Effect_Band0, 0)/1000000.0,
                    _ChronoRot_Band1 * AudioLinkGetChronotensity(_ChronoRot_Effect_Band1, 1)/1000000.0,
                    _ChronoRot_Band2 * AudioLinkGetChronotensity(_ChronoRot_Effect_Band2, 2)/1000000.0,
                    _ChronoRot_Band3 * AudioLinkGetChronotensity(_ChronoRot_Effect_Band3, 3)/1000000.0
                };
                float3 chronorot_axis[4] = {
                    normalize(_ChronoRot_Axis_Band0),
                    normalize(_ChronoRot_Axis_Band1),
                    normalize(_ChronoRot_Axis_Band2),
                    normalize(_ChronoRot_Axis_Band3),
                };
                uint chronorot_order[4] = {
                    _ChronoRot_Order_0,
                    _ChronoRot_Order_1,
                    _ChronoRot_Order_2,
                    _ChronoRot_Order_3,
                };

                if (_RotateAxis) {
                    float3 axis = chronorot_axis[chronorot_order[0]];
                    for (uint i = 0; i < 4; ++i) {
                        uint idx = chronorot_order[i];
                        float angle = _ChronoRot_Scale*frac(chronorot_band[idx])*360;
                        float3x3 R = AngleAxis3x3(radians(angle), axis);
                        pos = mul(R, pos);
                        axis = mul(R, chronorot_axis[chronorot_order[(i+1) % 4]]);
                    }
                } else {
                    for (uint i = 0; i < 4; ++i) {
                        uint idx = chronorot_order[i];
                        float angle = _ChronoRot_Scale*frac(chronorot_band[idx])*360;
                        pos = mul(AngleAxis3x3(radians(angle), chronorot_axis[idx]), pos);
                    }
                }
                
                return pos;
            }

            float4 billboard(float2 xy, float2 scale)
            {
                return mul(transpose(UNITY_MATRIX_IT_MV),
		    mul(UNITY_MATRIX_MV, float4(0.0, 0.0, 0.0, 1.0))
		    + float4(xy, 0.0, 0.0) * float4(scale, 1.0, 1.0)
                );
            }

            float4 billboard2(float3 xyz, float2 xy, float2 scale)
            {
                return mul(transpose(UNITY_MATRIX_IT_MV),
		    mul(UNITY_MATRIX_MV, float4(xyz, 1.0))
		    + float4(xy, 0.0, 0.0) * float4(scale, 1.0, 1.0)
                );
            }

            float4 billboard3(float3 xyz, float2 xy, float2 scale)
            {
                return mul(UNITY_MATRIX_P,
                    mul(UNITY_MATRIX_MV, float4(xyz, 1.0))
                    + float4(xy, 0.0, 0.0) * float4(scale, 1.0, 1.0));
            }

            // 12 input points * 32 instances * 6 samples per instance = up to 2304 particles renderable (i practice limited by CRT size)
            #define SAMPLECNT 12

	    [instance(32)]
            [maxvertexcount(SAMPLECNT*6)]
	    void geom(point v2g IN[1], inout TriangleStream<g2f> stream, uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
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

                for (int i = 0; i < SAMPLECNT; ++i)
                {
                    uint idx = i + operationID * SAMPLECNT;

                    int width, height;
                    _ParticleCRT.GetDimensions(width, height);
                    if (idx > uint(width)) {
                        break;
                    }

                    float ttl = particle_getTTL(idx);
                    if (ttl <= 0) {
                        continue;
                    }

                    part3 pointOut = particle_getPos(idx);
                    if (length(pointOut) > _Bounds) {
                        continue;
                    }
                    pointOut = rotate(pointOut);
                    float4 color = particle_getColor(idx);
                    o.color = color;

                    float pointSize = _PointSize;
                    if (_BlinkMode < 4) {
                        float al_beat = AudioLinkData(uint2(0,_BlinkMode)).r;
                        pointSize += al_beat*_PointSize*2;
                    } else {
                        float al_beat[4] = {
                            AudioLinkData(uint2(0,0)).r,
                            AudioLinkData(uint2(0,1)).r,
                            AudioLinkData(uint2(0,2)).r,
                            AudioLinkData(uint2(0,3)).r
                        };

                        uint type = particle_getType(idx);
                        for (uint i = 0; i < 4; ++i) {
                            if ((type & (1 << i)) != 0) {
                                pointSize += al_beat[i]*_PointSize*2;
                            }
                        }
                    }

                    float4 pointTL, pointTR, pointBL, pointBR;
                    if (_ParticleType == 0) {
                        pointTL = UnityObjectToClipPos(pointOut + billboard(TL*pointSize, IN[0].worldScale.xy));
		        pointTR = UnityObjectToClipPos(pointOut + billboard(TR*pointSize, IN[0].worldScale.xy));
		        pointBL = UnityObjectToClipPos(pointOut + billboard(BL*pointSize, IN[0].worldScale.xy));
		        pointBR = UnityObjectToClipPos(pointOut + billboard(BR*pointSize, IN[0].worldScale.xy));
                    } else {
                        float3 speed = rotate(particle_getSpeed(idx))*_LengthScale;
                        // pointTL = billboard3(pointOut + speed, TL*pointSize, IN[0].worldScale.xy);
			// pointTR = billboard3(pointOut + speed, TR*pointSize, IN[0].worldScale.xy);
		        // pointBL = billboard3(pointOut - speed, BL*pointSize, IN[0].worldScale.xy);
			// pointBR = billboard3(pointOut - speed, BR*pointSize, IN[0].worldScale.xy);
                        pointTL = billboard3(pointOut + speed, float2(-length(speed), -1)*pointSize, IN[0].worldScale.xy);
		        pointTR = billboard3(pointOut + speed, float2(-length(speed),  1)*pointSize, IN[0].worldScale.xy);
		        pointBL = billboard3(pointOut - speed, float2(length(speed),  -1)*pointSize, IN[0].worldScale.xy);
			pointBR = billboard3(pointOut - speed, float2(length(speed),   1)*pointSize, IN[0].worldScale.xy);
                    }

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
                return -clamp((1.0-pow(0.5/abs(a), .9)), -2, 0);
            }

            float4 frag(g2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);


                float val = linefn(length((frac(i.uv.xy) - float2(0.5, 0.5))*2));
                float4 color_in = i.color + _ColorAdd;
                float4 col = clamp(val*color_in, 0.0, 4.0);
                col.a *= _AlphaMultiplier;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}

