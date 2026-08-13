using System;
using System.Threading;
using ChatdollKit.Model;
using Cysharp.Threading.Tasks;
using UniVRM10;
using UnityEngine;

namespace Mikudayo.Avatar.Vrm10
{
    /// <summary>Natural blink implementation using the VRM 1.0 blink expression.</summary>
    public sealed class Vrm10Blink : MonoBehaviour, IBlink
    {
        [SerializeField] private Vector2 intervalSeconds = new Vector2(2.8f, 5.2f);
        [SerializeField, Min(0.01f)] private float closeSeconds = 0.06f;
        [SerializeField, Min(0.01f)] private float openSeconds = 0.10f;

        private Vrm10ExpressionCatalog catalog;
        private CancellationTokenSource lifetime;
        private bool enabledBlink;
        private bool loopStarted;

        public void Setup(GameObject avatarObject)
        {
            lifetime?.Cancel();
            lifetime?.Dispose();
            lifetime = new CancellationTokenSource();
            var instance = avatarObject != null
                ? avatarObject.GetComponentInChildren<Vrm10Instance>(true)
                : null;
            catalog = new Vrm10ExpressionCatalog(instance);
        }

        public async UniTask StartBlinkAsync()
        {
            enabledBlink = true;
            if (loopStarted) return;
            loopStarted = true;

            try
            {
                while (lifetime != null && !lifetime.IsCancellationRequested)
                {
                    while (catalog == null || !catalog.IsReady)
                    {
                        await UniTask.Delay(16, cancellationToken: lifetime.Token);
                    }

                    var delay = UnityEngine.Random.Range(intervalSeconds.x, intervalSeconds.y);
                    await UniTask.Delay(TimeSpan.FromSeconds(delay), cancellationToken: lifetime.Token);
                    if (!enabledBlink) continue;
                    Debug.Log("MikuAvatar: blink");
                    await Animate(0f, 1f, closeSeconds, lifetime.Token);
                    await Animate(1f, 0f, openSeconds, lifetime.Token);
                }
            }
            catch (OperationCanceledException)
            {
                // Normal teardown.
            }
        }

        public void StopBlink()
        {
            enabledBlink = false;
            SetBlinkWeight(0f);
        }

        private async UniTask Animate(float from, float to, float seconds, CancellationToken token)
        {
            var started = Time.realtimeSinceStartup;
            while (true)
            {
                var t = Mathf.Clamp01((Time.realtimeSinceStartup - started) / seconds);
                SetBlinkWeight(Mathf.SmoothStep(from, to, t));
                if (t >= 1f) break;
                await UniTask.Yield(PlayerLoopTiming.Update, token);
            }
        }

        private void SetBlinkWeight(float weight)
        {
            if (catalog == null) return;
            // Prefer the combined preset. Do not also drive the eye-specific
            // clips when it exists because some avatars bind the same meshes.
            if (catalog.SetWeight("blink", weight)) return;
            catalog.SetWeight("blinkLeft", weight);
            catalog.SetWeight("blinkRight", weight);
        }

        private void OnDestroy()
        {
            lifetime?.Cancel();
            lifetime?.Dispose();
        }
    }
}
