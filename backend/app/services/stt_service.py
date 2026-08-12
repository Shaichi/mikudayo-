"""Dịch vụ Speech-to-Text bằng faster-whisper (local, không cần key).

Transcribe audio từ mic thành text trước khi hỏi Gemini. Điều này cho phép
dùng model Gemini text-only (rẻ + nhanh) thay vì model phải hỗ trợ audio.

- Model: faster-whisper `small` (âm lượng ~500MB, cân bằng nhanh/đúng).
  Đổi cỡ: tiny (75MB) nhanh nhất, base (150MB), medium (1.5GB) chính xác hơn.
- Chạy trên GPU CUDNN nếu có (RTX 3050), fallback CPU.
- Load model lười (lần gọi đầu), giữ warm ở biến module.

Docs: https://github.com/SYSTRAN/faster-whisper
"""
from __future__ import annotations

import io
import logging
import os
import time

logger = logging.getLogger("stt")

# Cỡ model: tiny | base | small | medium | large-v3. small = cân bằng.
WHISPER_MODEL_SIZE = os.environ.get("WHISPER_MODEL", "small")
# Ngôn ngữ ưu tiên; để trống → Whisper tự dò.
WHISPER_LANGUAGE = os.environ.get("WHISPER_LANGUAGE", "ja")

_transcriber = None  # lazy-load, giữ warm


def _get_transcriber():
    """Load WhisperModel lười (lần đầu), giữ warm ở các lần sau."""
    global _transcriber
    if _transcriber is None:
        from faster_whisper import WhisperModel

        device = "cuda" if _cuda_available() else "cpu"
        compute_type = "float16" if device == "cuda" else "int8"
        logger.info(
            "Whisper init: model=%s device=%s compute=%s",
            WHISPER_MODEL_SIZE, device, compute_type,
        )
        t0 = time.time()
        _transcriber = WhisperModel(
            WHISPER_MODEL_SIZE, device=device, compute_type=compute_type
        )
        logger.info("Whisper model loaded in %.1fs", time.time() - t0)
    return _transcriber


def _cuda_available() -> bool:
    try:
        import torch

        return torch.cuda.is_available()
    except Exception:
        return False


def transcribe_audio(audio_bytes: bytes) -> str:
    """Transcribe WAV bytes → text.

    Trả về chuỗi text đã transcribe; nếu rỗng trả "".
    Nếu lỗi (model chưa tải / thiếu phụ thuộc) → trả "" (API fallback).
    """
    try:
        model = _get_transcriber()
        # faster-whisper đọc từ file hoặc path; ghi tạm để decode chắc chắn.
        data = io.BytesIO(audio_bytes)
        data.name = "input.wav"
        segments, _info = model.transcribe(
            data,
            language=WHISPER_LANGUAGE or None,
            vad_filter=True,          # bỏ khoảng lặng, chỉ giữ tiếng nói
            vad_parameters=dict(min_silence_duration_ms=300),
        )
        text = "".join(seg.text for seg in segments).strip()
        logger.info("Whisper transcript (len=%d): %s", len(text), text[:100])
        return text
    except Exception as exc:
        logger.error("Whisper transcribe lỗi: %s", exc)
        return ""


def stt_available() -> bool:
    """Trả True nếu có thể transcribe (model tải được)."""
    try:
        _get_transcriber()
        return True
    except Exception:
        return False