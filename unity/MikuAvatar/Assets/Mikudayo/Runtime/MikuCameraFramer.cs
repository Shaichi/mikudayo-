using UnityEngine;

namespace Mikudayo.Avatar
{
    /// <summary>Frames the conversational upper body from humanoid bones.</summary>
    public sealed class MikuCameraFramer : MonoBehaviour
    {
        public GameObject Target;
        [SerializeField, Range(0.7f, 2f)] private float distanceMultiplier = 1.18f;

        private void Start()
        {
            if (Target == null) return;
            var cameraComponent = GetComponent<Camera>();
            var animator = Target.GetComponentInChildren<Animator>(true);
            if (cameraComponent == null || animator == null || !animator.isHuman) return;

            var head = animator.GetBoneTransform(HumanBodyBones.Head);
            var hips = animator.GetBoneTransform(HumanBodyBones.Hips);
            var leftShoulder = animator.GetBoneTransform(HumanBodyBones.LeftShoulder);
            var rightShoulder = animator.GetBoneTransform(HumanBodyBones.RightShoulder);
            if (head == null || hips == null) return;

            var verticalFov = cameraComponent != null ? cameraComponent.fieldOfView : 40f;
            var aspect = cameraComponent != null ? cameraComponent.aspect : 1f;
            var verticalTangent = Mathf.Tan(verticalFov * 0.5f * Mathf.Deg2Rad);
            var horizontalTangent = verticalTangent * Mathf.Max(0.1f, aspect);

            var torsoHeight = Vector3.Distance(hips.position, head.position);
            var shoulderWidth = leftShoulder != null && rightShoulder != null
                ? Vector3.Distance(leftShoulder.position, rightShoulder.position)
                : torsoHeight * 0.65f;
            var verticalDistance = Mathf.Max(0.42f, torsoHeight * 0.72f) / verticalTangent;
            // Shoulder transforms sit close to the spine on this avatar, so
            // torso height is the stable proxy for conversational frame width.
            var horizontalDistance = Mathf.Max(0.48f, torsoHeight * 1.05f) / horizontalTangent;
            var distance = Mathf.Max(verticalDistance, horizontalDistance);
            var focus = Vector3.Lerp(hips.position, head.position, 0.62f);
            transform.position = focus + Vector3.forward * distance * distanceMultiplier;
            transform.LookAt(focus);

            Debug.Log(
                $"MikuAvatar: camera torsoHeight={torsoHeight:F3} shoulderWidth={shoulderWidth:F3} " +
                $"aspect={aspect:F3} focus={focus} position={transform.position}");
        }
    }
}
