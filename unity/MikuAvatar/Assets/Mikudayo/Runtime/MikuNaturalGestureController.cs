using System;
using System.Collections;
using UnityEngine;

namespace Mikudayo.Avatar
{
    /// <summary>
    /// Applies restrained head and chest gesture offsets. Arm and hand bones
    /// are intentionally left untouched so the VRM keeps its imported pose.
    /// </summary>
    [DefaultExecutionOrder(12000)]
    public sealed class MikuNaturalGestureController : MonoBehaviour
    {
        public GameObject AvatarRoot;

        [SerializeField, Range(1.5f, 6f)] private float gestureSeconds = 3.4f;
        [SerializeField, Range(0.1f, 1f)] private float fadeSeconds = 0.28f;

        public Action OnFinished;

        private Animator _animator;
        private Transform _chest;
        private Transform _head;

        private Coroutine _routine;
        private string _gesture;
        private float _elapsed;
        private float _weight;
        private bool _active;
        private bool _stopping;

        private void Awake()
        {
            var target = AvatarRoot != null ? AvatarRoot : gameObject;
            _animator = target.GetComponent<Animator>() ?? target.GetComponentInChildren<Animator>();
            if (_animator == null) _animator = FindObjectOfType<Animator>();
            if (_animator == null || !_animator.isHuman)
            {
                Debug.LogWarning("MikuAvatar: natural gesture controller needs a humanoid Animator");
                enabled = false;
                return;
            }

            _chest = GetBone(HumanBodyBones.UpperChest) ?? GetBone(HumanBodyBones.Chest);
            _head = GetBone(HumanBodyBones.Head);

            Debug.Log("MikuAvatar: natural head/chest gestures enabled; arms untouched");
        }

        public void Play(string name)
        {
            if (!enabled) return;
            if (_routine != null) StopCoroutine(_routine);

            _gesture = (name ?? string.Empty).Trim().ToLowerInvariant();
            _elapsed = 0f;
            _weight = 0f;
            _active = true;
            _stopping = false;
            _routine = StartCoroutine(GestureRoutine());
        }

        public void Stop()
        {
            if (_active) _stopping = true;
        }

        private IEnumerator GestureRoutine()
        {
            while (_active)
            {
                if (_stopping)
                {
                    _weight = Mathf.MoveTowards(
                        _weight, 0f, Time.deltaTime / Mathf.Max(0.05f, fadeSeconds));
                    if (_weight <= 0f) _active = false;
                }
                else
                {
                    _elapsed += Time.deltaTime;
                    var fadeIn = Mathf.Clamp01(_elapsed / fadeSeconds);
                    var fadeOut = Mathf.Clamp01(
                        (gestureSeconds - _elapsed) / fadeSeconds);
                    _weight = Mathf.SmoothStep(0f, 1f, Mathf.Min(fadeIn, fadeOut));
                    if (_elapsed >= gestureSeconds) _stopping = true;
                }

                yield return null;
            }

            _routine = null;
            _weight = 0f;
            OnFinished?.Invoke();
        }

        private void LateUpdate()
        {
            if (!_active || _weight <= 0f) return;

            var progress = Mathf.Clamp01(_elapsed / gestureSeconds);
            ApplyBodyPose(progress, _weight);
        }

        private void ApplyBodyPose(float progress, float weight)
        {
            var headEuler = Vector3.zero;
            var chestEuler = Vector3.zero;
            switch (_gesture)
            {
                case "sad":
                    headEuler = new Vector3(10f, -4f, 3f);
                    chestEuler = new Vector3(4f, 0f, 0f);
                    break;
                case "thinking":
                    headEuler = new Vector3(5f, -12f, -3f);
                    chestEuler = new Vector3(2f, 0f, -2f);
                    break;
                case "surprise":
                    headEuler = new Vector3(-5f, 0f, 0f);
                    chestEuler = new Vector3(-2f, 0f, 0f);
                    break;
                case "nod":
                    headEuler = new Vector3(Mathf.Sin(progress * Mathf.PI * 2f) * 8f, 0f, 0f);
                    break;
            }

            ApplyLocalOffset(_head, headEuler, weight);
            ApplyLocalOffset(_chest, chestEuler, weight);
        }

        private static void ApplyLocalOffset(Transform bone, Vector3 euler, float weight)
        {
            if (bone == null || euler.sqrMagnitude < 0.001f) return;
            var offset = Quaternion.SlerpUnclamped(
                Quaternion.identity, Quaternion.Euler(euler), weight);
            bone.localRotation *= offset;
        }

        private Transform GetBone(HumanBodyBones bone) => _animator.GetBoneTransform(bone);
    }
}
