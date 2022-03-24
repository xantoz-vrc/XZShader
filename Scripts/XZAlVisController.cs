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
        public MeshRenderer preview;

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

        public Text ctensityRotationScaleLabel;
        public Slider ctensityRotationScaleSlider;

        public Text ctensityRotationLabel;
        public Slider ctensityRotationSlider_Band1;
        public Slider ctensityRotationSlider_Band2;
        public Slider ctensityRotationSlider_Band3;
        public Slider ctensityRotationSlider_Band4;

        private float _initAmplitude;
        private int _initMode; // TODO: Might be better to be the enum?
        private bool _initCtensity;
        private float _initCtensityTilingScale;
        private float _initCtensityOffsetScale;
        private float _initCtensityRotationScale;
        private float _initCtensityRotationBand1;
        private float _initCtensityRotationBand2;
        private float _initCtensityRotationBand3;
        private float _initCtensityRotationBand4;

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

            _initCtensityRotationScale = ctensityRotationScaleSlider.value;

            _initCtensityRotationBand1 = ctensityRotationSlider_Band1.value;
            _initCtensityRotationBand2 = ctensityRotationSlider_Band2.value;
            _initCtensityRotationBand3 = ctensityRotationSlider_Band3.value;
            _initCtensityRotationBand4 = ctensityRotationSlider_Band4.value;

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
            ctensityRotationScaleLabel.text = "Chronotensity Rotation Scale: " + ctensityRotationScaleSlider.value.ToString("0.00");

            ctensityRotationLabel.text =
                "Chronotensity Rotation\n" +
                "Bass: " + ctensityRotationSlider_Band1.value.ToString("0.00") +
                "\tLow Mid: " + ctensityRotationSlider_Band2.value.ToString("0.00") +
                "\tHigh Mid: " + ctensityRotationSlider_Band3.value.ToString("0.00") +
                "\tTreble: " + ctensityRotationSlider_Band4.value.ToString("0.00");

            // Apply to material of preview strip
            Material material = preview.material;
            material.SetFloat("_Amplitude_Scale", amplitudeSlider.value);
            material.SetInt("_Mode", mode);
            material.SetFloat("_Chronotensity_Scale", ctensityToggle.isOn ? 1.0f : 0.0f);
            material.SetFloat("_Chronotensity_Tiling_Scale", ctensityTilingScaleSlider.value);
            material.SetFloat("_Chronotensity_Offset_Scale", ctensityOffsetScaleSlider.value);

            material.SetFloat("_ChronoRot_Scale", ctensityRotationScaleSlider.value);
            material.SetFloat("_ChronoRot_Band1", ctensityRotationSlider_Band1.value);
            material.SetFloat("_ChronoRot_Band2", ctensityRotationSlider_Band2.value);
            material.SetFloat("_ChronoRot_Band3", ctensityRotationSlider_Band3.value);
            material.SetFloat("_ChronoRot_Band4", ctensityRotationSlider_Band4.value);
        }

        public void ApplySettings()
        {
            int mode = modeConversion((int)modeSlider.value);

            // Set XZAlVis object up
            xzalvis.SetProgramVariable("amplitudeScale", amplitudeSlider.value);
            xzalvis.SetProgramVariable("mode", mode);
            xzalvis.SetProgramVariable("ctensity", ctensityToggle.isOn);
            xzalvis.SetProgramVariable("ctensityTilingScale", ctensityTilingScaleSlider.value);
            xzalvis.SetProgramVariable("ctensityOffsetScale", ctensityOffsetScaleSlider.value);

            xzalvis.SetProgramVariable("ctensityRotationScale", ctensityRotationScaleSlider.value);
            xzalvis.SetProgramVariable("ctensityRotation_Band1", ctensityRotationSlider_Band1.value);
            xzalvis.SetProgramVariable("ctensityRotation_Band2", ctensityRotationSlider_Band2.value);
            xzalvis.SetProgramVariable("ctensityRotation_Band3", ctensityRotationSlider_Band3.value);
            xzalvis.SetProgramVariable("ctensityRotation_Band4", ctensityRotationSlider_Band4.value);

            // xzalvis.SendCustomNetworkEvent(VRC.Udon.Common.Interfaces.NetworkEventTarget.All, "UpdateSettings");

            xzalvis.SendCustomEvent("UpdateSettings");
        }

        public void ResetSettings()
        {
            amplitudeSlider.value = _initAmplitude;
            modeSlider.value = _initMode;
            ctensityToggle.isOn = _initCtensity;
            ctensityTilingScaleSlider.value = _initCtensityTilingScale;
            ctensityOffsetScaleSlider.value = _initCtensityOffsetScale;

            ctensityRotationScaleSlider.value = _initCtensityRotationScale;

            ctensityRotationSlider_Band1.value = _initCtensityRotationBand1;
            ctensityRotationSlider_Band2.value = _initCtensityRotationBand2;
            ctensityRotationSlider_Band3.value = _initCtensityRotationBand3;
            ctensityRotationSlider_Band4.value = _initCtensityRotationBand4;

            laggyModeToggle.isOn = false;

            ApplySettings();
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
