// idea by Nave, original: https://pastebin.com/Q43UPHf4
#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;
using UnityEditor.Animations;
using System.Collections;

public class CreatePixelSendCRTAnimator : MonoBehaviour
{
    // [MenuItem("GameObject/Generate Animator Controller for PixelSendCRT")]
    [MenuItem("XZMenu/CreatePixelSendCRTAnimator")]
    static void CreateController()
    {
        string basePath = "Assets/XZShader/PixelSendCRT/Avatar/Anim/";

        // Creates the controller
        var controller = UnityEditor.Animations.AnimatorController.CreateAnimatorControllerAtPath(basePath + "PixelSendCRT Animator.controller");

        // Add parameters
        for (int i = 0; i < 16; ++i) {
            string hex = i.ToString("X");
            string V = $"V{hex}";
            controller.AddParameter(V, AnimatorControllerParameterType.Int);
            controller.AddLayer(V);
            // controller.layers[i+1].defaultWeight = 1.0f;
            // var layer = controller.layers[i+1]; layer.defaultWeight = 1.0f; controller.layers[i+1] = layer;

            var layer = controller.layers[i+1];
            layer.defaultWeight = 1.0f;

            var clip = new AnimationClip();
            clip.name = $"anim{V}";
            clip.wrapMode = WrapMode.Loop;
            AnimationClipSettings settings = AnimationUtility.GetAnimationClipSettings(clip);
            settings.loopTime = true;  // Set loop time to true
            AnimationUtility.SetAnimationClipSettings(clip, settings);

            AssetDatabase.CreateAsset(clip, basePath + clip.name + ".anim");

            for (int j = 0; j < 256; ++j) {
                var rootStateMachine = layer.stateMachine;

                // var state = controller.AddMotion(animation);
                // state.name = $"{V}={i}";

                var state = rootStateMachine.AddState($"{V}={j}", new Vector3(400.0f, j*50.0f, 0.0f));
                state.motion = clip;
                state.cycleOffset = ((float)(j))/255.0f;
                state.speed = 0.0f;

                if (j == 0) {
                    rootStateMachine.AddEntryTransition(state);
                }
                var transition = rootStateMachine.AddAnyStateTransition(state);
                transition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.Equals, j, V);
                transition.duration = 0;
            }
        }

        controller.AddParameter("CLK", AnimatorControllerParameterType.Bool);
        controller.AddLayer("CLK");

        controller.AddParameter("Reset", AnimatorControllerParameterType.Bool);
        controller.AddLayer("Reset");

        AssetDatabase.SaveAssets();
    }
}
#endif
