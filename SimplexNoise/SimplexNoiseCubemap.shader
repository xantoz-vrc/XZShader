Shader "Xantoz/SimplexNoiseCubemap"
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
                float3 t = float3(0, 0, 1) * _Time.x + AudioLinkGetChronoTime(0,0)/10;
                float val = simplex3d_fractal(IN.direction+t);
                return val;
            }
            ENDCG
        }
    }
}
