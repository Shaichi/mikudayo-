# Miku Japanese Conversation — Chỉ dẫn cho Claude

**Đọc `HANDOFF.md` trước khi sửa code** — đó là nguồn sự thật về trạng thái dự án (cập nhật gần nhất: 2026-08-14). `README.md` và `BACKEND_GUIDE.md` có chi tiết cài đặt/API.

## Lệnh cấm (đã chốt với chủ dự án)
- Không khôi phục TTS/model giọng local, CUDA, RVC — TTS hiện tại là **Fish Audio online**.
- Không upload audio microphone từ Android về backend; chỉ gửi transcript text (Google SpeechRecognizer xử lý trên điện thoại).
- Không gọi lại `speech_to_text.locales()` — từng treo trên ROM Xiaomi; locale `ja-JP` đã hardcode.
- Không resize/scale avatar Live2D khi bàn phím mở; chỉ đẩy composer lên bằng translate.
- Không thao tác git phá hủy (reset/checkout đè/clean hàng loạt); commit phải xem `git diff` chọn file, worktree thường có nhiều thay đổi chưa commit.
- Không tuyên bố UI/avatar đạt yêu cầu cho tới khi cài APK mới nhất và nhìn trên máy thật (ADB: `8a855606`, Xiaomi Android 14).

## Lệnh không chuẩn — không tự đoán
- Avatar là **Live2D trong WebView** (`assets/web/live2d/`). Unity và VRM 3D đã gỡ hẳn (2026-10-22, `HANDOFF.md` mục 16), không khôi phục. Model Live2D không commit; cách tạo `model/` ở `assets/web/live2d/README.md`.
- Backend: `START_BACKEND.cmd` (FastAPI tại `0.0.0.0:8000`, không tiến trình local nào khác). Test: `Invoke-RestMethod http://127.0.0.1:8000/health`.
- Test backend: `cd backend && python -m unittest discover -s tests -v`. Flutter: `flutter analyze && flutter test`.
- Python backend ưu tiên: `C:\Users\pc\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe`, fallback `backend\.venv`.

## Quy tắc commit
Không commit: `backend/.env` (chứa API key), installer Tailscale, audio/SQLite runtime, file tạm, cache.

## Việc ưu tiên hiện tại
Xem `HANDOFF.md` mục 10 — nổi bật: cài APK lên máy thật, kiểm tra portrait/zoom/keyboard, điền `FISH_API_KEY` để test end-to-end.
