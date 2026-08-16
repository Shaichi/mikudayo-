using UnityEngine;

namespace Mikudayo.Avatar
{
    /// <summary>
    /// Cross-fades between a small pool of upper-body idle variants at random
    /// intervals and adds a slow head glance. Runs at execution order 9000 so
    /// MikuRelaxedPose (10000) still layers breathing/head sway on top of the
    /// rest targets this class writes each Update. While a VRMA gesture plays
    /// the pool is frozen to stop the rest pose from shifting underneath.
    /// </summary>
    [DefaultExecutionOrder(9000)]
    public sealed class MikuIdlePool : MonoBehaviour
    {
        public Animator Animator;

        [SerializeField, Range(5f, 30f)] private float minHoldSeconds = 8f;
        [SerializeField, Range(10f, 40f)] private float maxHoldSeconds = 20f;
        [SerializeField, Range(0.5f, 4f)] private float blendSeconds = 2f;
        [SerializeField, Range(0f, 25f)] private float headGlanceDegrees = 8f;

        // (left shoulder, left elbow, right shoulder, right elbow) in degrees.
        // Shoulder offset composes with MikuRelaxedPose's upperArmDrop on the
        // same axis; elbow bends are negative because the mirrored rest pose
        // folds forward on -Z.
        private static readonly (float lShoulder, float lElbow, float rShoulder, float rElbow)[] Variants =
        {
            (0f, 0f, 0f, 0f),       // buông tự nhiên
            (4f, -30f, 4f, -30f),   // hai khuỷu gập nhẹ
            (0f, 0f, 8f, -55f),     // tay phải gập trước eo
            (8f, -55f, 0f, 0f),     // tay trái gập trước eo
        };

        private Transform leftUpperArm;
        private Transform rightUpperArm;
        private Transform leftLowerArm;
        private Transform rightLowerArm;
        private Transform head;

        private Quaternion leftUpperArmRest;
        private Quaternion rightUpperArmRest;
        private Quaternion leftLowerArmRest;
        private Quaternion rightLowerArmRest;
        private Quaternion headRest;

        private int _current;
        private int _target;
        private float _blend = 1f;
        private float _holdUntil;
        private bool _frozen;

        private void Awake()
        {
            if (Animator == null) Animator = GetComponent<Animator>();
            if (Animator == null || !Animator.isHuman)
            {
                Debug.LogWarning("MikuAvatar: idle pool needs a humanoid Animator");
                enabled = false;
                return;
            }

            leftUpperArm = Animator.GetBoneTransform(HumanBodyBones.LeftUpperArm);
            rightUpperArm = Animator.GetBoneTransform(HumanBodyBones.RightUpperArm);
            leftLowerArm = Animator.GetBoneTransform(HumanBodyBones.LeftLowerArm);
            rightLowerArm = Animator.GetBoneTransform(HumanBodyBones.RightLowerArm);
            head = Animator.GetBoneTransform(HumanBodyBones.Head);
            if (leftUpperArm == null || rightUpperArm == null ||
                leftLowerArm == null || rightLowerArm == null)
            {
                Debug.LogWarning("MikuAvatar: idle pool arm bones are missing");
                enabled = false;
                return;
            }

            leftUpperArmRest = leftUpperArm.localRotation;
            rightUpperArmRest = rightUpperArm.localRotation;
            leftLowerArmRest = leftLowerArm.localRotation;
            rightLowerArmRest = rightLowerArm.localRotation;
            if (head != null) headRest = head.localRotation;
            _holdUntil = Time.time + Random.Range(minHoldSeconds, maxHoldSeconds);
        }

        /// Giữ nguyên thế tay hiện tại trong lúc VRMA gesture đang phát.
        public void Freeze() => _frozen = true;

        /// Nối lại idle pool từ thế hiện tại.
        public void Release()
        {
            _frozen = false;
            _blend = 1f;
            _holdUntil = Time.time + Random.Range(minHoldSeconds, maxHoldSeconds);
        }

        private void Update()
        {
            if (_frozen) return;
            var t = Time.time;

            if (t >= _holdUntil && _blend >= 1f)
            {
                var next = _current;
                while (next == _current) next = Random.Range(0, Variants.Length);
                _target = next;
                _blend = 0f;
                _holdUntil = t + Random.Range(minHoldSeconds, maxHoldSeconds);
            }

            if (_blend < 1f)
            {
                _blend = Mathf.MoveTowards(_blend, 1f, Time.deltaTime / blendSeconds);
            }

            var a = Variants[_current];
            var b = Variants[_target];
            var s = Mathf.SmoothStep(0f, 1f, _blend);
            Apply(
                Mathf.Lerp(a.lShoulder, b.lShoulder, s),
                Mathf.Lerp(a.lElbow, b.lElbow, s),
                Mathf.Lerp(a.rShoulder, b.rShoulder, s),
                Mathf.Lerp(a.rElbow, b.rElbow, s));
            if (_blend >= 1f) _current = _target;

            if (head != null)
            {
                // Chỉ nửa dương của sin: liếc đi một nhịp rồi quay lại.
                var glance = Mathf.Max(0f, Mathf.Sin(t * 0.17f)) * headGlanceDegrees;
                head.localRotation = headRest * Quaternion.Euler(0f, glance, 0f);
            }
        }

        private void Apply(float lShoulder, float lElbow, float rShoulder, float rElbow)
        {
            leftUpperArm.localRotation = leftUpperArmRest * Quaternion.Euler(0f, 0f, lShoulder);
            rightUpperArm.localRotation = rightUpperArmRest * Quaternion.Euler(0f, 0f, rShoulder);
            leftLowerArm.localRotation = leftLowerArmRest * Quaternion.Euler(0f, 0f, lElbow);
            rightLowerArm.localRotation = rightLowerArmRest * Quaternion.Euler(0f, 0f, rElbow);
        }
    }
}
