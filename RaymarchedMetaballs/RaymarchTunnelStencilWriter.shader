Shader "Xantoz/RaymarchedTunnelStencilWriter"
{
    Properties
    {
    }

    SubShader
    {
        // Tags { "Queue"="Opaque" }
        // Tags { "Queue"="Opaque"  "IgnoreProjector"="True" }
        // Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Tags { "Queue"="AlphaTest+50" "IgnoreProjector"="True" }

        Stencil
        {
            Ref 2
            Comp Always
            Pass Replace
        }


        LOD 100
        Pass
        {
            Cull Back
            ZTest Always
            // ZWrite Off

            // All pixels in this Pass will pass the stencil test and write a value of 2 to the stencil buffer
            // You would typically do this if you wanted to prevent subsequent shaders from drawing to this area of the render target or restrict them to render to this area only
            Stencil
            {
                Ref 2
                Comp Always
                Pass Replace
            }

            ColorMask RGBA

            // Blend Zero One
            // Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            // #pragma use_dxc
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
        
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                // v.vertex.xyz -= 1*v.normal;
                // v.vertex.xyz -= 0.1*v.normal;
                // v.vertex.xyz += 0.1*v.normal;
                // v.vertex.xyz += 1*v.normal;

                o.vertex = UnityObjectToClipPos(v.vertex);
                
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            // fixed4 frag (v2f i) : SV_Target
            // {
            //     // sample the texture
            //     fixed4 col = fixed4(0,1,0,.5);

            //     // apply fog
            //     UNITY_APPLY_FOG(i.fogCoord, col);

            //     return col;
            // }
            fixed4 frag (v2f i, out uint ref : SV_StencilRef) : SV_Target
            {
                // sample the texture
                fixed4 col = fixed4(0,1,0,.5);

                ref = 2;
                
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);

                return col;
            }
            ENDCG
        }
    }
}
