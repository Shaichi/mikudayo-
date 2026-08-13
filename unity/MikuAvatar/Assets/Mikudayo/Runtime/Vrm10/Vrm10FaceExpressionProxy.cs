using System.Collections.Generic;
using ChatdollKit.Model;
using UniVRM10;
using UnityEngine;

namespace Mikudayo.Avatar.Vrm10
{
    /// <summary>ChatDollKit face adapter for a VRM 1.0 avatar.</summary>
    public sealed class Vrm10FaceExpressionProxy : MonoBehaviour, IFaceExpressionProxy
    {
        [SerializeField, Min(0.01f)] private float transitionSeconds = 0.18f;

        private readonly Dictionary<string, float> currentWeights = new Dictionary<string, float>();
        private Vrm10ExpressionCatalog catalog;
        private string activeExpression = "neutral";
        private float activeWeight = 1f;
        private bool smooth = true;

        public void Setup(GameObject avatarObject)
        {
            var instance = avatarObject != null
                ? avatarObject.GetComponentInChildren<Vrm10Instance>(true)
                : null;
            catalog = new Vrm10ExpressionCatalog(instance);
            CacheEmotionExpressions();
            ApplyInstant("neutral");
            Debug.Log($"MikuAvatar: VRM expressions=[{string.Join(", ", catalog.Names)}]");
        }

        public void SetExpression(string name = "Neutral", float value = 1.0f)
        {
            activeExpression = ResolveEmotion(name);
            activeWeight = Mathf.Clamp01(value);
            smooth = false;
            ApplyInstant(activeExpression, activeWeight);
        }

        public void SetExpressionSmoothly(string name = "Neutral", float value = 1.0f)
        {
            activeExpression = ResolveEmotion(name);
            activeWeight = Mathf.Clamp01(value);
            smooth = true;
        }

        private void Update()
        {
            if (catalog == null || !catalog.IsReady) return;
            if (currentWeights.Count == 0) CacheEmotionExpressions();

            var active = Vrm10ExpressionCatalog.Normalize(activeExpression);
            var step = transitionSeconds <= 0f ? 1f : Time.unscaledDeltaTime / transitionSeconds;

            foreach (var name in new List<string>(currentWeights.Keys))
            {
                var target = Vrm10ExpressionCatalog.Normalize(name) == active ? activeWeight : 0f;
                var next = smooth ? Mathf.MoveTowards(currentWeights[name], target, step) : target;
                currentWeights[name] = next;
                catalog.SetWeight(name, next);
            }

            smooth = true;
        }

        private void ApplyInstant(string name, float value = 1f)
        {
            if (catalog == null || !catalog.IsReady) return;
            var active = Vrm10ExpressionCatalog.Normalize(name);
            foreach (var key in new List<string>(currentWeights.Keys))
            {
                var weight = Vrm10ExpressionCatalog.Normalize(key) == active ? Mathf.Clamp01(value) : 0f;
                currentWeights[key] = weight;
                catalog.SetWeight(key, weight);
            }
        }

        private void CacheEmotionExpressions()
        {
            if (catalog == null) return;
            currentWeights.Clear();
            // Keep one stable entry per emotion. A VRM clip can be reachable by
            // both its preset and clip name; caching every alias would write two
            // different weights to the same ExpressionKey during one frame.
            var supportedEmotions = new[]
            {
                "neutral", "happy", "sad", "relaxed", "surprised", "angry"
            };

            foreach (var emotion in supportedEmotions)
            {
                if (catalog.TryResolve(emotion, out _)) currentWeights[emotion] = 0f;
            }
        }

        private string ResolveEmotion(string value)
        {
            switch (Vrm10ExpressionCatalog.Normalize(value))
            {
                case "excited": return FirstAvailable("surprised", "happy", "fun");
                case "thinking": return FirstAvailable("relaxed", "neutral");
                case "embarrassed": return FirstAvailable("surprised", "happy", "relaxed");
                case "sorrow": return FirstAvailable("sad", "sorrow");
                case "joy":
                case "fun": return FirstAvailable("happy", "joy", "fun");
                default: return FirstAvailable(string.IsNullOrWhiteSpace(value) ? "neutral" : value, "neutral");
            }
        }

        private string FirstAvailable(params string[] candidates)
        {
            foreach (var candidate in candidates)
            {
                if (catalog != null && catalog.TryResolve(candidate, out _)) return candidate;
            }

            // An unavailable neutral intentionally means all cached emotion
            // weights are driven to zero.
            return "neutral";
        }
    }
}
