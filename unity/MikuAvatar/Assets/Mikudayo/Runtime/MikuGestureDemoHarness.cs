using UnityEngine;

namespace Mikudayo.Avatar
{
    /// <summary>Editor-only GUI để thử từng gesture trong smoke build.</summary>
    public sealed class MikuGestureDemoHarness : MonoBehaviour
    {
        public MikuAvatarBridge Bridge;

        private static readonly string[] Gestures =
            { "wave", "clap", "nod", "sad", "thinking", "surprise" };

        private void OnGUI()
        {
            for (var i = 0; i < Gestures.Length; i++)
            {
                if (GUI.Button(new Rect(20, 80 + i * 60, 300, 50), $"Play {Gestures[i]}"))
                {
                    Bridge.PlayGesture("{\"gesture\":\"" + Gestures[i] + "\"}");
                }
            }
            if (GUI.Button(new Rect(20, 80 + Gestures.Length * 60, 300, 50), "Stop"))
            {
                Bridge.StopGesture("");
            }
        }
    }
}
