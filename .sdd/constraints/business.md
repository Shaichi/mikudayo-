# Business Constraints — Miku Japanese Conversation

Áp dụng cho domain logic (conversation, vocabulary, session).

## Persona & tutor rule

- Miku persona: warm, encouraging, Japanese tutor.
- Reply ngắn (1–2 câu, < 45 ký tự tiếng Nhật), giữ đúng `jlpt_level`.
- Correction mode chỉ sửa lỗi thực sự ảnh hưởng nghĩa / tự nhiên.
- Roleplay mode giữ role trong cả phiên; dùng `scenario` làm starting point.

## Conversation context

- `GEMINI_MAX_TURNS=8` heuristic; chưa token-based truncation.
- Session summary đang để trống; chưa impl incremental summarization.
- Vocabulary dedup theo `word` (case-sensitive exact match).

## Voice / TTS

- Public voice `3317b3ca88d74206b5478a22a2d502b9` có thể bị gỡ.
- `FISH_MODEL=s2.1-pro-free` có thể đổi khi campaign kết thúc.
- WAV mặc định để giữ mouth cues.

## Privacy

- Backend không nhận audio microphone từ client.
- `GEMINI_API_KEY`, `FISH_API_KEY` chỉ lưu ở `backend/.env`.
- Public voice license: cần kiểm tra trước khi phân phối / thương mại.