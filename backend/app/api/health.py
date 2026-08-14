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
    gemini, fish_audio = _build_services()
    fish_ready = fish_audio.check_health()
    return HealthStatus(
        status="ok",
        gemini=gemini.check_health(),
        fish_audio=fish_ready,
        mode="mock" if gemini.is_mock or not fish_ready else "live",
        model=settings.GEMINI_MODEL,
        tts_model=settings.FISH_MODEL,
    )
