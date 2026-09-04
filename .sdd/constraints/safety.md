# Safety Constraints — Miku Japanese Conversation

Áp dụng cho runtime safety, network, API key, storage.

## API safety

- `REQUIRE_AUTH=true` trong production → `API_TOKEN` bắt buộc.
- `ALLOW_MOCK=false` trong production (enforced bởi `Settings.validate()`).
- Production cần `FISH_API_KEY` + `TRUSTED_HOSTS`.
- Wildcard CORS / TrustedHost chỉ development.
- Body size cap `MAX_BODY_BYTES=65536`.
- Per-IP rate limit (in-memory) trừ `/v1/.../status`.

## Audio safety

- `MAX_AUDIO_BYTES=15 MB` reject response Fish vượt limit.
- WAV header sniff (`RIFF`/`RF64`) trước khi lưu.
- Mouth cues chỉ compute cho WAV (MP3/Opus không decode).
- `TEMP_TTL_SECONDS` cleanup file hết hạn + clear `audio_path` trong DB.

## Path safety

- `path.resolve().relative_to(settings.TEMP_AUDIO_DIR.resolve())` trước
  khi trả audio qua `FileResponse`.
- Không log raw API key.

## SpeechRecognizer

- Locale `ja-JP` hardcode (không gọi `speech_to_text.locales()` trên ROM
  Xiaomi nếu chưa test).
- `cancelOnError: false` để Android tự restart khi `done` sớm.
- `pauseFor` 5s sau ADB test (recognizer thường tự đóng trước 1.8s).