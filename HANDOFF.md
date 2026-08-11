# BÀN GIAO — Miku Japanese Conversation (Flutter + Gemini + VOICEVOX + RVC + Live2D)

> **Trạng thái:** Phiên 2 (2026-08-12) đã hoàn thành **Phase 0 → Phase 5** +
> scaffold **Phase 6 (research)**. Toàn pipeline chạy end-to-end với mock
> fallback cho cả 3 engine. Đã push lên GitHub `Shaichi/mikudayo-` (branch main).
> Tài liệu gốc: `Tai_lieu_du_an_Miku_Japanese_Conversation_Flutter (1).docx`.

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
| Audio upload + transcribe | `app/api/conversation.py` (field `audio`), `gemini_service.generate_turn(audio_bytes)` | ✅ mock trả `（音声入力・モック）…`; live gửi `types.Part.from_bytes` |
| TTS | `services/voicevox_service.py` `synthesize()` = `/audio_query` → `/synthesis`; `mock_wav()` 440+880Hz khi engine tắt | ✅ |
| RVC | `services/rvc_service.py` `convert()` POST `/convert`; fallback source.wav khi worker lỗi | ✅ |
| Lip-sync | `services/lipsync_service.py` RMS 50ms → `MouthCue{t_ms,mouth}` | ✅ |
| Audio endpoint | `GET /v1/audio/{turn_id}` → FileResponse wav | ✅ |
| `/health` engine flags | `voicevox`, `rvc` | ✅ |

Full pipeline thử thật (mock): `POST turn text → reply_ja + emotion + audio_url +
16 mouth_cues`, tải audio về = WAV RIFF hợp lệ. `sendAudio` upload → transcript mock
+ reply + cues.

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

### 1.5.5 Git

- Repo `https://github.com/Shaichi/mikudayo-.git`, branch `main`, đã push.
- `.gitignore` bổ sung: `.env`, `data/`, `audio/`, `build/`, `.claude/`.

---

## 2. VIỆC CÒN LẠI (defer — chỉ khi cần)

> Phase 2–5 đã xong. Chỉ còn việc *optional* dưới đây.

### Defer A — Cài engine thật để nghe giọng thật
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
