# HƯỚNG DẪN CHẠY BACKEND — Miku Japanese Conversation

Backend không còn chạy AivisSpeech, RVC, CUDA hoặc model giọng local. Toàn bộ TTS được gửi tới Fish Audio.

```text
Android Google SpeechRecognizer → transcript text → FastAPI → Gemini
                                                       ↓ reply_ja + emotion
                                                  Fish Audio online
                                                       ↓ WAV
                                           Flutter playback + lip-sync
```

## 1. Chuẩn bị

Yêu cầu Python 3.11+ và hai API key:

- `GEMINI_API_KEY`: tạo trong Google AI Studio.
- `FISH_API_KEY`: tạo tại <https://fish.audio/app/api-keys>.

```powershell
cd C:\Users\pc\Desktop\mikudayo\backend
Copy-Item .env.example .env
```

Điền tối thiểu:

```env
GEMINI_API_KEY=...
FISH_API_KEY=...
FISH_MODEL=s2.1-pro-free
FISH_REFERENCE_ID=3317b3ca88d74206b5478a22a2d502b9
FISH_AUDIO_FORMAT=wav
FISH_LATENCY=low
ALLOW_MOCK=false
```

Không commit `backend/.env`.

## 2. Cài dependencies

```powershell
cd C:\Users\pc\Desktop\mikudayo\backend
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
```

## 3. Khởi động

Nhấp đúp:

```text
C:\Users\pc\Desktop\mikudayo\START_BACKEND.cmd
```

Script chỉ khởi động FastAPI ở `0.0.0.0:8000`. Không có tiến trình TTS local khác.

Chạy thủ công:

```powershell
cd C:\Users\pc\Desktop\mikudayo\backend
.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## 4. Kiểm tra

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Khi cấu hình đủ key:

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

Gửi lượt hội thoại:

```powershell
curl.exe -X POST http://127.0.0.1:8000/v1/conversation/turn `
  -F "text=こんにちは" -F "mode=free_talk" -F "jlpt_level=N5"
```

Backend trả text ngay với `voice_mode=pending`. Flutter poll:

```text
GET /v1/audio/<turn_id>/status
GET /v1/audio/<turn_id>
```

Khi thành công, status có `voice_mode=fish_audio`.

## 5. Định dạng audio và lip-sync

- `wav`: mặc định, dung lượng lớn hơn nhưng backend tính được mouth cues RMS.
- `mp3` hoặc `opus`: nhẹ hơn; Flutter phát được nhưng backend hiện trả `mouth_cues=[]` để tránh phụ thuộc ffmpeg local.
- `pcm`: Fish hỗ trợ nhưng không nên dùng trực tiếp với `just_audio` hiện tại.

Luồng hiện tại dùng REST `/v1/tts` và tải audio trong background. SSE/WebSocket streaming thật chưa nối vào Flutter; đây là bước tối ưu riêng sau khi đo latency thực tế.

## 6. Troubleshooting

### `fish_audio: false`

- Kiểm tra `FISH_API_KEY` và `FISH_REFERENCE_ID` trong `backend/.env`.
- Restart backend sau khi sửa `.env`.
- `/health` chỉ kiểm tra cấu hình để không tiêu quota TTS.

### Audio status trả `error`

- Xem log cửa sổ `START_BACKEND.cmd`.
- Kiểm tra quota/free campaign và quyền truy cập model Fish.
- Nếu model miễn phí kết thúc, đổi `FISH_MODEL` sang model hiện có trong tài khoản.
- Nếu public voice bị gỡ, chọn voice khác trong Fish Voice Library và thay `FISH_REFERENCE_ID`.

### Điện thoại không kết nối backend

- Trong Settings của app dùng `http://<IP-PC>:8000`, không dùng `127.0.0.1`.
- PC và điện thoại phải cùng LAN/Tailscale; firewall phải cho phép TCP 8000.

### Chạy UI không có API key

Đặt `ALLOW_MOCK=true`. Backend trả WAV diagnostic ngắn để kiểm tra playback; đó không phải giọng Fish Audio.

## 7. Bảo mật và quyền sử dụng

- Chỉ backend giữ `FISH_API_KEY`; không nhúng key vào Flutter APK.
- Voice `3317b3ca88d74206b5478a22a2d502b9` là public/community voice. Kiểm tra điều khoản của voice trước khi phát hành hoặc thương mại hóa.
- Không gọi giọng này là giọng Hatsune Miku chính thức nếu chưa có quyền tương ứng.
