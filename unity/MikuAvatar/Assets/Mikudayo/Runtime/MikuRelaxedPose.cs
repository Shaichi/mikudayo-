using UnityEngine;

namespace Mikudayo.Avatar
{
    /// <summary>
    /// Keeps the avatar in a relaxed conversational pose and adds a restrained
    /// procedural idle. All offsets are rebuilt from the imported VRM rest pose
    /// every frame, so the motion cannot drift or accumulate over time.
    /// </summary>
    [DefaultExecutionOrder(10000)]
    public sealed class MikuRelaxedPose : MonoBehaviour
    {
        public Animator Animator;

        [SerializeField, Range(0f, 90f)] private float upperArmDrop = 68f;
        [SerializeField, Range(0f, 45f)] private float elbowBend = 0f;

        [Header("Procedural idle")]
        [SerializeField, Range(0f, 3f)] private float breathingDegrees = 0.8f;
        [SerializeField, Range(0f, 5f)] private float headTurnDegrees = 2.2f;
        [SerializeField, Range(0f, 3f)] private float headTiltDegrees = 1.1f;
        [SerializeField, Range(0f, 3f)] private float bodySwayDegrees = 0.7f;
        [SerializeField, Range(0f, 0.02f)] private float bodyBobMeters = 0.0025f;

        private Transform leftUpperArm;
        private Transform rightUpperArm;
        private Transform leftLowerArm;
        private Transform rightLowerArm;
        private Transform spine;
        private Transform chest;
        private Transform neck;
        private Transform head;
        private Transform hips;

        private Quaternion leftUpperArmRest;
        private Quaternion rightUpperArmRest;
        private Quaternion leftLowerArmRest;
        private Quaternion rightLowerArmRest;
        private Quaternion spineRest;
        private Quaternion chestRest;
        private Quaternion neckRest;
        private Quaternion headRest;
        private Vector3 hipsRestPosition;

        private void Awake()
        {
            if (Animator == null) Animator = GetComponent<Animator>();
            if (Animator == null || !Animator.isHuman)
            {
                Debug.LogWarning("MikuAvatar: relaxed pose needs a humanoid Animator");
                enabled = false;
                return;
            }

            leftUpperArm = Animator.GetBoneTransform(HumanBodyBones.LeftUpperArm);
            rightUpperArm = Animator.GetBoneTransform(HumanBodyBones.RightUpperArm);
            leftLowerArm = Animator.GetBoneTransform(HumanBodyBones.LeftLowerArm);
            rightLowerArm = Animator.GetBoneTransform(HumanBodyBones.RightLowerArm);
            spine = Animator.GetBoneTransform(HumanBodyBones.Spine);
            chest = Animator.GetBoneTransform(HumanBodyBones.UpperChest) ??
                    Animator.GetBoneTransform(HumanBodyBones.Chest);
            neck = Animator.GetBoneTransform(HumanBodyBones.Neck);
            head = Animator.GetBoneTransform(HumanBodyBones.Head);
            hips = Animator.GetBoneTransform(HumanBodyBones.Hips);

            if (leftUpperArm == null || rightUpperArm == null ||
                leftLowerArm == null || rightLowerArm == null)
            {
                Debug.LogWarning("MikuAvatar: relaxed pose arm bones are missing");
                enabled = false;
                return;
            }

            leftUpperArmRest = leftUpperArm.localRotation;
            rightUpperArmRest = rightUpperArm.localRotation;
            leftLowerArmRest = leftLowerArm.localRotation;
            rightLowerArmRest = rightLowerArm.localRotation;
            if (spine != null) spineRest = spine.localRotation;
            if (chest != null) chestRest = chest.localRotation;
            if (neck != null) neckRest = neck.localRotation;
            if (head != null) headRest = head.localRotation;
            if (hips != null) hipsRestPosition = hips.localPosition;

            Debug.Log("MikuAvatar: relaxed procedural idle enabled");
        }

        private void LateUpdate()
        {
            var time = Time.time;
            var breath = Mathf.Sin(time * 1.55f);
            var slowSway = Mathf.Sin(time * 0.52f);
            var secondarySway = Mathf.Sin(time * 0.31f + 1.7f);
            var headTurn = Mathf.Sin(time * 0.37f + 0.8f) * headTurnDegrees;
            var headTilt = Mathf.Sin(time * 0.29f + 2.1f) * headTiltDegrees;

            // Small independent frequencies keep the idle organic without
            // making the avatar look as if it is floating or dancing.
            if (hips != null)
            {
                hips.localPosition = hipsRestPosition + Vector3.up * (breath * bodyBobMeters);
            }

            if (spine != null)
            {
                spine.localRotation = spineRest * Quaternion.Euler(
                    breath * breathingDegrees * 0.35f,
                    secondarySway * bodySwayDegrees * 0.35f,
                    slowSway * bodySwayDegrees);
            }

            if (chest != null)
            {
                chest.localRotation = chestRest * Quaternion.Euler(
                    breath * breathingDegrees,
                    -secondarySway * bodySwayDegrees * 0.25f,
                    slowSway * bodySwayDegrees * 0.45f);
            }

            if (neck != null)
            {
                neck.localRotation = neckRest * Quaternion.Euler(
                    breath * 0.18f,
                    headTurn * 0.35f,
                    headTilt * 0.35f);
            }

            if (head != null)
            {
                head.localRotation = headRest * Quaternion.Euler(
                    breath * 0.35f,
                    headTurn * 0.65f,
                    headTilt * 0.65f);
            }

            // The mirrored signs turn the imported near-T-pose into a relaxed
            // A-pose while a tiny breathing offset keeps the arms from freezing.
            var armBreath = breath * 0.55f;
            leftUpperArm.localRotation = leftUpperArmRest * Quaternion.Euler(
                armBreath, 0f, upperArmDrop + slowSway * 0.35f);
            rightUpperArm.localRotation = rightUpperArmRest * Quaternion.Euler(
                armBreath, 0f, -upperArmDrop - slowSway * 0.35f);
            leftLowerArm.localRotation = leftLowerArmRest * Quaternion.Euler(0f, 0f, elbowBend);
            rightLowerArm.localRotation = rightLowerArmRest * Quaternion.Euler(0f, 0f, -elbowBend);
        }
    }
}
