"""Online text-to-speech through the Fish Audio API."""
from __future__ import annotations

import io
import math
import struct
import wave
from dataclasses import dataclass

import httpx

from ..core.config import settings
from ..core.logging import get_logger

logger = get_logger("fish_audio")


@dataclass(frozen=True)
class AudioPayload:
    data: bytes
    extension: str
    media_type: str


_MEDIA_TYPES = {
    "wav": "audio/wav",
    "mp3": "audio/mpeg",
    "opus": "audio/ogg",
    "pcm": "application/octet-stream",
}

_EMOTION_TAGS = {
    "happy": "[happy]",
    "excited": "[excited]",
    "thinking": "[calm]",
    "embarrassed": "[shy]",
    "sad": "[sad]",
}

_EMOTION_SPEED = {
    "neutral": 1.0,
    "happy": 1.05,
    "excited": 1.10,
    "thinking": 0.94,
    "embarrassed": 0.98,
    "sad": 0.90,
}


class FishAudioService:
    """Generate Japanese speech without running a local voice model."""

    def __init__(self) -> None:
        self.api_url = f"{settings.FISH_API_BASE_URL.rstrip('/')}/v1/tts"
        self.api_key = settings.FISH_API_KEY.strip()
        self.model = settings.FISH_MODEL.strip()
        self.reference_id = settings.FISH_REFERENCE_ID.strip()
        self.audio_format = settings.FISH_AUDIO_FORMAT.lower().strip()
        self.latency = settings.FISH_LATENCY.lower().strip()
        self.timeout = settings.FISH_TIMEOUT
        self.temperature = settings.FISH_TEMPERATURE
        self.top_p = settings.FISH_TOP_P
        self.use_emotion_tags = settings.FISH_EMOTION_TAGS

        if self.audio_format not in _MEDIA_TYPES:
            raise ValueError(
                "FISH_AUDIO_FORMAT must be wav, mp3, opus, or pcm"
            )
        if self.latency not in {"normal", "balanced", "low"}:
            raise ValueError(
                "FISH_LATENCY must be normal, balanced, or low"
            )

    @property
    def media_type(self) -> str:
        return _MEDIA_TYPES[self.audio_format]

    def is_configured(self) -> bool:
        """Do not spend TTS quota for /health; verify required credentials only."""
        return bool(self.api_key and self.model and self.reference_id)

    def check_health(self) -> bool:
        return self.is_configured()

    async def synthesize(self, text: str, emotion: str = "neutral") -> AudioPayload:
        if not text.strip():
            raise ValueError("Fish Audio requires non-empty text")
        if not self.is_configured():
            raise RuntimeError(
                "Fish Audio is not configured. Set FISH_API_KEY and "
                "FISH_REFERENCE_ID in backend/.env."
            )

        normalized_emotion = emotion if emotion in _EMOTION_SPEED else "neutral"
        spoken_text = text.strip()
        tag = _EMOTION_TAGS.get(normalized_emotion) if self.use_emotion_tags else None
        if tag:
            spoken_text = f"{tag} {spoken_text}"

        request_body = {
            "text": spoken_text,
            "reference_id": self.reference_id,
            "format": self.audio_format,
            "latency": self.latency,
            "temperature": self.temperature,
            "top_p": self.top_p,
            "prosody": {
                "speed": _EMOTION_SPEED[normalized_emotion],
                "volume": 0,
            },
        }
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "model": self.model,
        }

        timeout = httpx.Timeout(self.timeout, connect=min(self.timeout, 10.0))
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(self.api_url, headers=headers, json=request_body)
            response.raise_for_status()

        if not response.content:
            raise RuntimeError("Fish Audio returned an empty audio response")

        logger.info(
            "Fish Audio OK: %d bytes (model=%s, format=%s, emotion=%s)",
            len(response.content),
            self.model,
            self.audio_format,
            normalized_emotion,
        )
        return AudioPayload(
            data=response.content,
            extension=self.audio_format,
            media_type=self.media_type,
        )

    @staticmethod
    def mock_wav() -> AudioPayload:
        return AudioPayload(_mock_wav(), "wav", "audio/wav")


def media_type_for_extension(extension: str) -> str:
    return _MEDIA_TYPES.get(extension.lower().lstrip("."), "application/octet-stream")


def _mock_wav() -> bytes:
    """Generate a short WAV tone for UI development without spending API quota."""
    sample_rate = 16000
    duration = 0.8
    frame_count = int(sample_rate * duration)
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        samples = bytearray(frame_count * 2)
        for index in range(frame_count):
            seconds = index / sample_rate
            envelope = min(1.0, seconds * 20, (duration - seconds) * 20)
            value = int(
                8000
                * envelope
                * (
                    0.8 * math.sin(2 * math.pi * 440 * seconds)
                    + 0.2 * math.sin(2 * math.pi * 880 * seconds)
                )
            )
            struct.pack_into("<h", samples, index * 2, max(-32768, min(32767, value)))
        wav_file.writeframes(bytes(samples))
    return buffer.getvalue()


__all__ = ["AudioPayload", "FishAudioService", "media_type_for_extension"]
