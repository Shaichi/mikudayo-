# PROMPT BÀN GIAO — PHIÊN SAU (dán nguyên văn vào phiên mới để tiếp tục)

> Đây là prompt tự-chứa. Dán toàn bộ nội dung từ đây đến hết vào Claude Code ở phiên mới.
> Ngữ cảnh đầy đủ hơn nằm trong `HANDOFF.md` cùng thư mục (đọc thêm nếu cần).

---

## NHIỆM VỤ

Bạn đang tiếp tục dự án **"Miku Japanese Conversation"** — app luyện nói tiếng Nhật với trợ lý ảo phong cách Hatsune Miku, tại thư mục `C:\Users\pc\Desktop\mikudayo`.

Kiến trúc đích (theo tài liệu `Tai_lieu_du_an_Miku_Japanese_Conversation_Flutter (1).docx` trong thư mục):
**Flutter** (UI/mic/audio/avatar) + **FastAPI local** (orchestrator + Gemini + SQLite) + **VOICEVOX** (TTS port 50021) + **RVC worker** (voice conversion) + **SQLite** (history/vocab). MVP = push-to-talk 1 lượt.

**Mục tiêu phiên này:** hoàn thành **Phase 0 + Phase 1** (đã gần xong backend), xây **Flutter text chat** cho chạy end-to-end, viết README. KHÔNG làm Phase 2–6 (voice/TTS/RVC/avatar/realtime) — chỉ để khung sẵn.

---

## VIỆC ĐÃ LÀM XONG (đừng làm lại)

1. **Backend FastAPI đã tạo đủ cấu trúc** theo mục 7 tài liệu, đã test `from app.main import app` = OK:
   - `backend/app/core/config.py` — Settings từ `.env` (mock mode khi `GEMINI_API_KEY` trống).
   - `backend/app/db/sqlite.py` — 5 bảng: sessions, turns, vocabulary, turn_vocabulary, settings.
   - `backend/app/schemas/conversation.py` — Pydantic (ConversationResult, GeminiTurnOutput, VocabItem, MouthCue, HealthStatus…).
   - `backend/app/repositories/{conversation_repository,vocab_repository}.py` — CRUD.
   - `backend/app/services/gemini_service.py` — Gemini + JSON schema (mục 8.3) + **mock mode**.
   - `backend/app/services/{voicevox,rvc,lipsync}_service.py` — KHUNG SẴN, phương thức ném `NotImplementedError` (đúng, đừng sửa).
   - `backend/app/api/{conversation,health,history}.py` + `main.py` — POST `/v1/conversation/turn` (text + audio stub), `/health`, history, vocabulary, delete.
   - `backend/.env.example`, `requirements.txt`, `pyproject.toml`, `.gitignore`.
   - Đã cài pip: fastapi, uvicorn, python-multipart, google-genai, pydantic, httpx, python-dotenv.
2. **Flutter CHƯA sửa** — `lib/main.dart` vẫn là mẫu counter. Môi trường: Flutter 3.41.9 / Dart 3.11.5. Devices: Windows desktop, Chrome, Edge.

---

## VIỆC PHẢI LÀM (theo thứ tự)

### Bước 1 — Kiểm thử backend Phase 1 (chạy thật)
```bash
cd "C:\Users\pc\Desktop\mikudayo\backend"
cp .env.example .env          # để trống GEMINI_API_KEY -> mock mode
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```
Test trong terminal khác (hoặc dùng curl):
```bash
curl http://127.0.0.1:8000/health
curl -X POST http://127.0.0.1:8000/v1/conversation/turn -F "text=こんにちは" -F "mode=free_talk" -F "jlpt_level=N5"
```
- Kỳ vọng mock: trả JSON có `reply_ja`, `emotion`, `vocabulary`, `timing_ms`, `session_id`, `turn_id`, `voice_mode=mock`.
- Nếu lỗi → sửa rồi mới sang Flutter. (Lưu ý: `conversation.py` đã sửa logic session reuse.)

### Bước 2 — Flutter Phase 0+1: nền tảng
```bash
cd "C:\Users\pc\Desktop\mikudayo"
flutter pub add http flutter_riverpod path_provider
# (record + just_audio là Phase 2/3 — có thể add sẵn để tránh chạy lại pub get)
```
Tạo cấu trúc theo mục 6.1 tài liệu:
```
lib/
  app/        app.dart, router.dart, theme.dart
  core/       config/ (server URL), network/, errors/
  data/
    models/          conversation_turn.dart (ConversationResult, VocabItem, MouthCue)
    services/        api_service.dart   (dùng http, POST /v1/conversation/turn, GET history/vocab)
    repositories/    conversation_repository.dart, settings_repository.dart
  features/
    home/            home_screen.dart (nav tới conversation/history/vocabulary/settings)
    conversation/    conversation_screen.dart, conversation_view_model.dart, widgets/
    history/ history_screen.dart
    vocabulary/ vocabulary_screen.dart
    settings/ settings_screen.dart
  avatar/ avatar_controller.dart (Phase 5 mới cần bridge; giờ chỉ emotion -> emoji/icon)
  main.dart
```
- Theme Miku: màu cyan (`#00A0B0` / `#39C2D7`), Material 3, seed `Colors.cyan`.
- `api_service.dart`: đọc base URL từ settings (default `http://127.0.0.1:8000`), hàm `sendText({text, mode, jlptLevel, sessionId})` gửi multipart hoặc form → parse `ConversationResult`.

### Bước 3 — Màn hình Conversation (text chat)
- Nhập text → gửi → state `thinking` (hiển thị "Miku đang suy nghĩ…" / đủ các trạng thái tài liệu mục 5.2) → render:
  - Bubble reply_ja (nói chính).
  - transcript_ja (lời người học).
  - correction_ja + explanation_vi nếu có (chỉ khi mode=correction hoặc có lỗi).
  - Emotion badge (😊 😆 🤔 😳 😢) theo `emotion`.
  - Chip vocabulary (word/reading/meaning_vi).
- Avatar Miku: dùng hình tròn màu theme + emoji cảm xúc lớn thay cho Live2D (Phase 1). Giữ chỗ `avatar_controller` cho Phase 5.
- State machine tối thiểu Phase 1: `idle → thinking → idle | error` (lỗi hiển thị message thân thiện). File `conversation_view_model.dart` dùng Riverpod.

### Bước 4 — History + Vocabulary + Settings
- History: GET `/v1/sessions` → chọn session → GET `/v1/sessions/{id}/turns`.
- Vocabulary: GET `/v1/vocabulary`.
- Settings: server URL, mode (free_talk/correction/roleplay), jlpt_level (N5/N4/N3), scenario; lưu local (shared_preferences hoặc settings_repository) + gửi cùng mỗi turn.

### Bước 5 — README chính thức
Thay README mặc định: giới thiệu, kiến trúc, cách chạy backend (mock + live key), cách chạy Flutter, checklist Phase 1–6 (mục 20 tài liệu), note license.

### Bước 6 — Kiểm tra & bàn giao
- `flutter analyze` không còn lỗi; chạy thử trên Windows hoặc Chrome.
- Cập nhật `HANDOFF.md` cuối phiên: ghi rõ đã làm gì, còn gì cho Phase 2–6.

---

## THAM CHIẾU NHANH TỪ TÀI LIỆU

- **JSON schema Gemini** (mục 8.3): `{transcript_ja, reply_ja, correction_ja?, explanation_vi?, emotion, difficulty, vocabulary:[{word, reading, meaning_vi}]}`. Emotion: `neutral|happy|excited|thinking|embarrassed|sad`.
- **Response API** (mục 12.2): `turn_id, session_id, transcript_ja, reply_ja, correction_ja, explanation_vi, emotion, vocabulary, audio_url, voice_mode, mouth_cues, timing_ms`.
- **Modes**: free_talk / correction / roleplay; Level: N5/N4/N3.
- **Prompt system** (mục 8.2): tutor tiếng Nhật, reply 1–3 câu, 1 follow-up, chỉ sửa lỗi quan trọng, giải thích tiếng Việt, không nhận là Miku chính thức.
- **Bảo mật** (mục 13): key Gemini chỉ trong backend `.env`, KHÔNG nhúng Flutter. Google chuyển sang auth keys (Standard key từ chối từ 09/2026).
- **State machine** (mục 5.2): `idle→recording→uploading→thinking→synthesizing→playing→idle`; errors: `mic_denied|network_error|gemini_error|tts_error|rvc_fallback`. Hiển thị trạng thái cụ thể, không spinner đơn.
- **Package Phase sau**: record (P2), just_audio (P3), web_socket_channel (P6), permission_handler.
- **Android→PC**: cùng Wi-Fi, FastAPI bind `0.0.0.0`, emulator dùng `10.0.2.2`.

## LƯU Ý
- Các service VOICEVOX/RVC/lipsync ném `NotImplementedError` là **chủ ý** (Phase 3/4/5), không phải bug.
- Mock mode giúp toàn pipeline UI chạy không cần key Gemini.
- Không commit `.env`, model private, audio, DB history. Git repo chưa khởi tạo.
