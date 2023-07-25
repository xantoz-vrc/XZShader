Shader "Xantoz/SimplexNoiseTexture"
{
    Properties
    {
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

            float frag(v2f_customrendertexture IN) : COLOR
            {
                float val = simplex3d_fractal(IN.direction);
                return val;
            }
            ENDCG
        }
    }
}
