"""Dịch vụ RVC voice conversion — Phase 4.

Theo mục 9.2 tài liệu:
- RVC chỉ là lớp đổi timbre, chạy worker riêng.
- Worker giữ model warm (load khi start), tránh load lại mỗi request.
- Fallback: nếu worker timeout/crash -> dùng source.wav (không fail request).

Orchestration rules (mục 7.3):
- RVC fail -> phát WAV VOICEVOX, không fail toàn request.
"""
from __future__ import annotations

from ..core.config import settings
from ..core.logging import get_logger

logger = get_logger("rvc")


class RvcService:
    def __init__(self) -> None:
        self.worker_url = settings.RVC_WORKER_URL
        self.model_name = settings.RVC_MODEL_NAME

    def check_health(self) -> bool:
        try:
            import httpx

            resp = httpx.get(f"{self.worker_url}/health", timeout=3)
            return resp.status_code == 200
        except Exception:
            return False

    async def convert(self, source_wav: bytes) -> bytes:
        """Gửi source.wav tới worker -> final.wav.

        Worker giả định API:
          POST {worker_url}/convert
          multipart: model=<name>, file=source.wav
          -> trả wav bytes
        Nếu worker không chạy / lỗi / timeout -> trả lại source (fallback),
        để không phá toàn bộ pipeline.
        """
        if not source_wav:
            return source_wav

        try:
            import httpx

            files = {"file": ("input.wav", source_wav, "audio/wav")}
            data = {"model": self.model_name}
            async with httpx.AsyncClient(timeout=settings.RVC_TIMEOUT) as client:
                resp = await client.post(
                    f"{self.worker_url}/convert", files=files, data=data
                )
                resp.raise_for_status()
                if not resp.content:
                    raise ValueError("RVC worker trả file rỗng")
                logger.info("RVC OK: %d bytes", len(resp.content))
                return resp.content
        except Exception as exc:
            logger.warning("RVC fail (%s) — fallback source.wav.", exc)
            return source_wav
