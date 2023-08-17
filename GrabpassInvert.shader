Shader "Unlit/meme"
{
    SubShader
    {
        Tags { "Queue" = "Overlay" }
        GrabPass { "_GrabTexture" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct v2f
            {
                float4 grabPos : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _GrabTexture;

            v2f vert (float2 uv : TEXCOORD0)
            {
                v2f o;
                o.vertex = float4(float2(1,-1)*(uv*2-1),0,1);
                o.grabPos = ComputeGrabScreenPos(o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return 1.0-tex2D(_GrabTexture, i.grabPos.xy / i.grabPos.w);
            }
            ENDCG
        }
    }
}
