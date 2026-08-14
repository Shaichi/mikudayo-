# PROJECT STATUS / HANDOFF FOR GLM 5.2

> **Nguồn sự thật hiện tại của dự án — cập nhật ngày 2026-08-14.**
> Hãy đọc toàn bộ file này trước khi sửa code. `HANDOFF.md`, `README.md` và một số comment cũ có thể chưa phản ánh hết trạng thái mới nhất.

## 1. Mục tiêu sản phẩm

Đây là ứng dụng Flutter luyện hội thoại tiếng Nhật với nhân vật Miku 3D. Luồng chính trên Android:

```text
Người dùng nói tiếng Nhật
  → Google/Android SpeechRecognizer nhận audio trực tiếp trên điện thoại
  → Flutter chỉ nhận transcript dạng text
  → FastAPI gửi text tới Gemini
  → Gemini trả lời tiếng Nhật + emotion + sửa lỗi + từ vựng
  → Fish Audio sinh giọng Miku-like hoàn toàn online bằng reference_id
  → Flutter phát WAV và điều khiển biểu cảm/lip-sync của avatar Unity
```

Yêu cầu quan trọng của chủ dự án:

- Không chạy model giọng, CUDA hoặc GPU local; không tự host TTS/RVC.
- API key Fish chỉ nằm trong FastAPI, không nhúng vào Flutter APK.
- Android dùng nhận dạng giọng nói online của Google để ưu tiên độ chính xác.
- **Không upload audio từ Android xuống FastAPI**; chỉ gửi transcript dạng text.
- Avatar Miku phải hiển thị dọc, zoom gần giống ảnh tham chiếu: mặt ở khoảng 1/3 phía trên và thấy thân tới vùng đùi.
- Khi bàn phím mở, không được co/resize Unity hoặc đổi tỷ lệ Miku; chỉ đẩy ô nhập text lên trên bàn phím.
- Không cho màn hình hội thoại xoay ngang.

## 2. Trạng thái tổng quan

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| FastAPI + Gemini | Đã chạy | `/health` từng xác nhận `gemini=true` |
| Fish Audio online TTS | Đã tích hợp code | Cần điền `FISH_API_KEY` để kiểm tra live |
| Script khởi động backend | Đã làm | Double-click `START_BACKEND.cmd` |
| Flutter gọi backend bằng text | Đã chạy | Android gửi transcript, không gửi audio |
| Google SpeechRecognizer trên Android | Đã kiểm tra bằng máy thật | Nhận đúng `こんばんは` và `何か面白いですか` |
| Text-first/audio background | Đã giữ nguyên contract | Fish Audio chạy nền sau khi text Gemini được trả |
| Unity avatar nhúng trong Flutter Android | Đã build | Dùng `flutter_embed_unity` |
| Khóa portrait | Đã code và build APK | Chưa kiểm tra trực quan lại trên máy sau bản build cuối |
| Zoom Miku mới | Đã code, export Unity và build APK | Chưa kiểm tra trực quan lại trên máy sau bản build cuối |
| Keyboard chỉ đẩy ô text | Đã code và build APK | Chưa kiểm tra trực quan lại trên máy sau bản build cuối |
| `flutter analyze` | Đạt | `No issues found` ở lần chạy gần nhất |
| APK debug mới nhất | Đã build | 507,185,909 bytes; đường dẫn ở mục 8 |

## 3. Kiến trúc runtime hiện tại

### 3.1 Các tiến trình trên PC

| Thành phần | Địa chỉ | Vai trò |
|---|---|---|
| Fish Audio | `https://api.fish.audio/v1/tts` | TTS tiếng Nhật online, trả audio trực tiếp |
| FastAPI | `http://0.0.0.0:8000` | Gemini, lịch sử, bảo vệ Fish API key, trả audio |

Python backend hiện được ưu tiên tại:

```text
C:\Users\pc\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe
```

Nếu không có file trên, script fallback sang `backend\.venv\Scripts\python.exe`.

### 3.2 Pipeline trả lời

Endpoint chính:

```text
POST /v1/conversation/turn
```

Android gọi endpoint này bằng form text. Backend thực hiện:

1. Tạo/lấy session SQLite.
2. Gọi Gemini để lấy JSON có cấu trúc.
3. Lấy `reply_ja` và `emotion`.
4. Backend trả text/emotion ngay với `voice_mode=pending`, không chờ TTS.
5. Background task gọi Fish `/v1/tts` bằng `reply_ja`, emotion và `reference_id`.
6. Fish trả WAV/MP3/Opus trực tiếp; backend lưu tạm với đúng phần mở rộng.
7. Với WAV, backend tính mouth cues RMS. MP3/Opus hiện trả mouth cues rỗng.
8. Flutter poll `GET /v1/audio/<turn_id>/status`, sau đó phát `audio_url`.

Nếu thiếu Fish key và `ALLOW_MOCK=true`, backend trả WAV diagnostic để test UI. Nếu đã có key mà Fish lỗi, audio status chuyển sang `error` thay vì phát âm giả.

## 4. Google Speech-to-Text trên Android

Code chính: `lib/data/services/speech_recognition_service.dart`.

Đang dùng package:

```yaml
speech_to_text: ^7.4.0
```

Thiết kế đã chốt:

- Android `SpeechRecognizer`/Google xử lý microphone trực tiếp.
- Locale được đặt cố định là `ja-JP`.
- App chỉ lấy `recognizedWords`, sau đó gọi `ApiService.sendText(...)`.
- Không tạo WAV và không có API upload audio microphone.
- Nhập giọng nói hiện chỉ hỗ trợ Android; nền tảng khác vẫn nhập text và phát WAV trả lời bình thường.
- Nút microphone hỗ trợ bấm một lần để bắt đầu, bấm lần nữa để dừng/gửi; nhấn giữ và thả cũng được hỗ trợ.
- Đã xử lý race condition bằng `_voiceStartTask` và cập nhật trạng thái recording trước khi chờ khởi tạo recognizer.
- Thời gian tự kết thúc khi im lặng đã tăng từ `1.8s` lên `5s` sau khi ADB
  chứng minh recognizer thường đóng trước khi người dùng bắt đầu nói.
- App giữ kết quả không rỗng gần nhất, không để callback rỗng xóa transcript.
- Khi stop, app chờ callback muộn tối đa `1.8s`, chặn session dưới `800ms` và
  giải phóng audio playback trước khi mở microphone.

### Kiểm tra máy thật đã thành công

Thiết bị đã dùng:

```text
ADB ID: 8a855606
Tên hiển thị: 21121210C
Android 14 / API 34
```

Dịch vụ recognizer được Android chọn:

```text
com.google.android.tts/...GoogleTTSRecognitionService
```

Log đã xác nhận:

```text
[STT] initialized=true
[STT] listen locale=ja-JP
[STT] status=listening
NetworkSpeechRecognizer: Online recognizer - start listening
```

Kết quả thực tế đã nhận:

```text
こんばんは
何か面白いですか
日本の勉強
```

Bản sửa `error_no_match` ngày 2026-08-14 đã được build, cài lên thiết bị
`8a855606` và xác minh hai lượt liên tiếp nhận đúng `こんばんは` và
`日本の勉強`; không còn mất partial result sau callback rỗng.

Câu đầu đã được gửi tới backend và Miku trả lời:

```text
こんばんは！ミクです。きょうはどんなお話をしましょうか？
```

Lưu ý quan trọng: trước đây `speech_to_text.locales()` bị treo trên ROM Xiaomi sau khi initialize. Đã bỏ bước query locales và hardcode `ja-JP`. **Không thêm lại `locales()` nếu chưa kiểm tra đúng trên máy Xiaomi này.** Log SODA offline có `ConfigStatus 5`, nhưng recognizer online của Google vẫn hoạt động; đây không phải blocker vì yêu cầu là dùng online.

## 5. Flutter và Unity avatar

### 5.1 Renderer

- Android/iOS: `UnityAvatar` nhúng Unity native.
- Desktop: `VrmAvatar` qua web renderer.
- Package Android Unity:
  - `flutter_embed_unity: 2.0.0`
  - `flutter_embed_unity_6000_0_android: 2.0.0`

### 5.2 Thay đổi giao diện mới nhất

Khóa portrait được áp dụng ở ba nơi:

- `lib/main.dart`: chỉ cho `DeviceOrientation.portraitUp`.
- `android/app/src/main/AndroidManifest.xml`: `android:screenOrientation="portrait"`.
- Unity `ProjectSettings`: orientation Portrait và tắt mọi autorotate.

Không resize avatar khi mở bàn phím:

- `Scaffold.resizeToAvoidBottomInset = false`.
- Android activity dùng `android:windowSoftInputMode="adjustNothing"`.
- `MediaQuery.viewInsetsOf(context).bottom` chỉ được dùng để translate composer bằng `Matrix4.translationValues`.
- Unity viewport và các thành phần nền giữ nguyên kích thước.

Camera Miku hiện tại trong `MikuCameraFramer.cs`:

```csharp
distanceMultiplier = 0.68f;
focus = Vector3.Lerp(hips.position, head.position, 0.48f);
```

Mục tiêu bố cục: mặt nằm gần 1/3 phía trên, thân chiếm phần lớn khung dọc và thấy tới vùng đùi, giống ảnh tham chiếu người dùng đã gửi.

### 5.3 Trạng thái xác minh quan trọng

Source Unity đã được prepare, scene đã serialize `distanceMultiplier: 0.68`, module Unity đã export lại và Flutter APK đã build thành công. Tuy nhiên ADB mất kết nối sau quá trình Unity build, nên **bản zoom/portrait/keyboard mới nhất chưa được nhìn lại trực tiếp trên điện thoại**. Đây là việc ưu tiên số 1 khi tiếp tục.

## 6. Cách khởi động backend

Cách đơn giản nhất:

```text
Double-click: C:\Users\pc\Desktop\mikudayo\START_BACKEND.cmd
```

Script sẽ:

1. Kiểm tra Python backend.
2. Nhắc cấu hình `.env` nếu file chưa tồn tại.
3. Khởi động duy nhất FastAPI ở `0.0.0.0:8000`.
4. Không khởi động model giọng, CUDA hoặc tiến trình TTS local.

Kiểm tra nhanh trên PC:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Kết quả tốt cần có:

```json
{"status":"ok","gemini":true,"fish_audio":true,"mode":"live","tts_model":"s2.1-pro-free"}
```

Từ điện thoại không dùng `127.0.0.1`. URL backend trong Settings của app phải là:

```text
http://<IP-của-PC-trong-LAN-hoặc-Tailscale>:8000
```

## 7. Unity prepare và export

Unity source nằm tại:

```text
unity\MikuAvatar
```

Flutter sử dụng module Unity được export tại:

```text
android_room\android\unityLibrary
```

Sau mỗi thay đổi Unity source/scene, phải prepare và export lại. Các lệnh đã dùng thành công:

```powershell
& 'D:\Unity\Hub\Editor\6000.3.3f1\Editor\Unity.exe' `
  -batchmode -nographics -buildTarget Android `
  -projectPath 'C:\Users\pc\Desktop\mikudayo\unity\MikuAvatar' `
  -executeMethod Mikudayo.Avatar.Editor.MikuProjectSetup.PrepareEmbeddedScene `
  -quit `
  -logFile 'C:\Users\pc\Desktop\mikudayo\50-portrait-prepare.log'

& 'D:\Unity\Hub\Editor\6000.3.3f1\Editor\Unity.exe' `
  -batchmode -nographics -buildTarget Android `
  -projectPath 'C:\Users\pc\Desktop\mikudayo\unity\MikuAvatar' `
  -executeMethod ProjectExporterBatchmode.ExportProject `
  -exportPath 'C:\Users\pc\Desktop\mikudayo\android_room\android\unityLibrary' `
  -quit `
  -logFile 'C:\Users\pc\Desktop\mikudayo\51-portrait-export.log'
```

Log lần gần nhất có:

```text
Building project for Flutter succeeded
```

Không tự ý xóa `android_room/android/unityLibrary` nếu chưa sẵn sàng export lại từ Unity.

## 8. Build và cài Android

Tại thư mục root:

```powershell
flutter pub get
flutter analyze
flutter build apk --debug
```

APK mới nhất:

```text
C:\Users\pc\Desktop\mikudayo\build\app\outputs\flutter-apk\app-debug.apk
```

Thông tin build gần nhất:

```text
Kích thước: 507,185,909 bytes
Thời điểm: 2026-08-14 16:48:06
```

Cài lại khi điện thoại xuất hiện trong `adb devices`:

```powershell
adb devices
adb install -r 'C:\Users\pc\Desktop\mikudayo\build\app\outputs\flutter-apk\app-debug.apk'
```

Build sạch Unity IL2CPP cho ARMv7 + ARM64 có thể mất khoảng 20 phút. Không kết luận build bị treo chỉ vì không có log mới trong vài phút; kiểm tra process và chờ hợp lý.

## 9. File quan trọng

| File/thư mục | Trách nhiệm |
|---|---|
| `START_BACKEND.cmd` | Chỉ khởi động FastAPI; không chạy model local |
| `backend/app/api/conversation.py` | Trả text trước, chạy Fish Audio nền, cung cấp audio status |
| `backend/app/services/fish_audio_service.py` | Gọi Fish `/v1/tts`, map emotion/prosody và định dạng audio |
| `backend/app/core/config.py` | Cấu hình Gemini và Fish Audio |
| `backend/.env.example` | Mẫu biến môi trường, không chứa secret thật |
| `lib/data/services/speech_recognition_service.dart` | Google/Android STT, trả transcript text |
| `lib/data/services/api_service.dart` | Gọi FastAPI bằng text và parse response |
| `lib/features/conversation/conversation_view_model.dart` | Luồng mic, gửi text, phát audio và state hội thoại |
| `lib/features/conversation/conversation_screen.dart` | UI Miku, subtitle, mic, composer và keyboard behavior |
| `lib/main.dart` | Khởi tạo app và khóa portrait Flutter |
| `android/app/src/main/AndroidManifest.xml` | Permission mic/internet, portrait, soft input |
| `unity/MikuAvatar/Assets/Mikudayo/Runtime/MikuCameraFramer.cs` | Crop/zoom camera Miku |
| `unity/MikuAvatar/Assets/Mikudayo/Editor/MikuProjectSetup.cs` | Tạo/prepare embedded Unity scene |
| `unity/MikuAvatar/Assets/Mikudayo/Scenes/MikuAvatar.unity` | Scene đã serialize |

## 10. Vấn đề đã biết và việc chưa hoàn tất

### Ưu tiên cao

1. Kết nối lại điện thoại bằng ADB và cài APK mới nhất.
2. Kiểm tra trực quan đúng bốn điều:
   - màn hình không xoay ngang;
   - Miku đã zoom gần giống ảnh tham chiếu;
   - mở bàn phím không làm Miku co lại;
   - chỉ ô nhập text được đẩy lên trên bàn phím.
3. Điền `FISH_API_KEY`, thử microphone Google → transcript → Gemini → Fish Audio và quan sát emotion/avatar end-to-end.

### Kỹ thuật cần dọn sau khi UI được duyệt

- Luồng recorder/upload audio và STT backend cũ đã được xóa; backend chỉ nhận text.
- Flutter build cảnh báo NDK: app/Unity đang pin `27.2.12479018`, trong khi `speech_to_text` và `jni` đề nghị `28.2.13676358`. Build hiện vẫn thành công. Không đổi NDK riêng lẻ nếu chưa kiểm tra tương thích Unity + Flutter cùng lúc.
- APK debug khoảng 507 MB do Unity native libs/debug symbols. Tối ưu release/ABI/symbol chưa làm.
- Fish free model/campaign có thể thay đổi; chuẩn bị đổi `FISH_MODEL` khi gói hiện tại kết thúc.
- Public voice có thể bị gỡ hoặc đổi quyền. Khi đó thay `FISH_REFERENCE_ID`.
- SSE/WebSocket streaming thật chưa nối vào Flutter; bản hiện tại dùng REST background để giữ contract ổn định.

## 11. Trạng thái Git và quy tắc an toàn

Branch hiện tại:

```text
codex/fish-audio-tts
```

Worktree đang có nhiều thay đổi chưa commit, gồm cả source, Unity scene/export, test và file do người dùng tạo. **Không reset, checkout đè, clean hoặc xóa hàng loạt.** Trước khi commit phải xem `git diff` và chọn đúng file.

Một số file untracked đáng chú ý:

```text
START_BACKEND.cmd
backend/app/services/fish_audio_service.py
backend/tests/
lib/data/services/speech_recognition_service.dart
tailscale-setup-1.102.2-amd64.msi
tailscale-setup-latest.exe
unity/MikuAvatar/Assets/Mikudayo/Backgrounds/
```

Hai installer Tailscale không phải source của app; không đưa vào commit dự án. Không commit:

- `.env` có API key;
- audio người dùng, SQLite runtime hoặc file tạm;
- installer ngoài dự án;
- generated/cache không cần thiết.

## 12. Chỉ dẫn dành cho agent tiếp theo

Khi tiếp tục dự án:

1. Dùng file này làm baseline, sau đó kiểm chứng lại bằng code/log hiện tại.
2. TTS hiện tại là **Fish Audio online**; không khôi phục model giọng local.
3. Không thêm lại upload audio; yêu cầu đã chốt là Google SpeechRecognizer trên điện thoại và chỉ gửi text.
4. Không thêm lại gọi `speech_to_text.locales()` trên Xiaomi nếu chưa có phương án timeout/fallback đã test.
5. Không làm resize Unity khi bàn phím mở.
6. Sau khi sửa Unity, chạy cả prepare + export trước khi build Flutter.
7. Không tuyên bố zoom/keyboard đã đạt yêu cầu hình ảnh cho đến khi cài APK mới nhất và nhìn trên máy thật.
8. Bảo toàn các thay đổi chưa commit và không thực hiện thao tác Git phá hủy dữ liệu.
9. Nếu điều chỉnh camera, thay đổi nhỏ quanh `distanceMultiplier = 0.68f`, export, build và so sánh trên máy thật; tránh chỉnh nhiều biến cùng lúc.
10. Cập nhật lại file này sau mỗi mốc đã xác minh để agent sau không dựa vào trạng thái cũ.

## 13. Tiêu chí hoàn thành mốc tiếp theo

Mốc UI + voice hiện tại chỉ được coi là hoàn tất khi máy Android thật xác nhận:

- app chỉ chạy portrait;
- Miku có crop/zoom đúng ảnh tham chiếu;
- bàn phím không làm thay đổi kích thước hoặc tỷ lệ avatar;
- nhập text và microphone đều gửi được câu;
- Google recognizer online nhận tiếng Nhật;
- backend trả phản hồi Gemini;
- audio cuối có `voice_mode=fish_audio` khi Gemini và Fish được cấu hình;
- emotion của phản hồi được phản ánh hợp lý ở giọng và avatar;
- không có crash hoặc mất tương tác sau vài lượt liên tiếp.
