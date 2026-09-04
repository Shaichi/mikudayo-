#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Mikudayo.Avatar.Editor
{
    /// <summary>
    /// Builds the current scene with the opt-in gesture capture component
    /// attached in memory. The scene asset is never saved or rebuilt.
    /// </summary>
    public static class MikuGestureCaptureBuild
    {
        public static void BuildCurrentSceneGestureCapture()
        {
            const string scenePath = "Assets/Mikudayo/Scenes/MikuAvatar.unity";
            const string tempScenePath = "Assets/Mikudayo/Scenes/MikuAvatarGestureCaptureTemp.unity";
            var scene = SceneManager.GetActiveScene();
            if (!scene.IsValid() || scene.path != scenePath)
            {
                scene = EditorSceneManager.OpenScene(scenePath);
            }

            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(tempScenePath) != null)
            {
                AssetDatabase.DeleteAsset(tempScenePath);
            }

            if (!EditorSceneManager.SaveScene(scene, tempScenePath))
            {
                throw new IOException($"Could not save temporary scene: {tempScenePath}");
            }

            try
            {
                scene = EditorSceneManager.OpenScene(tempScenePath);
                var bridgeObject = GameObject.Find("MikuAvatarBridge");
                if (bridgeObject == null)
                {
                    throw new FileNotFoundException("MikuAvatarBridge was not found in the current scene");
                }

                var bridge = bridgeObject.GetComponent<MikuAvatarBridge>();
                if (bridge == null)
                {
                    throw new MissingComponentException("MikuAvatarBridge component was not found");
                }

                // Serialize the model-specific pose layer into the temporary
                // capture scene. Relying only on AddComponent from Bridge.Awake
                // is timing-sensitive when the VRM instance is created during
                // scene startup, and can leave the smoke player on the old
                // VRMA control-rig path.
                var avatarRoot = bridge.GestureController != null &&
                                 bridge.GestureController.AvatarRoot != null
                    ? bridge.GestureController.AvatarRoot
                    : null;
                if (avatarRoot != null)
                {
                    var natural = avatarRoot.GetComponent<MikuNaturalGestureController>() ??
                                  avatarRoot.AddComponent<MikuNaturalGestureController>();
                    natural.AvatarRoot = avatarRoot;
                    bridge.NaturalGestureController = natural;
                    if (bridge.GestureController != null)
                    {
                        bridge.GestureController.enabled = false;
                    }
                }

                var capture = bridgeObject.GetComponent<MikuAvatarSmokeCapture>() ??
                              bridgeObject.AddComponent<MikuAvatarSmokeCapture>();
                capture.Bridge = bridge;
                EditorSceneManager.SaveScene(scene, tempScenePath);

                var output = Path.GetFullPath(Path.Combine(
                    Application.dataPath, "../Builds/Windows/MikuAvatarGestureCapture.exe"));
                Directory.CreateDirectory(Path.GetDirectoryName(output));
                var report = BuildPipeline.BuildPlayer(
                    new[] { tempScenePath }, output, BuildTarget.StandaloneWindows64,
                    BuildOptions.Development);
                if (report.summary.result != BuildResult.Succeeded)
                {
                    throw new BuildFailedException($"Gesture capture build failed: {report.summary.result}");
                }

                Debug.Log($"MikuAvatar: gesture capture player ready at {output}");
            }
            finally
            {
                EditorSceneManager.OpenScene(scenePath, OpenSceneMode.Single);
                AssetDatabase.DeleteAsset(tempScenePath);
                AssetDatabase.Refresh();
            }
        }
    }
}
#endif
