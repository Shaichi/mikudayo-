"""Lip-sync service — Phase 5.

Theo mục 10.1 tài liệu:
- Đọc WAV, tính RMS theo cửa sổ 40–60 ms.
- Trả mảng {t_ms, mouth} (0..1) để Flutter/JS nội suy vào ParamMouthOpenY.
- Cues tính trên audio sau RVC để miệng bám đúng file đang phát.
"""
from __future__ import annotations

import io
import math
import wave

from ..core.logging import get_logger
from ..schemas.conversation import MouthCue

logger = get_logger("lipsync")


def _read_wav_samples(wav_bytes: bytes) -> tuple[list[int], int]:
    """Giải mã WAV PCM 16-bit mono/stereo -> (samples, sample_rate)."""
    with wave.open(io.BytesIO(wav_bytes), "rb") as w:
        n_channels = w.getnchannels()
        sampwidth = w.getsampwidth()
        rate = w.getframerate()
        raw = w.readframes(w.getnframes())

    if sampwidth == 2:
        import struct

        count = len(raw) // 2
        samples = struct.unpack(f"<{count}h", raw[: count * 2])
    elif sampwidth == 1:
        samples = [b - 128 for b in raw]
    else:
        logger.warning("Sampwidth %d không hỗ trợ — trả mảng rỗng.", sampwidth)
        return [], rate

    # Mix xuống mono nếu stereo.
    if n_channels > 1:
        samples = [
            samples[i] + samples[i + 1]
            for i in range(0, len(samples) - n_channels + 1, n_channels)
        ]
    return list(samples), rate


def compute_mouth_cues(wav_bytes: bytes, window_ms: int = 50) -> list[MouthCue]:
    """Tính mouth cues từ WAV: RMS cửa sổ `window_ms`, map sang 0..1.

    - Normalize theo percentile để miệng không đóng quá nhiều / mở quá ít.
    - Trả cues với t_ms tăng dần từ 0, bước bằng window_ms.
    """
    try:
        samples, rate = _read_wav_samples(wav_bytes)
    except Exception as exc:
        logger.warning("Lỗi đọc WAV cho lipsync: %s — trả mảng rỗng.", exc)
        return []

    if not samples or rate <= 0:
        return []

    window = max(1, int(rate * window_ms / 1000))
    step = window  # không overlap: mỗi window một cue.

    rms_values: list[float] = []
    for start in range(0, len(samples), step):
        chunk = samples[start : start + window]
        if not chunk:
            break
        mean_sq = sum(s * s for s in chunk) / len(chunk)
        rms = math.sqrt(mean_sq)
        rms_values.append(rms)

    if not rms_values:
        return []

    # Map RMS sang 0..1: dùng percentile 95 làm "miệng mở tối đa".
    max_rms = sorted(rms_values)[int(len(rms_values) * 0.95) - 1]
    max_rms = max(max_rms, 1.0)

    cues: list[MouthCue] = []
    for i, rms in enumerate(rms_values):
        mouth = min(1.0, max(0.02, rms / max_rms))
        cues.append(MouthCue(t_ms=i * window_ms, mouth=round(mouth, 3)))

    return cues
