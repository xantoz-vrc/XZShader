// ISC License
//
// Copyright 2021 xantoz
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

Shader "Xantoz/XZAudioLinkVisualizer"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 0
        // Default to Blend SrcAlpha One
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendMode("Src Blend Mode", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlendMode("Dst Blend Mode", Float) = 1

        [Header(Basic Setings)]
        [Enum(XZAudioLinkVisualizerMode)] _Mode("Visualizer Mode", Int) = 0
        [HDR]_Color1 ("Color 1 (Base Color)", Color) = (1,1,1,1)

        _ST0 ("UV tiling and offset global", Vector) = (1,1,0,0) // (happens before _ST and _Tiling_Scale and any of the chronotensity scroll and scaling effects). Also affects the vignette)
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

        [Space(10)]
        [Header(Misc)]
        [ToggleUI]_UseVertexColor ("Use vertex color to randomly show/not show and mix things up", Int) = 0

        _Fat ("Fattening", Float) = 0
    }

    CGINCLUDE
    #include "UnityCG.cginc"
    #include "cginc/XZAudioLinkVisualizer.cginc"
    ENDCG

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "VRCFallback"="Hidden" }
        LOD 100
        Cull[_CullMode]

        Pass
        {
            ZWrite Off
            Blend[_SrcBlendMode] [_DstBlendMode]

            CGPROGRAM
            #pragma target 5.0

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 vertexColor : COLOR;
                float3 normal : NORMAL;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 unmodified_uv : TEXCOORD1;
                float4 vertex : SV_POSITION;

                float vertexColorRand : COLOR1;
                int mode_add : COLOR2;
                UNITY_FOG_COORDS(3)

                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _ST0;
            int _UseVertexColor;
            float _Fat;

            v2f vert(appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float seed;
                if (_UseVertexColor) {
                    float rand = random(v.vertexColor.rg);
                    uint2 useed = uint2(
                        rand*20000000.0 +
                        AudioLinkGetChronotensity(1, 0) + AudioLinkGetChronotensity(2, 2),
                        AudioLinkGetChronotensity(0, 1) + AudioLinkGetChronotensity(5, 3))/2000000.0;
                    seed = random(useed);

                    o.vertexColorRand = seed;
                    o.mode_add = int(rand*10);
                } else {
                    seed = get_rarely_changing_random();
                }

                v.vertex.xyz += v.normal*_Fat;

                o.vertex = UnityObjectToClipPos(v.vertex);

                float2 uv = v.uv * _ST0.xy + _ST0.zw;
                o.unmodified_uv = uv;
                o.uv = get_uv2(uv, seed);

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }


            float4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                if (_UseVertexColor && !(i.vertexColorRand > 0.999 || i.vertexColorRand < 0.001)) {
                    discard;
                }

                float4 col = get_frag2(i.uv.xy, i.unmodified_uv.xy, i.mode_add);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
