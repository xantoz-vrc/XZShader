using UnityEngine;
using VRC.SDKBase;
using UnityEngine.UI;
using System;

namespace XZShader
{
#if UDON
    using UdonSharp;

#if !COMPILER_UDONSHARP && UNITY_EDITOR
    using UnityEditor;
    using UdonSharpEditor;
    using VRC.Udon;
    using VRC.Udon.Common;
    using VRC.Udon.Common.Interfaces;
    using System.Collections.Immutable;
#endif

    [UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
    public class XZAlVis : UdonSharpBehaviour
#else
    public class XZAlVis : MonoBehavior
#endif
    {
        public Material[] materials;

        [Space(10)]
        [UdonSynced] [Range(0.0f, 2.0f)] public float amplitudeScale = 0.4f;
        [UdonSynced] public int mode = 12;
        [UdonSynced] public bool ctensity = false;

        [UdonSynced] [Range(0.0f, 10.0f)] public float ctensityTilingScale = 0.0f;
        [UdonSynced] [Range(0.0f, 10.0f)] public float ctensityOffsetScale = 0.0f;
        [UdonSynced] [Range(-2.0f, 2.0f)] public float ctensityRotationScale = 0.0f;

        [UdonSynced] [Range(-2.0f, 2.0f)] public float ctensityRotation_Band1 = 0.0f;
        [UdonSynced] [Range(-2.0f, 2.0f)] public float ctensityRotation_Band2 = 0.0f;
        [UdonSynced] [Range(-2.0f, 2.0f)] public float ctensityRotation_Band3 = 0.0f;
        [UdonSynced] [Range(-2.0f, 2.0f)] public float ctensityRotation_Band4 = 0.0f;

        [UdonSynced] [Range(0.1f, 10.0f)] public float tilingScale = 1.0f;
        [UdonSynced] [Range(-360.0f, 360.0f)] public float rotation = 0.0f;

        private bool deserializing;
        private VRCPlayerApi localPlayer;

#if UNITY_EDITOR
        void Update()
        {
            //UpdateSettings();
        }
#endif

        void Start()
        {
            localPlayer = Networking.LocalPlayer;
            deserializing = false;

            _setMaterial();

            if (Networking.IsOwner(gameObject))
                RequestSerialization();
        }

        public override void OnDeserialization()
        {
            deserializing = true;
            _setMaterial();
            deserializing = false;
        }

        private void _setMaterial()
        {
            foreach (Material material in materials) {
                material.SetFloat("_Amplitude_Scale", amplitudeScale);
                material.SetInt("_Mode", mode);
                material.SetFloat("_Chronotensity_Scale", ctensity ? 1.0f : 0.0f);
                material.SetFloat("_Chronotensity_Tiling_Scale", ctensityTilingScale);
                material.SetFloat("_Chronotensity_Offset_Scale", ctensityOffsetScale);

                material.SetFloat("_ChronoRot_Scale", ctensityRotationScale);
                material.SetFloat("_ChronoRot_Band1", ctensityRotation_Band1);
                material.SetFloat("_ChronoRot_Band2", ctensityRotation_Band2);
                material.SetFloat("_ChronoRot_Band3", ctensityRotation_Band3);
                material.SetFloat("_ChronoRot_Band4", ctensityRotation_Band4);

                material.SetFloat("_Tiling_Scale", tilingScale);
                material.SetFloat("_Rotation", rotation);
            }
        }

        public void UpdateSettings()
        {
            if (deserializing)
                return;

            if (!Networking.IsOwner(gameObject))
                Networking.SetOwner(localPlayer, gameObject);

            _setMaterial();
            RequestSerialization();
        }
    }
}
