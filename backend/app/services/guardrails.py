"""Hậu kiểm xác định đầu ra Gemini (feat-ai-guardrails R5, R6, R9).

Hàm thuần, không gọi mạng. `apply` trả (output đã chuẩn hóa, danh sách vấn đề cứng);
vấn đề cứng nghĩa là cần sinh lại hoặc dùng câu dự phòng.
"""
from __future__ import annotations

import re
import unicodedata
from typing import Literal

from ..core.config import settings
from ..schemas.conversation import GeminiTurnOutput, JpLevel, Mode

CorrectionPolicy = Literal["free", "none", "correct"]

FALLBACK_REPLY = "ごめんなさい、もう一度言ってもらえますか？"
_JA = re.compile(r"[぀-ヿ一-鿿　-〿＀-￯]")
_SENTENCE_END = "。！？!?"
_LEAK_MARKERS = ("output contract", "system prompt", "system_instruction", "# context", "grounding knowledge")
MIN_JA_RATIO = 0.6


def sanitize_scenario(text: str, max_len: int | None = None) -> str:
    """Bỏ ký tự điều khiển/xuống dòng, gộp khoảng trắng, cắt độ dài (R9)."""
    cleaned = "".join(" " if unicodedata.category(c).startswith("C") else c for c in (text or ""))
    cleaned = re.sub(r"\s+", " ", cleaned).strip().replace('"', "'")
    limit = max_len or settings.MAX_SCENARIO_LENGTH
    return cleaned[:limit]


def ja_ratio(text: str) -> float:
    letters = [c for c in text if not c.isspace()]
    return sum(1 for c in letters if _JA.match(c)) / len(letters) if letters else 0.0


def _norm(text: str) -> str:
    return re.sub(r"[\s、。，．,.!！?？「」]", "", unicodedata.normalize("NFKC", text or ""))


def truncate_reply(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    cut = text[:limit]
    last = max(cut.rfind(c) for c in _SENTENCE_END)
    return cut[: last + 1] if last >= limit // 3 else cut


def apply(
    out: GeminiTurnOutput,
    *,
    user_text: str,
    level: JpLevel,
    mode: Mode,
    policy: CorrectionPolicy,
    last_gesture: str = "none",
) -> tuple[GeminiTurnOutput, list[str]]:
    data = out.model_dump()
    notes: list[str] = []
    hard: list[str] = []

    # Level phiên là nguồn sự thật.
    if data["difficulty"] != level:
        data["difficulty"] = level

    # Correction: chỉ giữ khi mode + policy cho phép và khác nguyên văn.
    correction = (data.get("correction_ja") or "").strip() or None
    if correction and (mode != "correction" or policy == "none"):
        correction = None
        notes.append("correction_dropped_policy")
    if correction and _norm(correction) == _norm(user_text):
        correction = None
        notes.append("correction_same_as_input")
    data["correction_ja"] = correction
    if correction is None:
        data["explanation_vi"] = None

    # Độ dài reply.
    reply = data["reply_ja"].strip()
    shortened = truncate_reply(reply, settings.AI_MAX_REPLY_CHARS)
    if shortened != reply:
        notes.append("reply_truncated")
    data["reply_ja"] = shortened

    # Từ vựng phải nằm trong reply.
    vocab = [v for v in data["vocabulary"] if v["word"] and v["word"] in data["reply_ja"]]
    if len(vocab) != len(data["vocabulary"]):
        notes.append("vocab_filtered")
    data["vocabulary"] = vocab

    # Không gesture hai lượt liền.
    if data["gesture"] != "none" and last_gesture not in ("", "none"):
        data["gesture"] = "none"
        notes.append("gesture_suppressed")

    # Vấn đề cứng.
    if ja_ratio(data["reply_ja"]) < MIN_JA_RATIO:
        hard.append("reply_not_japanese")
    low = data["reply_ja"].lower()
    if any(m in low for m in _LEAK_MARKERS):
        hard.append("prompt_leak")

    return GeminiTurnOutput.model_validate(data), hard + notes
