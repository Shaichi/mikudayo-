from __future__ import annotations

import io
import struct
import unittest
import wave

from pydantic import ValidationError

from app.schemas.conversation import GeminiTurnOutput
from app.services.lipsync_service import compute_mouth_cues


class BackendHardeningTest(unittest.TestCase):
    def test_gemini_vocabulary_is_bounded(self) -> None:
        with self.assertRaises(ValidationError):
            GeminiTurnOutput(
                transcript_ja="こんにちは",
                reply_ja="はい",
                vocabulary=[
                    {"word": str(index), "reading": "", "meaning_vi": ""}
                    for index in range(5)
                ],
            )

    def test_lipsync_closes_on_stereo_silence(self) -> None:
        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as wav_file:
            wav_file.setnchannels(2)
            wav_file.setsampwidth(2)
            wav_file.setframerate(1000)
            # 100 ms silence followed by a short stereo tone.
            samples: list[int] = [0] * 200
            samples.extend([12000, 12000] * 50)
            raw = b"".join(struct.pack("<h", sample) for sample in samples)
            wav_file.writeframes(raw)

        cues = compute_mouth_cues(buffer.getvalue(), window_ms=50)
        self.assertGreaterEqual(len(cues), 2)
        self.assertEqual(cues[0].mouth, 0.0)
        self.assertGreater(cues[-1].mouth, 0.0)


if __name__ == "__main__":
    unittest.main()
