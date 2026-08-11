"""Lip-sync service — PHASE 5 (chưa tích hợp Phase 1).

Theo mục 10.1 tài liệu:
- Đọc final.wav, tính RMS theo cửa sổ 40–60 ms.
- Trả mảng {t_ms, mouth} (0..1) để Flutter/JS nội suy vào ParamMouthOpenY.
- Cues tính trên audio sau RVC để miệng bám đúng file đang phát.

Phase 1 chưa cần. Khung sẵn cho phiên tiếp theo (Phase 5) triển khai.
"""
from __future__ import annotations

from ..core.logging import get_logger
from ..schemas.conversation import MouthCue

logger = get_logger("lipsync")


# TODO(Phase 5): triển khai compute_mouth_cues(wav_bytes) -> list[MouthCue]
# - Parse WAV (hoặc dùng pydub/wave).
# - Chia cửa sổ 40-60ms, tính RMS -> map sang 0..1.
def compute_mouth_cues(wav_bytes: bytes, window_ms: int = 50) -> list[MouthCue]:
    raise NotImplementedError("Lip-sync được triển khai ở Phase 5.")
