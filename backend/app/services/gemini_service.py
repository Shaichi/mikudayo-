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

SYSTEM_PROMPT_TEMPLATE = """You are Miku, a friendly Japanese conversation tutor. Your student is a Vietnamese learner of Japanese.

# Output contract — ALWAYS follow exactly
Return ONE JSON object matching the schema. Every field must be filled:
- transcript_ja: the user's most recent utterance in Japanese (or "（なし）" if none).
- reply_ja: your reply to the user, in Japanese.
- correction_ja: only if mode is "correction" AND the user made a real grammar/naturalness error; otherwise null.
- explanation_vi: Vietnamese explanation of the correction (only when correction_ja is set); otherwise null.
- emotion: one of [neutral, happy, excited, thinking, embarrassed, sad].
- difficulty: the JLPT level that best matches your reply.
- vocabulary: 0-4 new words from YOUR reply that the learner may not know. Each has word (Japanese), reading (kana), meaning_vi (Vietnamese). Use an empty list [] if nothing is worth teaching.

# Language
- reply_ja is ALWAYS in Japanese.
- emotion is your current mood (match the conversation tone).
- Do not claim to be the official Hatsune Miku or Crypton software.

# Speaking style — consistent, short, warm
- Keep reply_ja to 1-3 short sentences. No long paragraphs.
- Be warm and encouraging (Miku persona), but stay in character as a tutor.
- Use hiragana/kanji appropriate to the learner's level. For N5, keep sentences simple and add furigana-style reading hints only in vocabulary.
- Never answer a technical/off-topic question in detail; gently steer back to Japanese practice.

# Mode-specific rules
- free_talk: natural casual chat in Japanese. Ask at most ONE follow-up question per reply.
- correction: listen for grammar/naturalness errors in the user's Japanese. Correct only errors that materially affect meaning or naturalness. Put the corrected sentence in correction_ja and a short Vietnamese explanation in explanation_vi. Then reply normally in Japanese.
- roleplay: you play the role described below. Stay in that role for the whole conversation and address the user as the role requires. Use the scenario as the setting and starting point.

# Level matching
- Reply using vocabulary and grammar appropriate to {jlpt_level}.
- If the user speaks above their level, match them but keep replies simple.
- difficulty must equal {jlpt_level} unless the user's level is clearly different; otherwise keep {jlpt_level}.

# Context
- Current mode: {mode}
- Roleplay scenario (empty unless mode=roleplay): {scenario}
- Learner level: {jlpt_level}
- Conversation summary: {summary}
- Recent turns:
{recent_turns}
"""

SCHEMA_JSON = {
    "type": "object",
    "properties": {
        "transcript_ja": {"type": "string"},
        "reply_ja": {"type": "string"},
        # Gemini API không chấp nhận kiểu union ["string","null"] —
        # phải dùng "nullable": true (nếu không sẽ 502 "validation errors for Schema").
        "correction_ja": {"type": "string", "nullable": True},
        "explanation_vi": {"type": "string", "nullable": True},
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

# Schema NHỎ cho audio input. Model mới (gemini-flash-latest) trả 500 INTERNAL
# khi audio + schema to (có enum/array/nested). Khi có audio_bytes ta chỉ xin
# transcript + reply + emotion để model xử lý được; các field còn lại để default.
AUDIO_SCHEMA_JSON = {
    "type": "object",
    "properties": {
        "transcript_ja": {"type": "string"},
        "reply_ja": {"type": "string"},
        "emotion": {"type": "string", "enum": ["neutral", "happy", "excited", "thinking", "embarrassed", "sad"]},
    },
    "required": ["transcript_ja", "reply_ja", "emotion"],
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
        scenario: str = "",
    ) -> str:
        turns_text = "\n".join(
            f"User: {t.get('transcript_ja') or ''}\nMiku: {t.get('reply_ja') or ''}"
            for t in recent_turns[-settings.GEMINI_MAX_TURNS:]
        ) or "（初めての会話）"
        return SYSTEM_PROMPT_TEMPLATE.format(
            mode=mode,
            jlpt_level=level,
            summary=summary or "（まだ要約なし）",
            scenario=scenario or "（không có）",
            recent_turns=turns_text,
        )

    def generate_turn(
        self,
        user_text: str,
        mode: Mode,
        level: JpLevel,
        summary: str,
        recent_turns: list[dict],
        scenario: str = "",
        audio_bytes: Optional[bytes] = None,
        audio_mime: str = "audio/wav",
    ) -> GeminiTurnOutput:
        """Gọi Gemini với text (hoặc audio ở Phase 2+).

        - `audio_bytes` != None:
          1. Transcribe bằng faster-whisper (local, không key) → text.
          2. Gửi text đó vào Gemini (text-only, schema đầy đủ).
          => Không phụ thuộc model Gemini có hỗ trợ audio hay không.
          Nếu Whisper không ra text (lỗi) → fallback gửi audio thẳng vào Gemini
          bằng schema nhỏ (AUDIO_SCHEMA_JSON).
        - Mock mode: nếu có audio thì transcribe bằng chuỗi mẫu, vẫn trả reply.
        """
        if self._mock:
            if audio_bytes is not None:
                user_text = "（音声入力・モック）こんにちは、元気ですか？"
            return _mock_output(user_text, mode, level)

        from google.genai import types

        # --- Phase 2+: audio → text bằng Whisper (bên thứ 3 local) ---
        # Whisper transcribe trước → gọi Gemini text-only (3.5-flash-lite).
        # Không gửi audio thẳng Gemini vì model text-only sẽ 500.
        if audio_bytes is not None:
            from . import stt_service

            user_text = stt_service.transcribe_audio(audio_bytes)
            if not user_text.strip():
                # Whisper không nghe được giọng nói (rỗng/lỗi) → báo lỗi thân thiện.
                logger.warning("Whisper không transcribe được audio, trả lỗi.")
                raise ValueError("Không nghe rõ bạn nói gì. Hãy thử lại gần mic hơn.")

        try:
            # Quan trọng: gửi contents dạng UserContent (role=user), KHÔNG phải
            # string thô. Nếu gửi string, model bỏ qua user input và trả reply
            # chung chung ("lộn xộn"). UserContent giúp model nhận đúng user turn.
            contents = types.UserContent(parts=[types.Part(text=user_text)])
            schema = SCHEMA_JSON

            response = self._client.models.generate_content(
                model=settings.GEMINI_MODEL,
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=self.build_prompt(mode, level, summary, recent_turns, scenario),
                    response_mime_type="application/json",
                    response_schema=schema,
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
