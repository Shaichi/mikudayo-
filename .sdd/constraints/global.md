# Global Constraints — Miku Japanese Conversation

Áp dụng cho mọi feature. Không thay đổi ngoài RFC process.

## Ngôn ngữ và persona

- App là Miku nhưng **không** gọi output là giọng Hatsune Miku chính thức.
- UI tiếng Việt + tiếng Nhật (Gemini output); error message tiếng Việt.
- Code comment tiếng Việt hoặc tiếng Anh — không mix tùy tiện.

## Repository hygiene

- Không commit `.env`, installer Tailscale, runtime SQLite, audio user.
- Không thao tác git phá huỷ (`reset --hard`, `clean -fd`, `checkout --`).
- Không tạo installer ngoài dự án trong source tree.
- Commit phải review `git diff` trước.

## Verification gates

Mọi PR/task phải chạy:
- Backend: `python -m unittest discover -s tests -v`
- Flutter: `flutter analyze && flutter test`
- Unity: `prepare + export` batchmode trước khi build Flutter APK.

## Device verification

Mọi tuyên bố UI/avatar đạt yêu cầu cần:
- Cài APK mới nhất lên máy thật (ADB `8a855606`, Xiaomi Android 14).
- Kiểm tra portrait, zoom, keyboard behavior, gesture end-to-end.