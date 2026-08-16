# Avatar Gestures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thêm idle đa dạng (pool thế tay + head-gaze) và gesture theo sự kiện (vẫy tay, vỗ tay, buồn, thinking...) cho avatar Miku trên Android/Unity, điều khiển từ Flutter qua bridge string-only, với nguồn gesture do Gemini chọn (fallback map theo emotion).

**Architecture:** Gesture dùng file `.vrma` (VRM Animation) — vì UniVRM 0.127.2 không có editor importer cho extension `.vrma`, clip được lưu dạng `*.vrma.bytes` (TextAsset) trong `Resources/vrma_gestures/` và nạp runtime bằng `GlbLowLevelParser` (`.bytes` là extension Unity import thành TextAsset nên tránh được rủi ro StreamingAssets bị nén trong APK Android). Phát qua `Vrm10Instance.Runtime.VrmAnimation` với fade in/out để không đá bay lớp idle. Idle đa dạng là procedural component mới (`MikuIdlePool`) chạy TRƯỚC `MikuRelaxedPose` theo execution order. Flutter quyết định khi nào phát gesture (chào, chờ TTS, theo Gemini/emotion); Unity chỉ nhận lệnh là phát.

**Tech Stack:** Unity 6000.3.3f1 + UniVRM 0.127.2 (đã pin) + ChatdollKit; Flutter/Riverpod; FastAPI + Pydantic + google-genai.

**Spec:** `docs/superpowers/specs/2026-08-16-avatar-gestures-design.md`

## Global Constraints

- Chỉ Android/Unity cho gesture; desktop/web `VrmAvatar` không đụng.
- Không khôi phục TTS/model giọng local; không upload audio mic; không gọi `speech_to_text.locales()`; không resize avatar khi bàn phím mở.
- Không thao tác git phá hủy; commit phải xem `git diff` chọn file; không commit `.env`, installer, file tạm, cache.
- Sau mỗi thay đổi Unity phải chạy prepare + export bằng Unity batchmode trước khi build Flutter (lệnh ở `HANDOFF.md` mục 7, Unity tại `D:\Unity\Hub\Editor\6000.3.3f1`).
- Không tuyên bố UI/avatar đạt yêu cầu cho tới khi cài APK lên máy thật (ADB `8a855606`) và nhìn trực tiếp.
- Python backend: `C:\Users\pc\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe`, fallback `backend\.venv`. Test backend: `cd backend && python -m unittest discover -s tests -v`. Flutter: `flutter analyze && flutter test`.
- Gesture phải nằm gọn trong khung dọc (mặt → đùi): không di chuyển chân, tay cử động trước ngực/eo.
- Enum gesture thống nhất toàn hệ thống: `none, wave, nod, clap, sad, thinking, surprise`.
- Bridge Unity giữ API chỉ-string qua GameObject tên `MikuAvatarBridge`.

---

### Task 1: Asset VRMA + Unity spike xác minh nạp/phát VRMA runtime

**Files:**
- Create (asset, thủ công): `unity/MikuAvatar/Assets/Mikudayo/Resources/vrma_gestures/*.vrma.bytes`
- Create: `unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuGestureController.cs` (bản tối thiểu: load + play, chưa fade)
- Modify: `unity/MikuAvatar/Assets/Mikudayo/Editor/MikuProjectSetup.cs` (bật ControlRig + gắn component)
- Modify (temp, sẽ sửa ở Task 2): `unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuAvatarBridge.cs`

**Interfaces:**
- Consumes: file VRMA đặt sẵn trong `Assets/Mikudayo/Resources/vrma_gestures/` với tên: `wave.vrma.bytes`, `clap.vrma.bytes`, `nod.vrma.bytes`, `sad.vrma.bytes`, `thinking.vrma.bytes`, `surprise.vrma.bytes` (đuôi `.bytes` để Unity import thành TextAsset; chỉ cần tối thiểu `wave.vrma.bytes` + `thinking.vrma.bytes` cho spike; các file khác có thể bổ sung sau).
- Produces: class `Mikudayo.Avatar.MikuGestureController` với `public GameObject AvatarRoot`, `public void Play(string name)`, `public void Stop()`; các Task 2/3 sẽ thêm fade + event `OnFinished`.

- [ ] **Step 1: Lấy file VRMA (thủ công, cần người dùng đăng nhập BOOTH nếu cần)**

Nguồn (kiểm tra license từng file; chỉ dùng file cho phép dùng trong app; ghi credit vào ghi chú commit):
- VRoid official 7-file miễn phí trên BOOTH — tìm "VRMA" + "VRoid" trên booth.pm (credit: ピクシブ株式会社 VRoidプロジェクト).
- Bộ sample có sẵn đúng động tác cần: https://github.com/tk256ailab/vrm-viewer (thư mục `VRMA/`: `Goodbye.vrma`, `Clapping.vrma`, `Thinking.vrma`, `Sad.vrma`, `LookAround.vrma`, `Relax.vrma`, `Surprised.vrma`).

Đặt vào `unity/MikuAvatar/Assets/Mikudayo/Resources/vrma_gestures/` với tên chuẩn hóa **kèm đuôi `.bytes`** (để Unity import thành TextAsset, nạp được qua `Resources.Load` — bắt buộc nằm trong thư mục tên `Resources`):
`Goodbye.vrma → wave.vrma.bytes`, `Clapping.vrma → clap.vrma.bytes`, `Thinking.vrma → thinking.vrma.bytes`, `Sad.vrma → sad.vrma.bytes`, `Surprised.vrma → surprise.vrma.bytes`. Nếu không có clip gật đầu phù hợp thì BỎ `nod.vrma.bytes` (không chế clip giả). Nếu chưa tải được gì, dừng task và báo cho người dùng.

- [ ] **Step 2: Tạo `MikuGestureController.cs` bản tối thiểu**

```csharp
using System;
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using UniGLTF;
using UniVRM10;
using UnityEngine;

namespace Mikudayo.Avatar
{
    /// <summary>
    /// Plays one-shot VRM Animation (.vrma) clips on top of the idle pose.
    /// UniVRM 0.127.2 has no editor importer for the .vrma extension, so
    /// clips are stored as TextAssets (*.vrma.bytes under Resources/) and
    /// loaded at runtime.
    /// </summary>
    public sealed class MikuGestureController : MonoBehaviour
    {
        public GameObject AvatarRoot;
        public string GestureResourcesFolder = "vrma_gestures";

        private Vrm10Instance _instance;
        private readonly Dictionary<string, Vrm10AnimationInstance> _cache = new();
        private Vrm10AnimationInstance _current;
        private Animation _currentAnimation;
        private Coroutine _routine;

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
            if (_routine != null) StopCoroutine(_routine);
            _routine = StartCoroutine(PlayRoutine(name));
        }

        public void Stop()
        {
            if (_routine != null) { StopCoroutine(_routine); _routine = null; }
            Detach();
        }

        private IEnumerator PlayRoutine(string name)
        {
            if (!_cache.TryGetValue(name, out var clip))
            {
                Vrm10AnimationInstance loaded = null;
                var finished = false;
                LoadAsync(name, c => { loaded = c; finished = true; });
                while (!finished) yield return null;
                clip = loaded;
                if (clip != null) _cache[name] = clip;
            }
            if (clip == null) { _routine = null; yield break; }

            Attach(clip);
            while (_currentAnimation != null && _currentAnimation.isPlaying)
            {
                yield return null;
            }
            Detach();
            _routine = null;
        }

        private async void LoadAsync(string name, Action<Vrm10AnimationInstance> onComplete)
        {
            Vrm10AnimationInstance clip = null;
            try
            {
                clip = await LoadClipAsync(name);
            }
            catch (Exception exc)
            {
                Debug.LogWarning($"MikuAvatar: gesture '{name}' failed to load: {exc.Message}");
            }
            onComplete(clip);
        }

        private async Task<Vrm10AnimationInstance> LoadClipAsync(string name)
        {
            var asset = Resources.Load<TextAsset>($"{GestureResourcesFolder}/{name}.vrma");
            if (asset == null)
            {
                Debug.LogWarning($"MikuAvatar: gesture asset not found: {GestureResourcesFolder}/{name}.vrma");
                return null;
            }
            using var data = new GlbLowLevelParser(name, asset.bytes).Parse();
            using var loader = new VrmAnimationImporter(data);
            var instance = await loader.LoadAsync(new ImmediateCaller());
            return instance.GetComponent<Vrm10AnimationInstance>();
        }

        private void Attach(Vrm10AnimationInstance clip)
        {
            if (clip.BoxMan != null) clip.BoxMan.enabled = false;
            clip.LookAt = null; // bỏ track nhìn; LookAt/face đi đường riêng hiện có
            _current = clip;
            _currentAnimation = clip.GetComponent<Animation>();
            if (_currentAnimation != null) _currentAnimation.Play();
            _instance.Runtime.VrmAnimation = clip;
        }

        private void Detach()
        {
            if (_instance != null && _instance.Runtime.VrmAnimation == _current)
            {
                _instance.Runtime.VrmAnimation = null;
            }
            if (_currentAnimation != null) _currentAnimation.Stop();
            _current = null;
            _currentAnimation = null;
        }
    }
}
```

Lưu ý cho người implement: nếu compile báo thiếu member của interface hoặc API khác tên, tra trong `Library/PackageCache/com.vrmc.vrm@*/Runtime/` — không đoán bừa.

- [ ] **Step 3: Sửa `MikuProjectSetup.cs`**

(a) Trong `RebuildScene()`, ngay sau khối `relaxedPose.Animator = animator;` thêm:

```csharp
            var gestureController = avatar.AddComponent<MikuGestureController>();
            gestureController.AvatarRoot = avatar;
```

(b) Bật ControlRig — VRMA retarget cần `Vrm10RuntimeControlRig`, nhưng `m_useControlRig` là field private được serialize, KHÔNG có setter public (0.127.2 chỉ set qua importer). Cách an toàn: serialize `true` vào prefab instance trong editor trước khi scene được build, vì `Vrm10Instance.Runtime` chỉ lazy-init khi chơi:

```csharp
            var vrmInstance = avatar.GetComponent<UniVRM10.Vrm10Instance>();
            if (vrmInstance != null)
            {
                var serialized = new UnityEditor.SerializedObject(vrmInstance);
                var useControlRig = serialized.FindProperty("m_useControlRig");
                if (useControlRig != null && !useControlRig.boolValue)
                {
                    useControlRig.boolValue = true;
                    serialized.ApplyModifiedPropertiesWithoutUndo();
                }
            }
```

Nếu `FindProperty("m_useControlRig")` trả null (tên field đổi), mở `Library/PackageCache/com.vrmc.vrm@*/Runtime/Components/Vrm10Instance/Vrm10Instance.cs` xem tên field `[SerializeField]` thực tế và cập nhật. KHÔNG sửa file trong PackageCache.

- [ ] **Step 4: Thêm nút test tạm vào bridge (chỉ để spike)**

Trong `MikuAvatarBridge.cs` thêm tạm (sẽ thay bằng lệnh chuẩn ở Task 2):

```csharp
        public MikuGestureController GestureController;

        public void TestGesture(string name)
        {
            GestureController?.Play(name.Trim());
        }
```

Và trong `MikuProjectSetup.RebuildScene()` gán `bridge.GestureController = gestureController;`.

- [ ] **Step 5: Build Windows smoke và kiểm tra**

```powershell
& 'D:\Unity\Hub\Editor\6000.3.3f1\Editor\Unity.exe' `
  -batchmode -nographics -buildTarget StandaloneWindows64 `
  -projectPath 'C:\Users\pc\Desktop\mikudayo\unity\MikuAvatar' `
  -executeMethod Mikudayo.Avatar.Editor.MikuProjectSetup.BuildWindowsSmokeTest `
  -quit `
  -logFile 'C:\Users\pc\Desktop\mikudayo\60-gesture-spike-build.log'
```

Chờ kiên nhẫn (build IL2CPP có thể lâu; không kết luận treo khi im lặng vài phút — kiểm tra process). Log phải có `Windows smoke player ready`. Chạy `unity\MikuAvatar\Builds\Windows\MikuAvatarSmoke.exe`, gửi lệnh qua log hoặc dùng cách nhanh nhất: thêm tạm vào `MikuAvatarAutoDemo` một dòng `Bridge.TestGesture("wave")` sau vài giây, rồi build lại — quan sát avatar vẫy tay, idle thở vẫn chạy, không crash.

- [ ] **Step 6: Commit (chọn file bằng `git diff`, không add cả thư mục)**

```bash
git add unity/MikuAvatar/Assets/Mikudayo/Resources/ \
        unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuGestureController.cs \
        unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuGestureController.cs.meta \
        unity/MikuAvatar/Assets/Mikudayo/Editor/MikuProjectSetup.cs \
        unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuAvatarBridge.cs
git commit -m "feat(unity): spike VRMA gesture loading from Resources TextAssets

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Ghi chú trong commit message: tên file `.vrma.bytes` đã dùng + nguồn/license. Commit cả `.meta` của file/thư mục mới (bắt buộc để Unity giữ GUID); dùng `git status` để nhìn hết file mới trong `Resources/`.

---

### Task 2: Fade in/out, lệnh bridge chuẩn, harness test trong editor

**Files:**
- Modify: `unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuGestureController.cs`
- Modify: `unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuAvatarBridge.cs`
- Create: `unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuGestureDemoHarness.cs`
- Modify: `unity/MikuAvatar/Assets/Mikudayo/Editor/MikuProjectSetup.cs`

**Interfaces:**
- Consumes: `MikuGestureController` từ Task 1.
- Produces: `MikuGestureController.Play(string)` / `Stop()` với fade; `public Action OnFinished` (gọi khi gesture kết thúc tự nhiên hoặc sau fade-out). `MikuAvatarBridge.PlayGesture(string json)` payload `{"gesture":"wave"}`; `MikuAvatarBridge.StopGesture(string)`.

- [ ] **Step 1: Thêm fade vào `MikuGestureController`**

`IVrm10Animation` (0.127.2) chỉ có 4 member + `IDisposable` — đọc lại `Runtime/Components/VrmAnimationInstance/IVrm10Animation.cs` trong PackageCache trước khi viết:

```csharp
        [SerializeField, Range(0.1f, 1f)] private float fadeSeconds = 0.3f;
        public Action OnFinished;

        /// <summary>
        /// Bọc clip VRMA: xương vẫn retarget từ clip, nhưng expression map
        /// chỉ lộ khi weight vượt ngưỡng để biểu cảm fade theo. Runtime
        /// retarget là all-or-nothing (không có per-bone weight ở bản này)
        /// nên fade xương thực tế là ramp weight nhanh + detach dứt khoát;
        /// độ mềm của chuyển tiếp dựa vào lớp procedural tự phục hồi.
        /// </summary>
        private sealed class WeightedVrmaProxy : IVrm10Animation
        {
            private static readonly IReadOnlyDictionary<ExpressionKey, Func<float>> Empty =
                new Dictionary<ExpressionKey, Func<float>>();

            private readonly Vrm10AnimationInstance _clip;
            public float Weight;

            public WeightedVrmaProxy(Vrm10AnimationInstance clip) => _clip = clip;

            public (INormalizedPoseProvider, ITPoseProvider) ControlRig => _clip.ControlRig;
            public IReadOnlyDictionary<ExpressionKey, Func<float>> ExpressionMap =>
                Weight > 0.01f ? _clip.ExpressionMap : Empty;
            public LookAtInput? LookAt => null;
            public void ShowBoxMan(bool enable) { if (_clip.BoxMan != null) _clip.BoxMan.enabled = false; }
            public void Dispose() { } // Controller sở hữu instance clip; không destroy ở đây.
        }
```

Trong controller thêm field `private WeightedVrmaProxy _proxy;` và sửa `PlayRoutine` thành:

```csharp
            Attach(clip);
            var fadeUp = 0f;
            while (fadeUp < 1f && _currentAnimation != null && _currentAnimation.isPlaying)
            {
                fadeUp = Mathf.MoveTowards(fadeUp, 1f, Time.deltaTime / fadeSeconds);
                _proxy.Weight = fadeUp;
                yield return null;
            }
            while (_currentAnimation != null && _currentAnimation.isPlaying)
            {
                yield return null;
            }
            yield return FadeOutRoutine();
            Detach();
            _routine = null;
            OnFinished?.Invoke();
```

và `FadeOutRoutine` + `Stop`:

```csharp
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

        public void Stop()
        {
            if (_routine != null) { StopCoroutine(_routine); _routine = null; }
            StartCoroutine(StopRoutine());
        }

        private IEnumerator StopRoutine()
        {
            yield return FadeOutRoutine();
            Detach();
            OnFinished?.Invoke();
        }
```

`Attach` tạo proxy và gán: `_proxy = new WeightedVrmaProxy(clip); _instance.Runtime.VrmAnimation = _proxy;` — thay dòng gán thẳng clip. Nếu smoke test thấy chuyển tiếp quá giật, giảm `fadeSeconds` và chọn clip có frame đầu gần tư thế trung tính; không block task vì độ mềm.

- [ ] **Step 2: Lệnh bridge chuẩn**

Thay `TestGesture` bằng:

```csharp
        [Serializable]
        private sealed class GesturePayload
        {
            public string gesture;
        }

        public void PlayGesture(string message)
        {
            var gesture = ParseGesture(message);
            if (GestureController == null)
            {
                Debug.LogWarning("MikuAvatar: GestureController is not ready");
                return;
            }
            GestureController.Play(gesture);
            Debug.Log($"MikuAvatar: gesture={gesture}");
        }

        public void StopGesture(string _ = "")
        {
            GestureController?.Stop();
        }

        private static string ParseGesture(string message)
        {
            if (string.IsNullOrWhiteSpace(message)) return "";
            var trimmed = message.Trim();
            if (!trimmed.StartsWith("{")) return trimmed;
            try
            {
                return JsonUtility.FromJson<GesturePayload>(trimmed)?.gesture ?? "";
            }
            catch
            {
                return "";
            }
        }
```

- [ ] **Step 3: Harness test trong scene (bị loại khi prepare)**

```csharp
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
```

Trong `MikuProjectSetup.RebuildScene()`: `var gestureHarness = bridgeObject.AddComponent<MikuGestureDemoHarness>(); gestureHarness.Bridge = bridge;`. Trong `PrepareEmbeddedScene()`: thêm dòng loại nó như demo/capture hiện có:

```csharp
            var gestureHarness = Object.FindFirstObjectByType<MikuGestureDemoHarness>();
            if (gestureHarness != null) Object.DestroyImmediate(gestureHarness);
```

- [ ] **Step 4: Build Windows smoke, bấm nút từng gesture có file**

Build như Task 1 Step 5 (log `61-gesture-fade-build.log`). Chạy exe: bấm từng nút — gesture phát, kết thúc tự trả về idle thở, không kẹt pose; nút Stop cắt giữa chừng. Với gesture chưa có file `.vrma`, log cảnh báo `gesture asset not found`, không crash.

- [ ] **Step 5: Commit**

```bash
git add unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuGestureController.cs \
        unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuAvatarBridge.cs \
        unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuGestureDemoHarness.cs \
        unity/MikuAvatar/Assets/Mikudayo/Editor/MikuProjectSetup.cs
git commit -m "feat(unity): gesture bridge commands with fade and demo harness

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `MikuIdlePool` — pool thế tay + head-gaze

**Files:**
- Create: `unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuIdlePool.cs`
- Modify: `unity/MikuAvatar/Assets/Mikudayo/Editor/MikuProjectSetup.cs`
- Modify: `unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuAvatarBridge.cs`

**Interfaces:**
- Consumes: `MikuGestureController.OnFinished` (Task 2).
- Produces: `Mikudayo.Avatar.MikuIdlePool` với `public Animator Animator`, `public void Freeze()`, `public void Release()`.

- [ ] **Step 1: Viết `MikuIdlePool.cs`**

```csharp
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
```

- [ ] **Step 2: Gắn vào scene + nối Freeze/Release với gesture**

Trong `MikuProjectSetup.RebuildScene()`, ngay sau `gestureController.AvatarRoot = avatar;`:

```csharp
            var idlePool = avatar.AddComponent<MikuIdlePool>();
            idlePool.Animator = animator;
```

Trong `MikuAvatarBridge.cs`: thêm field `public MikuIdlePool IdlePool;`, sửa `PlayGesture` thêm `IdlePool?.Freeze();` trước `GestureController.Play(...)`, sửa `StopGesture` thêm `IdlePool?.Release();`, và trong `Awake`/`Start` (hoặc gán từ `MikuProjectSetup`) nối kết thúc tự nhiên:

```csharp
            if (GestureController != null && IdlePool != null)
            {
                GestureController.OnFinished = () => IdlePool.Release();
            }
```

Gán `bridge.IdlePool = idlePool;` trong `MikuProjectSetup.RebuildScene()`.

- [ ] **Step 3: Build Windows smoke, kiểm tra**

Build (log `62-idle-pool-build.log`), chạy exe, để yên ~40 giây: thế tay đổi ít nhất 2 kiểu, chuyển mềm, đầu liếc rồi quay lại, thở/lắc đầu của `MikuRelaxedPose` vẫn chạy chồng. Bấm Play gesture → tay đứng yên trong lúc gesture phát → sau khi gesture hết, idle pool tiếp tục.

- [ ] **Step 4: Commit**

```bash
git add unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuIdlePool.cs \
        unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuAvatarBridge.cs \
        unity/MikuAvatar/Assets/Mikudayo/Editor/MikuProjectSetup.cs
git commit -m "feat(unity): idle pose pool with head glance, frozen during gestures

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Flutter — enum `MikuGesture`, bridge, anti-spam (TDD)

**Files:**
- Modify: `lib/data/models/conversation_turn.dart`
- Modify: `lib/avatar/avatar_controller.dart`
- Modify: `lib/avatar/unity_avatar.dart`
- Create: `test/avatar_gesture_test.dart`

**Interfaces:**
- Produces cho Task 5: `MikuGesture` enum (`none, wave, nod, clap, sad, thinking, surprise`) + `MikuGesture.fromApi(String?)`; `ConversationResult.gesture`; `AvatarController.playGesture(MikuGesture)` / `stopGesture()`; `AvatarState.gesture`, `AvatarState.gestureSeq`.

- [ ] **Step 1: Viết test thất bại**

```dart
// test/avatar_gesture_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudayo/avatar/avatar_controller.dart';
import 'package:mikudayo/data/models/conversation_turn.dart';

void main() {
  test('MikuGesture.fromApi parses known names and falls back to none', () {
    expect(MikuGesture.fromApi('wave'), MikuGesture.wave);
    expect(MikuGesture.fromApi('clap'), MikuGesture.clap);
    expect(MikuGesture.fromApi(null), MikuGesture.none);
    expect(MikuGesture.fromApi('backflip'), MikuGesture.none);
  });

  test('ConversationResult parses gesture field', () {
    final result = ConversationResult.fromJson({
      'turn_id': 't',
      'session_id': 's',
      'transcript_ja': 'こんにちは',
      'reply_ja': 'こんばんは！',
      'gesture': 'clap',
    });
    expect(result.gesture, MikuGesture.clap);
  });

  test('AvatarController bumps gestureSeq on play and stop', () {
    final controller = AvatarController();
    controller.build();
    final before = controller.state.gestureSeq;
    controller.playGesture(MikuGesture.wave);
    expect(controller.state.gesture, MikuGesture.wave);
    expect(controller.state.gestureSeq, before + 1);
    controller.stopGesture();
    expect(controller.state.gesture, MikuGesture.none);
    expect(controller.state.gestureSeq, before + 2);
  });

  test('playGesture ignores none', () {
    final controller = AvatarController();
    controller.build();
    final before = controller.state.gestureSeq;
    controller.playGesture(MikuGesture.none);
    expect(controller.state.gestureSeq, before);
  });
}
```

- [ ] **Step 2: Chạy test, xác nhận thất bại**

Run: `flutter test test/avatar_gesture_test.dart`
Expected: FAIL — `MikuGesture` chưa tồn tại.

- [ ] **Step 3: Implement model**

Trong `lib/data/models/conversation_turn.dart`, sau enum `MikuEmotion`:

```dart
/// Cử chỉ thân/tay của Miku (Unity phát qua VRMA).
enum MikuGesture {
  none,
  wave,
  nod,
  clap,
  sad,
  thinking,
  surprise;

  static MikuGesture fromApi(String? raw) {
    for (final g in MikuGesture.values) {
      if (g.name == raw) return g;
    }
    return MikuGesture.none;
  }
}
```

Thêm vào `ConversationResult`: field `final MikuGesture gesture;` (constructor default `MikuGesture.none`) và parse `gesture: MikuGesture.fromApi(json['gesture'] as String?)` trong `fromJson`.

- [ ] **Step 4: Implement `AvatarController`**

Trong `lib/avatar/avatar_controller.dart` thêm vào `AvatarState`:

```dart
  final MikuGesture gesture;
  final int gestureSeq;
```

Constructor default `gesture = MikuGesture.none, gestureSeq = 0`; `build()` giữ `const AvatarState(...)`; `copyWith` thêm 2 param tương ứng. Thêm method:

```dart
  void playGesture(MikuGesture gesture) {
    if (gesture == MikuGesture.none) return;
    state = state.copyWith(gesture: gesture, gestureSeq: state.gestureSeq + 1);
  }

  void stopGesture() {
    state = state.copyWith(gesture: MikuGesture.none, gestureSeq: state.gestureSeq + 1);
  }
```

- [ ] **Step 5: Implement `UnityAvatar` sync**

Trong `lib/avatar/unity_avatar.dart` thêm field `int _lastGestureSeq = -1;`; trong `_onUnityMessage` khi handshake đặt lại `_lastGestureSeq = -1;`. Trong `_sync` thêm khối (sau khối emotion):

```dart
    if (state.gestureSeq != _lastGestureSeq) {
      _lastGestureSeq = state.gestureSeq;
      if (state.gesture == MikuGesture.none) {
        sendToUnity(_bridgeObject, 'StopGesture', '');
      } else {
        sendToUnity(
          _bridgeObject,
          'PlayGesture',
          jsonEncode({'gesture': state.gesture.name}),
        );
      }
    }
```

- [ ] **Step 6: Chạy test + analyze**

Run: `flutter test test/avatar_gesture_test.dart && flutter analyze`
Expected: toàn bộ PASS, `No issues found`.

- [ ] **Step 7: Commit**

```bash
git add lib/data/models/conversation_turn.dart lib/avatar/avatar_controller.dart \
        lib/avatar/unity_avatar.dart test/avatar_gesture_test.dart
git commit -m "feat(flutter): gesture model + Unity bridge sync

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Flutter — view model: chào, chờ TTS, Gemini/emotion mapping (TDD)

**Files:**
- Modify: `lib/features/conversation/conversation_view_model.dart`
- Create: `test/gesture_trigger_test.dart`

**Interfaces:**
- Consumes: Task 4 (`MikuGesture`, `AvatarController.playGesture/stopGesture`).
- Produces: `ConversationViewModel.gestureFor(ConversationResult)` static, hành vi wave/thinking trong `_completeTurn`.

- [ ] **Step 1: Viết test thất bại cho mapping**

```dart
// test/gesture_trigger_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudayo/data/models/conversation_turn.dart';
import 'package:mikudayo/features/conversation/conversation_view_model.dart';

ConversationResult _make(MikuEmotion emotion, MikuGesture gesture) =>
    ConversationResult(
      turnId: 't',
      sessionId: 's',
      transcriptJa: 'a',
      replyJa: 'b',
      emotion: emotion,
      gesture: gesture,
    );

void main() {
  test('gestureFor prefers Gemini gesture over emotion fallback', () {
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.happy, MikuGesture.nod)),
      MikuGesture.nod,
    );
  });

  test('gestureFor falls back by emotion when Gemini says none', () {
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.happy, MikuGesture.none)),
      MikuGesture.clap,
    );
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.excited, MikuGesture.none)),
      MikuGesture.clap,
    );
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.sad, MikuGesture.none)),
      MikuGesture.sad,
    );
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.thinking, MikuGesture.none)),
      MikuGesture.thinking,
    );
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.neutral, MikuGesture.none)),
      MikuGesture.none,
    );
  });
}
```

- [ ] **Step 2: Chạy test, xác nhận thất bại**

Run: `flutter test test/gesture_trigger_test.dart`
Expected: FAIL — `gestureFor` chưa tồn tại.

- [ ] **Step 3: Implement trong `ConversationViewModel`**

```dart
  /// Gesture cho một lượt: ưu tiên Gemini, fallback theo emotion.
  static MikuGesture gestureFor(ConversationResult result) =>
      result.gesture == MikuGesture.none
          ? _emotionGestureFallback[result.emotion] ?? MikuGesture.none
          : result.gesture;

  static const _emotionGestureFallback = {
    MikuEmotion.happy: MikuGesture.clap,
    MikuEmotion.excited: MikuGesture.clap,
    MikuEmotion.thinking: MikuGesture.thinking,
    MikuEmotion.sad: MikuGesture.sad,
  };

  static final RegExp _greetingPattern =
      RegExp(r'(こんにちは|こんばんは|おはよう|はじめまして)');

  bool _waveShown = false;

  /// Lượt đầu tiên của session mà người dùng chào → vẫy tay một lần.
  bool get _isGreetingTurn =>
      !state.messages.any((m) => m.isMiku) &&
      state.messages.lastWhere((m) => m.isUser, orElse: () => const Message(kind: MessageKind.system, text: '')).isUser &&
      _greetingPattern.hasMatch(
        state.messages.lastWhere((m) => m.isUser).text,
      );
```

Trong `_completeTurn`, ngay sau `final avatar = ref.read(avatarControllerProvider.notifier);`:

```dart
    // Vẫy tay một lần cho lượt chào đầu tiên.
    if (!_waveShown && _isGreetingTurn) {
      _waveShown = true;
      avatar.playGesture(MikuGesture.wave);
    }

    avatar.setEmotion(result.emotion);
```

Trong khối `if (result.voiceMode == 'pending')`, thêm dòng đầu:

```dart
      if (result.voiceMode == 'pending') {
        avatar.playGesture(MikuGesture.thinking);
        final audioStatus = await _repo.waitForAudio(...); // giữ nguyên
```

Trong khối `if (audioUrl.isNotEmpty)`, ngay trước `await _audio.prepareUrl(...)`:

```dart
        avatar.stopGesture(); // cắt thinking trước khi phát audio mới
```

Sau `_completeTurn` kết thúc (trước khi reset state về idle), thêm gesture của lượt:

```dart
    // Gesture theo ngữ cảnh trả lời (sau khi audio đã bắt đầu phát).
    avatar.playGesture(gestureFor(result));
```

Lưu ý anti-spam: `stopGesture` + `playGesture` cùng lượt là đúng trình tự (seq tăng, Unity nhận Stop rồi Play).

- [ ] **Step 4: Chạy test + analyze**

Run: `flutter test test/gesture_trigger_test.dart && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/conversation/conversation_view_model.dart test/gesture_trigger_test.dart
git commit -m "feat(flutter): trigger gestures on greeting, TTS wait, and reply

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Backend — trường `gesture` của Gemini + API (TDD)

**Files:**
- Modify: `backend/app/schemas/conversation.py`
- Modify: `backend/app/services/gemini_service.py`
- Modify: `backend/app/api/conversation.py`
- Create: `backend/tests/test_gesture_schema.py`

**Interfaces:**
- Produces cho Flutter: field `gesture` (string, default `"none"`) trong response `/v1/conversation/turn`.
- Enum backend: `Gesture = Literal["none", "wave", "nod", "clap", "sad", "thinking", "surprise"]`.

- [ ] **Step 1: Viết test thất bại**

```python
# backend/tests/test_gesture_schema.py
from __future__ import annotations

import unittest

from pydantic import ValidationError

from app.schemas.conversation import ConversationResult, GeminiTurnOutput


def _kwargs(**overrides):
    base = dict(transcript_ja="こんにちは", reply_ja="こんばんは！")
    base.update(overrides)
    return base


class GestureSchemaTest(unittest.TestCase):
    def test_gemini_output_defaults_gesture_none(self) -> None:
        out = GeminiTurnOutput(**_kwargs())
        self.assertEqual(out.gesture, "none")

    def test_gemini_output_accepts_known_gesture(self) -> None:
        out = GeminiTurnOutput(**_kwargs(gesture="wave"))
        self.assertEqual(out.gesture, "wave")

    def test_gemini_output_rejects_unknown_gesture(self) -> None:
        with self.assertRaises(ValidationError):
            GeminiTurnOutput(**_kwargs(gesture="backflip"))

    def test_conversation_result_exposes_gesture(self) -> None:
        result = ConversationResult(
            turn_id="t1", session_id="s1",
            transcript_ja="a", reply_ja="b", audio_url="",
            gesture="sad",
        )
        self.assertEqual(result.gesture, "sad")

    def test_gemini_schema_requires_gesture(self) -> None:
        from app.services.gemini_service import SCHEMA_JSON
        self.assertIn("gesture", SCHEMA_JSON["required"])
        self.assertEqual(
            SCHEMA_JSON["properties"]["gesture"]["enum"],
            ["none", "wave", "nod", "clap", "sad", "thinking", "surprise"],
        )


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Chạy test, xác nhận thất bại**

Run: `cd backend && "C:\Users\pc\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe" -m unittest tests.test_gesture_schema -v`
Expected: FAIL — `gesture` chưa có.

- [ ] **Step 3: Implement**

(a) `backend/app/schemas/conversation.py` — sau dòng `Emotion = Literal[...]`:

```python
Gesture = Literal["none", "wave", "nod", "clap", "sad", "thinking", "surprise"]
```

`GeminiTurnOutput` thêm:

```python
    gesture: Gesture = Field(default="none", description="Cử chỉ thân/tay cho avatar")
```

`ConversationResult` thêm:

```python
    gesture: Gesture = "none"
```

(b) `backend/app/services/gemini_service.py`:

Trong `SYSTEM_PROMPT_TEMPLATE` (mục Output contract, sau dòng emotion):

```text
- gesture: one of [none, wave, nod, clap, sad, thinking, surprise]. Pick ONE body gesture matching your reply (wave when greeting, clap when praising, nod when agreeing). Answer "none" most of the time — do NOT gesture every turn.
```

Trong `SCHEMA_JSON["properties"]` thêm:

```python
        "gesture": {
            "type": "string",
            "enum": ["none", "wave", "nod", "clap", "sad", "thinking", "surprise"],
        },
```

và thêm `"gesture"` vào danh sách `required`.

Trong `_mock_output` trả `gesture="none"`:

```python
        gesture="none",
```

(c) `backend/app/api/conversation.py` — trong `return ConversationResult(...)` của `conversation_turn` thêm `gesture=out.gesture,`.

- [ ] **Step 4: Chạy toàn bộ test backend**

Run: `cd backend && python -m unittest discover -s tests -v`
Expected: toàn bộ PASS kể cả `test_conversation_contract.py`.

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas/conversation.py backend/app/services/gemini_service.py \
        backend/app/api/conversation.py backend/tests/test_gesture_schema.py
git commit -m "feat(backend): Gemini gesture field passed through to Flutter

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Unity prepare + export + Flutter APK + kiểm tra máy thật

**Files:**
- Không sửa code; chạy pipeline build.
- Modify: `HANDOFF.md` (sau khi xác minh)

- [ ] **Step 1: Prepare + export Unity**

Chạy đúng 2 lệnh batchmode ở `HANDOFF.md` mục 7 (prepare rồi export), log đặt tên `63-gesture-prepare.log` / `64-gesture-export.log`. Kiểm tra log: `Building project for Flutter succeeded`. Không xóa `android_room/android/unityLibrary` trước khi export xong.

- [ ] **Step 2: Build APK Flutter**

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

- [ ] **Step 3: Cài lên máy thật và kiểm tra (BẮT BUỘC — không được bỏ qua)**

```powershell
adb devices
adb install -r 'C:\Users\pc\Desktop\mikudayo\build\app\outputs\flutter-apk\app-debug.apk'
```

Checklist trên máy (từ spec mục 8), mỗi mục phải nhìn trực tiếp:
1. Chờ 30s không làm gì: thế tay đổi ≥2 kiểu, đầu liếc, không giật/drift.
2. Nói/nhập câu chào (`こんばんは`): Miku vẫy tay 1 lần.
3. Trong lúc chờ giọng: chống cằm/nghiêng đầu; khi audio phát thì cắt mượt.
4. Câu trả lời vui: vỗ tay; buồn: cúi đầu; tay không văng khỏi khung dọc.
5. Vài lượt liên tiếp: không crash, không kẹt pose, portrait/zoom/keyboard không đổi.

Nếu mục nào hỏng: dừng, ghi hiện tượng + log `adb logcat`, KHÔNG tuyên bố hoàn thành.

- [ ] **Step 4: Cập nhật `HANDOFF.md`**

Cập nhật ngày, mục 2 (bảng trạng thái thêm dòng gesture), mục 5 (mô tả hệ gesture: file, lệnh bridge, StreamingAssets), mục 9 (file mới), mục 10 (việc còn lại: license VRMA, tune biên độ...). Ghi nguồn + license các file `.vrma` đã dùng.

- [ ] **Step 5: Commit**

```bash
git add HANDOFF.md
git commit -m "docs: handoff update after gesture milestone

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
