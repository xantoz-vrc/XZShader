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

        // [Space(10)]
        [Range(0.0f, 2.0f)]
        public float amplitudeScale;
        public int mode;

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
        }
    }
}
