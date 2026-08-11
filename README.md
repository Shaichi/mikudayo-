# 🎤 Miku Japanese Conversation

Ứng dụng **luyện nói tiếng Nhật** với trợ lý ảo phong cách Hatsune Miku.

- **Giao diện:** Flutter (Windows desktop / Web / Android / iOS)
- **Backend:** FastAPI (local) — orchestrator + Gemini AI + SQLite
- **Giọng nói (Phase 3+):** VOICEVOX (TTS) + RVC (voice conversion) + Live2D avatar

> **Trạng thái hiện tại: Phase 1 hoàn thành** — text chat chạy end-to-end với chế độ
> *mock* (không cần API key). Các Phase 2–6 (voice, TTS, RVC, avatar, realtime)
> đã có khung sẵn trong code nhưng chưa triển khai.

---

## Kiến trúc

```
┌─────────────────────┐     HTTP      ┌───────────────────────────────────────┐
│  Flutter (UI/mic)   │  ───────────▶ │  FastAPI (backend local)              │
│  · Text chat (P1)   │               │  · POST /v1/conversation/turn         │
│  · History/Vocab    │  ◀─────────── │  · Gemini + JSON schema (mock mode)   │
│  · Settings         │     JSON      │  · SQLite: sessions/turns/vocabulary  │
└─────────────────────┘               └───────────────────────────────────────┘
                                               │ (Phase 3+)
                                     VOICEVOX · RVC worker · Live2D
```

- **Flutter** giữ UI, mic, phát audio, avatar.
- **FastAPI** đóng vai orchestrator: ghép prompt, gọi Gemini, lưu lịch sử, TTS.
- **SQLite** (`backend/data/miku.db`) lưu 5 bảng: `sessions`, `turns`,
  `vocabulary`, `turn_vocabulary`, `settings`.

## Cách chạy

### 1. Backend (Phase 1)

Yêu cầu: **Python 3.11+**.

```bash
cd backend
python -m venv .venv
# Windows:
.venv\Scripts\activate
# Linux/macOS:
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env      # GEMINI_API_KEY để trống → mock mode
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Kiểm tra:

```bash
curl http://127.0.0.1:8000/health
# {"status":"ok","gemini":false,"voicevox":false,"rvc":false,"mode":"mock",...}

curl -X POST http://127.0.0.1:8000/v1/conversation/turn \
  -F "text=こんにちは" -F "mode=free_talk" -F "jlpt_level=N5"
```

#### Dùng Gemini thật (tùy chọn)

1. Tạo **Gemini API key** tại [Google AI Studio](https://aistudio.google.com/apikey).
   > ⚠️ Google đang chuyển sang **auth keys** — key Standard sẽ bị từ chối từ 09/2026.
2. Điền `GEMINI_API_KEY=<key>` vào `backend/.env` và restart backend.
   Chế độ tự chuyển sang **live**, `/health` báo `"gemini": true`.

### 2. Flutter

Yêu cầu: **Flutter 3.x** (`flutter doctor` OK).

```bash
flutter pub get
flutter run -d windows    # hoặc -d chrome / -d edge
```

Mở **Cài đặt** → nhấn **Kiểm tra máy chủ** để xác nhận kết nối backend
(mặc định `http://127.0.0.1:8000`).

- **Desktop/Web:** dùng `127.0.0.1` là được.
- **Điện thoại cùng Wi-Fi:** backend chạy với `--host 0.0.0.0`, rồi đặt
  server URL = `http://<IP máy>:8000`.
- **Android emulator:** dùng `http://10.0.2.2:8000`.

---

## Tính năng hiện có (Phase 1)

- 💬 **Text chat với Miku** — nhập tiếng Nhật → Gemini trả lời kèm:
  - **reply_ja** — câu trả lời chính.
  - **correction_ja + explanation_vi** — sửa lỗi + giải thích tiếng Việt
    (chế độ *Sửa lỗi*).
  - **emotion** — 😊 😄 😆 🤔 😳 😢 (ảnh hưởng biểu cảm avatar).
  - **vocabulary** — chip từ mới (word/reading/meaning_vi), tự lưu vào sổ.
  - Avatar Miku hình tròn theme cyan + emoji cảm xúc (thay Live2D ở Phase 1).
- 🗂 **Lịch sử hội thoại** — danh sách phiên, xem lại từng lượt, xóa phiên.
- 📖 **Sổ từ vựng** — từ đã học theo số lần gặp.
- ⚙️ **Cài đặt** — server URL, chế độ học, JLPT level, bối cảnh Role Play;
  lưu cục bộ (shared_preferences).

### State machine

`idle → thinking → idle | error` (Phase 1). Bản đầy đủ cho Phase 2–6:
`idle → recording → uploading → thinking → synthesizing → playing → idle`
với lỗi: `mic_denied | network_error | gemini_error | tts_error | rvc_fallback`.

## Cấu trúc thư mục

```
backend/
  app/
    core/config.py         # Settings từ .env (mock mode khi thiếu key)
    db/sqlite.py           # Schema 5 bảng
    schemas/               # Pydantic: ConversationResult, VocabItem...
    repositories/          # CRUD sessions/turns/vocabulary
    services/gemini_service.py   # Gemini + JSON schema + mock
    services/voicevox_service.py # KHUNG (Phase 3)
    services/rvc_service.py      # KHUNG (Phase 4)
    services/lipsync_service.py  # KHUNG (Phase 5)
    api/                   # /v1/conversation/turn, /health, history, vocab
lib/
  app/         # app.dart, theme.dart (cyan Miku), router.dart
  core/        # config (server URL), errors (ApiException), network
  data/
    models/    # conversation_turn, session_record, vocabulary_record
    services/  # api_service.dart (gọi FastAPI)
    repositories/  # conversation_repository, settings_repository
  features/
    home/            # màn hình chính
    conversation/    # text chat + view model + widgets
    history/         # lịch sử phiên
    vocabulary/      # sổ từ vựng
    settings/        # cài đặt + kiểm tra máy chủ
  avatar/        # avatar_controller.dart (Phase 5 sẽ thay bằng Live2D)
  main.dart
test/            # widget test + integration test (skip khi không có backend)
```

## Checklist các Phase

| Phase | Nội dung | Trạng thái |
|---|---|---|
| **0** | Setup: cài đặt, health check, Gemini key | ✅ Xong |
| **1** | Text chat: text → Gemini JSON → bubble | ✅ Xong |
| **2** | Voice input: record → upload → transcribe | ⏳ Kế tiếp |
| **3** | VOICEVOX: reply → wav → just_audio | 🔲 Khung sẵn |
| **4** | RVC: worker warm, convert, fallback | 🔲 Khung sẵn |
| **5** | Avatar: Live2D bridge, emotion, mouth cues | 🔲 Khung sẵn |
| **6** | Realtime: Gemini Live + WebSocket | 🔲 Sau cùng |

Gợi ý cho **Phase 2** (voice input):

```bash
flutter pub add record
```

Sửa `backend/app/api/conversation.py`: thay đoạn
`user_text = "（音声入力はPhase 2で対応）"` bằng lời gọi Gemini audio
understanding để transcribe.

## Bảo mật

- **Gemini API key chỉ đặt trong `backend/.env`** — KHÔNG nhúng vào Flutter.
  Git đã ignore `.env`.
- Chỉ bind `0.0.0.0` khi cần test từ điện thoại; không mở cổng ra internet.
- Giới hạn kích thước audio upload (20 MB).
- Retry Gemini với backoff khi gặp 429/5xx.

## License

Dự án cá nhân/phi thương mại. Khi thêm asset hãy kiểm tra từng nguồn:

- **Hatsune Miku** & hình ảnh liên quan — **Piapro CC BY-NC** (ghi attribution,
  phi thương mại).
- **VOICEVOX** — tuân theo [software terms](https://voicevox.hiroshiba.jp/) và
  điều khoản từng speaker.
- **RVC** — theo license của repo framework.
- **Live2D SDK/model** — theo license riêng của từng bên.
- Không tải "Miku RVC model" từ nguồn mập mờ.

## Tài liệu tham khảo

- `Tai_lieu_du_an_Miku_Japanese_Conversation_Flutter (1).docx` — tài liệu gốc
  (kiến trúc, API contract, prompt system, checklist 20 bước).
- `HANDOFF.md` — bàn giao giữa các phiên phát triển.
