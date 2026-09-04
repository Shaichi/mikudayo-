using System;
using System.Collections;
using System.IO;
using UnityEngine;

namespace Mikudayo.Avatar
{
    /// <summary>
    /// Opt-in deterministic desktop smoke capture. It is inert unless the
    /// player is launched with -mikudayoSmokeCapture.
    /// </summary>
    public sealed class MikuAvatarSmokeCapture : MonoBehaviour
    {
        public MikuAvatarBridge Bridge;

        private static readonly string[] Emotions =
        {
            "neutral", "happy", "excited", "thinking", "embarrassed", "sad"
        };

        private bool captureEnabled;
        private bool gestureCaptureEnabled;
        private string outputDirectory;

        private void Awake()
        {
            var args = Environment.GetCommandLineArgs();
            gestureCaptureEnabled = Array.IndexOf(args, "-mikudayoGestureCapture") >= 0;
            captureEnabled = gestureCaptureEnabled || Array.IndexOf(args, "-mikudayoSmokeCapture") >= 0;
            if (!captureEnabled) return;

            outputDirectory = GetArgumentValue(args, "-mikudayoSmokeOutput");
            if (string.IsNullOrWhiteSpace(outputDirectory))
            {
                outputDirectory = Path.Combine(Application.persistentDataPath, "MikuSmokeCaptures");
            }

            Directory.CreateDirectory(outputDirectory);
            var autoDemo = GetComponent<MikuAvatarAutoDemo>();
            if (autoDemo != null) autoDemo.enabled = false;
        }

        private IEnumerator Start()
        {
            if (!captureEnabled) yield break;
            if (Bridge == null) Bridge = GetComponent<MikuAvatarBridge>();

            if (gestureCaptureEnabled)
            {
                yield return RunGestureCapture();
                yield break;
            }

            yield return new WaitForSecondsRealtime(1.5f);
            for (var i = 0; i < Emotions.Length; i++)
            {
                var emotion = Emotions[i];
                Bridge.SetEmotion(emotion);
                Bridge.PlayMouthCues(CreateDemoSpeech(i));
                yield return new WaitForSecondsRealtime(0.5f);

                var path = Path.Combine(outputDirectory, $"{i + 1:00}_{emotion}.png");
                ScreenCapture.CaptureScreenshot(path);
                Debug.Log($"MikuAvatar: smoke capture emotion={emotion} path={path}");
                yield return new WaitForSecondsRealtime(0.5f);
            }

            Bridge.StopSpeech(string.Empty);
            yield return new WaitForSecondsRealtime(0.25f);
            var stoppedPath = Path.Combine(outputDirectory, "07_stopped.png");
            ScreenCapture.CaptureScreenshot(stoppedPath);
            Debug.Log($"MikuAvatar: smoke capture stopped path={stoppedPath}");
            yield return new WaitForSecondsRealtime(0.5f);

            Debug.Log("MikuAvatar: SMOKE_CAPTURE_COMPLETE");
            Application.Quit(0);
        }

        private IEnumerator RunGestureCapture()
        {
            yield return new WaitForSecondsRealtime(1.5f);
            Capture("00_idle");

            var gestures = new[] { "wave", "clap", "sad", "thinking", "surprise", "nod" };
            for (var i = 0; i < gestures.Length; i++)
            {
                var gesture = gestures[i];
                Bridge.PlayGesture($"{{\"gesture\":\"{gesture}\"}}");

                yield return new WaitForSecondsRealtime(0.8f);
                Capture($"{i + 1:00}_{gesture}_mid");

                // VRMA clips are about 3.93 seconds long. This frame verifies
                // that the avatar returns to its idle pose after completion.
                yield return new WaitForSecondsRealtime(5.3f);
                Capture($"{i + 1:00}_{gesture}_after");
                Bridge.StopGesture(string.Empty);
                yield return new WaitForSecondsRealtime(0.35f);
            }

            Capture("99_final");
            Debug.Log("MikuAvatar: GESTURE_CAPTURE_COMPLETE");
            Application.Quit(0);
        }

        private void Capture(string name)
        {
            var path = Path.Combine(outputDirectory, $"{name}.png");
            ScreenCapture.CaptureScreenshot(path);
            Debug.Log($"MikuAvatar: gesture capture={name} path={path}");
        }

        private static string GetArgumentValue(string[] args, string key)
        {
            for (var i = 0; i < args.Length - 1; i++)
            {
                if (string.Equals(args[i], key, StringComparison.OrdinalIgnoreCase)) return args[i + 1];
            }
            return null;
        }

        private static string CreateDemoSpeech(int sequence)
        {
            return JsonUtility.ToJson(new DemoSpeech
            {
                seq = sequence,
                duration_ms = 900,
                cues = new[]
                {
                    new DemoCue { t_ms = 0, mouth = 0f },
                    new DemoCue { t_ms = 150, mouth = 0.8f },
                    new DemoCue { t_ms = 500, mouth = 0.8f },
                    new DemoCue { t_ms = 900, mouth = 0f }
                }
            });
        }

        [Serializable]
        private sealed class DemoCue
        {
            public int t_ms;
            public float mouth;
        }

        [Serializable]
        private sealed class DemoSpeech
        {
            public int seq;
            public int duration_ms;
            public DemoCue[] cues;
        }
    }
}
