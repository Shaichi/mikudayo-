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
    # Audio được transcribe bằng faster-whisper local trước khi gọi Gemini →
    # Gemini chỉ nhận text → gemini-3.5-flash-lite (nhanh, nhẹ, quota rộng).
    # Lưu ý: 3.5-flash-lite KHÔNG nhận audio trực tiếp (500); 3-flash-preview hết quota 429.
    GEMINI_MODEL: str = _env("GEMINI_MODEL", "gemini-3.5-flash-lite")
    GEMINI_MAX_TURNS: int = int(_env("GEMINI_MAX_TURNS", "8"))
    GEMINI_TEMPERATURE: float = float(_env("GEMINI_TEMPERATURE", "0.7"))

    # --- VOICEVOX ---
    VOICEVOX_BASE_URL: str = _env("VOICEVOX_BASE_URL", "http://127.0.0.1:50021")
    VOICEVOX_SPEAKER_ID: int = int(_env("VOICEVOX_SPEAKER_ID", "0"))

    # --- STT (faster-whisper, Phase 2+) ---
    WHISPER_MODEL: str = _env("WHISPER_MODEL", "small")
    WHISPER_LANGUAGE: str = _env("WHISPER_LANGUAGE", "ja")

    # --- STT (faster-whisper, Phase 2+) ---
    WHISPER_MODEL: str = _env("WHISPER_MODEL", "small")
    WHISPER_LANGUAGE: str = _env("WHISPER_LANGUAGE", "ja")

    # --- RVC ---
    RVC_WORKER_URL: str = _env("RVC_WORKER_URL", "http://127.0.0.1:8010")
    RVC_MODEL_NAME: str = _env("RVC_MODEL_NAME", "")
    RVC_TIMEOUT: float = float(_env("RVC_TIMEOUT", "15"))

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
    MAX_AUDIO_BYTES: int = int(_env("MAX_AUDIO_BYTES", str(20 * 1024 * 1024)))


settings = Settings()
