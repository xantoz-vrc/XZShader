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
 
