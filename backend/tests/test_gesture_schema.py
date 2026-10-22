from __future__ import annotations

import unittest

from pydantic import ValidationError

from app.schemas.conversation import ConversationResult, GeminiTurnOutput


def _kwargs(**overrides):
    base = dict(transcript_ja="こんにちは", reply_ja="こんばんは！")
    base.update(overrides)
    return base


class GestureSchemaTest(unittest.TestCase):
    def test_gemini_output_defaults_gesture_none(self) -> None:
        out = GeminiTurnOutput(**_kwargs())
        self.assertEqual(out.gesture, "none")

    def test_gemini_output_accepts_known_gesture(self) -> None:
        out = GeminiTurnOutput(**_kwargs(gesture="wave"))
        self.assertEqual(out.gesture, "wave")

    def test_gemini_output_rejects_unknown_gesture(self) -> None:
        with self.assertRaises(ValidationError):
            GeminiTurnOutput(**_kwargs(gesture="backflip"))

    def test_conversation_result_exposes_gesture(self) -> None:
        result = ConversationResult(
            turn_id="t1", session_id="s1",
            transcript_ja="a", reply_ja="b", audio_url="",
            gesture="sad",
        )
        self.assertEqual(result.gesture, "sad")

    def test_gemini_schema_requires_gesture(self) -> None:
        from app.services.gemini_service import SCHEMA_JSON
        self.assertIn("gesture", SCHEMA_JSON["required"])
        self.assertEqual(
            SCHEMA_JSON["properties"]["gesture"]["enum"],
            ["none", "wave", "nod", "clap", "sad", "thinking", "surprise"],
        )


if __name__ == "__main__":
    unittest.main()
