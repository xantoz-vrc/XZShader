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


// This is similar to XZAudioLinkGeometryVectorScope2 but designed around using a Plane that is 200 tris big instead
// For simplicity it is designed around using the 200 tris in from the plane and geoPrimID, to give 2000 samples without using instancing
// Then we use instances to create duplicates of the thingy around a ring


Shader "Xantoz/XZAudioLinkGeometryVectorScopeRing"
{
    Properties
    {
        [HDR]_Color1 ("Color 1 (Base Color)", Color) = (1,1,1,1)

        [IntRange]_3D ("3D effect (move in Z direction as well)", Range(0,1)) = 0

        _PointSize ("Point Size", Float) = 0.025
        _AlphaMultiplier ("Alpha Multiplier (lower makes more transparent)", Range(0.0, 2.0)) = 0.5

        // Need to scale by a factor of 10 by deafult as the unity default plane is not 1x1 m like the quad but it is 10x10m (maybe I should've just made my own mesh with 200 tris?)
        _Scaling ("Scale Compensation", Range(0.1,20)) = 10

        _Amplitude_Scale ("Amplitude Scale", Range(0.0, 2.0)) = 1  // Scale amplitude of PCM data

        // Each option will set _OVERLAY_NONE, _OVERLAY_ADD, _OVERLAY_MULTIPLY shader keywords.
        [KeywordEnum(Quad, Point, Line)] _OutMode ("Output Mode", Float) = 0

        [Space(10)]
        [Header(Color Blink)]
        [HDR]_Color2 ("Color 2 (Blink Base Color)", Color) = (1,1,1,1)
        [HDR]_Color_Mul_Band0 ("Color Bass", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band1 ("Color Low Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band2 ("Color High Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band3 ("Color Treble", Color) = (0,0,0,0)

        [Space(10)]
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

        [Space(10)]
        [Header(Beat Movement xyz are just as you would imagine while w is movement along the circle radius)]
        _BeatMovement_Band0 ("Beat movement, Bass", Vector) = (0,0,0,0)
        _BeatMovement_Band1 ("Beat movement, Low Mid", Vector) = (0,0,0,0)
        _BeatMovement_Band2 ("Beat movement, High Mid", Vector) = (0,0,0,0)
        _BeatMovement_Band3 ("Beat movement, Treble", Vector) = (0,0,0,0)
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

        #define INSTANCES 8

        // 200 input triangles * 10 samples per instance = 2000 samples out
        #define SAMPLECNT 10
    ENDCG

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "VRCFallback"="Hidden" }
        LOD 100
        Cull Off
        ZWrite Off
        // ZTest always

        Pass
        {
            Blend SrcAlpha One
            // Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma multi_compile _OUTMODE_QUAD _OUTMODE_POINT _OUTMODE_LINE

            float _PointSize;
            float _AlphaMultiplier;

            float _Amplitude_Scale;
            float _Scaling;

            int _3D;

            float4 _Color1;
            float4 _Color2;
            float4 _Color_Mul_Band0;
            float4 _Color_Mul_Band1;
            float4 _Color_Mul_Band2;
            float4 _Color_Mul_Band3;

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

            float4 _BeatMovement_Band0;
            float4 _BeatMovement_Band1;
            float4 _BeatMovement_Band2;
            float4 _BeatMovement_Band3;

            struct appdata
            {
                float4 vertex : POSITION;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

	    struct v2g
	    {
		float4 vertex : POSITION0;
                float3 worldScale : COLOR0_nointerpolation;

		UNITY_VERTEX_OUTPUT_STEREO
            };

            struct g2f
            {
                float2 uv : TEXCOORD0;
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

                o.worldScale = _Scaling*float3(
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

            float3 placeOnRing(uint instanceID)
            {
                float instance = (float(instanceID)/float(INSTANCES));
                
                float angle = instance*2*UNITY_PI;
                float3 pos = float3(sin(angle), 0, cos(angle))*0.5;

                // int j = instance*128;
                int j = instance*32;
                float4 al_beatmove[4] = {
                    AudioLinkData(uint2(j,0)).r*_BeatMovement_Band0,
                    AudioLinkData(uint2(j,1)).r*_BeatMovement_Band1,
                    AudioLinkData(uint2(j,2)).r*_BeatMovement_Band2,
                    AudioLinkData(uint2(j,3)).r*_BeatMovement_Band3,
                };

                for (uint i = 0; i < 4; ++i) {
                    pos.xz *= (1 + al_beatmove[i].w);
                    pos.xyz += al_beatmove[i].xyz;
                }

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

            [instance(INSTANCES)]
#if defined(_OUTMODE_QUAD)
            // 8 samples * 6 vertices out (quad)
            [maxvertexcount(SAMPLECNT*6)]
	    void geom(triangle v2g IN[3], inout TriangleStream<g2f> stream, uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
#elif defined(_OUTMODE_LINE)
            // Needs one more vertex to link up to the line the next instance will draw
            [maxvertexcount(SAMPLECNT+1)]
	    void geom(triangle v2g IN[3], inout LineStream<g2f> stream, uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
#else // _OUTMODE_POINT
            [maxvertexcount(SAMPLECNT)]
	    void geom(triangle v2g IN[3], inout PointStream<g2f> stream, uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
#endif
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN[0]);

                g2f o;
                UNITY_INITIALIZE_OUTPUT(g2f, o);
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(IN[0], o);

                if (!AudioLinkIsAvailable())
                {
                    return;
                }

#if defined(_OUTMODE_QUAD)
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
                    uint sampleID = i + geoPrimID * SAMPLECNT;
                    float4 pcm = AudioLinkPCMData(sampleID)*0.5*_Amplitude_Scale;
                    float2 pcm_lr = PCMToLR(pcm);
                    float3 pointOut = placeOnRing(instanceID);
                    pointOut.xy += pcm_lr;

                    float4 pointTL, pointTR, pointBL, pointBR;
                    if (_3D) {
                        pointOut.z += pcm.g;
                        pointOut *= _Scaling;

                        pointTL = UnityObjectToClipPos(pointOut + billboard(TL*_PointSize, IN[0].worldScale.xy));
			pointTR = UnityObjectToClipPos(pointOut + billboard(TR*_PointSize, IN[0].worldScale.xy));
			pointBL = UnityObjectToClipPos(pointOut + billboard(BL*_PointSize, IN[0].worldScale.xy));
			pointBR = UnityObjectToClipPos(pointOut + billboard(BR*_PointSize, IN[0].worldScale.xy));
                    } else {
                        pointOut *= _Scaling;

                        pointTL = UnityObjectToClipPos(pointOut + float3(TL*_PointSize, 0.0));
                        pointTR = UnityObjectToClipPos(pointOut + float3(TR*_PointSize, 0.0));
                        pointBL = UnityObjectToClipPos(pointOut + float3(BL*_PointSize, 0.0));
                        pointBR = UnityObjectToClipPos(pointOut + float3(BR*_PointSize, 0.0));
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
#else // defined(_OUTMODE_LINE) || defined(_OUTMODE_POINT)
                int cnt = SAMPLECNT;
  #if defined(_OUTMODE_LINE)
                cnt++;
  #endif
                for (int i = 0; i < cnt; ++i)
                {
                    uint sampleID = i + geoPrimID * SAMPLECNT;
                    float4 pcm = AudioLinkPCMData(sampleID)*0.5*_Amplitude_Scale;
                    float2 pcm_lr = PCMToLR(pcm);
                    float3 pointOut = placeOnRing(instanceID);
                    pointOut.xy += pcm_lr;

                    if (_3D) {
                        pointOut.z += pcm.g;
                    }

                    pointOut *= _Scaling;

                    o.vertex = UnityObjectToClipPos(pointOut);
                    UNITY_TRANSFER_FOG(o, o.vertex);
                    stream.Append(o);
                }
#endif
            }

            float4 getBeatColor()
            {

                float4 colorband[4] = {
                    _Color_Mul_Band0,
                    _Color_Mul_Band1,
                    _Color_Mul_Band2,
                    _Color_Mul_Band3,
                };

#if defined(_OUTMODE_LINE) || defined(_OUTMODE_POINT)
                // Attempt to un-HDR the color
                for (uint i = 0; i < 4; ++i) {
                    colorband[i].rgb = colorband[i].rgb/max(colorband[i].r, max(colorband[i].g, colorband[i].g));
                }
#endif
                float al_beat[4] = {
                    AudioLinkData(uint2(0,0)).r,
                    AudioLinkData(uint2(0,1)).r,
                    AudioLinkData(uint2(0,2)).r,
                    AudioLinkData(uint2(0,3)).r
                };
                float4 al_color_mult =
                    colorband[0]*al_beat[0] +
                    colorband[1]*al_beat[1] +
                    colorband[2]*al_beat[2] +
                    colorband[3]*al_beat[3];
                return al_color_mult;
            }

            float linefn(float a)
            {
                return -clamp((1.0-pow(0.5/abs(a), .1)), -2, 0);
            }

            float4 frag(g2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                if (!AudioLinkIsAvailable())
                {
                    return float4(0,0,0,0);
                }

                float4 al_color_mult = getBeatColor();
#if defined(_OUTMODE_QUAD)
                float val = linefn(length((frac(i.uv.xy) - float2(0.5, 0.5))*2));
                float4 col = clamp(val*(_Color1 + _Color2*al_color_mult), 0.0, 1.0);

#else // defined(_OUTMODE_LINE) || defined(_OUTMODE_POINT)
                // Try our best to not wash out to white (no proper HDR support here)
                float4 col = clamp((_Color1 + _Color2*al_color_mult)/2, 0.0, 1.0);
#endif
                col.a *= _AlphaMultiplier;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
