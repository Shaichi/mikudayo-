# Shared Context — Miku Japanese Conversation

> Cross-feature notes. Cập nhật sau khi `architecture-profile.md` được
> approved. Hiện tại đang ở trạng thái **skeleton**.

## Quyết định kiến trúc chốt với chủ dự án (xem `CLAUDE.md`, `HANDOFF.md`)

1. TTS chỉ dùng **Fish Audio online**; không có model giọng/CUDA/RVC local.
2. Android gửi **transcript text** qua Google SpeechRecognizer; không upload
   audio microphone.
3. Mouth cues hiện chỉ tính trên WAV Fish trả về (RMS window 50ms).
4. Avatar portrait, bàn phím không resize Unity (chỉ translate composer).
5. Không gọi output là giọng Hatsune Miku chính thức; "Miku-like".
6. Unity project pin `6000.3.3f1`; NDK `27.2.12479018` (không đổi khi chưa
   kiểm tra Unity + Flutter cùng lúc).
7. Backend chạy 1 process qua `START_BACKEND.cmd` ở `0.0.0.0:8000`.
8. Tailscale / IP LAN cho phép Android kết nối tới backend.

## Cross-cutting contracts

- `client_request_id` (≤100 chars) = idempotency key ở backend.
- Gesture enum: `none|wave|nod|clap|sad|thinking|surprise`.
- Emotion enum: `neutral|happy|excited|thinking|embarrassed|sad`.
- Audio MIME: `wav|mp3|opus|pcm`; WAV cần cho mouth cues.

## Module đang chờ binding resolved

- Render pipeline (URP 17.3.0 vs README Built-in claim).
- NDK version (pinned vs upstream suggestion).
- Storage backend scaling (single SQLite instance).
- CI/CD workspace (chưa có).

> Mọi feature yêu cầu binding nêu trên phải dừng tại
> `AI RECOMMENDATION: PENDING HUMAN REVIEW`.