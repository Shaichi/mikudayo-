# HANDOFF — Lộ trình thay renderer 3D bằng Unity + ChatDollKit

> Cập nhật: 2026-08-12
> Workspace: `C:\Users\pc\Desktop\mikudayo`
> Target ưu tiên: Android thật; Windows chỉ là target phụ
> Trạng thái: đã nghiên cứu và dựng scaffold Unity, **chưa compile thành công bằng Unity, chưa có APK smoke-test, chưa tích hợp vào Flutter**.

Tài liệu này là nguồn sự thật cho agent tiếp quản. Không suy diễn rằng một hạng mục đã hoàn thành chỉ vì file đã tồn tại. Mỗi phase dưới đây có cổng nghiệm thu; chỉ đi tiếp khi cổng trước đã có bằng chứng.

---

## 0. Chỉ thị ngắn cho agent tiếp quản

Mục tiêu người dùng hiện tại là **thay hoàn toàn phần render avatar 3D đang lỗi bằng Unity/ChatDollKit**, tận dụng repo [ChatDollKit](https://github.com/uezo/ChatdollKit), giữ nguyên phần hội thoại hiện có của Flutter/FastAPI/Gemini/VOICEVOX/RVC.

Làm theo thứ tự bắt buộc:

1. Đọc hết tài liệu này và chạy `git status --short`; working tree đang bẩn và có thay đổi của người dùng/agent trước. Không `reset`, không `checkout --`, không xóa hàng loạt.
2. Kiểm tra tiến trình cài Unity đang chạy hay đã xong trước khi khởi động một lần cài khác.
3. Compile và chứng minh avatar chạy trong Unity standalone trước.
4. Build APK Unity standalone và xác nhận trực quan trên điện thoại thật.
5. Sau đó mới thêm URP/Flutter Embed, export `unityLibrary`, nối Flutter.
6. Chỉ xóa WebView renderer và asset cũ sau khi bản Flutter + Unity chạy ổn trên máy thật.
7. Không public hoặc phân phối riêng file `.vrm`; model chỉ được dùng cá nhân và tích hợp vào phần mềm.

Không dùng gói `ChatdollKit_0.7to084Migration.unitypackage`. Anchor “Migration from 0.7.x” trong URL người dùng gửi chỉ dành cho dự án **đã dùng ChatDollKit 0.7.x**. Repo này trước đây không dùng ChatDollKit, nên đây là tích hợp mới trên 0.8.16.

---

## 1. Kết quả cuối cùng cần đạt

Trong màn hình Conversation của app Android:

- Avatar Miku VRM 1.0 hiển thị đúng texture, tóc, vật liệu và camera framing; không màn hình đen, không shader hồng.
- Có blink tự nhiên.
- Có ít nhất sáu trạng thái ứng dụng: `neutral`, `happy`, `excited`, `thinking`, `embarrassed`, `sad`.
- Miệng chạy theo `MouthCue` từ backend trong lúc Flutter phát audio TTS.
- Điều hướng vào/ra Conversation, background/resume và xoay màn hình không crash hoặc mất renderer.
- Backend, thu âm, Gemini, VOICEVOX và RVC vẫn do Flutter/FastAPI quản lý; không viết lại pipeline hội thoại vào Unity ở phase này.
- Bản debug và release Android build được từ quy trình có thể lặp lại.

Không coi task hoàn thành nếu chỉ compile hoặc chỉ thấy log `READY`. Phải có xác nhận trực quan trên thiết bị thật.

---

## 2. Kiến trúc đã chốt

```text
FastAPI / Gemini / VOICEVOX / RVC
                |
                v
Flutter ConversationViewModel
  |                    |
  |                    +--> just_audio phát file TTS
  v
AvatarController (emotion + MouthCue timeline)
                |
                v
UnityAvatar / EmbedUnity
  sendToUnity("MikuAvatarBridge", method, JSON)
                |
                v
MikuAvatarBridge.cs
  +--> ChatDollKit ModelController / FaceController
  +--> Vrm10FaceExpressionProxy
  +--> Vrm10Blink
  +--> Vrm10MouthCueDriver
                |
                v
UniVRM10 Vrm10Instance.Runtime.Expression

Unity --JSON event--> Flutter: ready / error / speech_finished
```

Ranh giới trách nhiệm:

- Flutter giữ UI, navigation, microphone, API call, audio playback và state Riverpod.
- Unity chỉ giữ vòng đời/render avatar, animation, blink, expression và mouth cue.
- Không gửi audio base64 qua bridge. Payload bridge chỉ là chuỗi JSON nhỏ.
- Chỉ có một `EmbedUnity` trên một route; Unity runtime chỉ có một instance.

### Vì sao chỉ vendoring phần Model của ChatDollKit

Toàn bộ ChatDollKit có dialog, LLM, STT/TTS và nhiều tích hợp không cần thiết vì app đã có backend hoạt động. Scaffold hiện chỉ copy nguyên trạng `Assets/ChatdollKit/Scripts/Model` từ ChatDollKit 0.8.16 để dùng `ModelController`, `FaceController`, `SpeechController` và các interface.

ChatDollKit 0.8.16 VRM extension dùng API VRM 0.x (`VRMBlendShapeProxy`). Model của dự án là VRM 1.0, vì vậy scaffold có adapter riêng dùng `UniVRM10.Vrm10Instance.Runtime.Expression.SetWeight`.

---

## 3. Version và toolchain phải khóa

| Thành phần | Phiên bản/giá trị | Ghi chú |
|---|---:|---|
| Unity | `6000.3.3f1` | Revision `ef04196de0d6`; đáp ứng nhánh Unity 6000.3 của plugin Flutter |
| ChatDollKit | `0.8.16` | Commit/tag đã lấy: `eb5ad8f`; Apache-2.0 |
| UniVRM | `0.127.2` | Dùng package VRM 1.0; MIT |
| UniTask | `2.5.4` | MIT |
| uLipSync | `3.1.0` | Đang là dependency vì source Model có helper tham chiếu; MVP dùng MouthCue, không phân tích audio |
| Burst | `1.8.24` | Khai trong manifest hiện tại |
| Android min SDK | `25` | Unity 6 cơ bản hỗ trợ API 23+, nhưng implementation Android 2.0.0 của plugin ghi rõ Unity 6000.3 cần minSdk 25 |
| Android ABI | `arm64-v8a` | Scaffold đặt `AndroidArchitecture.ARM64` |
| NDK | `r27c` / `27.2.12479018` | Phải đồng nhất Unity export và Flutter app |
| JDK | `17` | Unity 6000.3 Android toolchain |
| Flutter plugin ứng viên | `flutter_embed_unity 2.0.0` | Hỗ trợ Unity 6000.3; plugin tự cảnh báo cơ chế embed là “delicate” |
| Android implementation | `flutter_embed_unity_6000_0_android 2.0.0` | Pin rõ ràng để tránh nhầm implementation 2022.3 |

Hiện Android Flutter dùng:

- AGP `8.11.1` trong `android/settings.gradle.kts`.
- Gradle wrapper `8.14`.
- `ndkVersion = flutter.ndkVersion` và `minSdk = flutter.minSdkVersion`.

Tài liệu plugin nêu matrix Unity 6000.2–6000.3 với **Gradle 8.13, AGP 8.10.0**, NDK r27c, JDK 17. Stack Flutter hiện tại (Gradle 8.14, AGP 8.11.1) cao hơn nhẹ; thử giữ nguyên trước và chỉ đổi khi có lỗi build cụ thể. Agent phải đối chiếu Gradle files do Unity 6000.3.3 xuất ra và thống nhất một version AGP cho `app` + `unityLibrary`; không vá mò từng lỗi dependency và không chỉnh trực tiếp file generated nếu có thể chỉnh từ Unity/exporter.

### Render Pipeline — decision gate quan trọng

- Scaffold hiện là Built-in Render Pipeline vì ChatDollKit README cảnh báo không dùng SRP.
- `flutter_embed_unity` lại hướng dẫn Unity project dùng URP.
- Trường hợp này dùng model **VRM 1.0** và adapter riêng, không dùng VRM 0.x extension của ChatDollKit. UniVRM 0.127.2 có MToon10 cho URP, nên URP là đường tích hợp khả thi.
- Phải chứng minh theo hai bước: Built-in standalone chạy trước, sau đó thêm URP + reimport model và chạy standalone lần nữa. Như vậy nếu avatar đen/hồng sẽ biết lỗi đến từ model/scaffold hay từ chuyển pipeline.

---

## 4. Trạng thái thật tại thời điểm bàn giao

### Đã làm

- Đã nghiên cứu ChatDollKit 0.8.16 và phần migration 0.7.x.
- Đã clone source tham khảo vào `tool/` (thư mục ignored): ChatDollKit, UniVRM và uLipSync.
- Đã tạo Unity project tại `unity/MikuAvatar`.
- Đã pin UPM dependencies trong `unity/MikuAvatar/Packages/manifest.json`.
- Đã copy model VRM 1.0 26,288,668 byte vào `unity/MikuAvatar/Assets/Mikudayo/Models/Miku.vrm`.
- Đã vendor phần `ChatdollKit/Scripts/Model` và license.
- Đã viết adapter VRM 1.0, bridge, auto-demo, camera framer và Editor setup/build script.
- Đã bổ sung `.gitignore` cho Unity cache/build/export.
- Đã cài Unity CLI `1.0.0-beta.3` tại `C:\Users\pc\AppData\Local\Unity\bin\unity.exe`.
- Đã cài xong Unity 6000.3.3f1 + Android toolchain bằng Unity CLI. Lệnh cài đã exit code 0 và liệt kê Unity, Android Build Support, OpenJDK, NDK, CMake, SDK Build/Platform/Command-line Tools cùng SDK Platforms 34–36.
- Theo yêu cầu người dùng, đã chuyển vị trí cài mặc định và cài lại Unity trực tiếp trên ổ D. Unity CLI hiện đăng ký `D:\Unity\Hub\Editor\6000.3.3f1\Editor\Unity.exe` với đủ Android Build Support, SDK/NDK Tools và OpenJDK.
- Đã xác nhận `Unity.exe`, `AndroidPlayer`, `SDK`, `NDK` và `OpenJDK` đều tồn tại trên D; bản Editor cũ trên C không còn.
- Dung lượng bản Unity trên D là khoảng 17.18 GB. Sau khi hoàn tất: C còn khoảng 74.94 GB, D còn khoảng 351.79 GB; Unity download cache trên C là 0 byte.
- Để Unity không tạo cache/build lớn trên C khi import lần đầu, các đường dẫn generated `unity/MikuAvatar/{Library,Builds,Temp,Obj,Logs}` là directory junction trỏ tới `D:\Unity\ProjectData\mikudayo\MikuAvatar\<name>`. Không xóa target trên D khi project/Editor đang chạy. Các đường dẫn này đã nằm trong `.gitignore`.

### Chưa làm / chưa được chứng minh

- Unity Package Manager chưa resolve project lần đầu.
- C# chưa compile bằng Unity; mọi đánh giá API hiện chỉ là source audit.
- Scene `.unity` và các `.meta` cho file mới chưa được Unity tạo.
- Chưa chạy Play Mode.
- Chưa build/cài APK Unity standalone.
- Chưa thêm URP hoặc Flutter Embed assets vào Unity.
- Chưa export `android/unityLibrary`.
- Chưa thêm plugin vào `pubspec.yaml`.
- Flutter hiện vẫn render `VrmAvatar` bằng WebView/three-vrm.
- Chưa kiểm thử lifecycle/performance/memory bản Unity trên điện thoại.

### Không được nhầm các file user đang sửa

Trước khi tài liệu này được viết, `git status --short` có ít nhất:

```text
 M .gitignore
 M HANDOFF.md
 M lib/avatar/avatar_controller.dart
 M lib/avatar/vrm_avatar.dart
 M pubspec.yaml
?? VRM_RENDER_OPTIONS.md
?? assets/
?? lib/avatar/asset_http_server.dart
?? runlog.txt
?? screen.png
?? screen2.png
?? unity/
```

Không hoàn tác những thay đổi này. WebView renderer là fallback cho tới Gate E.

---

## 5. Bản đồ file quan trọng

### Unity scaffold

- `unity/README.md`: hướng dẫn ngắn và version pin.
- `unity/THIRD_PARTY_NOTICES.md`: nguồn/license dependency.
- `unity/MikuAvatar/Packages/manifest.json`: UPM packages.
- `unity/MikuAvatar/ProjectSettings/ProjectVersion.txt`: Unity version.
- `unity/MikuAvatar/Assets/ChatdollKit/Scripts/Model/`: source Model từ upstream 0.8.16.
- `unity/MikuAvatar/Assets/ChatdollKit/LICENSE`: Apache-2.0.
- `unity/MikuAvatar/Assets/Mikudayo/Models/Miku.vrm`: model riêng tư.
- `unity/MikuAvatar/Assets/Mikudayo/Editor/MikuProjectSetup.cs`: tạo scene, build APK, generic Gradle export.
- `unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuAvatarBridge.cs`: API string cho Flutter.
- `unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuAvatarAutoDemo.cs`: tự cycle emotion/mouth cue.
- `unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuCameraFramer.cs`: camera theo bounds model.
- `unity/MikuAvatar/Assets/Mikudayo/Runtime/Vrm10/Vrm10ExpressionCatalog.cs`: resolve preset/custom expression.
- `unity/MikuAvatar/Assets/Mikudayo/Runtime/Vrm10/Vrm10FaceExpressionProxy.cs`: adapter `IFaceExpressionProxy`.
- `unity/MikuAvatar/Assets/Mikudayo/Runtime/Vrm10/Vrm10Blink.cs`: adapter `IBlink`.
- `unity/MikuAvatar/Assets/Mikudayo/Runtime/Vrm10/Vrm10MouthCueDriver.cs`: adapter `ILipSyncHelper`, nội suy cue theo realtime.

### Flutter hiện tại

- `lib/avatar/avatar_controller.dart`: state emotion + speech sequence + cues.
- `lib/avatar/vrm_avatar.dart`: WebView renderer hiện tại; sẽ thành legacy/fallback.
- `lib/avatar/asset_http_server.dart`: loopback server cho WebView; chỉ xóa sau Gate E.
- `lib/features/conversation/conversation_screen.dart`: đang mount `const VrmAvatar()` tại header.
- `lib/features/conversation/conversation_view_model.dart`: gọi `setEmotion`, `playMouthCues`, `stopMouth`.
- `lib/data/models/conversation_turn.dart`: model `MouthCue { tMs, mouth }`.
- `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`: điểm nối Unity Gradle module.

### Lưu ý về exporter hiện tại

`MikuProjectSetup.ExportAndroidLibrary()` hiện chỉ là generic Unity Gradle export vào `android/unityExport`. Nó **không thay thế exporter của flutter_embed_unity**. Tích hợp cuối phải import FlutterEmbed assets và dùng exporter của plugin để tạo đúng `android/unityLibrary`, hoặc sửa batch wrapper để gọi chính exporter đó. Không dùng generic export làm bằng chứng plugin đã được tích hợp.

---

## 6. Hợp đồng message phải giữ ổn định

GameObject bắt buộc có tên:

```text
MikuAvatarBridge
```

Public methods hiện có, mỗi method nhận đúng một `string`:

```text
Ping(string)              # cần bổ sung trước khi nối Flutter
SetEmotion(string)
PlayMouthCues(string)
StopSpeech(string)
```

Payload đề xuất chính thức:

```json
{"version":1,"emotion":"happy"}
```

```json
{
  "version": 1,
  "seq": 42,
  "duration_ms": 1860,
  "cues": [
    {"t_ms": 0, "mouth": 0.0},
    {"t_ms": 120, "mouth": 0.72},
    {"t_ms": 310, "mouth": 0.1}
  ]
}
```

`StopSpeech` có thể nhận `{"version":1,"seq":42}`; code hiện bỏ qua nội dung nhưng nên parse `seq` để một lệnh stop cũ không cắt speech mới.

Sau khi import FlutterEmbed, Unity phải gửi JSON qua `SendToFlutter.Send(...)`:

```json
{"type":"ready","version":1,"renderer":"chatdollkit","vrm":"1.0"}
{"type":"pong","version":1,"nonce":"<nonce-from-flutter>"}
{"type":"emotion_applied","emotion":"happy"}
{"type":"speech_started","seq":42}
{"type":"speech_finished","seq":42}
{"type":"error","code":"VRM_NOT_READY","message":"..."}
```

Flutter phải queue tối đa trạng thái mới nhất cho tới khi nhận `ready` hoặc `pong`. Khi ready, flush theo thứ tự: emotion mới nhất, sau đó speech mới nhất. Không phát lại các speech sequence cũ.

Không chỉ dựa vào `Start()` để handshake. Unity runtime chỉ khởi tạo scene một lần rồi giữ trong RAM; khi người dùng quay lại Conversation, `Start()` có thể không chạy lại. Mỗi lần `UnityAvatar` mount, Flutter phải gửi `Ping(nonce)` theo retry hữu hạn và chỉ coi bridge sẵn sàng khi nhận `pong` đúng nonce.

### Mapping emotion cần xác nhận theo model thật

| App | VRM ưu tiên | Fallback |
|---|---|---|
| `neutral` | `neutral` | tất cả emotion weight = 0 |
| `happy` | `happy` | `joy`, `fun` |
| `excited` | `surprised` | `happy`, `fun` |
| `thinking` | `relaxed` | `neutral` |
| `embarrassed` | `surprised` | `happy`, `relaxed` |
| `sad` | `sad` | `sorrow` |

Code hiện có mapping cơ bản nhưng chưa fallback đầy đủ khi preset mục tiêu không tồn tại. Trong lần import đầu, log toàn bộ `Vrm.Expression.Clips` và điều chỉnh mapping theo model này; đừng đoán bằng tên file.

---

## 7. Lộ trình triển khai có cổng nghiệm thu

### Phase 0 — Khóa baseline và xác nhận lại toolchain (Gate A đã đạt ở phiên này)

Checklist:

- [ ] Chạy `git status --short` và lưu kết quả vào báo cáo, không sửa unrelated files.
- [x] Tiến trình cài đã kết thúc exit code 0.
- [x] `Unity.exe` và AndroidPlayer đã được xác nhận tồn tại.
- [x] Sau khi chuyển Unity sang D: C còn khoảng 74.94 GB và D còn khoảng 351.79 GB, đủ cho import/build trước mắt.
- [ ] Xác nhận Unity license; nếu batch mode báo license, chạy login/open Editor theo luồng chính thức.

PowerShell:

```powershell
Set-Location 'C:\Users\pc\Desktop\mikudayo'
git status --short

$unityCli = 'C:\Users\pc\AppData\Local\Unity\bin\unity.exe'
& $unityCli --version
& $unityCli editors -i --format json

Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match '6000\.3\.3f1|unity\.exe.+install' } |
  Select-Object ProcessId, ParentProcessId, Name, CommandLine

$unityEditor = 'D:\Unity\Hub\Editor\6000.3.3f1\Editor\Unity.exe'
Test-Path -LiteralPath $unityEditor
Test-Path -LiteralPath 'D:\Unity\Hub\Editor\6000.3.3f1\Editor\Data\PlaybackEngines\AndroidPlayer'

# Cache/build Unity của project được đặt trên D qua junction:
Get-Item 'C:\Users\pc\Desktop\mikudayo\unity\MikuAvatar\Library' -Force |
  Select-Object FullName, LinkType, Target
```

Nếu không có process và Editor chưa tồn tại, chạy lại đúng một lần:

```powershell
& $unityCli install 6000.3.3f1 `
  -c ef04196de0d6 `
  -m android --cm --accept-eula --yes
```

Gate A đạt khi:

- `Unity.exe` tồn tại.
- CLI liệt kê 6000.3.3f1 installed.
- Có AndroidPlayer, SDK, NDK r27c và OpenJDK 17.
- Không còn installer chạy nền.

### Phase 1 — Resolve packages và compile Unity scaffold

Tạo log directory rồi chạy batch import:

```powershell
$project = 'C:\Users\pc\Desktop\mikudayo\unity\MikuAvatar'
$logDir = Join-Path $project 'Logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

& $unityEditor `
  -batchmode -quit `
  -accept-apiupdate `
  -projectPath $project `
  -logFile (Join-Path $logDir '01-import-and-scene.log') `
  -executeMethod Mikudayo.Avatar.Editor.MikuProjectSetup.RebuildScene

$LASTEXITCODE
```

Sau đó:

```powershell
rg -n "error CS|Compilation failed|Exception|FAILED|MikuAvatar:" `
  'unity/MikuAvatar/Logs/01-import-and-scene.log'
```

Các điểm cần audit nếu compile lỗi:

1. Package Git phải resolve đúng tag; không đổi sang HEAD.
2. Xác nhận `com.vrmc.vrmshaders` được kéo transitively; nếu không, pin đúng tag 0.127.2.
3. Xác nhận Burst/uLipSync/UniTask tương thích Unity 6000.3.
4. `BuildFailedException` phải đến từ `UnityEditor.Build`.
5. Nếu `LegacyRuntime.ttf` không còn hợp lệ, thay overlay bằng TextMeshPro hoặc font built-in được Unity 6 hỗ trợ; không để UI smoke-test chặn renderer.
6. `ModelController` yêu cầu `IBlink`, `IFaceExpressionProxy`, `ILipSyncHelper`, `FaceController`, `SpeechController` nằm cùng GameObject `MikuAvatarBridge`; Editor script hiện tạo đúng cấu trúc này.
7. `Animator` phải nằm trên root model; nếu importer tạo root trung gian, sửa `GetComponentInChildren<Animator>(true)` hoặc đặt `AvatarModel` đúng node.
8. Đừng import ChatDollKit VRM 0.x extension để “sửa” lỗi VRM 1.0.
9. Đổi `PlayerSettings.Android.minSdkVersion` từ API 23 lên API 25 trước bản export/plugin 2.0.0.

Gate B đạt khi:

- Batch command exit code 0.
- Không có compiler error.
- Có `Assets/Mikudayo/Scenes/MikuAvatar.unity`.
- Unity tạo `.meta` và `Packages/packages-lock.json` hợp lệ.
- Log có `MikuAvatar: scene rebuilt ...`.

### Phase 2 — Play Mode và smoke-test desktop

Mở project bằng đúng Editor, mở scene và Play:

```powershell
& $unityEditor -projectPath $project
```

Kiểm tra trực quan ít nhất 60 giây:

- [ ] Model xuất hiện đúng chiều, đúng tỷ lệ, không bị camera cắt đầu/tóc.
- [ ] Texture và MToon đúng; không material hồng/đen/trong suốt sai.
- [ ] Blink diễn ra ngẫu nhiên khoảng 2.8–5.2 giây.
- [ ] Auto-demo đổi qua 6 emotion mỗi 2.5 giây.
- [ ] Miệng mở/đóng theo demo cue và trở về 0.
- [ ] Console có `MikuAvatar: READY ChatDollKit=0.8.16 VRM=1.0`.
- [ ] Không có exception lặp mỗi frame.

Việc phải bổ sung trong phase này:

- Log danh sách expression thật của model một lần ở startup/debug.
- Sửa fallback mapping emotion nếu model thiếu preset.
- Nếu body hoàn toàn đứng yên: đây là giới hạn đã biết vì scaffold chỉ có `MikuIdlePlaceholder.anim`. Thêm một idle animation/VRMA có license phù hợp sau khi renderer ổn; không tải asset không rõ license vào repo.
- Test trực tiếp `SetEmotion`, `PlayMouthCues`, `StopSpeech` bằng Inspector/debug buttons hoặc một Editor test harness.

Gate C đạt khi có screenshot/video ngắn và log chứng minh cả model, blink, emotion, mouth cue đều chạy trong Play Mode.

### Phase 3 — APK Unity standalone trên Android thật

Build:

```powershell
& $unityEditor `
  -batchmode -quit `
  -accept-apiupdate `
  -projectPath $project `
  -logFile (Join-Path $logDir '02-android-smoke-build.log') `
  -executeMethod Mikudayo.Avatar.Editor.MikuProjectSetup.BuildAndroidApk

$LASTEXITCODE
```

Output dự kiến:

```text
unity/MikuAvatar/Builds/Android/MikuAvatar-debug.apk
```

Cài/chạy trên thiết bị:

```powershell
$adb = 'C:\Users\pc\AppData\Local\Android\Sdk\platform-tools\adb.exe'
& $adb devices -l
& $adb install -r 'unity/MikuAvatar/Builds/Android/MikuAvatar-debug.apk'
& $adb logcat -c
& $adb shell monkey -p com.shaichi.mikudayo.avatar.smoketest 1
& $adb logcat -d | Select-String 'MikuAvatar|Unity|FATAL EXCEPTION|AndroidRuntime'
```

Kiểm tra:

- [ ] Dùng thiết bị thật, không lấy emulator làm gate chính.
- [ ] Model load trong <= 10 giây sau cold start trên thiết bị hiện có.
- [ ] Trung bình đạt tối thiểu 30 FPS sau warm-up; không giật dài mỗi lần blink/emotion.
- [ ] Không tăng memory liên tục trong 5 phút auto-demo.
- [ ] Background/resume 10 lần không mất surface, không crash.
- [ ] Xoay portrait/landscape rồi về portrait không sai camera nghiêm trọng.
- [ ] Blink, emotion và mouth cue vẫn chạy giống Editor.

Gate D đạt khi APK standalone được người dùng/agent nhìn thấy hoạt động đúng trên máy thật. Nếu gate này không đạt, **không đụng Flutter integration**; sửa Unity trước.

### Phase 4 — Chuyển sang URP và import Flutter Embed

Tạo một checkpoint có thể so sánh (commit chỉ khi người dùng cho phép; nếu không thì giữ diff rõ ràng).

1. Thêm version URP tương thích Unity 6000.3 từ Unity Registry.
2. Tạo URP Pipeline Asset + Renderer Asset và gán vào `GraphicsSettings`/mọi Quality level dùng khi Android.
3. Reimport `Miku.vrm` để UniVRM chọn `VRM10/Universal Render Pipeline/MToon10`.
4. Nếu model dùng outline, thêm `MToonOutlineRenderFeature` theo UniVRM và kiểm tra tóc/miệng.
5. Chạy lại Gate C và D sau khi chuyển URP.
6. Import FlutterEmbed assets đúng release 2.0.0 cho Unity 6000.0/6000.3. Ưu tiên pin tag/commit; không dùng URL HEAD không khóa.
7. Tách scene/config smoke test và embedded. Smoke scene được có `MikuAvatarAutoDemo` + `Smoke Test UI`; embedded scene **không được có** hai component/object này vì auto-demo sẽ liên tục ghi đè emotion/mouth từ Flutter. Đặt `AudioSource.playOnAwake = false`.
8. Sửa `MikuAvatarBridge` để có `Ping` và gọi `SendToFlutter.Send(JSON)` cho `ready`, `pong`, `error`, `speech_started`, `speech_finished`.
9. Dùng menu/exporter `Flutter Embed -> Export project to Flutter app` hoặc batch entrypoint của chính plugin, output **chính xác** `android/unityLibrary`.

UPM URL được tài liệu plugin đưa ra cho Unity 6000.x:

```text
https://github.com/learntoflutter/flutter_embed_unity.git?path=example_unity_6000_0_project/Assets/FlutterEmbed
```

Trước khi thêm vào manifest chính, xác định tag/commit của release 2.0.0 và nối `#<tag-or-commit>`.

Gate E1 đạt khi APK Unity standalone vẫn render đúng sau URP. Gate E2 đạt khi `android/unityLibrary` được exporter plugin tạo và chứa Gradle module + native libs ARM64.

### Phase 5 — Nối Unity vào Flutter nhưng giữ fallback

#### 5.1 Dependency

Pin tạm thời, sau đó commit `pubspec.lock`:

```yaml
dependencies:
  flutter_embed_unity: 2.0.0
  flutter_embed_unity_6000_0_android: 2.0.0
```

Chạy `flutter pub get` và xác nhận federated Android implementation thực tế trong lockfile. Nếu package 2.0.0 đã chọn Unity 6 implementation mặc định, dependency explicit vẫn nên cùng version; không trộn `1.2.x` với `2.0.0`.

#### 5.2 Android Gradle

Sau export, thực hiện theo chính README/export log của plugin. Những thay đổi tối thiểu dự kiến:

`android/settings.gradle.kts`:

```kotlin
include(":app")
include(":unityLibrary")
project(":unityLibrary").projectDir = file("unityLibrary")
```

`android/app/build.gradle.kts`:

```kotlin
android {
    minSdk = 25
    ndkVersion = "27.2.12479018"
}

dependencies {
    implementation(project(":unityLibrary"))
}
```

Không copy nguyên snippet nếu exporter 2.0.0 đã tự patch. Kiểm tra diff sau export để tránh duplicate `include`/dependency.

`android/build.gradle.kts` cần repository cho AAR/JAR do Unity export:

```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        flatDir { dirs("${rootProject.projectDir}/unityLibrary/libs") }
    }
}
```

`android/gradle.properties` phải có property exporter cần, tối thiểu thường là:

```properties
unityStreamingAssets=
```

Và `androidResources.noCompress` trong app phải gồm `.unity3d`, `.ress`, `.resource`, `.obb`, `.bundle`, `.unityexp` cộng danh sách `unityStreamingAssets`. Lấy snippet Kotlin DSL từ đúng README 2.0.0; không copy manifest/module `launcher` của Unity standalone vào Flutter app.

Nếu AGP conflict:

- Đọc `android/unityLibrary/build.gradle*`, `gradle.properties` và export log.
- Dùng một AGP version ở root tương thích cả Flutter và Unity; với Unity 6000.3, ưu tiên matrix plugin trước.
- Giữ JDK 17 và NDK r27c.
- Chỉ tăng `org.gradle.jvmargs` khi log thật sự là OOM.
- Không dùng `pickFirst`/exclude native library bừa để che duplicate symbols.

#### 5.3 Flutter widget và state

Tạo `lib/avatar/unity_avatar.dart`:

- Dùng `EmbedUnity(onMessageFromUnity: ...)`.
- Cấu hình `EmbedUnityPreferences.messageFromUnityListeningBehaviour = MessageFromUnityListeningBehaviour.onlyMostRecentlyCreatedWidgetReceivesMessages` một lần khi app khởi động.
- Parse JSON event.
- Mỗi lần widget mount, gửi `Ping(nonce)` mỗi khoảng 250 ms, tối đa 15 giây; dừng retry khi có `pong` đúng nonce.
- Chưa `ready/pong`: giữ emotion mới nhất và speech mới nhất trong queue.
- Sau `ready/pong`: gọi `sendToUnity('MikuAvatarBridge', 'SetEmotion', json)`.
- Cues mới: gọi `PlayMouthCues` đúng một lần cho mỗi `speechSeq`.
- Stop/cancel/new turn: gọi `StopSpeech` với sequence.
- Dùng placeholder/loading UI rõ ràng, timeout khoảng 15 giây và hiển thị lỗi renderer thay vì màn hình trống.

Tạo facade `lib/avatar/avatar_surface.dart`:

- Android/iOS: `UnityAvatar`.
- Windows: tạm dùng `VrmAvatar` cũ hoặc placeholder; plugin Unity này không phải renderer Windows.
- `conversation_screen.dart` chỉ mount facade, không biết renderer cụ thể.

Sửa `AvatarState`:

- Thêm `copyWith` để `setEmotion` không reset `speechSeq`/cue.
- Thêm `stopSeq` hoặc event tương đương; `stopMouth()` hiện đang no-op và không đủ cho Unity khi user hủy/turn mới.
- Bảo đảm sequence luôn tăng đơn điệu trong cả session.
- Nếu speech mới đến trước speech cũ kết thúc, Unity bỏ cue cũ và chỉ chạy seq mới nhất.
- `Vrm10MouthCueDriver` lưu `activeSeq`, bỏ qua stale stop, luôn đặt `aa=0` khi stop/kết thúc/lỗi JSON và hỗ trợ `offset_ms` khi Flutter phải flush một speech đã bắt đầu.

Audio vẫn phát bằng `just_audio` ở Flutter. Hiện `_completeTurn()` gọi `_audio.playBytes(bytes)` rồi gần như lập tức gọi `avatar.playMouthCues(...)`; do `playBytes()` suspend ngay ở `getTemporaryDirectory()`/ghi file/`setFilePath`, miệng có thể chạy trước khi audio thật sự bắt đầu. Tách audio thành `prepareBytes()` và `playPrepared()` (hoặc callback `onPlaybackStarted`): gửi/arm cue ngay sát thời điểm gọi `AudioPlayer.play()`, đợi playback xong rồi gửi stop cùng `seq`. Đo drift; mục tiêu <= khoảng 100–120 ms. Nếu Unity ready muộn, gửi `offset_ms` và bỏ cues đã qua; nếu audio đã hết thì chỉ stop. Không gửi audio sang Unity để chữa drift nhỏ.

#### 5.4 Giới hạn plugin phải tôn trọng

- Chỉ một `EmbedUnity` trên một screen/route.
- Unity runtime không unload hoàn toàn khi widget dispose; nó pause và vẫn giữ memory.
- Không gửi lệnh trước `ready`.
- Plugin dùng hành vi Unity không được tài liệu hóa để nhúng vào widget; test đúng Unity 6000.3.3f1, không tự nâng Editor.

Gate E đạt khi `flutter analyze`, Flutter debug APK và app Conversation trên máy thật đều chạy với Unity renderer, trong khi WebView code vẫn còn để rollback.

Trong giai đoạn rollout, thêm feature flag compile-time, ví dụ `--dart-define=MIKU_AVATAR_RENDERER=unity|web`; mặc định giữ `web` cho tới khi Gate E đạt, sau đó đổi default sang `unity`. Feature flag phải đi qua `AvatarSurface`, không rải điều kiện trong Conversation UI.

### Phase 6 — Kiểm thử tích hợp bắt buộc

Chạy:

```powershell
flutter pub get
flutter analyze lib/
flutter test
flutter build apk --debug
```

Trên thiết bị Android thật:

1. Cold start app, mở Conversation, nhận đúng một event `ready`.
2. Trigger lần lượt 6 emotion; quay video hoặc chụp bằng chứng.
3. Gửi ít nhất 3 lượt hội thoại thật có TTS; xác nhận miệng chạy và đóng sau audio.
4. Bấm stop/cancel khi đang nói; miệng phải đóng ngay và cue cũ không tái phát.
5. Gửi turn mới khi turn cũ đang chạy; sequence mới thắng.
6. Back về Home rồi mở Conversation lại 10 lần; không black surface, không duplicate callback.
7. Background/resume 10 lần và khóa/mở màn hình.
8. Xoay màn hình, mở bàn phím, bật/tắt mic permission.
9. Ngắt backend/network: avatar vẫn render; chỉ phần hội thoại báo lỗi.
10. Theo dõi `adb logcat` cho `FATAL EXCEPTION`, `AndroidRuntime`, `Unity`, `MikuAvatar`.
11. Ghi `adb shell dumpsys meminfo com.example.mikudayo` sau warm-up và sau 10 vòng navigation; memory không tăng vô hạn.

Sau debug pass:

```powershell
flutter build apk --release
flutter build appbundle --release
```

Ghi lại:

- SHA-256 APK/AAB.
- Kích thước trước/sau Unity.
- Device model, Android API, ABI.
- Thời gian cold start tới `ready`.
- Memory PSS sau warm-up.
- Link/path screenshot hoặc video kiểm thử.

### Phase 7 — Cleanup chỉ sau khi Gate E pass

Nếu Android Unity đã ổn:

- Thay `VrmAvatar` bằng facade Unity trong Conversation.
- Nếu không cần Windows VRM nữa: xóa `webview_flutter`, `webview_windows`, `AssetHttpServer`, `assets/web/vrm` và comment liên quan.
- Nếu vẫn giữ Windows WebView: chấp nhận fallback có tài liệu, nhưng lưu ý Flutter assets sẽ làm model bị đóng gói trùng trong Android. Nên tách chiến lược asset hoặc dùng placeholder Windows để APK Android không chứa model lần hai.
- Xác nhận APK/AAB chỉ chứa một bản model VRM.
- Không commit `Library/`, `Temp/`, `Obj/`, `Logs/`, `Builds/`.
- Quyết định rõ `android/unityLibrary`: khuyến nghị giữ generated export trong `.gitignore` và thêm script export một lệnh cho máy/CI có Unity. Nếu chọn commit export để máy không có Unity build được, phải ghi rõ nguồn generated và cân nhắc Git LFS/kích thước repo.
- Sau MVP có thể loại uLipSync để giảm size bằng cách bỏ hai helper upstream tham chiếu nó; lúc đó cập nhật THIRD_PARTY_NOTICES và không còn tuyên bố folder Model được copy nguyên trạng.
- Thêm idle/body animation có license rõ ràng.

---

## 8. Rủi ro và cách ra quyết định

| Rủi ro | Dấu hiệu | Xử lý |
|---|---|---|
| Unity installer/UAC treo | Installer chạy lâu, `Unity.exe` chưa xuất hiện | Đọc `%APPDATA%\UnityHub\logs\cli-log.json`; không chạy installer thứ hai; xác nhận UAC |
| Unity license | Batch log báo no valid license | `unity auth status/login`, mở Editor một lần và kích hoạt Personal theo luồng chính thức |
| Package Git không resolve | Package Manager error/compile thiếu namespace | Xác nhận Git/network, tag pin và package path; không đổi toàn bộ version cùng lúc |
| VRM 1.0 expression không chạy | Model hiện nhưng mặt không đổi | Log `Expression.Clips`, sửa alias/fallback, xác nhận `Vrm10Instance.Runtime` sẵn sàng |
| Blink và face ghi đè nhau | Mắt giật hoặc emotion mất mỗi frame | Giữ blink/mouth là procedural key riêng; face proxy không ghi weight blink/mouth |
| URP shader hồng/đen | Built-in pass nhưng URP fail | Reimport model sau gán pipeline; include MToon10 URP shader; kiểm tra outline feature |
| Gradle/NDK conflict | `unityLibrary` build fail, native link fail | Đồng nhất AGP, JDK17, NDK r27c, minSdk25 theo Unity 6000.3/plugin 2.0.0 |
| PlatformView đen/lifecycle crash | Standalone pass nhưng Flutter embed fail | Xác nhận exporter plugin và đúng implementation Unity 6; thử trên máy thật, không emulator |
| Memory cao | App bị kill khi back/home | Chỉ một Unity widget, pause/resume đúng; giảm texture/quality; đo PSS thay vì đoán |
| APK quá lớn/model trùng | APK tăng bất thường | Xóa Flutter VRM asset sau rollout hoặc bỏ Windows WebView fallback |
| Model bị lộ | Repo/public artifact chứa `.vrm` rời | Repo phải private; không upload model rời; kiểm tra artifact/CI |

### Fallback nếu embedded widget không ổn

Standalone Unity phải pass trước. Nếu standalone pass nhưng `flutter_embed_unity` vẫn black/crash sau hai vòng sửa có bằng chứng, dừng và trình người dùng hai lựa chọn:

1. Dùng Unity full-screen Activity/route cho toàn bộ màn Conversation — gần với Unity as a Library chính thức và ổn định hơn, nhưng phải thiết kế lại UI Conversation cho route đó.
2. Giữ WebView renderer hiện tại làm fallback trong Flutter.

Không tự âm thầm chuyển cả app sang Unity hoặc viết lại backend; đó là mở rộng scope cần người dùng duyệt.

---

## 9. Các lỗi logic hiện có cần agent sửa sớm

1. `AvatarController.setEmotion()` đang tạo `AvatarState(emotion: ...)` mới và reset sequence/cues. Thêm `copyWith`.
2. `AvatarController.stopMouth()` đang no-op. Unity cần stop event/sequence thật.
3. `Vrm10FaceExpressionProxy.SetExpressionSmoothly(name, value)` hiện bỏ qua `value` và luôn target 1.0.
4. Fallback emotion hiện chưa hoạt động đầy đủ nếu `surprised`/`relaxed` không có trong model.
5. `StopSpeech` chưa chống stop message cũ cắt speech sequence mới.
6. `MikuAvatarBridge.Start()` chỉ `Debug.Log READY`; chưa gửi `ready` tới Flutter.
7. `MikuProjectSetup.ExportAndroidLibrary()` không phải exporter cuối cho flutter_embed_unity.
8. Idle clip hiện rỗng; renderer pass không đồng nghĩa body animation đã hoàn chỉnh.
9. `RebuildScene()` luôn thêm AutoDemo + Smoke Test UI; export embedded hiện sẽ bị demo ghi đè lệnh Flutter.
10. Chưa có `Ping/Pong`, nên lần vào Conversation thứ hai có thể chờ một event `Start/ready` không bao giờ phát lại.
11. `_audio.playBytes()` chuẩn bị file bất đồng bộ trong khi cue đã bắt đầu, nên lip-sync có thể chạy sớm.

Sửa các lỗi này theo phase tương ứng, không sửa đồng loạt trước khi có compile log vì dễ che nguyên nhân gốc.

---

## 10. Bảo mật, license và Git

- Repo GitHub hiện được ghi nhận là private: `Shaichi/mikudayo-`. Xác minh lại trước khi push model.
- `.gitattributes` có `*.vrm filter=lfs diff=lfs merge=lfs -text`.
- Model gốc có license cho personal use + integrate into software, nhưng không cho redistribute bản gốc/sửa đổi. Không gửi `.vrm` qua issue, public release source, paste service hoặc public CI artifact.
- `backend/.env` chứa key; tuyệt đối không commit.
- Không commit tool clones, Unity cache, download installer hoặc log lớn.
- Không xóa các thay đổi WebView/user trước khi Unity rollout pass.

---

## 11. Definition of Done

Agent chỉ báo “hoàn thành” khi mọi ô sau có bằng chứng:

- [x] Unity 6000.3.3f1 + Android modules được cài và xác nhận.
- [x] Unity project compile sạch.
- [x] Standalone player hiển thị model + blink + 6 emotion + mouth cue (xác minh tự động + ảnh Windows; chưa thay thế gate Android thật).
- [ ] APK Unity standalone pass trên Android thật.
- [ ] URP standalone vẫn pass.
- [ ] FlutterEmbed export tạo `android/unityLibrary` bằng đúng exporter.
- [ ] Flutter analyze/test/debug build pass.
- [ ] Conversation render Unity trên máy thật.
- [ ] Audio TTS và lip cue đồng bộ chấp nhận được.
- [ ] Stop/overlap sequence đúng.
- [ ] Back/reopen, background/resume, rotation pass.
- [ ] Release APK và AAB build pass.
- [ ] Không còn model trùng không chủ ý trong Android artifact.
- [ ] License/model secrecy được giữ.
- [ ] HANDOFF này được cập nhật bằng lệnh, exit code, artifact path/hash, device và vấn đề còn lại.

---

## 12. Nguồn kỹ thuật cần đọc khi bị chặn

- ChatDollKit README và setup/migration: https://github.com/uezo/ChatdollKit
- ChatDollKit v0.8.16: https://github.com/uezo/ChatdollKit/releases/tag/v0.8.16
- UniVRM v0.127.2: https://github.com/vrm-c/UniVRM/releases/tag/v0.127.2
- UniVRM URP support: https://vrm.dev/api/material/urp/
- UniVRM shader inclusion: https://vrm.dev/api/project/include_shaders/
- uLipSync v3.1.0: https://github.com/hecomi/uLipSync/releases/tag/v3.1.0
- flutter_embed_unity 2.0.0: https://pub.dev/packages/flutter_embed_unity
- FlutterEmbed Dart API: https://pub.dev/documentation/flutter_embed_unity/latest/flutter_embed_unity/
- Unity as a Library: https://docs.unity3d.com/6000.0/Documentation/Manual/UnityasaLibrary.html
- Unity CLI: https://docs.unity.com/en-us/hub/use-unity-cli

---

## 13. Mẫu cập nhật cuối cho agent thực thi

Khi dừng hoặc bàn giao tiếp, append mục sau thay vì viết báo cáo mơ hồ:

```text
Ngày/giờ:
Phase/Gate đạt:
Files đã sửa:
Commands + exit codes:
Unity version/modules thực tế:
APK/AAB path + SHA-256:
Device + Android API:
Kết quả trực quan:
Log lỗi còn lại:
Quyết định đã đưa ra:
Việc tiếp theo chính xác:
```

---

## 14. Cập nhật thực thi 2026-08-13 00:45 (Asia/Saigon)

```text
Ngày/giờ: 2026-08-13 00:45 +07:00
Phase/Gate đạt: Gate B đạt; Gate C đạt bằng Windows standalone smoke player có ảnh/log; APK cho Gate D đã build nhưng Gate D chưa đạt vì không có thiết bị Android kết nối.
Files đã sửa: unity/MikuAvatar/Packages/manifest.json, packages-lock.json, Assets/Mikudayo/Editor/MikuProjectSetup.cs, Runtime/MikuAvatarSmokeCapture.cs, Runtime/MikuCameraFramer.cs, Runtime/Vrm10/Vrm10Blink.cs, Runtime/Vrm10/Vrm10FaceExpressionProxy.cs, scene/controller/meta generated; HANDOFF.md.
Commands + exit codes: RebuildScene exit 0; BuildWindowsSmokeTest exit 0; Windows smoke player exit 0; BuildAndroidApk exit 0; adb devices exit 0 nhưng danh sách rỗng.
Unity version/modules thực tế: 6000.3.3f1 (ef04196de0d6); Android Gradle 8.13, AGP 8.10.0, NDK 27.2.12479018 r27c, OpenJDK bundled; APK minSdk 25, target/compile SDK 36, chỉ arm64-v8a.
APK/AAB path + SHA-256: unity/MikuAvatar/Builds/Android/MikuAvatar-debug.apk; 69,995,077 byte; SHA-256 562124FBE939CC4907E15BD8B5E4791CE6D8F204A9847F7668C8CA3739500D78. Chưa có AAB.
Device + Android API: chưa có thiết bị trong adb; chưa cài/chạy APK trên máy thật.
Kết quả trực quan: Windows player render đúng model/texture/MToon, log expression thật [happy, angry, sad, relaxed, surprised, aa, ih, ou, ee, oh, blink, blinkleft, blinkright, lookup, lookdown, lookleft, lookright, neutral], lần lượt áp dụng neutral/happy/excited/thinking/embarrassed/sad, mouth cue mở và ảnh stopped đóng miệng, có log blink, không exception. Ảnh tại unity/MikuAvatar/Logs/SmokeCaptures/ (generated/ignored).
Log lỗi còn lại: Unity telemetry Curl error vì network sandbox, không ảnh hưởng build. Burst từng báo invalid signature trong import đầu nhưng compile/build sau vẫn exit 0. Chưa có bằng chứng Android runtime/lifecycle/FPS/memory.
Quyết định đã đưa ra: sửa URL UniTask thành path package thật src/UniTask/Assets/Plugins/UniTask#2.5.4; pin Unity Test Framework 1.6.0 và Timeline 1.8.10 theo Unity 6000.3; không thêm VRMShaders riêng vì MToon10 nằm trong Assets/VRM10 ở UniVRM 0.127.2; giữ Built-in RP và chưa đụng Flutter/URP đúng theo gate; Android minSdk nâng lên 25; AudioSource playOnAwake=false; giữ WebView fallback.
Việc tiếp theo chính xác: kết nối điện thoại Android thật có USB debugging, chạy adb install -r APK, cold-start và kiểm tra model/blink/6 emotion/mouth/background-resume/rotation/logcat/memory. Chỉ khi Gate D pass mới bắt đầu Phase 4 URP + FlutterEmbed exporter.
```

---

## 15. Sửa pose/camera sau kiểm tra trực quan 2026-08-13 01:41 (Asia/Saigon)

```text
Nguyên nhân ảnh dị dạng: scene smoke-test gán một Animator Controller placeholder không có clip humanoid hợp lệ, khiến tay bị giữ ở pose gập cứng; camera cũ còn tính framing theo toàn bộ renderer bounds nên tóc dài tạo nhiều khoảng trống phía trên.
Files đã sửa: Assets/Mikudayo/Runtime/MikuRelaxedPose.cs (+ .meta), Assets/Mikudayo/Runtime/MikuCameraFramer.cs, Assets/Mikudayo/Editor/MikuProjectSetup.cs, scene generated; HANDOFF.md.
Cách sửa: bỏ gán controller placeholder; giữ rest pose humanoid và áp relaxed arm pose ổn định ở LateUpdate; tắt ModelController.Update không cần thiết nhưng vẫn giữ Awake cho face/blink; camera frame theo Head/Hips thay vì hair/render bounds.
Kiểm chứng trực quan: Windows smoke player build/chạy exit 0; neutral và happy đều có tay buông tự nhiên, thân người cân đối, khung hình tập trung; ảnh ở unity/MikuAvatar/Logs/PoseFixCaptures2/01_neutral.png và 02_happy.png (generated/ignored).
Kiểm chứng hành vi: log 07-pose-fix-player.log có READY, neutral/happy/excited/thinking/embarrassed/sad, blink và SMOKE_CAPTURE_COMPLETE; không có exception/null reference/error runtime.
APK Android đã rebuild sau sửa: unity/MikuAvatar/Builds/Android/MikuAvatar-debug.apk; 90,375,500 byte; SHA-256 1E7EF1781150F6184278C06A2C253FD96BA6D798A0744524E8A766E6E63C3C96.
Build evidence: 10-pose-fix-android-build.log có `MikuAvatar: APK ready` và `Exiting batchmode successfully`; timestamp APK 2026-08-13 01:40:36 +07:00.
Gate D vẫn chưa đạt: chưa có thiết bị Android thật kết nối để cài APK và kiểm tra lifecycle/FPS/memory. Không bắt đầu URP/FlutterEmbed trước gate này.
```

---

## 16. Thêm chuyển động idle procedural 2026-08-13 03:22 (Asia/Saigon)

```text
Thay đổi: MikuRelaxedPose.cs giờ tạo idle nhẹ trực tiếp trên humanoid bones: nhịp thở ở Spine/Chest, chuyển trọng tâm rất nhỏ ở Hips, nhìn/nghiêng đầu chậm ở Neck/Head và arm breathing offset. Mọi rotation/position đều tính lại từ rest pose mỗi frame nên không tích lũy drift.
Mức chuyển động được cố ý giữ nhỏ để phù hợp giao diện companion và không tranh quyền với face expression, mouth cue hoặc VRM spring-bone tóc.
Kiểm chứng Windows: BuildWindowsSmokeTest thành công; player smoke-test tự thoát; log có `relaxed procedural idle enabled`, đủ 6 emotion, blink và SMOKE_CAPTURE_COMPLETE; không có exception/null reference/runtime error. Ảnh kiểm tra ở unity/MikuAvatar/IdleCaptures/ (generated/ignored), pose tay vẫn tự nhiên.
APK Android mới: unity/MikuAvatar/Builds/Android/MikuAvatar-debug.apk; 90,374,387 byte; SHA-256 E2EC25F27F3F692968846F9DC593A0F4B6A015696D19CC921FA51834DCE17845; timestamp 2026-08-13 03:21:55 +07:00.
Build evidence: 13-procedural-idle-android-build.log có `MikuAvatar: APK ready` và `Exiting batchmode successfully`.
Gate D vẫn cần thiết bị Android thật; chưa dùng kết quả Windows thay cho kiểm tra runtime Android.
```

---

## 17. Pose tay nghỉ tự nhiên bằng two-bone IK 2026-08-13 03:54 (Asia/Saigon)

```text
Phản hồi trực quan: pose A ban đầu khiến hai tay duỗi thẳng, đối xứng và cứng.
Thay đổi: MikuRelaxedPose.cs giờ giải two-bone IK cho từng tay từ đúng humanoid Left/RightUpperArm, LowerArm và Hand. Điểm nghỉ đặt gần hông, hơi ở trước thân; pole khuỷu thiên về phía sau. Hai bên được lệch nhẹ về cao độ/vị trí để tránh mannequin pose: một tay thả thấp hơn, tay còn lại cong nhẹ cạnh hông.
Kiểm chứng Windows: BuildWindowsSmokeTest thành công; capture neutral/thinking ở unity/MikuAvatar/NaturalArmsIkCapturesV3/ cho thấy tay không còn duỗi đối xứng hoặc ép vào váy; đủ 6 emotion/blink/mouth smoke flow và SMOKE_CAPTURE_COMPLETE; không exception/null reference/runtime error.
APK Android mới: unity/MikuAvatar/Builds/Android/MikuAvatar-debug.apk; 90,379,627 byte; SHA-256 CCC150880C3D50715119D4BAEC8246F4AC69486CC8D2ED239452FBC508264B2E; timestamp 2026-08-13 03:53:56 +07:00.
Build evidence: 26-natural-arms-android-build.log có `MikuAvatar: APK ready` và `Exiting batchmode successfully`.
Gate D vẫn cần thiết bị Android thật để xác nhận chuyển động/pose trên GPU và tỷ lệ màn hình thiết bị.
```

---

## 18. Hoàn tác pose tay IK theo yêu cầu người dùng 2026-08-13 04:05 (Asia/Saigon)

```text
Yêu cầu: quay lại pose cũ trước các thử nghiệm chỉnh tay.
Đã hoàn tác riêng phần two-bone IK/asymmetry và toàn bộ target/pole tay trong MikuRelaxedPose.cs. Khôi phục upperArmDrop=68, elbowBend=0 và arm breathing offset của bản idle trước đó. Vẫn giữ breathing/body sway/head movement, spring bone, blink, expression và mouth cue.
Kiểm chứng Windows: BuildWindowsSmokeTest thành công; capture neutral tại unity/MikuAvatar/RevertedArmsCaptures/01_neutral.png khớp pose cũ; smoke flow có SMOKE_CAPTURE_COMPLETE, không exception/null reference/runtime error.
APK Android sau hoàn tác: unity/MikuAvatar/Builds/Android/MikuAvatar-debug.apk; 90,374,387 byte; SHA-256 E3FA42542F22CA187CC189512A00B73B4721A0138A70A658ABC3577AC8562FFC; timestamp 2026-08-13 04:04:33 +07:00.
Build evidence: 29-revert-arms-android-build.log có `MikuAvatar: APK ready` và `Exiting batchmode successfully`.
```

---

## 19. Triển khai giao diện Conversation companion 2026-08-13 04:20 (Asia/Saigon)

```text
Thay đổi UI: ConversationScreen được chuyển từ app bar + avatar cố định + danh sách bubble sang companion stage toàn màn hình: nền dark/cyan, avatar phủ toàn viewport, top controls tối giản, status pill nghe/suy nghĩ/nói, phụ đề Miku nổi, nút push-to-talk trung tâm, composer mở theo yêu cầu và lịch sử chat trong draggable bottom sheet.
Pipeline giữ nguyên: gửi text, giữ mic để record/send, Gemini/VOICEVOX/RVC, emotion và mouth cues vẫn dùng ConversationViewModel/AvatarController hiện có. ConversationState thêm activeReply để phụ đề xuất hiện trong lúc synthesize/play thay vì chờ playback kết thúc.
VrmAvatar thêm width/height cấu hình để renderer lấp đầy stage. AudioService thêm setMuted(bool); nút loa trên UI điều khiển volume playback thật.
Files sửa trong lượt này: lib/features/conversation/conversation_screen.dart, conversation_view_model.dart, lib/avatar/vrm_avatar.dart, lib/data/services/audio_service.dart, HANDOFF.md.
Kiểm chứng: dart format thành công; flutter analyze `No issues found`; test/widget_test.dart pass; ba api_service_live_test không chạy được vì backend 127.0.0.1:8000 không được khởi động trong lượt này (network_error, không phải regression UI); flutter build windows --debug thành công.
Flutter Android APK: build/app/outputs/flutter-apk/app-debug.apk; 210,436,391 byte; SHA-256 49E3F169B4451B72D2A16A74D8A1A674B49988B49AC6807900CC4ED2983393EF; build assembleDebug thành công.
Giới hạn hiện tại: APK Flutter này vẫn dùng renderer WebView/three-vrm hiện tại. Unity standalone đã sẵn sàng nhưng chưa được embed vào Flutter; phải pass Gate D trên thiết bị thật rồi mới thêm URP/flutter_embed_unity theo thứ tự HANDOFF.
```
# 20. Flutter + Unity integration completed (2026-08-13)

- Embedded the Unity 6000.3 VRM renderer into the Flutter conversation screen with `flutter_embed_unity` 2.0.0.
- Converted the model import/render path to URP + MToon URP; verified the model no longer renders magenta.
- Added Flutter -> Unity emotion and mouth-cue synchronization and Unity -> Flutter ready/pong messages.
- Exported the production Unity Android library to `android/unityLibrary` and wired Gradle for Android API 25+, NDK r27c and ARM64.
- Final integrated debug APK: `build/app/outputs/flutter-apk/app-debug.apk` (561,739,089 bytes).
- Installed and smoke-tested on Samsung SM-A505F (Android API 36): Unity READY, neutral emotion, procedural idle and repeated blink all confirmed; no fatal exception after the final rebuild.
- Visual evidence: `flutter-unity-final.png`.
- Static analysis: `dart analyze lib test` -> no issues found.
