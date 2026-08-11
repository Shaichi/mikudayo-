"""Endpoint /health — kiểm tra FastAPI + các engine."""
from __future__ import annotations

from fastapi import APIRouter

from ..core.config import settings
from ..schemas.conversation import HealthStatus
from ..services.gemini_service import GeminiService
from ..services.rvc_service import RvcService
from ..services.voicevox_service import VoicevoxService

router = APIRouter()


def _build_services():
    gemini = GeminiService()
    voicevox = VoicevoxService()
    rvc = RvcService()
    return gemini, voicevox, rvc


@router.get("/health", response_model=HealthStatus)
def health() -> HealthStatus:
    gemini, voicevox, rvc = _build_services()
    return HealthStatus(
        status="ok",
        gemini=gemini.check_health(),
        voicevox=voicevox.check_health(),
        rvc=rvc.check_health(),
        mode="mock" if gemini.is_mock else "live",
        model=settings.GEMINI_MODEL,
    )
