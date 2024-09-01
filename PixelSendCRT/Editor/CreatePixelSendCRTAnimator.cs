// idea by Nave, original: https://pastebin.com/Q43UPHf4
#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;
using UnityEditor.Animations;
using System.Collections;

public class CreatePixelSendCRTAnimator : MonoBehaviour
{
    private static string basePath = "Assets/XZShader/PixelSendCRT/Avatar/Anim/";
    private static string parameterPrefix = "PixelSendCRT/";

    private static AnimationClip createBoolAnimationClip(string name, bool val)
    {
        var clip = new AnimationClip();
        string onoff = val ? "ON" : "OFF";
        clip.name = $"anim{name}{onoff}";
        var curve = AnimationCurve.Linear(0.0f, val ? 1.0f : 0.0f, 0.0f, val ? 1.0f : 0.0f);
        clip.SetCurve("Quad GrabPass", typeof(Renderer), $"material._{name}", curve);
        AssetDatabase.CreateAsset(clip, basePath + clip.name + ".anim");
        return clip;
    }

    // [MenuItem("GameObject/Generate Animator Controller for PixelSendCRT")]
    [MenuItem("XZMenu/CreatePixelSendCRTAnimator")]
    static void CreateController()
    {
        // Creates the controller
        var controller = UnityEditor.Animations.AnimatorController.CreateAnimatorControllerAtPath(basePath + "PixelSendCRT Animator.controller");

        // Add parameters
        for (int i = 0; i < 16; ++i) {
            string hex = i.ToString("X");
            string V = $"V{hex}";
            controller.AddParameter(parameterPrefix + V, AnimatorControllerParameterType.Int);
            controller.AddLayer(parameterPrefix + V);
            // controller.layers[i+1].defaultWeight = 1.0f;
            // var layer = controller.layers[i+1]; layer.defaultWeight = 1.0f; controller.layers[i+1] = layer;

            var layer = controller.layers[i+1];
            layer.defaultWeight = 1.0f;

            var clip = new AnimationClip();
            clip.name = $"anim{V}";
            clip.wrapMode = WrapMode.Loop;
            var curve = AnimationCurve.Linear(0.0f, 0.0f, 1.0f, 1.0f);
            clip.SetCurve("Quad GrabPass", typeof(Renderer), $"material._{V}", curve);
            AnimationClipSettings settings = AnimationUtility.GetAnimationClipSettings(clip);
            settings.loopTime = true;  // Set loop time to true
            AnimationUtility.SetAnimationClipSettings(clip, settings);

            AssetDatabase.CreateAsset(clip, basePath + clip.name + ".anim");

            for (int j = 0; j < 256; ++j) {
                var rootStateMachine = layer.stateMachine;

                var state = rootStateMachine.AddState($"{V}={j}", new Vector3(400.0f, j*50.0f, 0.0f));
                state.motion = clip;
                state.cycleOffset = ((float)(j))/255.0f;
                state.speed = 0.0f;

                // if (j == 0) { rootStateMachine.AddEntryTransition(state); }
                var transition = rootStateMachine.AddAnyStateTransition(state);
                transition.AddCondition(UnityEditor.Animations.AnimatorConditionMode.Equals, j, parameterPrefix + V);
                transition.duration = 0;
                transition.canTransitionToSelf = false;
            }
        }

        {
            controller.AddParameter(parameterPrefix + "CLK", AnimatorControllerParameterType.Bool);
            controller.AddLayer(parameterPrefix + "CLK");
            var rootStateMachine = controller.layers[controller.layers.Length-1].stateMachine;

            var clkOnClip  = createBoolAnimationClip("CLK", true);
            var clkOffClip = createBoolAnimationClip("CLK", false);
            var clkOnState  = rootStateMachine.AddState("CLK ON",  new Vector3(400.0f, 0.0f, 0.0f));
            var clkOffState = rootStateMachine.AddState("CLK OFF", new Vector3(400.0f, 50.0f, 0.0f));
            clkOnState.motion = clkOnClip;
            clkOffState.motion = clkOffClip;

            // rootStateMachine.AddEntryTransition(clkOffState);
            var transitionOn  = rootStateMachine.AddAnyStateTransition(clkOnState);
            var transitionOff = rootStateMachine.AddAnyStateTransition(clkOffState);

            transitionOn.AddCondition(UnityEditor.Animations.AnimatorConditionMode.If, 0, parameterPrefix + "CLK");
            transitionOff.AddCondition(UnityEditor.Animations.AnimatorConditionMode.IfNot, 0, parameterPrefix + "CLK");

            transitionOn.duration = 0;
            transitionOn.canTransitionToSelf = false;;
            transitionOff.duration = 0;
            transitionOff.canTransitionToSelf = false;
        }

        {
            controller.AddParameter(parameterPrefix + "Reset", AnimatorControllerParameterType.Bool);
            controller.AddLayer(parameterPrefix + "Reset");
            var rootStateMachine = controller.layers[controller.layers.Length-1].stateMachine;

            var resetOnClip = createBoolAnimationClip("Reset", true);
            var resetOffClip = createBoolAnimationClip("Reset", false);
            var resetOnState  = rootStateMachine.AddState("Reset ON",  new Vector3(400.0f, 0.0f, 0.0f));
            var resetOffState = rootStateMachine.AddState("Reset OFF", new Vector3(400.0f, 50.0f, 0.0f));
            resetOnState.motion = resetOnClip;
            resetOffState.motion = resetOffClip;

            // rootStateMachine.AddEntryTransition(resetOffState);
            var transitionOn  = rootStateMachine.AddAnyStateTransition(resetOnState);
            var transitionOff = rootStateMachine.AddAnyStateTransition(resetOffState);

            transitionOn.AddCondition(UnityEditor.Animations.AnimatorConditionMode.If, 0, parameterPrefix + "Reset");
            transitionOff.AddCondition(UnityEditor.Animations.AnimatorConditionMode.IfNot, 0, parameterPrefix + "Reset");

            transitionOn.duration = 0;
            transitionOn.canTransitionToSelf = false;;
            transitionOff.duration = 0;
            transitionOff.canTransitionToSelf = false;
        }

        AssetDatabase.SaveAssets();
    }
}
#endif
