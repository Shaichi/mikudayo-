# BÀI TOÁN: Chọn cách render Miku 3D (VRM) trong app Flutter — cần tư vấn

> File này ghi lại đầy đủ vấn đề + hiện trạng + các hướng đã đánh giá, để trình
> một AI khác (hoặc kỹ sư khác) tư vấn khách quan.
>
> **Yêu cầu cần được trả lời:** Nên chọn hướng nào giữa (1) three.js trong WebView,
> (2) embed Unity, (3) 2D-animated kiểu Grok, hay hướng khác? Nêu rõ lý do + cách triển khai.

---

## 1. Bối cảnh dự án

- **App:** "Miku Japanese Conversation" — app hội thoại tiếng Nhật với nhân vật Miku.
- **Stack:** Flutter (frontend, đã có Android + Windows target) + FastAPI (backend).
  Voice: AivisSpeech + RVC. AI trả lời: Gemini.
- **Mục tiêu hiện tại:** có **mô hình Miku 3D** render trong app (avatar), với:
  - **Đầy đủ cảm xúc** (happy / sad / excited / thinking / embarrassed / neutral)
  - **Miệng mấp máy đúng lúc nói** (lip-sync theo audio + mouth cues từ backend)
  - Nhấp nháy mắt tự nhiên.
- **Model đã có:** file VRM 1.0 `茶味式　初音ミク vrm 1.0.vrm` (26MB, fan-made,
  cho phép personal use + tích hợp software, nhưng KHÔNG được phân phối lại bản gốc).
  Đã kiểm tra: có đủ expressions (happy/angry/sad/relaxed/surprised/neutral),
  visemes (aa/ih/ou/ee/oh), blink presets, LookAt.
- **Người dùng:** dùng cá nhân, không thương mại. Mục tiêu chạy **chủ yếu trên Android**,
  không quan trọng Windows desktop.

---

## 2. Kiến trúc hiện tại của app (liên quan avatar)

- Flutter có `AvatarController` (Riverpod Notifier) quản lý state:
  `emotion` (`MikuEmotion`) + `mouthOpen` (0..1). Backend trả `MouthCue` (list
  {t_ms, mouth}) đồng bộ với audio → `playMouthCues` cập nhật `mouthOpen` 30ms/lần.
- Có contract `Live2dBridge` (abstract) + `NoopLive2dBridge` (fallback).
- Trước đây avatar là **emoji** trong hình tròn (`MikuAvatar`).

---

## 3. Hiện trạng: đã làm được gì với hướng three.js + WebView

Đã triển khai và **chạy thành công trên Windows** (WebView2):

- Trang `index.html` dùng **three.js** (`three.module.js`) + **`@pixiv/three-vrm`**
  (loader VRM **chính thức** của VRM Consortium cho web) + `GLTFLoader`.
- Flutter map thư mục chứa trang + model thành host ảo (`addVirtualHostNameMapping`
  trên webview_windows) → fetch model cùng origin → không CORS.
- Giao tiếp 2 chiều:
  - Web → Flutter: `postMessage` (nhận `{type:'loaded'}`).
  - Flutter → Web: `postWebMessage` (gửi `{type:'emotion', value}` / `{type:'mouth', value}`).
- Emotion map sang VRM preset (`happy→happy`, `thinking→relaxed`, `excited→embarrassed→happy`,
  `sad→sad`). Lip-sync qua viseme `AA`. Blink timer.
- **Xác minh được trên Windows:** `flutter analyze` 0 issues, build OK, log cho thấy
  model load, emotion + lip-sync + blink hoạt động.

**Đã gặp + sửa 1 lỗi trên Windows (học được):**
- Không dùng `import` URL CDN trực tiếp trong ESM module — WebView2 Virtual Host
  Mapping chặn direct-URL ESM import từ origin khác. **Phải dùng importmap.**
- Bug: `new THREE.GLTFLoader()` sai (GLTFLoader không nằm trong THREE namespace);
  đúng `new GLTFLoader()` (import riêng).

---

## 4. Vấn đề đang chặn: Android WebView CORS với ESM module

- Chuyển sang **webview_flutter** (cho Android/iOS), dùng **`loadFlutterAsset`** →
  trên Android load qua **`file:///android_asset/flutter_assets/...`** với origin `null`.
- Với origin `null` (file://), **Android WebView CHẶN import ESM module** vì CORS:
  - Chromium log: *"Access to script at 'file:///.../three.module.js' from origin
    'null' has been blocked by CORS policy: Cross origin requests are only supported
    for protocol schemes: chrome, chrome-untrusted, data, http, https."*
- Kết quả: script module không chạy, Miku 3D không hiện trên Android (chỉ khung rỗng).

---

## 5. Các hướng đang cân nhắc (cần bạn quyết giúp)

### Hướng A — three.js trong WebView (đang làm, gần ra)
Chuyển các file ESM import chéo (three.module + GLTFLoader + three-vrm, cả 3 import
barename `"three"`) thành sản phẩm chạy được trên Android WebView.

**Các sub-lựa chọn:**
- **A1. Bundle bằng esbuild** → 1 file JS self-contained (không còn import), nhúng
  vào HTML string, nạp bằng `loadHtmlString` (baseUrl https hợp lệ) hoặc file. Không
  CORS, không cần importmap. (Đang chuẩn bị làm; `npx esbuild` đã test OK.)
- A2. Dùng `WebViewAssetLoader` (AndroidX) map asset → `https://appassets.androidplatform.net/`
  (origin https hợp lệ) — cần custom native (plugin webview_flutter_android không expose
  trực tiếp từ Dart), phức tạp hơn A1.
- A3. Nhúng JS trực tiếp vào HTML string (inline), tránh import file — nhưng vẫn cần
  import chéo, không khả thi khi không có origin hợp lệ.

**Ưu:** giữ đúng model VRM 3D của user; `three-vrm` là loader VRM chính thức; nhẹ
(chỉ thêm model + trang); chỉ cần Flutter; giao tiếp 2 chiều rõ ràng.
**Nhược:** render 3D trên WebView kém hiệu năng hơn native/Unity (với 1 VRM đơn thì
ổn); physics tóc/váy + shader không bằng Unity; chất lượng trông "web-y" hơn.

### Hướng B — Embed Unity (với flutter_unity_widget)
- UniVRM là loader VRM gốc của hệ sinh thái VRM; chất lượng blendshape, physics tóc/váy,
  shader tốt hơn.
- **Nhưng:** bắt buộc cài **Unity Editor** + tạo Unity project + xuất player qua
  `flutter_unity_widget`.
- Binary Android tăng **+100–200MB** (Unity player).
- `flutter_unity_widget` nổi tiếng **dễ vỡ**: loạn version Unity/AGP/Gradle, build
  release hay lỗi, hỗ trợ iOS kém, duy trì bấp bênh.
- Với Flutter mới (3.4x / sdk ^3.11) khả năng đụng lỗi tích hợp cao.

### Hướng C — 2D-animated "kiểu Grok"
- Grok/xAI dùng **2D skeleton/Live2D-style** (mắt, miệng, tóc chuyển động trên nền
  neon), không phải 3D.
- Trong Flutter: có thể dùng Live2D qua WebView, hoặc sprite/chuyển động 2D thuần Flutter.
- **Đơn giản, nhẹ, an toàn đa nền tảng** (Android + iOS).
- **Nhưng lùi lại so với yêu cầu gốc** của user: user muốn **3D Miku thật**, không
  phải 2D hoạt hình.

---

## 6. Câu hỏi cần tư vấn

1. Với **mục tiêu Android + model VRM 1.0 + yêu cầu emotion & lip-sync**, bạn chọn
   hướng nào (A/B/C hay khác)? Vì sao?
2. Nếu là hướng A: A1 (esbuild bundle 1 file) có phải cách tốt nhất để giải CORS
   file:// trên Android WebView không? Có hạn chế gì (hiệu năng, memory, mix-klip)?
3. Có giải pháp "importmap hoặc ESM chạy được trên Android WebView file://" mà tôi
   chưa thử không (vd `setAllowFileAccess`/`setAllowFileAccessFromFileURLs`/`setAllowUniversalAccessFromFileURLs`,
   hay `loadDataWithBaseURL` với baseUrl https để có origin hợp lệ)?
4. Khuyến nghị dùng `webview_flutter` hay bản `webview_flutter_android` v4.12 có cách
   nào expose `WebViewAssetLoader` / custom WebViewClient từ Dart không, hay phải viết
   native plugin riêng?
5. Nếu đổi sang Unity hoặc 2D: công sức ước tính + rủi ro với Flutter hiện tại?

---

## 7. Môi trường kỹ thuật (để tư vấn chính xác)

- Flutter 3.41.9 / Dart 3.11.5, `webview_flutter ^4.14.1` + `webview_flutter_android 4.12.0`.
- Windows 11, Android SDK 36.1.0; máy có Android device (API 34) để test.
- `pubspec.yaml`: không cài `flutter_unity_widget` hay Live2D SDK.
- Model: `茶味式　初音ミク vrm 1.0.vrm` (26MB, VRM 1.0), nằm trong `web/vrm-model/`
  (Windows build) và `assets/web/vrm-model/` (prepared cho Android).
- Muốn build release APK/AAB cho mục đích cá nhân.
