"""Dịch vụ RVC voice conversion — PHASE 4 (chưa tích hợp Phase 1).

Theo mục 9.2 tài liệu:
- RVC chỉ là lớp đổi timbre, chạy worker riêng (venv riêng).
- Model lifecycle: load khi start worker, giữ warm.
- Input source.wav từ VOICEVOX, Output final.wav.
- Fallback: nếu worker timeout/crash -> dùng source.wav.

Phase 1 chưa dùng. Đây là khung để phiên tiếp theo (Phase 4) triển khai.
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

    # TODO(Phase 4): triển khai convert(source_wav) -> final_wav.
    # Nếu lỗi: trả lại source wav (fallback), không fail toàn request.
    def convert(self, source_wav: bytes) -> bytes:
        raise NotImplementedError("RVC conversion được triển khai ở Phase 4.")
