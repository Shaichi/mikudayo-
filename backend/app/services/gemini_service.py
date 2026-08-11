"""Dịch vụ gọi Gemini với structured output (Phase 1 — text chat).

Theo mục 8 của tài liệu:
- Gemini phân tích audio/text và tạo text + JSON theo schema.
- Backend yêu cầu JSON schema thay vì parse text tự do.
- Khi thiếu GEMINI_API_KEY, chạy chế độ mock để pipeline vẫn hoạt động.
"""
from __future__ import annotations

import random
from typing import Optional

from pydantic import ValidationError

from ..core.config import settings
from ..core.logging import get_logger
from ..schemas.conversation import GeminiTurnOutput, JpLevel, Mode

logger = get_logger("gemini")

SYSTEM_PROMPT_TEMPLATE = """You are a Japanese conversation tutor represented by a virtual character.
Goal: help a Vietnamese learner practice spoken Japanese.
Rules:
- Speak mainly in Japanese at the requested JLPT level.
- Keep each spoken reply short (1-3 sentences) unless the user asks for detail.
- Continue the conversation naturally; ask at most one follow-up question.
- Correct only errors that materially affect naturalness/grammar.
- Explanations for corrections must be in Vietnamese.
- Do not claim to be the official Hatsune Miku or Crypton software.
- Return output strictly using the response schema.
Current mode: {mode}
Learner level: {jlpt_level}
Conversation summary: {summary}
Recent turns: {recent_turns}
"""

SCHEMA_JSON = {
    "type": "object",
    "properties": {
        "transcript_ja": {"type": "string"},
        "reply_ja": {"type": "string"},
        "correction_ja": {"type": ["string", "null"]},
        "explanation_vi": {"type": ["string", "null"]},
        "emotion": {
            "type": "string",
            "enum": ["neutral", "happy", "excited", "thinking", "embarrassed", "sad"],
        },
        "difficulty": {"type": "string", "enum": ["N5", "N4", "N3"]},
        "vocabulary": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "word": {"type": "string"},
                    "reading": {"type": "string"},
                    "meaning_vi": {"type": "string"},
                },
                "required": ["word"],
            },
        },
    },
    "required": ["transcript_ja", "reply_ja", "emotion", "difficulty", "vocabulary"],
}

# Chế độ mock — dùng khi chưa có key, để UI/API test được.
_MOCK_REPLIES_N5 = [
    "こんにちは！元気ですか？",
    "いいですね。私は日本語の練習が好きです。",
    "なるほど。それからどうしましたか？",
    "上手ですね！もう一度言ってみてください。",
    "はい、わかりました。次に進みましょう。",
]
_MOCK_REPLIES_N4 = [
    "そうですか。詳しく教えてください。",
    "なるほど、それは面白いですね。",
    "たしかにそうですね。私もそう思います。",
    "ちょっと難しいですが、がんばりましょう。",
]
_MOCK_REPLIES_N3 = [
    "なるほど、そういうことですか。文脈がよくわかりました。",
    "それは良い考えですね。具体的にはどうする予定ですか？",
]


def _mock_output(user_text: str, mode: Mode, level: JpLevel) -> GeminiTurnOutput:
    pool = {
        "N5": _MOCK_REPLIES_N5,
        "N4": _MOCK_REPLIES_N4,
        "N3": _MOCK_REPLIES_N3,
    }[level]
    reply = random.choice(pool)
    vocab = [
        {
            "word": "日本語",
            "reading": "にほんご",
            "meaning_vi": "tiếng Nhật",
        },
        {
            "word": "勉強",
            "reading": "べんきょう",
            "meaning_vi": "việc học tập",
        },
    ]
    emotion = random.choice(["neutral", "happy", "excited"])
    return GeminiTurnOutput(
        transcript_ja=user_text or "（音声入力はまだ対応していません）",
        reply_ja=reply,
        correction_ja=None if mode != "correction" else user_text,
        explanation_vi=None if mode != "correction" else "（Mock）Đây là câu trả lời mẫu để kiểm tra pipeline.",
        emotion=emotion,
        difficulty=level,
        vocabulary=[{**v, "word": v["word"], "reading": v["reading"], "meaning_vi": v["meaning_vi"]} for v in vocab],
    )


class GeminiService:
    def __init__(self) -> None:
        self._client: Optional[object] = None
        self._mock = not bool(settings.GEMINI_API_KEY)
        if not self._mock:
            try:
                from google import genai
                from google.genai import types

                self._client = genai.Client(api_key=settings.GEMINI_API_KEY)
                self._types = types
                logger.info("Gemini client ready (model=%s)", settings.GEMINI_MODEL)
            except Exception as exc:  # pragma: no cover
                logger.warning("Không khởi tạo được Gemini client: %s — dùng mock.", exc)
                self._mock = True

    @property
    def is_mock(self) -> bool:
        return self._mock

    def build_prompt(
        self,
        mode: Mode,
        level: JpLevel,
        summary: str,
        recent_turns: list[dict],
    ) -> str:
        turns_text = "\n".join(
            f"User: {t.get('transcript_ja') or ''}\nMiku: {t.get('reply_ja') or ''}"
            for t in recent_turns[-settings.GEMINI_MAX_TURNS:]
        ) or "（初めての会話）"
        return SYSTEM_PROMPT_TEMPLATE.format(
            mode=mode,
            jlpt_level=level,
            summary=summary or "（まだ要約なし）",
            recent_turns=turns_text,
        )

    def generate_turn(
        self,
        user_text: str,
        mode: Mode,
        level: JpLevel,
        summary: str,
        recent_turns: list[dict],
    ) -> GeminiTurnOutput:
        if self._mock:
            return _mock_output(user_text, mode, level)

        from google.genai import types

        try:
            response = self._client.models.generate_content(
                model=settings.GEMINI_MODEL,
                contents=user_text,
                config=types.GenerateContentConfig(
                    system_instruction=self.build_prompt(mode, level, summary, recent_turns),
                    response_mime_type="application/json",
                    response_schema=SCHEMA_JSON,
                    temperature=settings.GEMINI_TEMPERATURE,
                ),
            )
            raw = response.text
            logger.debug("Gemini raw output: %s", raw[:500])
            # Chuẩn hóa: loại bỏ markdown code fence nếu có
            cleaned = raw.strip()
            if cleaned.startswith("```"):
                cleaned = cleaned.split("\n", 1)[1]
                cleaned = cleaned.rsplit("```", 1)[0].strip()
            data = __import__("json").loads(cleaned)
            return GeminiTurnOutput.model_validate(data)
        except ValidationError as exc:
            logger.error("Gemini trả JSON sai schema: %s", exc)
            raise
        except Exception as exc:
            logger.error("Gemini lỗi: %s", exc)
            raise

    def check_health(self) -> bool:
        if self._mock:
            return False
        try:
            self._client.models.get(model=settings.GEMINI_MODEL)
            return True
        except Exception:
            return False
