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

        public ModelController ModelController;
        public Vrm10MouthCueDriver MouthDriver;

        private void Awake()
        {
            if (ModelController == null) ModelController = GetComponent<ModelController>();
            if (MouthDriver == null) MouthDriver = GetComponent<Vrm10MouthCueDriver>();
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
    }
}
