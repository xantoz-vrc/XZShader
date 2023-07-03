Shader "Xantoz/AudioLinkRing"
{
    Properties
    {
        [Enum(AudioLinkBandEnum)]_Band ("AudioLink band", Int) = 0
        _Threshold ("Threshold", Float) = 0.6
        _Time ("Time", Float) = 10.0
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

            float frag(v2f_customrendertexture IN) : COLOR
            {
                float beat = AudioLinkData(uint2(0,_Band)).r;
                float4 tex = tex2D(_SelfTexture2D, IN.globalTexcoord.uv);

                float col = 0;
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
