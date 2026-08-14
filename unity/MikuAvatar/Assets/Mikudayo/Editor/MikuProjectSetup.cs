#if UNITY_EDITOR
using System.IO;
using ChatdollKit.Model;
using Mikudayo.Avatar.Vrm10;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.UI;

namespace Mikudayo.Avatar.Editor
{
    public static class MikuProjectSetup
    {
        private const string ModelPath = "Assets/Mikudayo/Models/Miku.vrm";
        private const string SceneDirectory = "Assets/Mikudayo/Scenes";
        private const string ScenePath = SceneDirectory + "/MikuAvatar.unity";
        private const string AnimatorPath = "Assets/Mikudayo/MikuAvatar.controller";
        private const string IdleClipPath = "Assets/Mikudayo/MikuIdlePlaceholder.anim";
        private const string UrpDirectory = "Assets/Mikudayo/Rendering";
        private const string UrpRendererPath = UrpDirectory + "/MikuUniversalRenderer.asset";
        private const string UrpPipelinePath = UrpDirectory + "/MikuUniversalPipeline.asset";
        private const string BackgroundTexturePath = "Assets/Mikudayo/Backgrounds/miku_room.png";
        private const string BackgroundMaterialPath = "Assets/Mikudayo/Backgrounds/MikuRoomBackground.mat";

        [MenuItem("Mikudayo/Rebuild Miku Avatar Scene")]
        public static void RebuildScene()
        {
            ConfigureUrp();
            ConfigureVrmImporterForUrp();
            var modelPrefab = AssetDatabase.LoadAssetAtPath<GameObject>(ModelPath);
            if (modelPrefab == null)
            {
                throw new FileNotFoundException($"VRM 1.0 model was not imported: {ModelPath}");
            }

            EnsureDirectory(SceneDirectory);
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var avatar = (GameObject)PrefabUtility.InstantiatePrefab(modelPrefab);
            avatar.name = "MikuVRM10";
            avatar.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity);
            var animator = avatar.GetComponentInChildren<Animator>(true);
            if (animator == null) animator = avatar.AddComponent<Animator>();
            // An empty humanoid clip forces Unity's retargeted default pose and
            // bends this model's elbows/wrists unnaturally. Preserve the VRM
            // rest pose and layer a small deterministic relaxed pose instead.
            animator.runtimeAnimatorController = null;
            var relaxedPose = avatar.AddComponent<MikuRelaxedPose>();
            relaxedPose.Animator = animator;

            var bridgeObject = new GameObject("MikuAvatarBridge");
            var audioSource = bridgeObject.AddComponent<AudioSource>();
            audioSource.playOnAwake = false;
            var blink = bridgeObject.AddComponent<Vrm10Blink>();
            var faceProxy = bridgeObject.AddComponent<Vrm10FaceExpressionProxy>();
            var mouth = bridgeObject.AddComponent<Vrm10MouthCueDriver>();
            mouth.AvatarRoot = avatar;
            var faceController = bridgeObject.AddComponent<FaceController>();
            var speechController = bridgeObject.AddComponent<SpeechController>();
            speechController.AudioSource = audioSource;
            var modelController = bridgeObject.AddComponent<ModelController>();
            modelController.AvatarModel = avatar;
            // Face/blink setup still runs in Awake; disabling Update prevents
            // ChatDollKit from driving a missing animation controller.
            modelController.enabled = false;
            var bridge = bridgeObject.AddComponent<MikuAvatarBridge>();
            bridge.ModelController = modelController;
            bridge.MouthDriver = mouth;
            var demo = bridgeObject.AddComponent<MikuAvatarAutoDemo>();
            demo.Bridge = bridge;
            var smokeCapture = bridgeObject.AddComponent<MikuAvatarSmokeCapture>();
            smokeCapture.Bridge = bridge;

            // Keep explicit references alive and make setup intent obvious.
            EditorUtility.SetDirty(blink);
            EditorUtility.SetDirty(faceProxy);
            EditorUtility.SetDirty(faceController);

            CreateBackground();
            CreateCamera(avatar);
            CreateLighting();
            CreateStatusOverlay();

            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Selection.activeGameObject = bridgeObject;
            Debug.Log($"MikuAvatar: scene rebuilt at {ScenePath}");
        }

        [MenuItem("Mikudayo/Prepare Embedded Flutter Scene")]
        public static void PrepareEmbeddedScene()
        {
            RebuildScene();
            ConfigureAndroidPlayer();
            EditorUserBuildSettings.exportAsGoogleAndroidProject = true;
            var demo = Object.FindFirstObjectByType<MikuAvatarAutoDemo>();
            if (demo != null) Object.DestroyImmediate(demo);
            var capture = Object.FindFirstObjectByType<MikuAvatarSmokeCapture>();
            if (capture != null) Object.DestroyImmediate(capture);
            var overlay = GameObject.Find("Smoke Test UI");
            if (overlay != null) Object.DestroyImmediate(overlay);

            EditorSceneManager.SaveScene(SceneManager.GetActiveScene(), ScenePath);
            AssetDatabase.SaveAssets();
            Debug.Log("MikuAvatar: embedded Flutter scene prepared");
        }

        [MenuItem("Mikudayo/Build Android Smoke-Test APK")]
        public static void BuildAndroidApk()
        {
            RebuildScene();
            ConfigureAndroidPlayer();
            EditorUserBuildSettings.exportAsGoogleAndroidProject = false;
            var output = Path.GetFullPath(Path.Combine(Application.dataPath, "../Builds/Android/MikuAvatar-debug.apk"));
            Directory.CreateDirectory(Path.GetDirectoryName(output));
            var report = BuildPipeline.BuildPlayer(
                new[] { ScenePath }, output, BuildTarget.Android, BuildOptions.Development);
            if (report.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
            {
                throw new BuildFailedException($"Android build failed: {report.summary.result}");
            }
            Debug.Log($"MikuAvatar: APK ready at {output}");
        }

        [MenuItem("Mikudayo/Build Windows Smoke-Test Player")]
        public static void BuildWindowsSmokeTest()
        {
            RebuildScene();
            var output = Path.GetFullPath(Path.Combine(
                Application.dataPath, "../Builds/Windows/MikuAvatarSmoke.exe"));
            Directory.CreateDirectory(Path.GetDirectoryName(output));
            var report = BuildPipeline.BuildPlayer(
                new[] { ScenePath }, output, BuildTarget.StandaloneWindows64, BuildOptions.Development);
            if (report.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
            {
                throw new BuildFailedException($"Windows smoke build failed: {report.summary.result}");
            }
            Debug.Log($"MikuAvatar: Windows smoke player ready at {output}");
        }

        [MenuItem("Mikudayo/Export Android Unity Library")]
        public static void ExportAndroidLibrary()
        {
            RebuildScene();
            ConfigureAndroidPlayer();
            EditorUserBuildSettings.exportAsGoogleAndroidProject = true;
            var output = Path.GetFullPath(Path.Combine(Application.dataPath, "../../../android/unityExport"));
            Directory.CreateDirectory(output);
            var report = BuildPipeline.BuildPlayer(
                new[] { ScenePath }, output, BuildTarget.Android, BuildOptions.Development);
            if (report.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
            {
                throw new BuildFailedException($"Android library export failed: {report.summary.result}");
            }
            Debug.Log($"MikuAvatar: Android Gradle export ready at {output}");
        }

        private static RuntimeAnimatorController EnsureAnimatorController()
        {
            var controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(AnimatorPath);
            if (controller != null) return controller;

            var clip = new AnimationClip { name = "MikuIdlePlaceholder" };
            AssetDatabase.CreateAsset(clip, IdleClipPath);
            controller = AnimatorController.CreateAnimatorControllerAtPath(AnimatorPath);
            controller.AddParameter("BaseParam", AnimatorControllerParameterType.Int);
            var state = controller.layers[0].stateMachine.AddState("Idle");
            state.motion = clip;
            controller.layers[0].stateMachine.defaultState = state;
            return controller;
        }

        private static void CreateCamera(GameObject avatar)
        {
            var cameraObject = new GameObject("Main Camera");
            cameraObject.tag = "MainCamera";
            var cameraComponent = cameraObject.AddComponent<Camera>();
            cameraComponent.fieldOfView = 36f;
            cameraComponent.nearClipPlane = 0.03f;
            cameraComponent.farClipPlane = 100f;
            cameraComponent.clearFlags = CameraClearFlags.SolidColor;
            cameraComponent.backgroundColor = new Color(0.018f, 0.035f, 0.055f, 1f);
            var framer = cameraObject.AddComponent<MikuCameraFramer>();
            framer.Target = avatar;
        }

        private static void CreateBackground()
        {
            var texture = AssetDatabase.LoadAssetAtPath<Texture2D>(BackgroundTexturePath);
            if (texture == null)
            {
                throw new FileNotFoundException($"Background image was not imported: {BackgroundTexturePath}");
            }

            var material = AssetDatabase.LoadAssetAtPath<Material>(BackgroundMaterialPath);
            if (material == null)
            {
                var shader = Shader.Find("Universal Render Pipeline/Unlit");
                if (shader == null) throw new MissingReferenceException("URP Unlit shader was not found");
                material = new Material(shader) { name = "MikuRoomBackground" };
                AssetDatabase.CreateAsset(material, BackgroundMaterialPath);
            }

            material.SetTexture("_BaseMap", texture);
            material.SetColor("_BaseColor", Color.white);
            EditorUtility.SetDirty(material);

            var background = GameObject.CreatePrimitive(PrimitiveType.Quad);
            background.name = "Miku Room Background";
            background.transform.position = new Vector3(0f, 1.05f, -1.15f);
            // The source is 16:9. This oversized quad keeps the image's aspect
            // ratio and lets a portrait camera crop the sides without stretching.
            background.transform.localScale = new Vector3(6.4f, 3.6f, 1f);
            var renderer = background.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            var collider = background.GetComponent<MeshCollider>();
            if (collider != null) Object.DestroyImmediate(collider);
        }

        private static void CreateLighting()
        {
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.16f, 0.22f, 0.25f);
            RenderSettings.ambientEquatorColor = new Color(0.06f, 0.09f, 0.11f);
            RenderSettings.ambientGroundColor = new Color(0.018f, 0.025f, 0.032f);

            var key = new GameObject("Key Light");
            var light = key.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(0.72f, 1f, 0.98f);
            light.intensity = 0.72f;
            key.transform.rotation = Quaternion.Euler(35f, 155f, 0f);

            var fill = new GameObject("Fill Light");
            var fillLight = fill.AddComponent<Light>();
            fillLight.type = LightType.Directional;
            fillLight.color = new Color(0.95f, 0.55f, 1f);
            fillLight.intensity = 0.18f;
            fill.transform.rotation = Quaternion.Euler(20f, -35f, 0f);
        }

        private static void CreateStatusOverlay()
        {
            var canvasObject = new GameObject("Smoke Test UI", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            var canvas = canvasObject.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvasObject.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1080, 1920);

            var textObject = new GameObject("Status", typeof(RectTransform), typeof(CanvasRenderer), typeof(Text));
            textObject.transform.SetParent(canvasObject.transform, false);
            var rect = textObject.GetComponent<RectTransform>();
            rect.anchorMin = new Vector2(0.05f, 0.89f);
            rect.anchorMax = new Vector2(0.95f, 0.98f);
            rect.offsetMin = rect.offsetMax = Vector2.zero;
            var text = textObject.GetComponent<Text>();
            text.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            text.fontSize = 34;
            text.alignment = TextAnchor.MiddleCenter;
            text.color = new Color(0.32f, 1f, 0.88f);
            text.text = "ChatDollKit 0.8.16 • VRM 1.0 smoke test\nEmotion + blink + mouth cues auto-demo";
        }

        private static void ConfigureAndroidPlayer()
        {
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.shaichi.mikudayo.avatar.smoketest");
            PlayerSettings.productName = "Miku Avatar Smoke Test";
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel25;
            PlayerSettings.Android.applicationEntry = AndroidApplicationEntry.Activity;
            PlayerSettings.Android.targetArchitectures =
                AndroidArchitecture.ARMv7 | AndroidArchitecture.ARM64;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
        }

        [MenuItem("Mikudayo/Configure URP")]
        public static void ConfigureUrp()
        {
            EnsureDirectory(UrpDirectory);
            var renderer = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(UrpRendererPath);
            if (renderer == null)
            {
                renderer = ScriptableObject.CreateInstance<UniversalRendererData>();
                AssetDatabase.CreateAsset(renderer, UrpRendererPath);
            }

            var pipeline = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(UrpPipelinePath);
            if (pipeline == null)
            {
                pipeline = UniversalRenderPipelineAsset.Create(renderer);
                pipeline.name = "MikuUniversalPipeline";
                pipeline.msaaSampleCount = 2;
                pipeline.renderScale = 1f;
                AssetDatabase.CreateAsset(pipeline, UrpPipelinePath);
            }

            GraphicsSettings.defaultRenderPipeline = pipeline;
            QualitySettings.renderPipeline = pipeline;
            EditorUtility.SetDirty(pipeline);
            AssetDatabase.SaveAssets();
            Debug.Log($"MikuAvatar: URP configured at {UrpPipelinePath}");
        }

        private static void ConfigureVrmImporterForUrp()
        {
            AssetDatabase.ImportAsset(ModelPath, ImportAssetOptions.ForceSynchronousImport);
            var importer = AssetImporter.GetAtPath(ModelPath);
            if (importer == null)
            {
                throw new InvalidDataException($"VRM importer was not found for {ModelPath}");
            }

            // UniVRM's editor assemblies are intentionally not auto-referenced,
            // so configure its serialized enum without coupling this setup
            // assembly to package-internal editor types. Enum value 2 is URP.
            var serializedImporter = new SerializedObject(importer);
            var renderPipeline = serializedImporter.FindProperty("RenderPipeline");
            if (renderPipeline == null)
            {
                throw new InvalidDataException("UniVRM RenderPipeline setting was not found");
            }

            if (renderPipeline.intValue != 2)
            {
                renderPipeline.intValue = 2;
                serializedImporter.ApplyModifiedPropertiesWithoutUndo();
                importer.SaveAndReimport();
            }
        }

        private static void EnsureDirectory(string assetPath)
        {
            if (AssetDatabase.IsValidFolder(assetPath)) return;
            var parent = Path.GetDirectoryName(assetPath)?.Replace('\\', '/');
            var name = Path.GetFileName(assetPath);
            if (!string.IsNullOrEmpty(parent)) EnsureDirectory(parent);
            AssetDatabase.CreateFolder(parent, name);
        }
    }
}
#endif
