# 🎤 Miku Japanese Conversation

Ứng dụng **luyện nói tiếng Nhật** với trợ lý ảo phong cách Hatsune Miku.

- **Giao diện:** Flutter (Windows desktop / Web / Android / iOS)
- **Backend:** FastAPI (local) — orchestrator + Gemini AI + SQLite
- **Giọng nói (Phase 3–5):** VOICEVOX (TTS) + RVC (voice conversion) + lip-sync avatar
- **Realtime (Phase 6):** nghiên cứu (research only), WS scaffold `/v2/live`

> **Trạng thái hiện tại: Phase 1–5 hoàn thành** — toàn pipeline chạy end-to-end:
> nhập text hoặc nói (mic) → Gemini trả lời → VOICEVOX đọc → RVC đổi giọng
> → avatar lip-sync theo audio. Cả 3 engine (Gemini/VOICEVOX/RVC) chạy chế độ
> **mock** khi chưa cài, nên app test được ngay không cần bất kỳ key/engine nào.

---

## Kiến trúc

```
┌─────────────────────────┐   HTTP/multipart  ┌───────────────────────────────────────┐
│  Flutter (UI + mic)     │  ───────────────▶ │  FastAPI (backend local)              │
│  · Text chat (P1)       │                   │  · POST /v1/conversation/turn         │
│  · Push-to-talk (P2)    │  ◀─────────────── │  · Gemini + JSON schema (mock mode)   │
│  · Play audio (P3)      │   JSON + audio_url│  · SQLite: sessions/turns/vocabulary  │
│  · History/Vocab/Set    │                   │  · WS /v2/live (P6 research)          │
└─────────────────────────┘                   └───────────────────────────────────────┘
   │ mic (P2)   │ just_audio (P3)   │ avatar (P5)          │
   ▼            ▼                   ▼            VOICEVOX (P3) · RVC worker (P4) · lip-sync (P5)
```

- **Flutter** giữ UI, mic (record 16kHz mono), phát audio (just_audio), avatar
  (emotion + lip-sync theo `MouthCue`).
- **FastAPI** đóng vai orchestrator: ghép prompt, gọi Gemini, lưu lịch sử,
  TTS (VOICEVOX), voice conversion (RVC), tính mouth cues.
- **SQLite** (`backend/data/miku.db`) lưu 5 bảng: `sessions`, `turns`,
  `vocabulary`, `turn_vocabulary`, `settings`.

## Cách chạy

### 1. Backend

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

#### Bật engine thật (tùy chọn)

Pipeline chạy được ngay với mock, nhưng muốn giọng thật thì cài 3 engine:

| Engine | Cách cài | Khi hoạt động `/health` báo |
|---|---|---|
| **Gemini** | Key tại [Google AI Studio](https://aistudio.google.com/apikey), điền `GEMINI_API_KEY` vào `backend/.env`, restart backend | `"gemini": true` |
| **VOICEVOX** | Cài [VOICEVOX](https://voicevox.hiroshiba.jp/) (mở app → mặc định cổng 50021) | `"voicevox": true` |
| **RVC** | Chạy worker RVC ở cổng 8010, set `RVC_WORKER_URL` (mặc định `http://127.0.0.1:8010/`) | `"rvc": true` |

> 🔧 **Cách chạy RVC worker** (Phase 4) — cần môi trường riêng:
> ```bash
> cd backend
> python -m venv .venv-rvc        # Python 3.10 (fairseq không chạy trên 3.11)
> .venv-rvc\Scripts\activate
> pip install rvc-python fastapi uvicorn python-multipart   # pip <= 24.0 nếu omegaconf lỗi
> .venv-rvc\Scripts\python.exe rvc_worker.py
> ```
> Model giọng Miku đặt trong `backend/models/` (gitignore — không commit).
> Hiện tại: `miku_mellow_rvc.pth` + `.index` (NoCrypt/miku_RVC). Đã verify
> end-to-end: text → Gemini → VOICEVOX → RVC 2.5s, output 40kHz.

> ⚠️ **Model Gemini**: mặc định `gemini-3-flash-preview` — model mới duy nhất
> hỗ trợ **audio input + JSON schema + system_instruction** trên key hiện tại.
> `gemini-2.5-flash` trả **404** cho key mới; `gemini-flash-latest` không nhận
> audio (500 INTERNAL). Có thể đổi trong `backend/.env` (`GEMINI_MODEL`).
> Google đang chuyển sang **auth keys** — key Standard sẽ bị từ chối từ 09/2026.

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

## Tính năng hiện có (Phase 1–5)

- 💬 **Text chat với Miku** — nhập tiếng Nhật → Gemini trả lời kèm:
  - **reply_ja** — câu trả lời chính.
  - **correction_ja + explanation_vi** — sửa lỗi + giải thích tiếng Việt
    (chế độ *Sửa lỗi*).
  - **emotion** — 😊 😄 😆 🤔 😳 😢 (điều khiển biểu cảm avatar).
  - **vocabulary** — chip từ mới (word/reading/meaning_vi), tự lưu vào sổ.
- 🎤 **Push-to-talk (Phase 2)** — giữ nút mic để nói → upload WAV 16kHz →
  Gemini audio understanding transcribe → trả lời.
- 🔊 **Giọng nói Miku (Phase 3)** — reply → **VOICEVOX** TTS → phát qua
  just_audio. Khi VOICEVOX chưa cài: tự sinh WAV mock (tonal) nên pipeline
  vẫn chạy đủ.
- 🎵 **RVC voice conversion (Phase 4)** — chuyển giọng VOICEVOX qua worker RVC;
  nếu RVC lỗi/tắt → fallback về giọng gốc (`rvc_fallback`), không crash.
- 👄 **Lip-sync + avatar (Phase 5)** — backend tính `MouthCue` (RMS 40–60ms),
  Flutter phát avatar mở/ngậm miệng đồng bộ audio. Khi có SDK Live2D thật chỉ
  cần implement `Live2dBridge` (UI không đổi).
- 🗂 **Lịch sử hội thoại** — danh sách phiên, xem lại từng lượt, xóa phiên.
- 📖 **Sổ từ vựng** — từ đã học theo số lần gặp.
- ⚙️ **Cài đặt** — server URL, chế độ học, JLPT level, bối cảnh Role Play;
  lưu cục bộ (shared_preferences).

### State machine

Pipeline đầy đủ (Phase 2–5):
`idle → recording → uploading → thinking → synthesizing → playing → idle`
với lỗi: `mic_denied | network_error | gemini_error | tts_error | rvc_fallback`.
Mỗi bước đều có status label trên màn hình ("Miku đang suy nghĩ…", "Đang phát…").

### Chế độ engine

| Engine | Nếu cài | Nếu chưa cài |
|---|---|---|
| Gemini | live (cần `GEMINI_API_KEY` trong `.env`) | mock (trả câu mẫu, vẫn parse JSON) |
| VOICEVOX (port 50021) | TTS thật qua `/audio_query` + `/synthesis` | WAV mock 440Hz+880Hz |
| RVC (port 8010) | ✅ convert qua `/convert` (model Miku, GPU) | fallback về giọng VOICEVOX gốc |
| Live2D | chưa có SDK Flutter chính thức | emoji + mouth scale |

`/health` báo trạng thái từng engine (`"gemini": true/false`, ...) để biết đang
chạy live hay mock.

## Cấu trúc thư mục

```
backend/
  app/
    core/config.py         # Settings từ .env (mock mode khi thiếu key)
    db/sqlite.py           # Schema 5 bảng
    schemas/               # Pydantic: ConversationResult, VocabItem...
    repositories/          # CRUD sessions/turns/vocabulary
    services/gemini_service.py   # Gemini + JSON schema + mock (text/audio)
    services/voicevox_service.py # TTS: audio_query → synthesis + mock_wav
    services/rvc_service.py      # convert qua worker + fallback
    services/lipsync_service.py  # MouthCue: RMS 40–60ms trên wav
    api/                   # /v1/conversation/turn, /v1/audio/{id}, /health,
                           # history, vocab, /v2/live (realtime research)
lib/
  app/         # app.dart, theme.dart (cyan Miku), router.dart
  core/        # config (server URL), errors (ApiException), network
  data/
    models/    # conversation_turn, session_record, vocabulary_record
    services/  # api_service.dart (sendText/sendAudio), audio_service.dart (record/play)
    repositories/  # conversation_repository, settings_repository
  features/
    home/            # màn hình chính
    conversation/    # text chat + push-to-talk + view model + widgets
    history/         # lịch sử phiên
    vocabulary/      # sổ từ vựng
    settings/        # cài đặt + kiểm tra máy chủ
  avatar/        # avatar_controller.dart + live2d_bridge.dart (lip-sync P5)
  main.dart
test/            # widget test + live integration test (cần backend chạy)
```

## Checklist các Phase

| Phase | Nội dung | Trạng thái |
|---|---|---|
| **0** | Setup: cài đặt, health check, Gemini key | ✅ Xong |
| **1** | Text chat: text → Gemini JSON → bubble | ✅ Xong |
| **2** | Voice input: record → upload → transcribe | ✅ Xong |
| **3** | VOICEVOX: reply → wav → just_audio | ✅ Xong (mock fallback) |
| **4** | RVC: worker warm, convert, fallback | ✅ Xong (verified live: 40kHz, 2.5s) |
| **5** | Avatar: emotion + lip-sync mouth cues | ✅ Xong (Live2D bridge chờ SDK) |
| **6** | Realtime: Gemini Live + WebSocket | 🔬 Research only — WS scaffold `/v2/live` |

**Phase 6** theo tài liệu (mục 14.1): Gemini Live hiện là Preview, dùng stateful
WebSocket (PCM 16kHz in / 24kHz out). Giữ **push-to-talk là sản phẩm chính**;
chỉ merge realtime nếu latency < ~1s. Khung `backend/app/api/realtime.py` đã có:
nhận text event + PCM chunk, ack round-trip — đủ để test đường truyền WSS từ Flutter.

## Bảo mật

- **Gemini API key chỉ đặt trong `backend/.env`** — KHÔNG nhúng vào Flutter.
  Git đã ignore `.env`.
- Chỉ bind `0.0.0.0` khi cần test từ điện thoại; không mở cổng ra internet.
- Giới hạn kích thước audio upload (20 MB).
- Retry Gemini với backoff khi gặp 429/5xx.
- Audio tạm trong `backend/data/audio/` (TTL; không log raw audio).
- Mic chỉ ghi khi người dùng giữ nút push-to-talk; xóa file tạm sau khi upload.

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
