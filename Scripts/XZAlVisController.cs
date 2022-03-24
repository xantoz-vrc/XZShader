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

        private float _initAmplitude;
        private int _initMode; // TODO: Might be better to be the enum?

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
            UpdateSettings();
        }

        public void UpdateSettings()
        {
            // Update labels
            amplitudeLabel.text = "Amplitude Scale: " + ((int)Remap( amplitudeSlider.value, 0f, 2f, 0f, 200f )).ToString() + "%";
            modeLabel.text = "Mode: " +　modeToString((int)modeSlider.value) + "(" + ((int)modeSlider.value).ToString() + ")";

            xzalvis.SetProgramVariable("amplitudeScale", amplitudeSlider.value);
            xzalvis.SetProgramVariable("mode", (int)modeSlider.value);

            xzalvis.SendCustomEvent("UpdateSettings");
        }

        public void ResetSettings()
        {
            amplitudeSlider.value = _initAmplitude;
            modeSlider.value = _initMode;
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
