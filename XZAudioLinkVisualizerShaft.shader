// Copyright (c) 2020, Suzuki Kojiro
// All rights reserved.

// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:

// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.

// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


Shader "Xantoz/XZAudioLinkVisualizerShaft"
{
    Properties
    {
	_Depth ("Depth", 2D) = "white" {}
	_Brightness ("Brightness", Range(0, 10)) = 1.0
	_DirectionalFactor ("Directional Factor", Range (0, 5.0)) = 1.0
	_ConstantFactor ("Constant Factor", Range (0, 5.0)) = 0.2
	[MaterialToggle] _Invert ("Invert", Int) = 0
	_Scale ("Scale", Range(0, 1)) = 1

        [Space(10)]
        [Header(Visualizer)]
        [Space(10)]

        [Header(Basic Setings)]
        [Enum(XZAudioLinkVisualizerMode)] _Mode("Visualizer Mode", Int) = 0
        [HDR]_Color1 ("Color 1 (Base Color)", Color) = (1,1,1,1)

        _ST ("UV tiling and offset", Vector) = (1,1,0,0)
        _Tiling_Scale ("UV Tiling scale", Range(0.1, 10.0)) = 1.0 // First added so we could have a nice slider in ShaderFes 2021 (normally you could also just modify _ST)

        _Rotation ("Rotation", Range(-360,360)) = 0.0
        // When enabled should randomly reverse the direction of rotation at times
        [IntRange]_Rotation_Reversing ("[Experimental] Random Rotation Reversing (Chronotensity)", Range(0,1)) = 0

        _Amplitude_Scale ("Amplitude Scale", Range(0.0, 2.0)) = 1.0  // Scale amplitude of PCM & DFT data in plots

        [Space(10)]
        [Header(Vignette)]
        _Vignette_Intensity ("Vignette Intensity", Range(0.0,1.0)) = 1.0
        _Vignette_Inner_Radius ("Vignette Inner Radius", Range(0.0, 1.41421356237)) = 0.85
        _Vignette_Outer_Radius ("Vignette Outer Radius", Range(0.0, 1.41421356237)) = 1.0
        [Enum(Circle,0, Diamond,1, Box,2)] _Vignette_Type("Vignette Type", Int) = 0


        [Space(10)]
        [Header(Color Blink)]
        [HDR]_Color2 ("Color 2 (Blink Base Color)", Color) = (1,1,1,1)
        [HDR]_Color_Mul_Band0 ("Color Bass", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band1 ("Color Low Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band2 ("Color High Mid", Color) = (0,0,0,0)
        [HDR]_Color_Mul_Band3 ("Color Treble", Color) = (0,0,0,0)

        [Space(10)]
        [Header(Chronotensity Scroll (Tiling and Offset))]
        // This one affects the values as they come out of AudioLink. Can be used to toggle chronotensity scroll.
        _Chronotensity_Scale ("Chronotensity Scroll Scale (Toggle Scroll)", Range(-1.0, 1.0)) = 1.0

        [Enum(AudioLinkChronotensityEnum)]_Chronotensity_Effect_Band0 ("Chronotensity Scroll Type, Bass", Int) = 1
        _Chronotensity_ST_Band0 ("Chronotensity Scroll, Bass", Vector) = (0,0,0,0)
        [Enum(AudioLinkChronotensityEnum)]_Chronotensity_Effect_Band1 ("Chronotensity Scroll Type, Low Mid", Int) = 1
        _Chronotensity_ST_Band1 ("Chronotensity Scroll, Low Mid", Vector) = (0,0,0,0)
        [Enum(AudioLinkChronotensityEnum)]_Chronotensity_Effect_Band2 ("Chronotensity Scroll Type, High Mid", Int) = 1
        _Chronotensity_ST_Band2 ("Chronotensity Scroll, High Mid", Vector) = (0,0,0,0)
        [Enum(AudioLinkChronotensityEnum)]_Chronotensity_Effect_Band3 ("Chronotensity Scroll Type, Treble", Int) = 1
        _Chronotensity_ST_Band3 ("Chronotensity Scroll, Treble", Vector) = (0,0,0,0)

        _Chronotensity_Tiling_Scale ("Chronotensity Tiling Scale", Range(0.0, 10.0)) = 1.0
        _Chronotensity_Offset_Scale ("Chronotensity Offset Scale", Range(0.0, 10.0)) = 1.0

        // When the tiling value goes above these we will wrap around
        // and start shrinking back to starting point again using our
        // custom fmirror function (see below)
        _Chronotensity_Tiling_Wrap_U ("Chronotensity Tiling Wrap U", Float) = 3.0
        _Chronotensity_Tiling_Wrap_V ("Chronotensity Tiling Wrap V", Float) = 3.0


        [Space(10)]
        [Header(Chronotensity Rotation)]
        // Can be used to toggle chronotensity rotation on/off, and to reverse it
        _ChronoRot_Scale ("Chronotensity Rotation Scale", Range(-1.0, 1.0)) = 1.0

        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band0 ("Chronotensity Rotation Type, Bass", Int) = 1
        _ChronoRot_Band0 ("Chronotensity Rotation, Bass", Float) = 0.0
        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band1 ("Chronotensity Rotation Type, Low Mid", Int) = 1
        _ChronoRot_Band1 ("Chronotensity Rotation, Low Mid", Float) = 0.0
        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band2 ("Chronotensity Rotation Type, High Mid", Int) = 1
        _ChronoRot_Band2 ("Chronotensity Rotation, High Mid", Float) = 0.0
        [Enum(AudioLinkChronotensityEnum)]_ChronoRot_Effect_Band3 ("Chronotensity Rotation Type, Treble", Int) = 1
        _ChronoRot_Band3 ("Chronotensity Rotation, Treble", Float) = 0.0
    }
    SubShader
    {
	Tags { "RenderType" = "Transparent" "Queue"="Overlay+101" }
	Blend One One
	// Blend SrcAlpha One


	CGINCLUDE
	#include "UnityCG.cginc"
        #include "cginc/XZAudioLinkVisualizer.cginc"

	struct appdata
	{
	    float4 vertex : POSITION;
	    float3 normal : NORMAL;
	};

	struct v2f
	{
	    float4 vertex : SV_POSITION;
	    float3 worldPos : TEXCOORD1;
	    float3 normal : NORMAL;
	};

	static const float PI = 3.14159265;

	static const float FOV_ANGLE = 30.0 * PI / 180.0;
	static const float NEAR_DISTANCE = 0.1;
	static const float FAR_DISTANCE = 10.0;
	static const float ASPECT = 2.0;

	sampler2D_float _Depth;

	float _Brightness;
	float _DirectionalFactor;
	float _ConstantFactor;
	int _Invert;
	float _Scale;

	float3 convertToProjection(float3 p)
	{
	    float3 localPos = mul(unity_WorldToObject, float4(p, 1)).xyz;
	    float h = FAR_DISTANCE * tan(FOV_ANGLE * 0.5);
	    float w = h * ASPECT;
	    float ratio = localPos.z / FAR_DISTANCE;
	    float2 r = ratio * float2(w, h);
	    float3 tp;
	    tp.xy = localPos.xy / r * 0.5 + 0.5;
	    tp.z = localPos.z / FAR_DISTANCE;
	    return tp;
	}

	fixed isInside(float3 p)
	{
	    if (p.z < 0 || p.z > 1)
	    return 0;

	    if (p.x < 0 || p.x > 1)
	    return 0;
	    
	    if (p.y < 0 || p.y > 1)
	    return 0;
	    
	    return 1;
	}

	v2f vert(appdata v)
	{
	    v2f o;
	    o.vertex = UnityObjectToClipPos(v.vertex);
	    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
	    o.normal = mul(unity_ObjectToWorld, float4(v.normal, 0.0)).xyz;
	    return o;
	}

	float LinearDepth(float z)
	{
	    z = 1 - z;
	    float x = 1 - FAR_DISTANCE / NEAR_DISTANCE;
	    float y = FAR_DISTANCE / NEAR_DISTANCE;
	    return 1.0 / (x * z + y);
	}

	fixed4 trace(float3 p, float3 dir)
	{
	    float4 c = float4(0, 0, 0, 0);

	    float3 tp = convertToProjection(p);
	    float3 projectorPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));

	    // [unroll]
	    for (uint i = 0; i < 50; i++)
	    {
		p += dir * tp.z * 0.2;
		tp = convertToProjection(p);

		if (isInside(tp))
		{
		    float2 tp2 = _Invert ? float2(tp.x, 1 - tp.y) : tp.xy;
		    tp2 = (tp2 - 0.5) / _Scale + 0.5;
		    float d = LinearDepth(tex2Dlod(_Depth, float4(tp.xy, 0, 0)));

		    if (d > tp.z)
		    {
			float3 v1 = normalize(p - _WorldSpaceCameraPos);
			float3 v2 = normalize(projectorPos - p);
			float r = pow(dot(v1, v2) + 1, _DirectionalFactor) + _ConstantFactor;
			// c.rgb += all(saturate(tp2) == tp2) ? (tex2Dlod(_MainTex, float4(tp2, 0, 1)).rgb * 0.01 * pow(tp.z, -0.2) * r) : 0.0;
			c.rgb += all(saturate(tp2) == tp2) ? (get_frag(get_uv(tp2), tp2).rgb * 0.01 * pow(tp.z, -0.2) * r) : 0.0;
			// c.rgb += all(saturate(tp2) == tp2) ? (float3(0.0, 0.0, 0.1) * 0.01 * pow(tp.z, -0.2) * r) : 0.0;
                        // c.rgb += float4(0.0, 0.0, 0.1, 1.0);
		    }
		}
	    }

	    return c * _Brightness;
	}
	
	fixed4 frag(v2f i) : SV_Target
	{
	    float3 viewDir = normalize(i.worldPos - _WorldSpaceCameraPos);
	    float side = dot(viewDir, i.normal);

	    float3 cameraInObjectSpace = convertToProjection(_WorldSpaceCameraPos);

	    if (isInside(cameraInObjectSpace))
	    {
		return trace(_WorldSpaceCameraPos, viewDir);
	    }
	    else
	    {
		if (side >= 0)
                {
		    return fixed4(0, 0, 0, 0);
                }

		return trace(i.worldPos, viewDir);
	    }
	}
	ENDCG

	Pass
	{
	    Cull Off
	    ZTest Less
	    ZWrite On

	    CGPROGRAM
            #pragma target 5.0
	    #pragma vertex vert
	    #pragma fragment frag
	    ENDCG
	}
    }
}
