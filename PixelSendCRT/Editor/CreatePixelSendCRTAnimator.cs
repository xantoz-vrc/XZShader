// idea by Nave, original: https://pastebin.com/Q43UPHf4
#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;
using UnityEngine.Assertions;
using UnityEditor.Animations;
using System.Collections;

public class CreatePixelSendCRTAnimator : MonoBehaviour
{
    private static string basePath = "Assets/XZShader/PixelSendCRT/Avatar/Anim/";
    private static string parameterPrefix = "PixelSendCRT/";

    // Wipe the AnimatorController clean: remove all parameters, layers, and states
    private static void wipeAnimatorController(AnimatorController animatorController)
    {
        if (animatorController == null) return;

        animatorController.parameters = new AnimatorControllerParameter[0];
        animatorController.layers = new AnimatorControllerLayer[0];

        // Optionally, add a new default layer if needed
        AnimatorControllerLayer baseLayer = new AnimatorControllerLayer {
            name = "Base Layer",
            stateMachine = new AnimatorStateMachine()
        };
        animatorController.AddLayer(baseLayer);

        Debug.Log("AnimatorController wiped clean.");
    }

    private static AnimatorController getAnimatorController(string path)
    {
        AnimatorController animatorController = AssetDatabase.LoadAssetAtPath<AnimatorController>(path);

        if (animatorController == null) {
            animatorController = AnimatorController.CreateAnimatorControllerAtPath(path);
            Debug.Log("AnimatorController created at: " + path);
        } else {
            Debug.Log("AnimatorController loaded from: " + path);
            wipeAnimatorController(animatorController);
        }

        EditorUtility.SetDirty(animatorController);

        return animatorController;
    }

    private static AnimationClip getAnimationClip(string path)
    {
        AnimationClip clip = AssetDatabase.LoadAssetAtPath<AnimationClip>(path);

        if (clip == null) {
            clip = new AnimationClip();
            AssetDatabase.CreateAsset(clip, path);
            Debug.Log("AnimationClip created at: " + path);
        } else {
            Debug.Log("AnimationClip loaded from: " + path);
            if (clip.empty) {
                Debug.LogWarning("Expected that pre-existing AnimationClip would contain something, but it was already empty");
            }

            clip.ClearCurves();
            // clip.events = new AnimationEvent[0];
        }

        Assert.IsTrue(clip.empty);

        clip.frameRate = 512; // Double what we actually need, I think?

        EditorUtility.SetDirty(clip);
        return clip;
    }

    private static AnimationClip createBoolAnimationClip(string name, bool val)
    {
        string onoff = val ? "ON" : "OFF";

        var clipname = $"anim{name}{onoff}";
        var path = basePath + clipname + ".anim";

        var clip = getAnimationClip(path);
        clip.name = clipname;
        var curve = AnimationCurve.Linear(0.0f, val ? 1.0f : 0.0f, 0.0f, val ? 1.0f : 0.0f);
        clip.SetCurve("Quad GrabPass", typeof(Renderer), $"material._{name}", curve);
        return clip;
    }

    // [MenuItem("GameObject/Generate Animator Controller for PixelSendCRT")]
    [MenuItem("XZMenu/CreatePixelSendCRTAnimator")]
    static void CreateController()
    {
        // Creates the controller
        var controller = getAnimatorController(basePath + "PixelSendCRT Animator.controller");

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

            var clipname = $"anim{V}";
            var clip = getAnimationClip(basePath + clipname + ".anim");
            clip.name = clipname;
            clip.wrapMode = WrapMode.ClampForever;
            var curve = AnimationCurve.Linear(0.0f, 0.0f, 1.0f, 1.0f);
            clip.SetCurve("Quad GrabPass", typeof(Renderer), $"material._{V}", curve);
            AnimationClipSettings settings = AnimationUtility.GetAnimationClipSettings(clip);
            settings.loopTime = true;  // Set loop time to true
            AnimationUtility.SetAnimationClipSettings(clip, settings);

            for (int j = 0; j < 256; ++j) {
                var rootStateMachine = layer.stateMachine;

                var state = rootStateMachine.AddState($"{V}={j}", new Vector3(400.0f, j*50.0f, 0.0f));
                state.motion = clip;
                state.cycleOffset = (j == 255) ? 1.0f - Mathf.Epsilon : ((float)(j))/255.0f;
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
            var layer = controller.layers[controller.layers.Length-1];
            layer.defaultWeight = 1.0f;
            var rootStateMachine = layer.stateMachine;

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
            transitionOn.canTransitionToSelf = false;
            transitionOff.duration = 0;
            transitionOff.canTransitionToSelf = false;
        }

        {
            controller.AddParameter(parameterPrefix + "Reset", AnimatorControllerParameterType.Bool);
            controller.AddLayer(parameterPrefix + "Reset");
            var layer = controller.layers[controller.layers.Length-1];
            layer.defaultWeight = 1.0f;
            var rootStateMachine = layer.stateMachine;

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

        EditorUtility.SetDirty(controller);
        AssetDatabase.SaveAssets();
    }
}
#endif
