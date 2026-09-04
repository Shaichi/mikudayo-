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
        [SerializeField, Range(0.1f, 1f)] private float fadeSeconds = 0.3f;

        /// <summary>
        /// Raised after the gesture ends (naturally or via Stop), once the
        /// fade-out has finished and the animation has been detached.
        /// </summary>
        public Action OnFinished;

        private Vrm10Instance _instance;
        private readonly Dictionary<string, LoadedClip> _cache = new();
        private LoadedClip _current;
        private WeightedVrmaProxy _proxy;
        private Coroutine _routine;
        private bool _playing;
        private bool _attachPending;
        private bool _controlRigChecked;
        private bool _finishedDelivered;
        private Animator _modelAnimator;
        private UnityEngine.Avatar _originalAvatar;
        private readonly Dictionary<Transform, RestBonePose> _restPose = new();

        private readonly struct RestBonePose
        {
            public readonly Vector3 LocalPosition;
            public readonly Quaternion LocalRotation;
            public readonly Vector3 LocalScale;

            public RestBonePose(Transform bone)
            {
                LocalPosition = bone.localPosition;
                LocalRotation = bone.localRotation;
                LocalScale = bone.localScale;
            }
        }

        private sealed class LoadedClip
        {
            public Vrm10AnimationInstance Clip;
            public Animation Animation;
            public AnimationClip LegacyClip;
        }

        /// <summary>
        /// Bọc clip VRMA để weight áp dụng đồng thời cho xương, hips và
        /// expression. Khi weight về 0, control rig trở về T-pose chuẩn trước
        /// khi được detach khỏi runtime.
        /// </summary>
        private sealed class WeightedVrmaProxy : IVrm10Animation
        {
            private static readonly IReadOnlyDictionary<ExpressionKey, Func<float>> Empty =
                new Dictionary<ExpressionKey, Func<float>>();

            private readonly Vrm10AnimationInstance _clip;
            private readonly INormalizedPoseProvider _sourcePose;
            private readonly ITPoseProvider _sourceTPose;
            private readonly Vector3 _neutralHips;
            private readonly BlendedPoseProvider _blendedPose;
            public float Weight;

            public WeightedVrmaProxy(Vrm10AnimationInstance clip)
            {
                _clip = clip;
                _sourcePose = clip.ControlRig.Item1;
                _sourceTPose = clip.ControlRig.Item2;
                _neutralHips = _sourcePose.GetRawHipsPosition();
                _blendedPose = new BlendedPoseProvider(this);
            }

            public (INormalizedPoseProvider, ITPoseProvider) ControlRig =>
                (_blendedPose, _sourceTPose);
            public IReadOnlyDictionary<ExpressionKey, Func<float>> ExpressionMap =>
                Weight > 0.01f ? _clip.ExpressionMap : Empty;
            public LookAtInput? LookAt => null;
            public void ShowBoxMan(bool enable) { if (_clip.BoxMan != null) _clip.BoxMan.enabled = false; }
            public void Dispose() { } // Controller sở hữu instance clip; không destroy ở đây.

            private sealed class BlendedPoseProvider : INormalizedPoseProvider
            {
                private readonly WeightedVrmaProxy _owner;

                public BlendedPoseProvider(WeightedVrmaProxy owner) => _owner = owner;

                public Vector3 GetRawHipsPosition()
                {
                    var animatedHips = _owner._sourcePose.GetRawHipsPosition();
                    return Vector3.Lerp(_owner._neutralHips, animatedHips, _owner.Weight);
                }

                public Quaternion GetNormalizedLocalRotation(
                    HumanBodyBones bone, HumanBodyBones parentBone)
                {
                    var animated = _owner._sourcePose
                        .GetNormalizedLocalRotation(bone, parentBone);
                    // The VRMA control rig is normalized: identity is its
                    // neutral T-pose. Slerp here makes fade affect bones too,
                    // not only expressions.
                    return Quaternion.SlerpUnclamped(
                        Quaternion.identity, animated, _owner.Weight);
                }
            }
        }

        private void Awake()
        {
            if (AvatarRoot != null) _instance = AvatarRoot.GetComponent<Vrm10Instance>();
            if (_instance == null) _instance = GetComponent<Vrm10Instance>();
            if (_instance == null)
            {
                Debug.LogWarning("MikuAvatar: gesture controller has no Vrm10Instance");
                enabled = false;
                return;
            }

            _modelAnimator = _instance.GetComponent<Animator>();
            _originalAvatar = _modelAnimator != null ? _modelAnimator.avatar : null;
            foreach (var bone in _instance.Humanoid.BoneMap)
            {
                if (bone.Item1 != null) _restPose[bone.Item1] = new RestBonePose(bone.Item1);
            }
        }

        public void Play(string name)
        {
            if (_instance == null || string.IsNullOrEmpty(name)) return;
            Detach();
            if (_routine != null) StopCoroutine(_routine);
            _finishedDelivered = false;
            _routine = StartCoroutine(PlayRoutine(name));
        }

        public void Stop()
        {
            if (_routine != null)
            {
                StopCoroutine(_routine);
                _routine = null;
            }
            if (!_playing && _proxy == null) return;
            _routine = StartCoroutine(StopRoutine());
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
                    QueueFinished();
                    yield break;
                }

                _cache[name] = clip;
            }

            if (!Attach(clip))
            {
                _routine = null;
                yield break;
            }

            var fadeUp = 0f;
            while (fadeUp < 1f && _playing && clip.Animation != null && clip.Animation.isPlaying)
            {
                fadeUp = Mathf.MoveTowards(fadeUp, 1f, Time.deltaTime / fadeSeconds);
                _proxy.Weight = fadeUp;
                yield return null;
            }
            while (_playing && clip.Animation != null && clip.Animation.isPlaying)
            {
                yield return null;
            }
            // A later Play() may have taken over this routine mid-fade; the
            // new routine owns the fade-out/detach/callback in that case.
            if (!_playing || _current != clip)
            {
                _routine = null;
                yield break;
            }
            yield return FadeOutRoutine();
            Detach();
            _routine = null;
            QueueFinished();
        }

        private IEnumerator FadeOutRoutine()
        {
            if (_proxy == null) yield break;
            var fadeDown = _proxy.Weight;
            while (fadeDown > 0f)
            {
                fadeDown = Mathf.MoveTowards(fadeDown, 0f, Time.deltaTime / (fadeSeconds * 0.5f));
                _proxy.Weight = fadeDown;
                yield return null;
            }
        }

        private IEnumerator StopRoutine()
        {
            yield return FadeOutRoutine();
            Detach();
            QueueFinished();
            _routine = null;
        }

        private void QueueFinished()
        {
            if (_finishedDelivered) return;
            _finishedDelivered = true;
            OnFinished?.Invoke();
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
                if (result.LegacyClip != null) result.LegacyClip.wrapMode = WrapMode.Once;
                result.Animation.wrapMode = WrapMode.Once;
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
            _proxy = new WeightedVrmaProxy(clip.Clip);
            _instance.Runtime.VrmAnimation = _proxy;
            _playing = true;
            _attachPending = false;
            _finishedDelivered = false;
            return true;
        }

        private void Detach()
        {
            _attachPending = false;
            _playing = false;
            var wasAttached = _current != null;
            if (_current == null)
            {
                _proxy = null;
                return;
            }
            // WeightedVrmaProxy is a plain C# class (IVrm10Animation only
            // derives from IDisposable), so compare by reference, not via a
            // UnityEngine.Object cast.
            if (_instance != null &&
                ReferenceEquals(_instance.Runtime.VrmAnimation, _proxy))
            {
                _instance.Runtime.VrmAnimation = null;
            }
            if (_current.Animation != null) _current.Animation.Stop();
            _current = null;
            _proxy = null;
            ClearControlRig();
            // Safety net: Detach can also run outside a finishing routine —
            // a new Play() detaches the previous gesture before starting its
            // own, and LateUpdate detaches defensively when the clip, its
            // Animation component, or the control rig disappears. In those
            // paths the coroutine callback never fires, so deliver OnFinished
            // here instead.
            if (wasAttached && !_finishedDelivered)
            {
                _finishedDelivered = true;
                OnFinished?.Invoke();
            }
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
            var backingField = GetControlRigBackingField();
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

        private void ClearControlRig()
        {
            if (_instance == null) return;

            var runtime = _instance.Runtime;
            var rig = runtime.ControlRig;

            // Vrm10RuntimeControlRig temporarily swaps the model Animator's
            // avatar. Restore the imported avatar after destroying the rig so
            // MikuRelaxedPose and MikuIdlePool stay humanoid for later clips.
            if (rig != null)
            {
                // UniVRM 0.127.2's Dispose() passes a Transform to
                // Object.Destroy(), which Unity rejects at runtime. Remove
                // the generated avatar and its GameObject explicitly.
                var generatedAvatar = rig.ControlRigAnimator != null
                    ? rig.ControlRigAnimator.avatar
                    : null;
                Transform generatedRoot = null;
                if (rig.Bones.TryGetValue(HumanBodyBones.Hips, out var hips))
                {
                    generatedRoot = hips.ControlBone != null
                        ? hips.ControlBone.parent
                        : null;
                }

                if (generatedAvatar != null) Destroy(generatedAvatar);
                if (generatedRoot != null) Destroy(generatedRoot.gameObject);
            }

            if (_modelAnimator != null) _modelAnimator.avatar = _originalAvatar;

            var backingField = GetControlRigBackingField();
            if (backingField != null) backingField.SetValue(runtime, null);
            _controlRigChecked = false;
            RestoreImportedPose();
        }

        private void RestoreImportedPose()
        {
            foreach (var pair in _restPose)
            {
                if (pair.Key == null) continue;
                pair.Key.localPosition = pair.Value.LocalPosition;
                pair.Key.localRotation = pair.Value.LocalRotation;
                pair.Key.localScale = pair.Value.LocalScale;
            }
        }

        private static FieldInfo GetControlRigBackingField()
        {
            return typeof(Vrm10Runtime).GetField("<ControlRig>k__BackingField",
                BindingFlags.NonPublic | BindingFlags.Instance);
        }
    }
}
