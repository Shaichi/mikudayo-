from __future__ import annotations

import io
import unittest
import wave
from unittest.mock import patch

from app.services.fish_audio_service import FishAudioService, add_wav_preroll


class _FakeResponse:
    content = b"RIFF-online-audio"

    def raise_for_status(self) -> None:
        return None


class _FakeClient:
    def __init__(self, *args, **kwargs) -> None:
        self.request: tuple[str, dict, dict] | None = None

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, traceback) -> None:
        return None

    async def post(self, url: str, *, headers: dict, json: dict) -> _FakeResponse:
        self.request = (url, headers, json)
        return _FakeResponse()


class FishAudioServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_synthesize_uses_reference_id_and_emotion(self) -> None:
        service = FishAudioService()
        service.api_key = "test-key"
        service.reference_id = "voice-id"
        service.model = "test-model"
        service.audio_format = "wav"
        fake_client = _FakeClient()

        with patch(
            "app.services.fish_audio_service.httpx.AsyncClient",
            return_value=fake_client,
        ):
            result = await service.synthesize("今日は一緒に勉強しよう！", "happy")

        self.assertEqual(result.data, b"RIFF-online-audio")
        self.assertEqual(result.extension, "wav")
        assert fake_client.request is not None
        url, headers, body = fake_client.request
        self.assertEqual(url, "https://api.fish.audio/v1/tts")
        self.assertEqual(headers["Authorization"], "Bearer test-key")
        self.assertEqual(headers["model"], "test-model")
        self.assertEqual(body["reference_id"], "voice-id")
        self.assertTrue(body["text"].startswith("[happy] "))
        self.assertGreater(body["prosody"]["speed"], 1.0)

    async def test_missing_key_is_not_reported_as_online(self) -> None:
        service = FishAudioService()
        service.api_key = ""

        self.assertFalse(service.check_health())
        with self.assertRaises(RuntimeError):
            await service.synthesize("こんにちは")


    def test_wav_preroll_preserves_audio_after_silence(self) -> None:
        source = FishAudioService.mock_wav()
        padded = add_wav_preroll(source, 300)

        with wave.open(io.BytesIO(source.data), "rb") as original:
            original_frames = original.readframes(original.getnframes())
            sample_rate = original.getframerate()
            frame_width = original.getnchannels() * original.getsampwidth()
        with wave.open(io.BytesIO(padded.data), "rb") as result:
            result_frames = result.readframes(result.getnframes())

        silence_bytes = round(sample_rate * 0.3) * frame_width
        self.assertEqual(result_frames[:silence_bytes], bytes(silence_bytes))
        self.assertEqual(result_frames[silence_bytes:], original_frames)


if __name__ == "__main__":
    unittest.main()
