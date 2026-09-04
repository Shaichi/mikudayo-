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


def _bool_env(key: str, default: bool) -> bool:
    value = _env(key, "true" if default else "false").strip().lower()
    return value in {"1", "true", "yes", "on"}


def _int_env(key: str, default: int, minimum: int = 0, maximum: int | None = None) -> int:
    try:
        value = int(_env(key, str(default)))
    except (TypeError, ValueError):
        value = default
    value = max(minimum, value)
    return min(value, maximum) if maximum is not None else value


def _float_env(
    key: str,
    default: float,
    minimum: float = 0.0,
    maximum: float | None = None,
) -> float:
    try:
        value = float(_env(key, str(default)))
    except (TypeError, ValueError):
        value = default
    value = max(minimum, value)
    return min(value, maximum) if maximum is not None else value


def _csv_env(key: str, default: str) -> tuple[str, ...]:
    raw = _env(key, default)
    return tuple(item.strip() for item in raw.split(",") if item.strip())


class Settings:
    # --- App ---
    APP_NAME: str = "Miku Japanese Conversation"
    ENVIRONMENT: str = _env("ENVIRONMENT", "development").strip().lower()
    DEBUG: bool = _bool_env("DEBUG", ENVIRONMENT in {"development", "test"})

    # --- Gemini ---
    GEMINI_API_KEY: str = _env("GEMINI_API_KEY", "")
    # Android nhận dạng giọng nói bằng Google SpeechRecognizer rồi chỉ gửi text.
    # Backend vì vậy dùng model text nhanh, nhẹ và quota rộng.
    GEMINI_MODEL: str = _env("GEMINI_MODEL", "gemini-3.5-flash-lite")
    GEMINI_MAX_TURNS: int = _int_env("GEMINI_MAX_TURNS", 8, 1, 30)
    GEMINI_TEMPERATURE: float = _float_env("GEMINI_TEMPERATURE", 0.7, 0.0, 2.0)
    # Gemini Thinking: 'minimal' | 'low' | 'medium' | 'high' | '' (tắt).
    # Tài liệu xác nhận gemini-3.5-flash-lite HỖ TRỢ thinking (default minimal).
    # Chỉ tốn thời gian tính toán, KHÔNG tốn phí/thêm quota.
    GEMINI_THINKING: str = _env("GEMINI_THINKING", "minimal")

    # --- Vocabulary Reinforcement ---
    VOCAB_REINFORCEMENT_ENABLED: bool = _bool_env("VOCAB_REINFORCEMENT_ENABLED", True)
    VOCAB_REINFORCEMENT_LIMIT: int = _int_env("VOCAB_REINFORCEMENT_LIMIT", 5, 1, 20)
    VOCAB_REINFORCEMENT_THRESHOLD: int = _int_env("VOCAB_REINFORCEMENT_THRESHOLD", 3, 1, 10)

    # --- RAG Grammar Grounding ---
    RAG_GRAMMAR_ENABLED: bool = _bool_env("RAG_GRAMMAR_ENABLED", True)
    RAG_EMBEDDING_MODEL: str = _env("RAG_EMBEDDING_MODEL", "gemini-embedding-001")
    RAG_EMBEDDING_DIM: int = _int_env("RAG_EMBEDDING_DIM", 768, 128, 3072)
    RAG_SIMILARITY_THRESHOLD: float = _float_env("RAG_SIMILARITY_THRESHOLD", 0.70, 0.0, 1.0)
    RAG_TIMEOUT_SECONDS: float = _float_env("RAG_TIMEOUT_SECONDS", 0.20, 0.05, 5.0)
    RAG_TOP_K: int = _int_env("RAG_TOP_K", 3, 1, 10)

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
    FISH_AUDIO_PREROLL_MS: int = _int_env("FISH_AUDIO_PREROLL_MS", 300, 0, 5000)
    FISH_LATENCY: str = _env("FISH_LATENCY", "low")
    FISH_TIMEOUT: float = _float_env("FISH_TIMEOUT", 60.0, 1.0, 180.0)
    FISH_RETRY_ATTEMPTS: int = _int_env("FISH_RETRY_ATTEMPTS", 3, 1, 5)
    FISH_TEMPERATURE: float = _float_env("FISH_TEMPERATURE", 0.7, 0.0, 2.0)
    FISH_TOP_P: float = _float_env("FISH_TOP_P", 0.7, 0.0, 1.0)
    FISH_EMOTION_TAGS: bool = _bool_env("FISH_EMOTION_TAGS", True)

    # --- Data ---
    DATA_DIR: Path = BASE_DIR / _env("DATA_DIR", "data")
    TEMP_AUDIO_DIR: Path = BASE_DIR / _env("TEMP_AUDIO_DIR", "temp")
    DB_PATH: Path = DATA_DIR / "miku.db"
    TEMP_TTL_SECONDS: int = _int_env("TEMP_TTL_SECONDS", 3600, 60, 7 * 24 * 3600)

    # --- Server ---
    HOST: str = _env("HOST", "0.0.0.0")
    PORT: int = _int_env("PORT", 8000, 1, 65535)
    DB_TIMEOUT_SECONDS: float = _float_env("DB_TIMEOUT_SECONDS", 10.0, 1.0, 60.0)

    # --- API safety and resource limits ---
    API_TOKEN: str = _env("API_TOKEN", "").strip()
    REQUIRE_AUTH: bool = _bool_env(
        "REQUIRE_AUTH", ENVIRONMENT in {"production", "prod"}
    )
    CORS_ORIGINS: tuple[str, ...] = _csv_env(
        "CORS_ORIGINS", "*" if ENVIRONMENT in {"development", "test"} else ""
    )
    TRUSTED_HOSTS: tuple[str, ...] = _csv_env(
        "TRUSTED_HOSTS", "*" if ENVIRONMENT in {"development", "test"} else ""
    )
    MAX_BODY_BYTES: int = _int_env("MAX_BODY_BYTES", 64 * 1024, 1024, 4 * 1024 * 1024)
    MAX_TEXT_LENGTH: int = _int_env("MAX_TEXT_LENGTH", 2000, 32, 10000)
    MAX_SCENARIO_LENGTH: int = _int_env("MAX_SCENARIO_LENGTH", 240, 16, 2000)
    FISH_MAX_TEXT_LENGTH: int = _int_env("FISH_MAX_TEXT_LENGTH", 1200, 32, 10000)
    MAX_AUDIO_BYTES: int = _int_env("MAX_AUDIO_BYTES", 15 * 1024 * 1024, 64 * 1024, 100 * 1024 * 1024)
    RATE_LIMIT_REQUESTS: int = _int_env("RATE_LIMIT_REQUESTS", 60, 1, 10000)
    RATE_LIMIT_WINDOW_SECONDS: int = _int_env("RATE_LIMIT_WINDOW_SECONDS", 60, 1, 3600)
    AUDIO_MAX_CONCURRENCY: int = _int_env("AUDIO_MAX_CONCURRENCY", 2, 1, 16)
    AUDIO_STALE_SECONDS: int = _int_env("AUDIO_STALE_SECONDS", 300, 30, 86400)

    # --- Mock / offline ---
    # Khi không có GEMINI_API_KEY hoặc engine không chạy, backend chạy chế độ
    # mock để app Flutter vẫn hoạt động end-to-end được (phục vụ dev/UI).
    ALLOW_MOCK: bool = _bool_env("ALLOW_MOCK", ENVIRONMENT in {"development", "test"})

    def validate(self) -> None:
        """Fail early only when production explicitly requires live services."""
        if self.REQUIRE_AUTH and not self.API_TOKEN:
            raise RuntimeError("REQUIRE_AUTH=true nhưng API_TOKEN chưa được cấu hình")
        if self.ENVIRONMENT in {"production", "prod"} and self.ALLOW_MOCK:
            raise RuntimeError("ALLOW_MOCK phải false trong môi trường production")
        if self.ENVIRONMENT in {"production", "prod"} and not self.FISH_API_KEY:
            raise RuntimeError("FISH_API_KEY chưa được cấu hình trong production")
        if self.ENVIRONMENT in {"production", "prod"} and not self.TRUSTED_HOSTS:
            raise RuntimeError("TRUSTED_HOSTS phải được cấu hình trong production")


settings = Settings()
