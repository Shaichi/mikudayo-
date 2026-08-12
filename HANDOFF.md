# BÀN GIAO — Miku Japanese Conversation (Flutter + Gemini + VOICEVOX + RVC + Live2D)

> **Trạng thái:** Phiên 2 (2026-08-12) đã hoàn thành **Phase 0 → Phase 5** +
> scaffold **Phase 6 (research)**. Cả 3 engine thật (Gemini/VOICEVOX/RVC) đã
> verify end-to-end — `voice_mode:"rvc"`, giọng Miku thật. Đã push lên GitHub
> `Shaichi/mikudayo-` (branch main).
> Tài liệu gốc: `Tai_lieu_du_an_Miku_Japanese_Conversation_Flutter (1).docx`.

---

## 0. TÍCH HỢP VRM 3D (mới — Phiên 3)

> **Trạng thái:** Model Miku 3D thật (VRM 1.0) render trong app qua
> WebView2 + three.js. VERIFIED — model load, emotion + lip-sync + blink hoạt động.

### 0.1 Cách hoạt động
- `web/vrm/index.html` — trang renderer dùng `three.js` + `@pixiv/three-vrm`
  (CDN qua importmap). Load model từ `web/vrm-model/`.
- `web/vrm-model/茶味式　初音ミク vrm 1.0.vrm` — model thật (26MB) được Flutter map
  thành host `app.local` qua `addVirtualHostNameMapping` (WebView2 Windows).
- `lib/avatar/vrm_avatar.dart` — widget `VrmAvatar` (ConsumerStatefulWidget): khởi
  tạo WebviewController, listen `webMessage` cho `{type:'loaded'}`, watch
  `avatarControllerProvider` và `postWebMessage` emotion/mouth lên JS.
- UI: `conversation_screen.dart` `_Header` dùng `VrmAvatar` thay `MikuAvatar`(emoji).

### 0.2 Xử lý emotion + lip-sync (JS trong index.html)
- **Emotion**: `applyEmotion(emo)` map `MikuEmotion` → preset VRM
  (neutral/happy/excited/thinking/embarrassed/sad → neutral/happy/happy/relaxed/happy/sad),
  reset preset cũ, set preset mới = 1.
- **Lip-sync**: `mouth` → `targetMouth` → nội suy → `expressionManager.setValue('aa', ...)`.
- **Blink**: timer 3s set `blink` 1 rồi 0.

### 0.3 Gotcha quan trọng (đã chạy thật)
- **Không dùng `import` URL trực tiếp** cho CDN trong ESM — WebView2 Virtual Host
  Mapping origin chặn direct-URL ESM import (script không chạy). **Phải dùng importmap**.
- Bug từng gặp: `new THREE.GLTFLoader()` sai (GLTFLoader không nằm trong THREE
  namespace) → đúng `new GLTFLoader()` (import riêng từ `three/addons/loaders/`).
- `addVirtualHostNameMapping` phải gọi SAU `initialize()` (dùng `_methodChannel` late).

### 0.4 License model — KHÔNG được phân phối bản gốc
- Model `茶味式　初音ミク` (author: nao_0902 / tyami-store booth). License đọc từ
  `利用規約/20241028105600vn3license_en.pdf` (đã extract full text).
- ✅ Personal use, integration vào software (R), chỉnh file format — **Permitted**.
- ⚠️ **Redistribution original version (M) + modified (N) — PROHIBITED.**
  → **KHÔNG commit model lên GitHub public.** Chỉ commit nếu repo PRIVATE.
  File license gốc giữ trong thư mục `茶味式　初音ミク/` (gitignored) — KHÔNG commit.
- Repo hiện tại: **PRIVATE** `Shaichi/mikudayo-` → model trong `web/vrm-model/`
  an toàn khi commit (chỉ mình bạn truy cập).

### 0.5 Build / chạy
- `flutter build windows --debug` → `build/windows/x64/runner/Debug/mikudayo.exe`.
- WebView2 runtime có sẵn trên Windows 11. CDN cần internet lần đầu (three.js/three-vrm).
- `flutter analyze` → 0 issues. Test live backend vẫn chạy độc lập.

### 0.6 Hướng tiếp theo đã chốt
- Sau VRM: **redesign toàn app theo "Dark hologram Futuristic"** (UI + cải tiến UX,
  backend không đổi). User đã chọn scope này.

---

## 1. ĐÃ HOÀN THÀNH (Phiên 2 — Phase 0–5 + Phase 6 scaffold)

> Mục 1.1/1.2 giữ lại từ đầu phiên (Phase 0+1). Mục 1.5 trở đi là phần mới
> Phase 2–6 trong cùng phiên.

### 1.1 Backend Phase 1 — VERIFIED ✅
Đã chạy thật với mock mode và test toàn bộ endpoints:

| Kiểm thử | Kết quả |
|---|---|
| `GET /health` | ✅ `{status:ok, mode:mock, gemini:false,...}` |
| `POST /v1/conversation/turn` (text) | ✅ trả reply_ja, emotion, vocabulary, turn_id, session_id, voice_mode=mock |
| Session reuse | ✅ gửi `session_id` → dùng chung phiên |
| Correction mode | ✅ trả correction_ja + explanation_vi |
| `GET /v1/sessions` + `/turns` | ✅ |
| `GET /v1/vocabulary` | ✅ |
| `DELETE /v1/sessions/{id}` | ✅ |

- File `.env` đã tạo (copy từ `.env.example`, GEMINI_API_KEY trống → mock).
- Backend chạy: `python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000`.

### 1.2 Flutter Phase 0+1 — XONG ✅
Thay mẫu counter bằng app hoàn chỉnh:

**Cấu trúc `lib/`:**
```
lib/
  app/        app.dart (MikuApp + ProviderScope), theme.dart (cyan #00A0B0/#39C2D7), router.dart
  core/       config/server_config.dart, errors/api_exception.dart
  data/
    models/   conversation_turn.dart (ConversationResult, VocabItem, MouthCue, MikuEmotion),
              session_record.dart, vocabulary_record.dart
    services/ api_service.dart (http: sendText, getSessions, getTurns, getVocabulary,
              deleteSession, health)
    repositories/ conversation_repository.dart, settings_repository.dart (shared_preferences)
  features/
    home/            home_screen.dart (nav 4 tính năng, hero avatar)
    conversation/    conversation_screen.dart, conversation_view_model.dart,
                     widgets/{chat_bubble,vocab_chip,miku_avatar}.dart
    history/         history_screen.dart (sessions → detail turns → delete)
    vocabulary/      vocabulary_screen.dart
    settings/        settings_screen.dart (server URL, mode, level, scenario + health check)
  avatar/    avatar_controller.dart (placeholder Phase 5)
  main.dart  (init SharedPreferences → override settingsRepositoryProvider)
```

**Tính năng Phase 1:**
- Text chat → backend → bubble reply_ja + transcript + correction_ja + explanation_vi
  + emotion badge (😊😄😆🤔😳😢) + vocabulary chips.
- Avatar Miku hình tròn gradient cyan + emoji cảm xúc.
- State machine `idle → thinking → idle | error` (ApiException message thân thiện).
- History / Vocabulary / Settings đầy đủ, lưu settings local.

**Dependencies thêm:** `http`, `flutter_riverpod`, `path_provider`, `shared_preferences`.

### 1.3 Kiểm thử Flutter ✅
- `flutter analyze` → **No issues found**.
- `flutter test` → widget test pass (home screen hiển thị); integration test
  (`test/api_service_live_test.dart`) pass khi backend mock chạy (mặc định skip).
- `flutter build windows --debug` → ✅ build OK.
- Chạy thử `mikudayo.exe` → process chạy, không crash.
- Smoke test full flow (3 lượt chat + history + vocab) qua API → OK.

### 1.4 README + HANDOFF ✅
- `README.md` chính thức: giới thiệu, kiến trúc, cách chạy backend (mock + live),
  cách chạy Flutter (desktop/phone/emulator), checklist Phase 1–6, bảo mật, license.
- `.gitignore` gốc bổ sung backend/.env, data/, *.wav.
- DB `backend/data/miku.db` đã xóa để bàn giao sạch (server tạo lại khi chạy).

---

## 1.5 PHASE 2–6 ĐÃ TRIỂN KHAI (cùng phiên)

### 1.5.1 Backend Phase 2–5 — VERIFIED ✅

| Thành phần | File | Trạng thái |
|---|---|---|
| Audio upload + transcribe | `app/api/conversation.py` (field `audio`), `gemini_service.generate_turn(audio_bytes)` | ✅ mock trả `（音声入力・モック）…`; live: **faster-whisper transcribe → Gemini text** |
| TTS | `services/voicevox_service.py` `synthesize()` = `/audio_query` → `/synthesis`; `mock_wav()` 440+880Hz khi engine tắt | ✅ |
| RVC | `services/rvc_service.py` `convert()` POST `/convert`; fallback source.wav khi worker lỗi | ✅ |
| Lip-sync | `services/lipsync_service.py` RMS 50ms → `MouthCue{t_ms,mouth}` | ✅ |
| Audio endpoint | `GET /v1/audio/{turn_id}` → FileResponse wav | ✅ |
| `/health` engine flags | `voicevox`, `rvc` | ✅ |

Full pipeline thử thật (mock): `POST turn text → reply_ja + emotion + audio_url +
16 mouth_cues`, tải audio về = WAV RIFF hợp lệ. `sendAudio` upload → transcript mock
+ reply + cues.

### 1.5.2.5 STT faster-whisper (Phase 2+) — VERIFIED ✅

- `pip install faster-whisper` + `app/services/stt_service.py` (transcribe WAV → text).
- Pipeline: **audio mic → Whisper transcribe → Gemini text-only → reply → TTS → RVC**.
  → KHÔNG cần model Gemini hỗ trợ audio → dùng `gemini-3.5-flash-lite` (nhanh/nhẹ).
- Model `small` (~500MB), device tự chọn (CUDA/CPU), `WHISPER_LANGUAGE=ja`.
- Audio rỗng/không nghe rõ → `400 "Không nghe rõ bạn nói gì."` (thân thiện).
- Verified: VOICEVOX 発話 "こんにちは…" → Whisper transcribe chính xác
  `こんにちは私はミクです日本語を練習しましょう` → Gemini reply → voice_mode=rvc.
- Log UTF-8 fix trong `core/logging.py` (Windows console cp1252 gây UnicodeEncodeError).

### 1.5.2.6 Prompt nhất quán — VERIFIED ✅

- **Gốc rễ "lộn xộn"**: `contents` gửi dạng **string thô** → Gemini **bỏ qua
  user input**, trả reply chung chung (`transcript_ja:"（なし）"`). Fix: gửi
  `contents = types.UserContent(parts=[types.Part(text=user_text)])`.
- Viết lại `SYSTEM_PROMPT_TEMPLATE`: **Output contract** (mô tả từng field của
  schema), **Language**, **Speaking style** (1–3 câu ngắn, ấm áp, Miku persona),
  **Mode-specific rules** (free_talk/correction/roleplay), **Level matching**
  (difficulty = jlpt_level), **Context** (mode/scenario/level/summary/recent).
- Thêm param `scenario` vào `build_prompt`/`generate_turn` + plumb qua
  `conversation.py` (form field `scenario`).
- Verified 3 mode qua HTTP (requests lib): free_talk trả lời tự nhiên + 1 câu
  hỏi; correction bắt đúng lỗi `ますた→ました` + giải thích tiếng Việt; roleplay
  đóng vai đúng (店員 nói `いらっしゃいませ！`).
- **Lưu ý push GitHub**: mạng chặn HTTP/2 → lỗi "Failed to connect github.com
  port 443" dù curl OK. Fix: `git config http.version HTTP/1.1` (đã set local).

### 1.5.2 Flutter Phase 2–5 — XONG ✅

- **Push-to-talk** (`conversation_screen.dart` `_InputBar`): giữ mic → `recording` (đếm
  giây), nhả → `stopRecordingAndSend()`, kéo ra ngoài → hủy. Mic record package
  (WAV 16kHz mono) qua `data/services/audio_service.dart`.
- **Playback** just_audio: `_completeTurn` tải audio_bytes → `playBytes` song song
  `avatar.playMouthCues(mouthCues)`.
- **Avatar lip-sync**: `avatar_controller.dart` `AvatarState.mouthOpen` + `playMouthCues()`
  (Timer 30ms nội suy cue), `miku_avatar.dart` scale emoji theo `mouthOpen`.
- **Live2D bridge**: `lib/avatar/live2d_bridge.dart` — abstract `Live2dBridge` +
  `NoopLive2dBridge`. Khi có SDK thật chỉ cần implement + `setBridge()`, UI không đổi.

### 1.5.3 Phase 6 scaffold (research) 🔬

- `backend/app/api/realtime.py` — WebSocket `/v2/live`: nhận text event + PCM chunk,
  ack round-trip (đã test WS: event.ack, pcm.ack, disconnect OK).
- Chưa nối Gemini Live (Preview, stateful WSS, PCM 16k/24k). Giữ push-to-talk là
  sản phẩm chính; merge realtime chỉ khi latency < ~1s (mục 14.1 tài liệu).

### 1.5.4 Kiểm thử Phase 2–5 ✅

- `flutter analyze` → **No issues found** (sửa `dispose()` → `ref.onDispose` trong
  `avatar_controller.dart`, `prefer_function_declarations_over_variables` trong test).
- `flutter test` → **4/4 pass** (3 live integration vs backend mock + widget test).
- `flutter build windows --debug` → ✅ build OK.
- Live WS test `/v2/live` round-trip OK.

### 1.5.5 RVC live — VERIFIED ✅ (3 engine thật)

Cài **cả 3 engine chạy thật** và verify end-to-end (text → Gemini → VOICEVOX → RVC):

| Thành phần | Trạng thái live |
|---|---|
| Gemini | ✅ `gemini:true`, model `gemini-3.5-flash-lite` (key thật, text-only + Whisper STT) |
| VOICEVOX | ✅ `voicevox:true` (app 0.25.2, port 50021, speaker 0) |
| RVC | ✅ `rvc:true` (worker port 8010, model `miku_mellow_rvc.pth`, GPU) |

- **RVC worker**: `backend/rvc_worker.py` (port 8010) — môi trường riêng
  `.venv-rvc` (Python 3.10, fairseq không chạy 3.11). Cần `pip<=24.0` nếu
  omegaconf lỗi metadata. Model `miku_mellow_rvc.pth` + `.index` trong
  `backend/models/` (gitignore).
- **Verify thật**: `POST /v1/conversation/turn` text → `voice_mode:"rvc"`,
  audio download = WAV **40kHz mono 7.28s 582KB**; RVC worker log
  `convert OK: 350252 -> 582444 bytes in 2.57s` (GPU, lần đầu ~66s cold→warm).
- Bước vẽ: `<source>` (24kHz VOICEVOX) → `/convert` → RVC output (40kHz),
  fallback về source.wav khi worker lỗi (`rvc_fallback`).
- RVC API: `set_params(f0up_key=0, f0method="rmvpe")` rồi `infer_file(in,out)`
  — `infer_file` KHÔNG nhận kwargs.

### 1.5.6 Git

- Repo `https://github.com/Shaichi/mikudayo-.git`, branch `main`, đã push.
- `.gitignore` bổ sung: `.env`, `data/`, `audio/`, `build/`, `.claude/`,
  `backend/.venv-rvc/`, `backend/models/`.

---

## 2. VIỆC CÒN LẠI (defer — chỉ khi cần)

> Phase 2–5 đã xong. Chỉ còn việc *optional* dưới đây.

### Defer A — cài engine thật (đã xong ✅, giữ lại để reference)
> Đã cài + verify 3 engine thật ở mục 1.5.5. Nếu build trên máy mới:
- Cài **VOICEVOX** (cổng 50021) → `/health` báo `voicevox:true`; giọng Miku-like.
- Chạy **RVC worker** (cổng 8010) + load model → `rvc:true`, nghe giọng chuyển đổi.
- Điền `GEMINI_API_KEY` vào `.env` → trả lời + transcribe thật (thay mock).

### Defer B — Live2D avatar thật
- Chưa có SDK Live2D chính thức cho Flutter (mục 10 tài liệu). Implement
  `Live2dBridge` (web/native), gọi `avatarController.setBridge()` — UI không đổi.

### Defer C — Phase 6 Realtime (research only)
- Gemini Live là Preview: stateful WebSocket, PCM 16kHz in / 24kHz out [S7][S24].
- Khung `/v2/live` đã có (event + PCM ack). Khi thử: nối Gemini Live client,
  đo latency; merge nhánh chỉ khi < ~1s và ổn định.

---

## 3. LƯU Ý KỸ THUẬT
- Backend mock khi `GEMINI_API_KEY` trống → toàn pipeline UI test được không cần key.
  VOICEVOX/RVC tắt → tự mock WAV / fallback, app vẫn chạy đủ pipeline.
- Key Gemini chỉ trong `backend/.env`, không commit. Google chuyển auth keys từ 09/2026.
- Environment: Windows 11, Python 3.11.15, Flutter 3.41.9 / Dart 3.11.5.
- Git: repo `Shaichi/mikudayo-`, branch `main`, đã push (README + HANDOFF + full source).
- Console Windows không hiển thị UTF-8 qua `curl` (ra `?????`) — test bằng
  `PYTHONIOENCODING=utf-8 python -c "..."` với httpx, hoặc dùng `-F "text=..."`
  với tool hỗ trợ UTF-8.
- Backend chạy mock mode 3 engine: có thể xóa `backend/data/miku.db` + `backend/data/audio/`
  bất cứ lúc nào — server tự tạo lại.
