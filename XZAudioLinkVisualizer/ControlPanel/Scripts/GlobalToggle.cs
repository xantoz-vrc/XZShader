using UnityEngine;
using VRC.SDKBase;
using UnityEngine.UI;

namespace XZShader
{
#if UDON
    using UdonSharp;
    using VRC.Udon;

    [UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
    public class GlobalToggle : UdonSharpBehaviour
    {
        [UdonSynced]
        private bool syncedValue;
        private bool deserializing;
        private Toggle toggle;
        private VRCPlayerApi localPlayer;

        private void Start()
        {
            toggle = transform.GetComponent<Toggle>();
            localPlayer = Networking.LocalPlayer;
            syncedValue = toggle.isOn;
            deserializing = false;

            if (Networking.IsOwner(gameObject))
                RequestSerialization();
        }

        public override void OnDeserialization()
        {
            deserializing = true;
            toggle.isOn = syncedValue;
            deserializing = false;
        }

        public void ToggleUpdate()
        {
            if (deserializing)
                return;
            if (!Networking.IsOwner(gameObject))
                Networking.SetOwner(localPlayer, gameObject);

            syncedValue = toggle.isOn;
            RequestSerialization();
        }
    }
#else
    public class GlobalToggle : MonoBehaviour
    {
    }
#endif
}
