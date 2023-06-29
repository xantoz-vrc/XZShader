// CRT version that uses the CRT to get some extra effects

Shader "Xantoz/XZCRTZoomFade"
{
    Properties
    {
    }

    SubShader
    {
        Lighting Off
        Blend One Zero
        // Blend DstAlpha OneMinusDstAlpha
        // Blend SrcAlpha OneMinusSrcAlpha

        // Blend One OneMinusDstAlpha
        // Blend SrcAlpha OneMinusDstAlpha
        // Blend SrcAlpha OneMinusDstAlpha

        Pass
        {
            CGPROGRAM
            #include "UnityCustomRenderTexture.cginc"
            #include "UnityCG.cginc"
            #include "../cginc/AudioLinkFuncs.cginc"
            // #include "cginc/XZAudioLinkVisualizer.cginc"


            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 5.0

            float4 frag(v2f_customrendertexture IN) : COLOR
            {

                float al_beat[4] = {0,0,0,0};
                if (AudioLinkIsAvailable())
                {
                    al_beat[0] = AudioLinkData(uint2(0,0)).r;
                    al_beat[1] = AudioLinkData(uint2(0,1)).r;
                    al_beat[2] = AudioLinkData(uint2(0,2)).r;
                    al_beat[3] = AudioLinkData(uint2(0,3)).r;
                }

                const float rot = -2*(-0.5f + al_beat[1]);
                const float sinX = sin(radians(rot));
                const float cosX = cos(radians(rot));
                const float sinY = sin(radians(rot));
                const float2x2 rotationMatrix = float2x2(cosX, -sinX, sinY, cosX);

                float2 uv = IN.globalTexcoord.xy;

                float2 zoomSpeed = 1.02 + (float2(al_beat[0] + al_beat[1]/3, al_beat[0] + al_beat[3]/3) - 0.5);
                // float zoomSpeed = 1.03 + (al_beat[0] - 0.5);

                float2 new_uv = (mul(uv-0.5, rotationMatrix))*(zoomSpeed) + 0.5;

                float4 rotatecol = tex2D(_SelfTexture2D, new_uv);
                // float4 nowcol = tex2D(_SelfTexture2D, uv);
                float4 nowcol = tex2D(_SelfTexture2D, uv*(1 + al_beat[2]/16));

                float4 col = float4(0,0,0,0);
                // col = (rotatecol*0.4 + nowcol*0.6)/2;

                rotatecol.rgb = float3(rotatecol.b, rotatecol.r, rotatecol.g);
                // rotatecol.rgb = 1/float3(rotatecol.b, rotatecol.g, rotatecol.r);

                // rotatecol.rgb = 1/rotatecol.rgb;
                // rotatecol = 1/rotatecol;

                rotatecol.rgb = clamp(rotatecol.rgb, -0.9, 0.9);

                // col.rgb = (rotatecol.rgb*0.8*rotatecol.a + nowcol.rgb*nowcol.a)/2;
                // col.rgb = (rotatecol.rgb*0.8 + nowcol.rgb*nowcol.a)/2;
                
                // col.rgb = (rotatecol.rgb*0.8 + nowcol.rgb)/2;


                col.rgb = (rotatecol.rgb*0.8*rotatecol.a + nowcol.rgb*(1 - nowcol.a))/2;

                // col.rgb = (rotatecol.rgb*0.8*rotatecol.a + nowcol.rgb*(1 -nowcol.a))/2;
                // col.rgb = (rotatecol.rgb*0.8*(1 - nowcol.a) + nowcol.rgb*(1 -nowcol.a))/2;

                // col.rgb = (rotatecol.rgb*0.8);

                // // col.rgb = (rotatecol.rgb*0.99 + nowcol.rgb)/2;
                // // col.rgb = rotatecol.*0.8;

                // col.a = rotatecol*0.99;
                // col.a = nowcol.a*0.88;
                col.a = (rotatecol.a*0.99 + nowcol.a*0.88)/2;

                // col.rgb = clamp(col.rgb, -1.5, 1.5);
                col.rgb = clamp(col.rgb, -0.9, 0.9);
                // col = clamp(col, -0.9, 0.9);

                return col;
            }
            ENDCG
        }
    }
}
