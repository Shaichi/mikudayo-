using System;
using System.Collections.Generic;
using ChatdollKit.Model;
using Mikudayo.Avatar.Vrm10;
using UnityEngine;

namespace Mikudayo.Avatar
{
    /// <summary>
    /// Stable string-only API for Flutter/Android UnitySendMessage calls.
    /// Keep the GameObject name `MikuAvatarBridge` when exporting as a library.
    /// </summary>
    public sealed class MikuAvatarBridge : MonoBehaviour
    {
        [Serializable]
        private sealed class EmotionPayload
        {
            public string emotion;
        }

        [Serializable]
        private sealed class GesturePayload
        {
            public string gesture;
        }

        public ModelController ModelController;
        public Vrm10MouthCueDriver MouthDriver;
        public MikuGestureController GestureController;
        public MikuNaturalGestureController NaturalGestureController;
        public MikuIdlePool IdlePool;

        public void PlayGesture(string message)
        {
            var gesture = ParseGesture(message);
            if (NaturalGestureController == null)
            {
                Debug.LogWarning("MikuAvatar: natural gesture controller is not ready");
                return;
            }
            NaturalGestureController.Play(gesture);
            // Play() may detach a previous gesture and invoke OnFinished.
            // Freeze after Play so that callback cannot immediately unfreeze
            // the new gesture's idle state.
            IdlePool?.Freeze();
            Debug.Log($"MikuAvatar: gesture={gesture}");
        }

        public void StopGesture(string _ = "")
        {
            if (NaturalGestureController != null) NaturalGestureController.Stop();
            else GestureController?.Stop();
            IdlePool?.Release();
        }

        private void Awake()
        {
            if (ModelController == null) ModelController = GetComponent<ModelController>();
            if (MouthDriver == null) MouthDriver = GetComponent<Vrm10MouthCueDriver>();
            if (NaturalGestureController == null)
            {
                var avatarRoot = GestureController != null && GestureController.AvatarRoot != null
                    ? GestureController.AvatarRoot
                    : gameObject;
                NaturalGestureController = avatarRoot.GetComponent<MikuNaturalGestureController>();
                if (NaturalGestureController == null)
                {
                    NaturalGestureController = avatarRoot.AddComponent<MikuNaturalGestureController>();
                }
            }
            if (NaturalGestureController != null && IdlePool != null)
            {
                NaturalGestureController.OnFinished = () => IdlePool.Release();
            }
            else if (GestureController != null && IdlePool != null)
            {
                GestureController.OnFinished = () => IdlePool.Release();
            }
            gameObject.name = "MikuAvatarBridge";
        }

        private void Start()
        {
            if (MouthDriver != null && ModelController != null && ModelController.AvatarModel != null)
            {
                MouthDriver.ConfigureViseme(ModelController.AvatarModel);
            }
            Debug.Log("MikuAvatar: READY ChatDollKit=0.8.16 VRM=1.0");
            SendToFlutter.Send("{\"type\":\"ready\",\"version\":\"1.0\"}");
        }

        public void Ping(string message)
        {
            var escaped = string.IsNullOrEmpty(message) ? "" : message.Replace("\\", "\\\\").Replace("\"", "\\\"");
            SendToFlutter.Send($"{{\"type\":\"pong\",\"echo\":\"{escaped}\"}}");
        }

        public void SetEmotion(string message)
        {
            var emotion = ParseEmotion(message);
            if (ModelController == null || ModelController.FaceController == null)
            {
                Debug.LogWarning("MikuAvatar: FaceController is not ready");
                return;
            }

            ModelController.FaceController.SetFace(new List<FaceExpression>
            {
                new FaceExpression(emotion, float.MaxValue)
            });
            Debug.Log($"MikuAvatar: emotion={emotion}");
        }

        public void PlayMouthCues(string json)
        {
            MouthDriver?.PlayJson(json);
        }

        public void StopSpeech(string _ = "")
        {
            MouthDriver?.Stop();
        }

        private static string ParseEmotion(string message)
        {
            if (string.IsNullOrWhiteSpace(message)) return "neutral";
            var trimmed = message.Trim();
            if (!trimmed.StartsWith("{")) return trimmed;
            try
            {
                return JsonUtility.FromJson<EmotionPayload>(trimmed)?.emotion ?? "neutral";
            }
            catch
            {
                return "neutral";
            }
        }

        private static string ParseGesture(string message)
        {
            if (string.IsNullOrWhiteSpace(message)) return "";
            var trimmed = message.Trim();
            if (!trimmed.StartsWith("{")) return trimmed;
            try
            {
                return JsonUtility.FromJson<GesturePayload>(trimmed)?.gesture ?? "";
            }
            catch
            {
                return "";
            }
        }
    }
}
