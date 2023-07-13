Shader "Xantoz/AudioLinkRing"
{
    Properties
    {
        _Threshold ("Threshold", Float) = 0.6
        _TimeBand0 ("Cooldown time (bass)", Float) = 1.0
        _TimeBand0 ("Cooldown time (low mid)", Float) = 1.0
        _TimeBand0 ("Cooldown time (high mid)", Float) = 1.0
        _TimeBand0 ("Cooldown time (treble)", Float) = 0.5
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
            #include "UnityCustomRenderTexture.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 5.0

            uint _Band;
            float _Threshold;

            float4 frag(v2f_customrendertexture IN) : COLOR
            {
                float beat = AudioLinkData(uint2(0,_Band)).r;
                float4 tex = tex2D(_SelfTexture2D, IN.globalTexcoord.uv);

                float4 col = float4(0,0,0,0);
                if (tex.r > 0.0) {
                    col = tex.r - unity_DeltaTime.x;
                } else {
                    col = _Time;
                }

                return col;
            }
            ENDCG
        }
    }
}
