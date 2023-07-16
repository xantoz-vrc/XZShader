Shader "Xantoz/AudioLinkRing/RingCRT"
{
    Properties
    {
        _Threshold ("Threshold (bass, low mid, high mid, treble)", Vector) = (0.6, 0.6, 0.6, 0.6)
        _TimeBand ("Ring speed/Cooldown (bass, low mid, high mid, treble)", Vector) = (0.5, 0.5, 0.5, 0.2)
    }

    SubShader
    {
        Lighting Off
        Blend One Zero

        CGINCLUDE
        #include "../cginc/AudioLinkFuncs.cginc"
        ENDCG

        Pass
        {
            CGPROGRAM
            #define _SelfTexture2D _JunkTexture
            #include "UnityCustomRenderTexture.cginc"
            #undef _SelfTexture2D
            Texture2D<float4> _SelfTexture2D;

            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 5.0

            float4 _Threshold;
            float4 _TimeBand;
   
            float4 frag(v2f_customrendertexture i) : COLOR
            {
                if (!AudioLinkIsAvailable()) {
                    return float4(0,0,0,0);
                }

                uint x = i.globalTexcoord.x * _CustomRenderTextureWidth;
                uint y = i.globalTexcoord.y * _CustomRenderTextureHeight;

                float4 tex = _SelfTexture2D[uint2(x,y)];
                float4 col = float4(0,0,0,0);
                float al_beat = AudioLinkData(uint2(0,y)).r;

                // .r is normal raw value attack on beat, .g is raw inverted hold until beat releases
                // .b and .a is normalized, and made to grow rather than shrink, to be between 1.0 and 0.0 of the previous two
                if (tex.r > 0.0) { 
                    col.r = tex.r - unity_DeltaTime.x; 
                } else if (al_beat > _Threshold[y]) { 
                    col.r = _TimeBand[y];
                }
                if (al_beat > _Threshold[y]) {
                    col.g = _TimeBand[y];
                } else if (tex.g > 0.0) {
                    col.g = tex.g - unity_DeltaTime.x;
                }

                col.b = col.r / _TimeBand[y];
                col.a = col.g / _TimeBand[y];
                
                return col;
            }
            ENDCG
        }
    }
}
