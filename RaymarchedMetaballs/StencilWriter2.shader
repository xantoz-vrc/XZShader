Shader "Xantoz/FragmentStencilRef"
{
    SubShader
    {
        Tags { "Queue"="AlphaTest+50" }
xb        
        Pass
        {
            Stencil {
                Ref 0        // doesn't actually matter since we'll be replacing it in the fragment
                Comp Always
                Pass Replace // needed to overrite the current stencil value
            }
            
            // ColorMask 0   // hides rendering to the visible color buffer
            ZWrite Off
            ZTest Always
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            // force DXC compiler
            // https://forum.unity.com/threads/unity-is-adding-a-new-dxc-hlsl-compiler-backend-option.1086272/
            #pragma use_dxc
            
            #include "UnityCG.cginc"
            
            float4 vert (float4 vertex : POSITION) : SV_POSITION
            {
                return UnityObjectToClipPos(vertex);
            }
            
            half4 frag (float4 pos : SV_POSITION
                , out uint ref : SV_StencilRef
            ) : SV_Target
            {
                // make a fun pattern
                float val = frac((pos.x * pos.y) / 200.0);
                
                // map the pattern to the output stencil ref
                ref = uint(val * 255.0);
                
                // visualize the fun pattern
                return half4(val, val, val, 1.0);
            }
            ENDCG
        }
    }
}
