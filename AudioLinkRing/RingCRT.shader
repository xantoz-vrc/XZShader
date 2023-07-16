Shader "Xantoz/AudioLinkRing/RingCRT"
{
    Properties
    {
        // Note on thresholds:
        // In normal mode lowerthreshold is required to trigger a ring from an empty state
        // While retriggering a ring from center is from the higher threshold
        //
        // In hold mode the upper threshold is what is required to make the ring appear or be retriggered
        // while we have to go below the low threshold to release the ring

        _LowerThreshold ("LowerThreshold (bass, low mid, high mid, treble)", Vector) = (0.2, 0.2, 0.2, 0.2)
        _UpperThreshold("Higher threshold", Vector) = (0.5, 0.5, 0.5, 0.5)
        // Think of this one as the time before a ring currently going outwards can be interrupted by a new one (TODO: consider supporting more than one outgoing ring)
        _CooldownBand ("Cooldown before can be retriggered (bass, low mid, high mid, treble)", Vector) = (0.2, 0.2, 0.2, 0.2)
        // think of this one as speed
        _TimeBand("Time until released ring reaches largest size (bass, low mid, high mid, treble)", Vector) = (0.5, 0.5, 0.5, 0.5)
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

            float4 _LowerThreshold;
            float4 _UpperThreshold;
            float4 _CooldownBand;
            float4 _TimeBand;
   
            float4 frag(v2f_customrendertexture i) : COLOR
            {
                uint x = i.globalTexcoord.x * _CustomRenderTextureWidth;
                uint y = i.globalTexcoord.y * _CustomRenderTextureHeight;

                if (!AudioLinkIsAvailable() || y > 3) {
                    return float4(0,0,0,0);
                }

                float4 tex = _SelfTexture2D[uint2(x,y)];
                float4 col = float4(0,0,0,0);
                float al_beat = AudioLinkData(uint2(0,y)).r;

                float cooledDownTime = _TimeBand[y] - _CooldownBand[y];

                // .r is raw value starting at _TimeBand and counting down to 0
                // .g is a normalized value that starts at 1 and counts down to 0
                // .b counts seconds upwards while held in held modes

                switch (x) {
                    // 0th colum is normal that starts moving outwards immediately
                    case 0:
                    // Retriggering requires a slightly higher than configured threshold
                    if ((al_beat > _UpperThreshold[y] && tex.r <= cooledDownTime) ||
                        (al_beat > _LowerThreshold[y] && tex.r <= 0.0)) {
                        col.r = _TimeBand[y];
                    } else if (tex.r > 0.0) {
                        col.r = tex.r - unity_DeltaTime.x;
                    }
                    break;

                    // 1st column is hold while active, release when it goes below the lowewr threshold
                    case 1:
                    // First appearing or retriggering on the higher threshold, but releasing when it goes below the low threshold
                    if ((tex.r ==_TimeBand[y] && al_beat > _LowerThreshold[y]) ||
                        (tex.r <= cooledDownTime && al_beat > _UpperThreshold[y])) {
                        col.r = _TimeBand[y];
                        col.b = tex.b + unity_DeltaTime.x;
                    } else if (tex.r > 0.0) {
                        col.r = tex.r - unity_DeltaTime.x;
                    }
                    break;

                    // Appear on band y, release on band 0
                    case 2:
                    break;

                    // Appear on band y, release on band 1
                    case 3:
                    break;

                    // Appear on band y, release on band 2
                    case 4:
                    break;

                    // Appear on band y, release on band 3
                    case 5:
                    break;
                }

                // Scaled value at .b
                col.g = col.r / _TimeBand[y];
                
                return col;
            }
            ENDCG
        }
    }
}
