"""Dịch vụ VOICEVOX TTS — PHASE 3 (chưa tích hợp vào pipeline Phase 1).

Theo mục 9.1 tài liệu:
- POST {base}/audio_query?text=<reply>&speaker=<id>  -> audio_query.json
- chỉnh speedScale/pitchScale/intonationScale nếu cần
- POST {base}/synthesis?speaker=<id>  Body: audio_query.json  -> source.wav

Phase 1 chỉ dùng text chat, chưa cần TTS. File này là khung sẵn để phiên
tiếp theo (Phase 3) triển khai và nối vào conversation pipeline.
"""
from __future__ import annotations

from ..core.config import settings
from ..core.logging import get_logger

logger = get_logger("voicevox")


class VoicevoxService:
    def __init__(self) -> None:
        self.base_url = settings.VOICEVOX_BASE_URL
        self.speaker_id = settings.VOICEVOX_SPEAKER_ID

    def check_health(self) -> bool:
        """Kiểm tra engine có chạy trên port không. Phase 1 chỉ dùng cho /health."""
        try:
            import httpx

            resp = httpx.get(f"{self.base_url}/version", timeout=3)
            return resp.status_code == 200
        except Exception:
            return False

    # TODO(Phase 3): triển khai synthesize_reply(reply_ja) -> source.wav
    # Sử dụng /audio_query + /synthesis theo pseudo-flow ở mục 9.1.
    def synthesize(self, text: str) -> bytes:
        raise NotImplementedError("VOICEVOX synthesis được triển khai ở Phase 3.")
