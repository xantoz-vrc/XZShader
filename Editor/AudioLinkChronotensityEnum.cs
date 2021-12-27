public enum AudioLinkChronotensityEnum
{
    Increase = 0,                               // Motion increases as intensity of band increases. It does not go backwards.
    Increase_Filtered = 1,                      // Same as above but uses ALPASS_FILTERAUDIOLINK instead of ALPASS_AUDIOLINK.
    BackAndForth = 2,                           // Motion moves back and forth as a function of intensity.
    BackAndForth_Filtered = 3,                  // Same as above but uses ALPASS_FILTERAUDIOLINK instead of ALPASS_AUDIOLINK.
    DarkIncrease_LightStationary = 4,           // Fixed speed increase when the band is dark. Stationary when light.
    DarkIncrease_LightStationary_Filtered = 5,  // Same as above but uses ALPASS_FILTERAUDIOLINK instead of ALPASS_AUDIOLINK.
    DarkIncrease_LightDecrease = 6,             // Fixed speed increase when the band is dark. Fixed speed decrease when light.
    DarkIncrease_LightDecrease_Filtered = 7,    // Same as above but uses ALPASS_FILTERAUDIOLINK instead of ALPASS_AUDIOLINK.
}
