Shader "Xantoz/AudiolinkUnlitShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Band3Movement ("Treble Movement", Vector) = (0,0,0,0)
        _Band2Movement ("High Mid Movement", Vector) = (0,0,0,0)
        _Band1Movement ("Low Mid Movement", Vector) = (0,0,0,0)
        _Band0Movement ("Bass Movement", Vector) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            Texture2D<float4> _AudioTexture;
            float4 _MainTex_ST;

            float4 _Band3Movement;
            float4 _Band2Movement;
            float4 _Band1Movement;
            float4 _Band0Movement;
            
            v2f vert (appdata v)
            {
                v2f o;

                int w,h;
                _AudioTexture.GetDimensions(w,h);
                if (w > 16)
                {
                    float3 distance = 0.0;

                    float band[4];
                    for (int i =0; i < 4; ++i)
                    {
                        band[i] = _AudioTexture[int2(0,i)].r;
                    }

                    distance += _Band3Movement.xyz*band[3];
                    distance += _Band2Movement.xyz*band[2];
                    distance += _Band1Movement.xyz*band[1];
                    distance += _Band0Movement.xyz*band[0];

                    v.vertex.xyz += v.normal*distance;
                    
                    //const float treble = _AudioTexture[int2(0,i)].r;
                    //v.vertex.xyz += v.normal * (0.1*treble.r);
                    //v.vertex.z -= 0.05*treble.r;
                }
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                
                int w, h;
                _AudioTexture.GetDimensions(w,h);
                if (w > 16)
                {
                    const float4 bass = _AudioTexture[int2(0,0)];
                    col *= 0.5 + 2*bass.r;
                }
                
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
