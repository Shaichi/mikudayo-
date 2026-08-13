using System.Collections;
using Mikudayo.Avatar.Vrm10;
using UnityEngine;

namespace Mikudayo.Avatar
{
    /// <summary>Standalone smoke test used before any Flutter integration.</summary>
    public sealed class MikuAvatarAutoDemo : MonoBehaviour
    {
        public MikuAvatarBridge Bridge;
        [SerializeField] private bool runOnStart = true;
        [SerializeField, Min(0.5f)] private float emotionSeconds = 2.5f;

        private static readonly string[] Emotions =
        {
            "neutral", "happy", "excited", "thinking", "embarrassed", "sad"
        };

        private IEnumerator Start()
        {
            if (!runOnStart) yield break;
            if (Bridge == null) Bridge = GetComponent<MikuAvatarBridge>();
            yield return new WaitForSeconds(1.5f);

            var index = 0;
            while (true)
            {
                Bridge.SetEmotion(Emotions[index % Emotions.Length]);
                Bridge.PlayMouthCues(CreateDemoSpeech(index));
                index++;
                yield return new WaitForSeconds(emotionSeconds);
            }
        }

        private static string CreateDemoSpeech(int sequence)
        {
            var payload = new DemoSpeech
            {
                seq = sequence,
                duration_ms = 1900,
                cues = new[]
                {
                    new DemoCue { t_ms = 0, mouth = 0f },
                    new DemoCue { t_ms = 120, mouth = 0.75f },
                    new DemoCue { t_ms = 300, mouth = 0.12f },
                    new DemoCue { t_ms = 480, mouth = 0.9f },
                    new DemoCue { t_ms = 720, mouth = 0.2f },
                    new DemoCue { t_ms = 940, mouth = 0.82f },
                    new DemoCue { t_ms = 1210, mouth = 0.08f },
                    new DemoCue { t_ms = 1420, mouth = 0.65f },
                    new DemoCue { t_ms = 1750, mouth = 0f },
                    new DemoCue { t_ms = 1900, mouth = 0f }
                }
            };
            return JsonUtility.ToJson(payload);
        }

        [System.Serializable]
        private sealed class DemoCue
        {
            public int t_ms;
            public float mouth;
        }

        [System.Serializable]
        private sealed class DemoSpeech
        {
            public int seq;
            public int duration_ms;
            public DemoCue[] cues;
        }
    }
}
