using System;
using ChatdollKit.Model;
using UniVRM10;
using UnityEngine;

namespace Mikudayo.Avatar.Vrm10
{
    /// <summary>
    /// Drives the VRM 1.0 `aa` expression from the existing backend MouthCue
    /// timeline. This keeps Flutter free of frame timers and avoids sending
    /// audio as base64 across the Unity bridge.
    /// </summary>
    public sealed class Vrm10MouthCueDriver : MonoBehaviour, ILipSyncHelper
    {
        [Serializable]
        private sealed class Cue
        {
            public int t_ms;
            public float mouth;
        }

        [Serializable]
        private sealed class SpeechPayload
        {
            public int seq;
            public int duration_ms;
            public Cue[] cues;
        }

        public GameObject AvatarRoot;
        [SerializeField, Range(0f, 2f)] private float gain = 1f;
        [SerializeField, Range(0f, 0.25f)] private float smoothingSeconds = 0.04f;

        private Vrm10ExpressionCatalog catalog;
        private SpeechPayload speech;
        private float startedAt;
        private float current;
        private float velocity;
        private bool playing;

        private void Start()
        {
            if (AvatarRoot != null) ConfigureViseme(AvatarRoot);
        }

        public void ConfigureViseme(GameObject avatarObject)
        {
            AvatarRoot = avatarObject;
            var instance = avatarObject != null
                ? avatarObject.GetComponentInChildren<Vrm10Instance>(true)
                : null;
            catalog = new Vrm10ExpressionCatalog(instance);
            ResetViseme();
        }

        public void PlayJson(string json)
        {
            try
            {
                var parsed = JsonUtility.FromJson<SpeechPayload>(json);
                if (parsed == null || parsed.cues == null || parsed.cues.Length == 0)
                {
                    Stop();
                    return;
                }

                speech = parsed;
                startedAt = Time.realtimeSinceStartup;
                playing = true;
            }
            catch (Exception ex)
            {
                Debug.LogError($"MikuAvatar: invalid mouth cue payload: {ex.Message}");
                Stop();
            }
        }

        public void Stop()
        {
            playing = false;
            speech = null;
            current = 0f;
            velocity = 0f;
            catalog?.SetWeight("aa", 0f);
        }

        public void ResetViseme() => Stop();

        private void Update()
        {
            if (!playing || speech == null || catalog == null || !catalog.IsReady) return;

            var elapsedMs = (Time.realtimeSinceStartup - startedAt) * 1000f;
            var target = Sample(elapsedMs) * gain;
            current = smoothingSeconds <= 0f
                ? target
                : Mathf.SmoothDamp(current, target, ref velocity, smoothingSeconds);
            catalog.SetWeight("aa", Mathf.Clamp01(current));

            var duration = speech.duration_ms > 0
                ? speech.duration_ms
                : speech.cues[speech.cues.Length - 1].t_ms;
            if (elapsedMs >= duration + 100f) Stop();
        }

        private float Sample(float elapsedMs)
        {
            var cues = speech.cues;
            if (elapsedMs <= cues[0].t_ms) return cues[0].mouth;

            for (var i = 1; i < cues.Length; i++)
            {
                if (elapsedMs > cues[i].t_ms) continue;
                var previous = cues[i - 1];
                var next = cues[i];
                var span = Mathf.Max(1f, next.t_ms - previous.t_ms);
                return Mathf.Lerp(previous.mouth, next.mouth, (elapsedMs - previous.t_ms) / span);
            }

            return 0f;
        }
    }
}
