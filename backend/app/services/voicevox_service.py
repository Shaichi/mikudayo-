"""Dịch vụ VOICEVOX TTS — Phase 3.

Theo mục 9.1 tài liệu:
- POST {base}/audio_query?text=<reply>&speaker=<id>  -> audio_query.json
- chỉnh speedScale/pitchScale/intonationScale nếu cần
- POST {base}/synthesis?speaker=<id>  Body: audio_query.json  -> source.wav

Orchestration rules (mục 7.3):
- VOICEVOX fail -> không fail toàn request; fallback mock wav để UI vẫn chạy.
- Engine có thể chưa cài -> `synthesize()` trả mock wav (silence ngắn + tone)
  kèm flag, để Flutter phát được end-to-end khi không có engine.
"""
from __future__ import annotations

import io
import struct
import wave
from typing import Optional

from ..core.config import settings
from ..core.logging import get_logger

logger = get_logger("voicevox")


class VoicevoxService:
    def __init__(self) -> None:
        self.base_url = settings.VOICEVOX_BASE_URL
        self.speaker_id = settings.VOICEVOX_SPEAKER_ID

    def is_available(self) -> bool:
        return self.check_health()

    def check_health(self) -> bool:
        """Kiểm tra engine có chạy trên port không."""
        try:
            import httpx

            resp = httpx.get(f"{self.base_url}/version", timeout=3)
            return resp.status_code == 200
        except Exception:
            return False

    @staticmethod
    def mock_wav() -> bytes:
        """WAV mẫu dùng khi engine không có sẵn (mock TTS)."""
        return _mock_wav()

    async def synthesize(self, text: str) -> bytes:
        """Tạo WAV cho `text` (reply_ja của Miku).

        Luồng: /audio_query -> audio_query.json -> /synthesis -> source.wav.
        Nếu engine không chạy -> trả mock wav (để UI test được end-to-end).
        """
        if not text.strip():
            return _mock_wav()

        import httpx

        try:
            params = {"text": text, "speaker": self.speaker_id}
            async with httpx.AsyncClient(timeout=15) as client:
                # 1. AudioQuery
                aq = await client.post(
                    f"{self.base_url}/audio_query", params=params
                )
                aq.raise_for_status()
                query = aq.json()
                # 2. Tinh chỉnh giọng đọc (tuỳ chọn)
                query["speedScale"] = min(max(query.get("speedScale", 1.0), 0.5), 2.0)
                # 3. Synthesis — gửi audio_query JSON dưới dạng body JSON
                # (httpx: dict phải dùng `json=`, không dùng `content=` sẽ lỗi
                #  "Unexpected type for 'content'").
                syn = await client.post(
                    f"{self.base_url}/synthesis",
                    params={"speaker": self.speaker_id},
                    json=query,
                )
                syn.raise_for_status()
                wav = syn.content
                logger.info("VOICEVOX OK: %d bytes", len(wav))
                return wav
        except Exception as exc:
            logger.warning("VOICEVOX fail (%s) — dùng mock wav.", exc)
            return _mock_wav()


def _mock_wav() -> bytes:
    """WAV mẫu: 0.8s tone 440Hz 16kHz mono 16-bit — đủ để Flutter phát thử."""
    import math

    sample_rate = 16000
    duration = 0.8
    frames = int(sample_rate * duration)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        # Phải ghi qua w.writeframes để wave module cập nhật header RIFF.
        samples = bytearray(frames * 2)
        for i in range(frames):
            t = i / sample_rate
            envelope = min(1.0, t * 20, (duration - t) * 20)
            amp = int(8000 * envelope)
            val = int(
                amp
                * (0.8 * math.sin(2 * 3.14159 * 440 * t)
                   + 0.2 * math.sin(2 * 3.14159 * 880 * t))
            )
            val = max(-32768, min(32767, val))
            struct.pack_into("<h", samples, i * 2, val)
        w.writeframes(bytes(samples))
    return buf.getvalue()


__all__ = ["VoicevoxService", "_mock_wav"]
