using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using UniGLTF;
using UniVRM10;
using UnityEngine;

namespace Mikudayo.Avatar
{
    /// <summary>
    /// Plays one-shot VRM Animation (.vrma) clips on top of the idle pose.
    /// UniVRM 0.127.2 has no editor importer for the .vrma extension, so
    /// clips are stored as TextAssets (*.vrma.bytes under Resources/) and
    /// loaded at runtime. Gesture rotations are retargeted through the
    /// Vrm10Instance's runtime control rig, so MikuRelaxedPose keeps writing
    /// the rest pose underneath while the clip is playing.
    /// </summary>
    /// <remarks>
    /// Runs in the default execution slot: its LateUpdate only monitors clip
    /// completion. MikuRelaxedPose (10000) keeps writing the rest pose while
    /// Vrm10Instance (11000) copies the animation onto the model afterwards.
    /// </remarks>
    public sealed class MikuGestureController : MonoBehaviour
    {
        public GameObject AvatarRoot;
        public string GestureResourcesFolder = "vrma_gestures";

        private Vrm10Instance _instance;
        private readonly Dictionary<string, LoadedClip> _cache = new();
        private LoadedClip _current;
        private Coroutine _routine;
        private bool _playing;
        private bool _attachPending;
        private bool _controlRigChecked;

        private sealed class LoadedClip
        {
            public Vrm10AnimationInstance Clip;
            public Animation Animation;
            public AnimationClip LegacyClip;
        }

        private void Awake()
        {
            if (AvatarRoot != null) _instance = AvatarRoot.GetComponent<Vrm10Instance>();
            if (_instance == null) _instance = GetComponent<Vrm10Instance>();
            if (_instance == null)
            {
                Debug.LogWarning("MikuAvatar: gesture controller has no Vrm10Instance");
                enabled = false;
            }
        }

        public void Play(string name)
        {
            if (_instance == null || string.IsNullOrEmpty(name)) return;
            Detach();
            if (_routine != null) StopCoroutine(_routine);
            _routine = StartCoroutine(PlayRoutine(name));
        }

        public void Stop()
        {
            if (_routine != null)
            {
                StopCoroutine(_routine);
                _routine = null;
            }
            Detach();
        }

        private IEnumerator PlayRoutine(string name)
        {
            _attachPending = true;
            if (!_cache.TryGetValue(name, out var clip))
            {
                // One frame of delay keeps the synchronous GLB parse out of
                // the caller's frame; ImmediateCaller never leaves this thread.
                yield return null;
                try
                {
                    clip = LoadClip(name);
                }
                catch (Exception exc)
                {
                    Debug.LogWarning($"MikuAvatar: gesture '{name}' failed to load: {exc.Message}");
                    clip = null;
                }

                if (clip == null || clip.Clip == null)
                {
                    _attachPending = false;
                    _routine = null;
                    yield break;
                }

                _cache[name] = clip;
            }

            if (!Attach(clip))
            {
                _routine = null;
                yield break;
            }

            while (_playing)
            {
                yield return null;
            }
            _routine = null;
        }

        private LoadedClip LoadClip(string name)
        {
            var asset = Resources.Load<TextAsset>($"{GestureResourcesFolder}/{name}.vrma");
            if (asset == null)
            {
                Debug.LogWarning($"MikuAvatar: gesture asset not found: {GestureResourcesFolder}/{name}.vrma");
                return null;
            }

            using var data = new GlbLowLevelParser(name, asset.bytes).Parse();
            using var loader = new VrmAnimationImporter(data);
            // ImmediateCaller resolves everything synchronously on this
            // thread, so the task is completed by the time GetResult returns.
            var gltfInstance = loader.LoadAsync(new ImmediateCaller()).GetAwaiter().GetResult();
            if (gltfInstance == null) return null;

            var result = new LoadedClip
            {
                Clip = gltfInstance.GetComponent<Vrm10AnimationInstance>(),
                Animation = gltfInstance.GetComponent<Animation>(),
            };
            if (result.Animation != null)
            {
                // The importer assigns Unity 2022+ AnimationClips, which the
                // legacy Animation component cannot sample; mark them legacy.
                result.LegacyClip = result.Animation.clip;
                if (result.LegacyClip != null) result.LegacyClip.legacy = true;
            }
            if (result.Clip != null && result.Clip.BoxMan != null) result.Clip.BoxMan.enabled = false;
            return result;
        }

        private bool Attach(LoadedClip clip)
        {
            if (EnsureControlRig() == null)
            {
                _attachPending = false;
                return false;
            }

            _current = clip;
            // The clip's ControlRig is the retarget SOURCE and is already an
            // InitRotationPoseProvider created by Vrm10AnimationInstance.
            // Vrm10Runtime.Process retargets it into the model's control rig
            // (the sink). Look-at and face stay on the existing
            // blink/mouth/emotion path.
            clip.Clip.LookAt = null;
            if (clip.Animation != null && clip.LegacyClip != null)
            {
                clip.Animation.Play();
            }
            _instance.Runtime.VrmAnimation = clip.Clip;
            _playing = true;
            _attachPending = false;
            return true;
        }

        private void Detach()
        {
            _attachPending = false;
            _playing = false;
            if (_current == null) return;
            if (_instance != null &&
                (UnityEngine.Object)_instance.Runtime.VrmAnimation == _current.Clip)
            {
                _instance.Runtime.VrmAnimation = null;
            }
            if (_current.Animation != null) _current.Animation.Stop();
            _current = null;
        }

        private void LateUpdate()
        {
            if (!_playing || _attachPending) return;
            if (_current == null || _current.Clip == null || _instance == null)
            {
                Detach();
                return;
            }

            if (_instance.Runtime.ControlRig == null)
            {
                Detach();
                return;
            }

            if (_current.Animation != null && !_current.Animation.isPlaying)
            {
                Detach();
            }
        }

        private Vrm10RuntimeControlRig EnsureControlRig()
        {
            var rig = _instance.Runtime.ControlRig;
            if (rig != null || _controlRigChecked) return rig;
            _controlRigChecked = true;

            // In 0.127.2 Vrm10Instance.m_useControlRig is a private field that
            // is NOT serialized, and the scripted importer always constructs
            // the runtime without a control rig (VrmScriptedImporterImpl does
            // not pass useControlRig to Vrm10Importer). VRMA retargeting needs
            // one, so build it once with the same call Vrm10Runtime would use.
            var runtime = _instance.Runtime;
            var backingField = typeof(Vrm10Runtime).GetField("<ControlRig>k__BackingField",
                BindingFlags.NonPublic | BindingFlags.Instance);
            if (backingField == null)
            {
                Debug.LogWarning("MikuAvatar: Vrm10Runtime.ControlRig backing field was not found; VRMA gestures unavailable");
                return null;
            }

            var controlRig = new Vrm10RuntimeControlRig(_instance.Humanoid, _instance.transform);
            backingField.SetValue(runtime, controlRig);
            Debug.Log("MikuAvatar: built VRM control rig for VRMA gesture retargeting");
            return controlRig;
        }
    }
}
