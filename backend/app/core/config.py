"""Cấu hình ứng dụng backend.

Đọc từ biến môi trường (hoặc file .env). Không commit .env, model private,
audio người dùng hoặc DB history lên Git.
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parents[2]  # backend/
load_dotenv(BASE_DIR / ".env")


def _env(key: str, default: str = "") -> str:
    return os.environ.get(key, default)


class Settings:
    # --- App ---
    APP_NAME: str = "Miku Japanese Conversation"
    DEBUG: bool = _env("DEBUG", "true").lower() == "true"

    # --- Gemini ---
    GEMINI_API_KEY: str = _env("GEMINI_API_KEY", "")
    # Android nhận dạng giọng nói bằng Google SpeechRecognizer rồi chỉ gửi text.
    # Backend vì vậy dùng model text nhanh, nhẹ và quota rộng.
    GEMINI_MODEL: str = _env("GEMINI_MODEL", "gemini-3.5-flash-lite")
    GEMINI_MAX_TURNS: int = int(_env("GEMINI_MAX_TURNS", "8"))
    GEMINI_TEMPERATURE: float = float(_env("GEMINI_TEMPERATURE", "0.7"))
    # Gemini Thinking: 'minimal' | 'low' | 'medium' | 'high' | '' (tắt).
    # Tài liệu xác nhận gemini-3.5-flash-lite HỖ TRỢ thinking (default minimal).
    # Chỉ tốn thời gian tính toán, KHÔNG tốn phí/thêm quota.
    GEMINI_THINKING: str = _env("GEMINI_THINKING", "minimal")

    # --- Fish Audio online TTS ---
    FISH_API_BASE_URL: str = _env("FISH_API_BASE_URL", "https://api.fish.audio")
    FISH_API_KEY: str = _env("FISH_API_KEY", "")
    FISH_MODEL: str = _env("FISH_MODEL", "s2.1-pro-free")
    FISH_REFERENCE_ID: str = _env(
        "FISH_REFERENCE_ID", "3317b3ca88d74206b5478a22a2d502b9"
    )
    # WAV mặc định để giữ lip-sync RMS hiện tại. Có thể đổi thành mp3/opus nếu
    # chấp nhận không có mouth cues phía backend.
    FISH_AUDIO_FORMAT: str = _env("FISH_AUDIO_FORMAT", "wav")
    # Give Android time to acquire audio focus before the first syllable.
    FISH_AUDIO_PREROLL_MS: int = int(_env("FISH_AUDIO_PREROLL_MS", "300"))
    FISH_LATENCY: str = _env("FISH_LATENCY", "low")
    FISH_TIMEOUT: float = float(_env("FISH_TIMEOUT", "60"))
    FISH_TEMPERATURE: float = float(_env("FISH_TEMPERATURE", "0.7"))
    FISH_TOP_P: float = float(_env("FISH_TOP_P", "0.7"))
    FISH_EMOTION_TAGS: bool = _env("FISH_EMOTION_TAGS", "true").lower() == "true"

    # --- Data ---
    DATA_DIR: Path = BASE_DIR / _env("DATA_DIR", "data")
    TEMP_AUDIO_DIR: Path = BASE_DIR / _env("TEMP_AUDIO_DIR", "temp")
    DB_PATH: Path = DATA_DIR / "miku.db"
    TEMP_TTL_SECONDS: int = int(_env("TEMP_TTL_SECONDS", "3600"))

    # --- Server ---
    HOST: str = _env("HOST", "0.0.0.0")
    PORT: int = int(_env("PORT", "8000"))

    # --- Mock / offline ---
    # Khi không có GEMINI_API_KEY hoặc engine không chạy, backend chạy chế độ
    # mock để app Flutter vẫn hoạt động end-to-end được (phục vụ dev/UI).
    ALLOW_MOCK: bool = _env("ALLOW_MOCK", "true").lower() == "true"


settings = Settings()
