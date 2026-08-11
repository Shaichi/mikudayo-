# BÀN GIAO — Miku Japanese Conversation (Flutter + Gemini + VOICEVOX + RVC + Live2D)

> **Trạng thái:** Phiên 2 (2026-08-12) đã hoàn thành **Phase 0 + Phase 1** —
> backend chạy mock, Flutter text chat end-to-end hoạt động, README + tests OK.
> Tài liệu gốc: `Tai_lieu_du_an_Miku_Japanese_Conversation_Flutter (1).docx`.

---

## 1. ĐÃ HOÀN THÀNH (Phiên 2)

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

## 2. VIỆC CÒN LẠI (Phase 2–6)

> Chi tiết trong tài liệu gốc + README (mục Checklist).

### Phase 2 — Voice input (kế tiếp)
- `flutter pub add record` (+ permission_handler).
- `backend/app/api/conversation.py`: thay stub `user_text = "（音声入力はPhase 2で対応）"`
  bằng lời gọi Gemini audio understanding → transcribe.
- Flutter: giữ-nút-record → WAV → upload (multipart `audio` field đã hỗ trợ sẵn
  trong endpoint). State machine thêm `recording → uploading`.

### Phase 3 — VOICEVOX (TTS)
- Triển khai `voicevox_service.synthesize()` (audio_query → synthesis).
- Thêm `GET /v1/audio/{id}` trả wav; `audio_url` trong response.
- Flutter: `flutter pub add just_audio` → phát audio_url, đồng bộ state `synthesizing → playing`.

### Phase 4 — RVC worker
- Triển khai `rvc_service.convert()` + fallback source.wav khi RVC lỗi.
- Worker URL từ settings (`RVC_WORKER_URL`).

### Phase 5 — Avatar Live2D
- Triển khai `lipsync_service.compute_mouth_cues()` (RMS 40–60ms).
- Thay `avatar_controller.dart` bằng Live2D bridge; khớp `MouthCue` + `MikuEmotion`.

### Phase 6 — Realtime
- Gemini Live + WebSocket (`/v2/live` khung sẵn). Research trước, merge nếu ổn.

---

## 3. LƯU Ý KỸ THUẬT
- Backend mock khi `GEMINI_API_KEY` trống → toàn pipeline UI test được không cần key.
- VOICEVOX/RVC/lipsync service ném `NotImplementedError` là **chủ ý** (Phase 3/4/5).
- Key Gemini chỉ trong `backend/.env`, không commit. Google chuyển auth keys từ 09/2026.
- Environment: Windows 11, Python 3.11.15, Flutter 3.41.9 / Dart 3.11.5.
- Git repo **chưa khởi tạo** (nên `git init` khi bắt đầu Phase 2).
- Console Windows không hiển thị UTF-8 qua `curl` (ra `?????`) — test bằng
  `PYTHONIOENCODING=utf-8 python -c "..."` với httpx, hoặc dùng `-F "text=..."`
  với tool hỗ trợ UTF-8.
