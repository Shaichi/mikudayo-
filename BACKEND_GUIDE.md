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
FISH_SAMPLE_RATE=24000
FISH_AUDIO_PREROLL_MS=150
FISH_LATENCY=low
ALLOW_MOCK=false
ENVIRONMENT=production
REQUIRE_AUTH=true
API_TOKEN=<token-dài-ngẫu-nhiên>
CORS_ORIGINS=https://your-web-client.example
TRUSTED_HOSTS=your-api.example
```

Không commit `backend/.env`.

Ở local có thể dùng `ENVIRONMENT=development`, `ALLOW_MOCK=true` và để trống
`API_TOKEN`. Khi chạy public, bắt buộc dùng `ALLOW_MOCK=false`, bật
`REQUIRE_AUTH=true`, đặt `API_TOKEN` trong backend và gửi token qua
`Authorization: Bearer <token>` hoặc `X-API-Key`. Không đặt token vào URL.

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

Backend trả text ngay với `voice_mode=pending`. Flutter long-poll (backend giữ
request tới khi giọng xong, tối đa `wait` giây, ≤ 20):

```text
GET /v1/audio/<turn_id>/status?wait=15
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
- `/health` chỉ kiểm tra cấu hình để không tiêu quota TTS. `status=degraded`
  nghĩa là process còn sống nhưng một dependency chưa sẵn sàng; dùng
  `/health/live` cho liveness probe.

### Audio status trả `error`

- Xem log cửa sổ `START_BACKEND.cmd`.
- Kiểm tra quota/free campaign và quyền truy cập model Fish.
- Nếu model miễn phí kết thúc, đổi `FISH_MODEL` sang model hiện có trong tài khoản.
- Nếu public voice bị gỡ, chọn voice khác trong Fish Voice Library và thay `FISH_REFERENCE_ID`.

### Điện thoại không kết nối backend

- Trong Settings của app dùng `http://<IP-PC>:8000`, không dùng `127.0.0.1`.
- PC và điện thoại phải cùng LAN/Tailscale; firewall phải cho phép TCP 8000.

### Chạy UI không có API key

Đặt `ENVIRONMENT=development` và `ALLOW_MOCK=true`. Backend trả WAV
diagnostic ngắn để kiểm tra playback; đó không phải giọng Fish Audio. Request
text bị giới hạn theo `MAX_TEXT_LENGTH`, audio tạm được dọn theo
`TEMP_TTL_SECONDS`.

## 7. Bảo mật và quyền sử dụng

- Chỉ backend giữ `FISH_API_KEY`; không nhúng key vào Flutter APK.
- Voice `3317b3ca88d74206b5478a22a2d502b9` là public/community voice. Kiểm tra điều khoản của voice trước khi phát hành hoặc thương mại hóa.
- Không gọi giọng này là giọng Hatsune Miku chính thức nếu chưa có quyền tương ứng.

## 8. Triển khai Cloud miễn phí 24/7 với Koyeb

Repository đã có sẵn [backend/Dockerfile](file:///C:/Users/pc/Desktop/mikudayo/backend/Dockerfile) tối ưu cho Koyeb Eco Free Tier (512MB RAM).

### Các bước triển khai:

1. **Đăng ký tài khoản:** Truy cập [koyeb.com](https://www.koyeb.com/) và đăng nhập bằng GitHub.
2. **Tạo Service mới:** Chọn **Create Service** → Chọn **GitHub**.
3. **Chọn repository:** Chọn repo `Shaichi/mikudayo-` và branch mong muốn.
4. **Cấu hình Builder:**
   - **Root directory:** `backend`
   - **Builder:** `Dockerfile`
5. **Cấu hình Port & Route:**
   - Port: `8000` (Protocol: HTTP)
   - Public route: `/`
6. **Cấu hình Instance:**
   - Chọn **Eco** → **Nano** ($0/tháng, 512MB RAM).
   - Region: `Frankfurt (fra)` hoặc `Washington D.C. (was)`.
7. **Biến môi trường (Environment Variables):**
   - `GEMINI_API_KEY`: API Key Gemini của bạn.
   - `GEMINI_MODEL`: `gemini-3.6-flash`.
   - `FISH_API_KEY`: Key Fish Audio (nếu dùng TTS).
   - `REQUIRE_AUTH`: `false` (để client Flutter gọi API không cần header token).
   - `CORS_ORIGINS`: `*`
   - `TRUSTED_HOSTS`: `*`
8. **Bấm Deploy:** Sau ~2 phút, Koyeb cấp URL HTTPS (ví dụ: `https://miku-backend-xxx.koyeb.app`). Dán URL này vào mục cài đặt server trên app Flutter.

