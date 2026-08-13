using System;
using System.Collections.Generic;
using UniVRM10;
using UnityEngine;

namespace Mikudayo.Avatar.Vrm10
{
    /// <summary>
    /// Resolves VRM 1.0 preset/custom expression names without assuming that a
    /// particular model exposes every preset. All weights use the VRM 1.0
    /// normalized 0..1 range.
    /// </summary>
    internal sealed class Vrm10ExpressionCatalog
    {
        private readonly Vrm10Instance instance;
        private readonly Dictionary<string, ExpressionKey> keys =
            new Dictionary<string, ExpressionKey>(StringComparer.OrdinalIgnoreCase);

        public Vrm10ExpressionCatalog(Vrm10Instance instance)
        {
            this.instance = instance;
            Refresh();
        }

        public bool IsReady => instance != null && instance.Vrm != null && instance.Runtime != null;

        public IEnumerable<string> Names => keys.Keys;

        public void Refresh()
        {
            keys.Clear();
            if (instance == null || instance.Vrm == null) return;

            foreach (var expression in instance.Vrm.Expression.Clips)
            {
                if (expression.Clip == null) continue;
                var key = new ExpressionKey(expression.Preset, expression.Clip.name);
                Add(expression.Clip.name, key);
                Add(expression.Preset.ToString(), key);
            }
        }

        public bool TryResolve(string name, out ExpressionKey key)
        {
            if (keys.Count == 0) Refresh();
            if (keys.TryGetValue(Normalize(name), out key)) return true;

            // A few VRM authoring tools retain older naming conventions.
            foreach (var candidate in AliasCandidates(name))
            {
                if (keys.TryGetValue(Normalize(candidate), out key)) return true;
            }

            key = default;
            return false;
        }

        public bool SetWeight(string name, float weight)
        {
            if (!IsReady || !TryResolve(name, out var key)) return false;
            instance.Runtime.Expression.SetWeight(key, Mathf.Clamp01(weight));
            return true;
        }

        private void Add(string name, ExpressionKey key)
        {
            var normalized = Normalize(name);
            if (!string.IsNullOrEmpty(normalized)) keys[normalized] = key;
        }

        private static IEnumerable<string> AliasCandidates(string name)
        {
            switch (Normalize(name))
            {
                case "happy":
                case "joy":
                case "fun":
                    return new[] { "happy", "joy", "fun" };
                case "sad":
                case "sorrow":
                    return new[] { "sad", "sorrow" };
                case "thinking":
                case "relaxed":
                    return new[] { "relaxed", "thinking" };
                case "excited":
                    return new[] { "surprised", "happy", "fun" };
                case "embarrassed":
                    return new[] { "surprised", "happy", "relaxed" };
                case "a":
                case "aa":
                    return new[] { "aa", "a" };
                default:
                    return new[] { name };
            }
        }

        internal static string Normalize(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return string.Empty;
            return value.Trim().ToLowerInvariant()
                .Replace("_", string.Empty)
                .Replace("-", string.Empty)
                .Replace(" ", string.Empty);
        }
    }
}
