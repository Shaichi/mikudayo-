"""Endpoint POST /v1/conversation/turn — pipeline hội thoại (Phase 1: text chat).

Luồng MVP (mục 5.1):
1. Nhận text (hoặc audio — Phase 2) + mode + level.
2. Ghép system prompt + session context, gọi Gemini.
3. Gemini trả JSON (transcript, reply, correction, explanation, emotion, vocab).
4. Lưu turn vào SQLite.
5. Phase 3+: TTS + RVC + lip-sync rồi trả audio. Phase 1 trả text + mock cues.
"""
from __future__ import annotations

import json
import time

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from pydantic import ValidationError

from ..core.config import settings
from ..core.logging import get_logger
from ..repositories import conversation_repository as conv_repo
from ..repositories import vocab_repository as vocab_repo
from ..schemas.conversation import (
    ConversationRequest,
    ConversationResult,
    JpLevel,
    Mode,
    VocabItem,
)
from ..services.gemini_service import GeminiService

logger = get_logger("api.conversation")

router = APIRouter()

_gemini = GeminiService()


@router.post("/v1/conversation/turn", response_model=ConversationResult)
async def conversation_turn(
    audio: UploadFile | None = File(default=None, description="Audio input (Phase 2+)"),
    session_id: str = Form(default=""),
    mode: Mode = Form(default="free_talk"),
    jlpt_level: JpLevel = Form(default="N5"),
    scenario: str = Form(default=""),
    text: str = Form(default="", description="Text input (Phase 1)"),
) -> ConversationResult:
    timing: dict = {}

    if audio is not None and audio.filename:
        data = await audio.read()
        if len(data) > settings.MAX_AUDIO_BYTES:
            raise HTTPException(413, "Audio quá lớn")
        timing["upload_bytes"] = len(data)
        # TODO(Phase 2): gọi Gemini audio understanding để transcribe.
        user_text = "（音声入力はPhase 2で対応）"
        logger.info("Nhận audio %s (%d bytes) — Phase 2 chưa xử lý.", audio.filename, len(data))
    else:
        user_text = (text or "").strip()
        if not user_text:
            raise HTTPException(422, "Cần gửi text (Phase 1) hoặc audio (Phase 2).")

    # --- Session ---
    # Dùng session có sẵn nếu tồn tại; ngược lại tạo session mới.
    sid = session_id if session_id and conv_repo.get_session(session_id) else None
    if sid is None:
        sid = conv_repo.new_session(mode, jlpt_level, scenario or None)

    summary = conv_repo.get_session(sid).get("summary") or ""
    recent = conv_repo.get_recent_turns(sid, settings.GEMINI_MAX_TURNS)

    # --- Gemini ---
    t0 = time.perf_counter()
    try:
        out = _gemini.generate_turn(user_text, mode, jlpt_level, summary, recent)
    except ValidationError:
        raise HTTPException(502, "Gemini trả JSON không đúng schema.")
    except Exception as exc:
        logger.error("Gemini lỗi: %s", exc)
        raise HTTPException(502, "Không gọi được Gemini.")
    timing["gemini_ms"] = int((time.perf_counter() - t0) * 1000)

    # --- Lưu turn ---
    turn_id = conv_repo.add_turn(
        session_id=sid,
        transcript_ja=out.transcript_ja,
        reply_ja=out.reply_ja,
        correction_ja=out.correction_ja,
        explanation_vi=out.explanation_vi,
        emotion=out.emotion,
        audio_path=None,  # Phase 3+
    )

    # --- Lưu vocabulary ---
    for item in out.vocabulary:
        vid = vocab_repo.upsert_vocab(item)
        vocab_repo.link_turn_vocab(turn_id, vid)

    timing["total_ms"] = int(time.perf_counter() * 0) + sum(
        v for k, v in timing.items() if isinstance(v, int)
    ) + int((time.perf_counter() - t0) * 1000)

    voice_mode = "mock"
    audio_url = ""

    return ConversationResult(
        turn_id=turn_id,
        session_id=sid,
        transcript_ja=out.transcript_ja,
        reply_ja=out.reply_ja,
        correction_ja=out.correction_ja,
        explanation_vi=out.explanation_vi,
        emotion=out.emotion,
        vocabulary=out.vocabulary,
        audio_url=audio_url,
        voice_mode=voice_mode,
        mouth_cues=[],
        timing_ms=timing,
    )
