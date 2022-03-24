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
        public Material material;

        [Space(10)]
        [Range(0.0f, 2.0f)]
        public float amplitudeScale = 0.4f;
        public int mode = 12;
        public bool ctensity = false;

        [Range(0.0f, 10.0f)]
        public float ctensityTilingScale = 0.0f;
        [Range(0.0f, 10.0f)]
        public float ctensityOffsetScale = 0.0f;

#if UNITY_EDITOR
        void Update()
        {
            //UpdateSettings();
        }
#endif

        void Start()
        {
            if (material == null) Debug.Log("Not connected to material");
            UpdateSettings();
        }

        public void UpdateSettings()
        {
            material.SetFloat("_Amplitude_Scale", amplitudeScale);
            material.SetInt("_Mode", mode);
            material.SetFloat("_Chronotensity_Scale", ctensity ? 1.0f : 0.0f);
            material.SetFloat("_Chronotensity_Tiling_Scale", ctensityTilingScale);
            material.SetFloat("_Chronotensity_Offset_Scale", ctensityOffsetScale);
        }
    }
}
