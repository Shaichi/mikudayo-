# Miku Japanese Conversation

Ứng dụng Flutter luyện hội thoại tiếng Nhật với avatar Miku 3D.

## Pipeline hiện tại

```text
Mic Android
  → Google SpeechRecognizer trên điện thoại
  → transcript text
  → FastAPI + Gemini
  → reply_ja + emotion
  → Fish Audio online TTS
  → WAV/MP3/Opus
  → Flutter playback + avatar emotion/lip-sync
```

Không còn sử dụng AivisSpeech, RVC, CUDA/GPU hoặc model giọng local. Backend chỉ làm orchestration nhẹ, bảo vệ API key, lưu lịch sử và chuyển audio Fish về app.

## Thành phần

- Flutter: UI, Google SpeechRecognizer, playback `just_audio`, Unity avatar.
- FastAPI: Gemini, SQLite, Fish Audio proxy, audio status.
- Fish Audio: sinh toàn bộ giọng nói online qua `reference_id`.
- Android chỉ gửi transcript text; audio microphone không được upload về backend.

## Chạy backend

1. Sao chép `backend/.env.example` thành `backend/.env`.
2. Điền `GEMINI_API_KEY` và `FISH_API_KEY`.
3. Nhấp đúp `START_BACKEND.cmd`.

Cấu hình TTS mặc định:

```env
FISH_MODEL=s2.1-pro-free
FISH_REFERENCE_ID=3317b3ca88d74206b5478a22a2d502b9
FISH_AUDIO_FORMAT=wav
FISH_LATENCY=low
```

WAV được chọn mặc định để giữ mouth cues RMS. Có thể dùng MP3/Opus để giảm băng thông, nhưng lip-sync backend hiện chỉ tính trên WAV.

Kiểm tra:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Kết quả live:

```json
{
  "status": "ok",
  "gemini": true,
  "fish_audio": true,
  "mode": "live",
  "model": "gemini-3.5-flash-lite",
  "tts_model": "s2.1-pro-free"
}
```

Chi tiết cài đặt và xử lý lỗi: `BACKEND_GUIDE.md`.

## API hội thoại

```text
POST /v1/conversation/turn
GET  /v1/audio/{turn_id}/status
GET  /v1/audio/{turn_id}
```

`POST /v1/conversation/turn` trả text/emotion trước với `voice_mode=pending`. Fish Audio chạy ở background; Flutter poll status và phát audio khi `voice_mode=fish_audio`.

## Tính năng

- Chat tiếng Nhật với Gemini, có sửa lỗi và giải thích tiếng Việt.
- Google Speech-to-Text trên Android, không upload audio.
- TTS tiếng Nhật online bằng public Fish voice qua `reference_id`.
- Emotion từ Gemini tác động lên tag/prosody Fish và biểu cảm avatar.
- Text-first response để UI không phải chờ TTS.
- WAV mouth cues cho lip-sync.
- Lịch sử hội thoại, từ vựng và cài đặt server.
- Portrait-only; bàn phím chỉ đẩy composer, không resize avatar.

## Cấu trúc chính

```text
backend/app/api/conversation.py           hội thoại + audio background/status
backend/app/services/fish_audio_service.py Fish Audio REST client
backend/app/services/gemini_service.py     Gemini + context hội thoại
backend/app/services/lipsync_service.py    mouth cues từ WAV
backend/app/core/config.py                 cấu hình .env
lib/data/services/speech_recognition_service.dart  Google STT Android
lib/data/services/api_service.dart         FastAPI client
lib/data/services/audio_service.dart       playback
lib/features/conversation/                 UI và state hội thoại
unity/MikuAvatar/                          avatar 3D
```

## Test

```powershell
cd backend
python -m unittest discover -s tests -v

cd ..
flutter analyze
flutter test
```

Các unit test Fish dùng HTTP giả lập, không tiêu quota.

## Bảo mật và quyền

- Không commit `backend/.env` hoặc nhúng API key vào APK.
- Public/community voice có thể bị thay đổi hoặc gỡ. Trước khi phân phối/thương mại hóa, kiểm tra điều khoản của voice và thương hiệu liên quan.
- Dự án gọi output là “Miku-like”; không mặc định đây là giọng Hatsune Miku chính thức.

## Tài liệu

- `BACKEND_GUIDE.md`: cài và chạy backend Fish Audio.
- `HANDOFF.md`: trạng thái dự án cho agent tiếp theo.
