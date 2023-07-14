using UnityEngine;
using VRC.SDKBase;
using UnityEngine.UI;
using System;

namespace XZShader
{
#if UDON
    using UdonSharp;
    using VRC.Udon;

    [UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
    public class XZAlVisController : UdonSharpBehaviour
    {
        [Tooltip("Materials which the controller should control")]
        public Material[] materials;

        [Space(10)]
        [UdonSynced] [Range(0.0f, 2.0f)] public float amplitudeScale = 1.0f;
        [UdonSynced] public int mode = 12;
        [UdonSynced] public bool ctensity = true;

        [UdonSynced] [Range(0.0f, 10.0f)] public float ctensityTilingScale   = 5.28f;
        [UdonSynced] [Range(0.0f, 10.0f)] public float ctensityOffsetScale   = 9.0f;
        [UdonSynced] [Range(-2.0f, 2.0f)] public float ctensityRotationScale = 1.0f;

        [UdonSynced] [Range(-2.0f, 2.0f)] public float ctensityRotation_Band0 = 0.5f;
        [UdonSynced] [Range(-2.0f, 2.0f)] public float ctensityRotation_Band1 = 0.0f;
        [UdonSynced] [Range(-2.0f, 2.0f)] public float ctensityRotation_Band2 = 0.0f;
        [UdonSynced] [Range(-2.0f, 2.0f)] public float ctensityRotation_Band3 = 0.0f;

        [UdonSynced] [Range(0.1f, 10.0f)] public float tilingScale = 1.0f;
        [UdonSynced] [Range(-360.0f, 360.0f)] public float rotation = 0.0f;

        private bool deserializing;
        private VRCPlayerApi localPlayer;

        [Space(10)]
        public MeshRenderer previewView;
        public MeshRenderer activeView;

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
        public Slider ctensityRotationSlider_Band0;
        public Slider ctensityRotationSlider_Band1;
        public Slider ctensityRotationSlider_Band2;
        public Slider ctensityRotationSlider_Band3;

        public Text tilingScaleLabel;
        public Slider tilingScaleSlider;
        public Text rotationLabel;
        public Slider rotationSlider;

        private float _initAmplitudeScale;
        private int _initMode;
        private bool _initCtensity;
        private float _initCtensityTilingScale;
        private float _initCtensityOffsetScale;
        private float _initCtensityRotationScale;
        private float _initCtensityRotation_Band0;
        private float _initCtensityRotation_Band1;
        private float _initCtensityRotation_Band2;
        private float _initCtensityRotation_Band3;

        private float _initTilingScale;
        private float _initRotation;

        void Start()
        {
            localPlayer = Networking.LocalPlayer;
            deserializing = false;

            // Copy properties over to the active view and preview view meshrenderers. It is
            // neccessary to do it this way, since the materials in question might be another
            // variant of XZAlVis such as the projector one, for instance
            activeView.material.CopyPropertiesFromMaterial(materials[0]);
            previewView.material.CopyPropertiesFromMaterial(materials[0]);
            activeView.material.SetInt("_DstBlend", 0);
            activeView.material.SetInt("_DstBlendMode", 1);
            activeView.material.SetInt("_SrcBlend", 1);
            activeView.material.SetInt("_SrcBlendMode", 5);
            previewView.material.SetInt("_DstBlend", 0);
            previewView.material.SetInt("_DstBlendMode", 1);
            previewView.material.SetInt("_SrcBlend", 1);
            previewView.material.SetInt("_SrcBlendMode", 5);

            // TODO: consider just grabbing default values from the material instead?
            _initAmplitudeScale         = amplitudeScale;
            _initMode                   = mode;
            _initCtensity               = ctensity;
            _initCtensityTilingScale    = ctensityTilingScale;
            _initCtensityOffsetScale    = ctensityOffsetScale;
            _initCtensityRotationScale  = ctensityRotationScale;
            _initCtensityRotation_Band0 = ctensityRotation_Band0;
            _initCtensityRotation_Band1 = ctensityRotation_Band1;
            _initCtensityRotation_Band2 = ctensityRotation_Band2;
            _initCtensityRotation_Band3 = ctensityRotation_Band3;
            _initTilingScale            = tilingScale;
            _initRotation               = rotation;

            if (Networking.IsOwner(gameObject)) {
                amplitudeSlider.value              = amplitudeScale;
                modeSlider.value                   = mode;
                ctensityToggle.isOn                = ctensity;
                ctensityTilingScaleSlider.value    = ctensityTilingScale;
                ctensityOffsetScaleSlider.value    = ctensityOffsetScale;
                ctensityRotationScaleSlider.value  = ctensityRotationScale;
                ctensityRotationSlider_Band0.value = ctensityRotation_Band0;
                ctensityRotationSlider_Band1.value = ctensityRotation_Band1;
                ctensityRotationSlider_Band2.value = ctensityRotation_Band2;
                ctensityRotationSlider_Band3.value = ctensityRotation_Band3;
                tilingScaleSlider.value            = tilingScale;
                rotationSlider.value               = rotation;
            }

/*
            _initAmplitudeScale         = amplitudeSlider.value;
            _initMode                   = modeSlider.value;
            _initCtensity               = ctensityToggle.isOn;
            _initCtensityTilingScale    = ctensityTilingScaleSlider.value;
            _initCtensityOffsetScale    = ctensityOffsetScaleSlider.value;
            _initCtensityRotationScale  = ctensityRotationScaleSlider.value;
            _initCtensityRotation_Band0 = ctensityRotationSlider_Band0.value;
            _initCtensityRotation_Band1 = ctensityRotationSlider_Band1.value;
            _initCtensityRotation_Band2 = ctensityRotationSlider_Band2.value;
            _initCtensityRotation_Band3 = ctensityRotationSlider_Band3.value;
            _initTilingScale            = tilingScaleSlider.value;
            _initRotation               = rotationSlider.value;

            if (Networking.IsOwner(gameObject)) {
                amplitudeSlider.value              = amplitudeScale;
                modeSlider.value                   = mode;
                ctensityToggle.isOn                = ctensity;
                ctensityTilingScaleSlider.value    = ctensityTilingScale;
                ctensityOffsetScaleSlider.value    = ctensityOffsetScale;
                ctensityRotationScaleSlider.value  = ctensityRotationScale;
                ctensityRotationSlider_Band0.value = ctensityRotation_Band0;
                ctensityRotationSlider_Band1.value = ctensityRotation_Band1;
                ctensityRotationSlider_Band2.value = ctensityRotation_Band2;
                ctensityRotationSlider_Band3.value = ctensityRotation_Band3;
                tilingScaleSlider.value            = tilingScale;
                rotationSlider.value               = rotation;
            }
*/

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

        // Updates the preview material (this should be a callback from the sliders etc.)
        public void UpdatePreview()
        {
            int newMode = modeConversion((int)modeSlider.value);

            // Update labels
            amplitudeLabel.text = "Amplitude Scale: " + amplitudeSlider.value.ToString("0.00");
            modeLabel.text =
                "Mode: " + modeToString(newMode) + "(" + newMode.ToString() + ")" +
                ((newMode >= 11) ? " <sub>Note: Auto modes do not sync perfectly</sub>" : "");
            ctensityTilingScaleLabel.text = "Chronotensity Tiling Scale: " + ctensityTilingScaleSlider.value.ToString("0.00");
            ctensityOffsetScaleLabel.text = "Chronotensity Offset Scale: " + ctensityOffsetScaleSlider.value.ToString("0.00");
            ctensityRotationScaleLabel.text = "Chronotensity Rotation Scale: " + ctensityRotationScaleSlider.value.ToString("0.00");

            ctensityRotationLabel.text =
                "Chronotensity Rotation\n" +
                "Bass: " + ctensityRotationSlider_Band0.value.ToString("0.00") +
                "\tLow Mid: " + ctensityRotationSlider_Band1.value.ToString("0.00") +
                "\tHigh Mid: " + ctensityRotationSlider_Band2.value.ToString("0.00") +
                "\tTreble: " + ctensityRotationSlider_Band3.value.ToString("0.00");

            tilingScaleLabel.text = "Tiling: " + tilingScaleSlider.value.ToString("0.00");
            rotationLabel.text = "Rotation: " + rotationSlider.value.ToString("0.00");

            // Apply to material of preview strip
            previewView.material.SetFloat("_Amplitude_Scale", amplitudeSlider.value);
            previewView.material.SetInt("_Mode", newMode);
            previewView.material.SetFloat("_Chronotensity_Scale", ctensityToggle.isOn ? 1.0f : 0.0f);
            previewView.material.SetFloat("_Chronotensity_Tiling_Scale", ctensityTilingScaleSlider.value);
            previewView.material.SetFloat("_Chronotensity_Offset_Scale", ctensityOffsetScaleSlider.value);
            previewView.material.SetFloat("_ChronoRot_Scale", ctensityRotationScaleSlider.value);
            previewView.material.SetFloat("_ChronoRot_Band0", ctensityRotationSlider_Band0.value);
            previewView.material.SetFloat("_ChronoRot_Band1", ctensityRotationSlider_Band1.value);
            previewView.material.SetFloat("_ChronoRot_Band2", ctensityRotationSlider_Band2.value);
            previewView.material.SetFloat("_ChronoRot_Band3", ctensityRotationSlider_Band3.value);
            previewView.material.SetFloat("_Tiling_Scale", tilingScaleSlider.value);
            previewView.material.SetFloat("_Rotation", rotationSlider.value);
        }

        public override void OnDeserialization()
        {
            deserializing = true;
            setMaterial();
            deserializing = false;
        }

        // Sets the active material up
        private void setMaterial()
        {
            foreach (Material material in materials) {
                material.SetFloat("_Amplitude_Scale", amplitudeScale);
                material.SetInt("_Mode", mode);
                material.SetFloat("_Chronotensity_Scale", ctensity ? 1.0f : 0.0f);
                material.SetFloat("_Chronotensity_Tiling_Scale", ctensityTilingScale);
                material.SetFloat("_Chronotensity_Offset_Scale", ctensityOffsetScale);
                material.SetFloat("_ChronoRot_Scale", ctensityRotationScale);
                material.SetFloat("_ChronoRot_Band0", ctensityRotation_Band0);
                material.SetFloat("_ChronoRot_Band1", ctensityRotation_Band1);
                material.SetFloat("_ChronoRot_Band2", ctensityRotation_Band2);
                material.SetFloat("_ChronoRot_Band3", ctensityRotation_Band3);
                material.SetFloat("_Tiling_Scale", tilingScale);
                material.SetFloat("_Rotation", rotation);
            }

            activeView.material.SetFloat("_Amplitude_Scale", amplitudeScale);
            activeView.material.SetInt("_Mode", mode);
            activeView.material.SetFloat("_Chronotensity_Scale", ctensity ? 1.0f : 0.0f);
            activeView.material.SetFloat("_Chronotensity_Tiling_Scale", ctensityTilingScale);
            activeView.material.SetFloat("_Chronotensity_Offset_Scale", ctensityOffsetScale);
            activeView.material.SetFloat("_ChronoRot_Scale", ctensityRotationScale);
            activeView.material.SetFloat("_ChronoRot_Band0", ctensityRotation_Band0);
            activeView.material.SetFloat("_ChronoRot_Band1", ctensityRotation_Band1);
            activeView.material.SetFloat("_ChronoRot_Band2", ctensityRotation_Band2);
            activeView.material.SetFloat("_ChronoRot_Band3", ctensityRotation_Band3);
            activeView.material.SetFloat("_Tiling_Scale", tilingScale);
            activeView.material.SetFloat("_Rotation", rotation);
        }

        public void ApplySettings()
        {
            if (deserializing)
                return;

            if (!Networking.IsOwner(gameObject))
                Networking.SetOwner(localPlayer, gameObject);

            int newMode = modeConversion((int)modeSlider.value);
            amplitudeScale = amplitudeSlider.value;
            mode = newMode;
            ctensity = ctensityToggle.isOn;
            ctensityTilingScale = ctensityTilingScaleSlider.value;
            ctensityOffsetScale = ctensityOffsetScaleSlider.value;
            ctensityRotationScale = ctensityRotationScaleSlider.value;
            ctensityRotation_Band0 = ctensityRotationSlider_Band0.value;
            ctensityRotation_Band1 = ctensityRotationSlider_Band1.value;
            ctensityRotation_Band2 = ctensityRotationSlider_Band2.value;
            ctensityRotation_Band3 = ctensityRotationSlider_Band3.value;
            tilingScale = tilingScaleSlider.value;
            rotation = rotationSlider.value;

            setMaterial();
            RequestSerialization();
        }

        public void ResetSettings()
        {
            amplitudeSlider.value = _initAmplitudeScale;
            modeSlider.value = _initMode;
            ctensityToggle.isOn = _initCtensity;
            ctensityTilingScaleSlider.value = _initCtensityTilingScale;
            ctensityOffsetScaleSlider.value = _initCtensityOffsetScale;
            ctensityRotationScaleSlider.value = _initCtensityRotationScale;
            ctensityRotationSlider_Band0.value = _initCtensityRotation_Band0;
            ctensityRotationSlider_Band1.value = _initCtensityRotation_Band1;
            ctensityRotationSlider_Band2.value = _initCtensityRotation_Band2;
            ctensityRotationSlider_Band3.value = _initCtensityRotation_Band3;
            tilingScaleSlider.value = _initTilingScale;
            rotationSlider.value = _initRotation;
            laggyModeToggle.isOn = false;
        }

        // Instead of restoring the default setup this zeroes everything. Useful if the default
        // are set up to be cool defaults, but is not a good preset to start tweaking from.
        public void ZeroSettings()
        {
            amplitudeSlider.value = 1.0f;
            modeSlider.value = 8;                           // PCM ribbon
            ctensityToggle.isOn = false;
            ctensityTilingScaleSlider.value = 0.0f;
            ctensityOffsetScaleSlider.value = 0.0f;
            ctensityRotationScaleSlider.value = 1.0f;
            ctensityRotationSlider_Band0.value = 0.0f;
            ctensityRotationSlider_Band1.value = 0.0f;
            ctensityRotationSlider_Band2.value = 0.0f;
            ctensityRotationSlider_Band3.value = 0.0f;
            tilingScaleSlider.value = 1.0f;
            rotationSlider.value = 0.0f;
            laggyModeToggle.isOn = false;
        }

        // TODO: Figure out a better way using the enum or something
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
