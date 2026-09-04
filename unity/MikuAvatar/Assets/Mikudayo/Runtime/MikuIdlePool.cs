using UnityEngine;

namespace Mikudayo.Avatar
{
    /// <summary>
    /// Adds a slow head glance. Arm, forearm and hand bones are deliberately
    /// not touched; they remain at the imported VRM pose.
    /// </summary>
    [DefaultExecutionOrder(10500)]
    public sealed class MikuIdlePool : MonoBehaviour
    {
        public Animator Animator;

        [SerializeField, Range(0f, 25f)] private float headGlanceDegrees = 8f;
        private Transform head;

        private void Awake()
        {
            if (Animator == null) Animator = GetComponent<Animator>();
            if (Animator == null || !Animator.isHuman)
            {
                Debug.LogWarning("MikuAvatar: idle head glance needs a humanoid Animator");
                enabled = false;
                return;
            }

            head = Animator.GetBoneTransform(HumanBodyBones.Head);
        }

        /// Kept for API compatibility; no arm pose is generated here.
        public void Freeze() => _frozen = true;

        /// Re-enable the head glance after a gesture.
        public void Release()
        {
            _frozen = false;
        }

        private bool _frozen;

        private void LateUpdate()
        {
            if (_frozen) return;
            var t = Time.time;

            if (head != null)
            {
                // Chỉ nửa dương của sin: liếc đi một nhịp rồi quay lại.
                var glance = Mathf.Max(0f, Mathf.Sin(t * 0.17f)) * headGlanceDegrees;
                head.localRotation *= Quaternion.Euler(0f, glance, 0f);
            }
        }
    }
}
