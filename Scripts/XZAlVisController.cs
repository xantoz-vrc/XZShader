using UnityEngine;
using VRC.SDKBase;
using UnityEngine.UI;
using System;

namespace XZShader
{
#if UDON
    using UdonSharp;
    using VRC.Udon;

    public class XZAlVisController : UdonSharpBehaviour
    {
        public UdonBehaviour xzalvis;

        [Space(10)]
        public Text amplitudeLabel;
        public Slider amplitudeSlider;

        public Text modeLabel;
        public Slider modeSlider;
        public Toggle laggyModeToggle;

        public Toggle ctensityToggle;

        public Text ctensityTilingScaleLabel;
        public Slider ctensityTilingScaleSlider;

        public Text ctensityOffsetScaleLabel;
        public Slider ctensityOffsetScaleSlider;

        private float _initAmplitude;
        private int _initMode; // TODO: Might be better to be the enum?
        private bool _initCtensity;
        private float _initCtensityTilingScale;
        private float _initCtensityOffsetScale;

#if UNITY_EDITOR
        void Update()
        {
            //UpdateSettings();
        }
#endif

        void Start()
        {
            if (xzalvis == null) Debug.Log("Not connected to XZALVis");
            _initAmplitude = amplitudeSlider.value;
            _initMode = (int)modeSlider.value;
            _initCtensity = ctensityToggle.isOn;
            _initCtensityTilingScale = ctensityTilingScaleSlider.value;
            _initCtensityOffsetScale = ctensityOffsetScaleSlider.value;
            UpdateSettings();
        }

        private int modeConversion(int mode)
        {
            if (laggyModeToggle.isOn) {
                return mode;
            } else {
                // Auto becomes Auto2, and both PCM XY modes round down
                return (mode == 11)             ? 12 :
                       (mode == 6 || mode == 7) ? 5  : mode;
            }
        }

        public void UpdateSettings()
        {
            int mode = modeConversion((int)modeSlider.value);

            // Update labels
            amplitudeLabel.text = "Amplitude Scale: " + amplitudeSlider.value.ToString("0.00");
            modeLabel.text = "Mode: " +　modeToString(mode) + "(" + mode.ToString() + ")";
            ctensityTilingScaleLabel.text = "Chronotensity Tiling Scale: " + ctensityTilingScaleSlider.value.ToString("0.00");
            ctensityOffsetScaleLabel.text = "Chronotensity Offset Scale: " + ctensityOffsetScaleSlider.value.ToString("0.00");

            xzalvis.SetProgramVariable("amplitudeScale", amplitudeSlider.value);
            xzalvis.SetProgramVariable("mode", mode);
            xzalvis.SetProgramVariable("ctensity", ctensityToggle.isOn);
            xzalvis.SetProgramVariable("ctensityTilingScale", ctensityTilingScaleSlider.value);
            xzalvis.SetProgramVariable("ctensityOffsetScale", ctensityOffsetScaleSlider.value);

            xzalvis.SendCustomEvent("UpdateSettings");
        }

        public void ResetSettings()
        {
            amplitudeSlider.value = _initAmplitude;
            modeSlider.value = _initMode;
            ctensityToggle.isOn = _initCtensity;
            ctensityTilingScaleSlider.value = _initCtensityTilingScale;
            ctensityOffsetScaleSlider.value = _initCtensityOffsetScale;

            laggyModeToggle.isOn = false;
        }

        private float Remap(float t, float a, float b, float u, float v)
        {
            return ( (t-a) / (b-a) ) * (v-u) + u;
        }

        // TODO: There must be a better way...
        private String modeToString(int mode)
        {
            if (mode == 0)
                return "PCM_Horizontal";
            else if (mode == 1)
                return "PCM_Vertical";
            else if (mode == 2)
                return "PCM_LR";
            else if (mode == 3)
                return "PCM_Circle";
            else if (mode == 4)
                return "PCM_Circle_Mirror";
            else if (mode == 5)
                return "PCM_Circle_LR";
            else if (mode == 6)
                return "PCM_XY_Scatter";
            else if (mode == 7)
                return"PCM_XY_Line";
            else if (mode == 8)
                return "PCM_Ribbon";
            else if (mode == 9)
                return "Spectrum_Circle_Mirror";
            else if (mode == 10)
                return "Spectrum_Ribbon";
            else if (mode == 11)
                return "Auto";
            else if (mode == 12)
                return "Auto2";
            else
                return "???";
        }
    }
#else
    public class XZAlVisController2 : MonoBehaviour
    {
    }
#endif
}
