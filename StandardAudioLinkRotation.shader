Shader "Xantoz/StandardAudioLinkRotation"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}
        
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        
        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}
        
        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}
        
        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        _ParallaxMap ("Height Map", 2D) = "black" {}
        
        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}
        
        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}
        
        _DetailMask("Detail Mask", 2D) = "white" {}
        
        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        _DetailNormalMapScale("Scale", Float) = 1.0
        _DetailNormalMap("Normal Map", 2D) = "bump" {}
        
        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0
        
        
        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
    }
 
    CGINCLUDE
    // You may define one of these to expressly specify it.
    // #define UNITY_BRDF_PBS BRDF1_Unity_PBS
    // #define UNITY_BRDF_PBS BRDF2_Unity_PBS
    // #define UNITY_BRDF_PBS BRDF3_Unity_PBS
 
    // You can reduce the time to compile by constraining the usage of eash features.
    // Corresponding shader_feature pragma should be disabled.
    // #define _NORMALMAP 1
    // #define _ALPHATEST_ON 1
    // #define _EMISSION 1
    // #define _METALLICGLOSSMAP 1
    // #define _DETAIL_MULX2 1
    ENDCG
 
    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 300
        
        // It seems Blend command is getting overridden later
        // in the processing of  Surface shader.
        // Blend [_SrcBlend] [_DstBlend]
        ZWrite [_ZWrite]
        
    CGPROGRAM
        #pragma target 3.0
 
        #pragma shader_feature _NORMALMAP
        // #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
        #pragma shader_feature _ALPHATEST_ON
        #pragma shader_feature _EMISSION
        #pragma shader_feature _METALLICGLOSSMAP
        #pragma shader_feature ___ _DETAIL_MULX2
        #pragma shader_feature _PARALLAXMAP
 
        // #pragma multi_compile_fwdbase
        // #pragma multi_compile_fog
        #pragma multi_compile_instance

        #pragma surface surf Standard vertex:vert finalcolor:final fullforwardshadows addshadow // Opaque or Cutout
        // #pragma surface surf Standard vertex:vert finalcolor:final fullforwardshadows addshadow alpha:fade // Fade
        // #pragma surface surf Standard vertex:vert finalcolor:final fullforwardshadows addshadow alpha:premul // Transparent
 
        #include "UnityStandardInput.cginc"
        // just for NormalizePerPixelNormal()
        #include "UnityStandardCore.cginc"
        // LightingStandard(), LightingStandard_GI(), LightingStandard_Deferred() and
        // struct SurfaceOutputStandard are defined here.
        #include "UnityPBSLighting.cginc"

        #include "cginc/AudioLinkFuncs.cginc"

        struct appdata_vert {
            float4 vertex : POSITION;
            half3 normal : NORMAL;
            float2 uv0 : TEXCOORD0;
            float2 uv1 : TEXCOORD1;
            float4 texcoord1 : TEXCOORD2; // lightmaps and meta pass (not sure)
            float4 texcoord2 : TEXCOORD3; // dynamig GI and meta pass (not sure)
          #ifdef _TANGENT_TO_WORLD
            float4 tangent : TANGENT;
          #endif

            UNITY_VERTEX_INPUT_INSTANCE_ID
        };
        
        struct Input {
            float4 texcoords;
          #if defined(_PARALLAXMAP)
            half3 viewDirForParallax;
          #endif
        };

        float4 RotateAroundYInDegrees (float4 vertex, float degrees)
        {
            float alpha = degrees * UNITY_PI / 180.0;
            float sina, cosa;
            sincos(alpha, sina, cosa);
            float2x2 m = float2x2(cosa, -sina, sina, cosa);
            return float4(mul(m, vertex.xz), vertex.yw).xzyw;
        }

        void vert (inout appdata_vert v, out Input o) {
            UNITY_SETUP_INSTANCE_ID(v);
            UNITY_INITIALIZE_OUTPUT(Input, o);

            float ctensity_bass = AudioLinkGetChronotensity(1, 0)/1000.0;
            v.vertex = RotateAroundYInDegrees(v.vertex, ctensity_bass);

            o.texcoords.xy = TRANSFORM_TEX(v.uv0, _MainTex); // Always source from uv0
            o.texcoords.zw = TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap);
          #ifdef _PARALLAXMAP
            TANGENT_SPACE_ROTATION; // refers to v.normal and v.tangent
            o.viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
          #endif
        }
        
        void surf (Input IN, inout SurfaceOutputStandard o) {
          #ifdef _PARALLAXMAP
            half3 viewDirForParallax = NormalizePerPixelNormal(IN.viewDirForParallax);
          #else
            half3 viewDirForParallax = half3(0,0,0);
          #endif

            float4 texcoords = IN.texcoords;
            texcoords = Parallax(texcoords, viewDirForParallax);
            half alpha = Alpha(texcoords.xy);
          #if defined(_ALPHATEST_ON)
            clip (alpha - _Cutoff);
          #endif
            o.Albedo = Albedo(texcoords);

          #ifdef _NORMALMAP
            o.Normal = NormalInTangentSpace(texcoords);
            o.Normal = NormalizePerPixelNormal(o.Normal);
          #endif

            o.Emission = Emission(texcoords.xy);
            half2 metallicGloss = MetallicGloss(texcoords.xy);
            o.Metallic = metallicGloss.x; // _Metallic;
            o.Smoothness = metallicGloss.y; // _Glossiness;
            o.Occlusion = Occlusion(texcoords.xy);
            o.Alpha = alpha;
        }
        
        void final (Input IN, SurfaceOutputStandard o, inout fixed4 color)
        {
            color = OutputForward(color, color.a);
        }

        ENDCG
    }
    
    FallBack Off
    CustomEditor "StandardShaderGUI"
}
