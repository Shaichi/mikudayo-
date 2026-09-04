"""Endpoint /health — kiểm tra cấu hình backend và dịch vụ online."""
from __future__ import annotations

from fastapi import APIRouter

from ..core.config import settings
from ..schemas.conversation import HealthStatus
from ..services.gemini_service import GeminiService
from ..services.fish_audio_service import FishAudioService

router = APIRouter()


def _build_services():
    gemini = GeminiService()
    fish_audio = FishAudioService()
    return gemini, fish_audio


@router.get("/health", response_model=HealthStatus)
def health() -> HealthStatus:
    gemini_ready = False
    fish_ready = False
    is_mock = False
    try:
        gemini = GeminiService()
        gemini_ready = gemini.check_health()
        is_mock = gemini.is_mock
    except Exception:
        pass

    try:
        fish_audio = FishAudioService()
        fish_ready = fish_audio.check_health()
    except Exception:
        pass

    status = "ok" if gemini_ready and (fish_ready or settings.ALLOW_MOCK) else "degraded"
    return HealthStatus(
        status=status,
        gemini=gemini_ready,
        fish_audio=fish_ready,
        mode="mock" if is_mock or not fish_ready else "live",
        model=settings.GEMINI_MODEL,
        tts_model=settings.FISH_MODEL,
    )


@router.get("/health/live")
def liveness() -> dict[str, str]:
    """Process liveness probe that does not call external providers."""
    return {"status": "ok"}
