"""Endpoint POST /v1/conversation/turn — pipeline hội thoại (Phase 1–5).

Luồng MVP (mục 5.1):
1. Nhận transcript text từ Flutter + mode + level.
2. Ghép system prompt + session context, gọi Gemini.
3. Gemini trả JSON (transcript, reply, correction, explanation, emotion, vocab).
4. Lưu turn vào SQLite.
5. Fish Audio sinh giọng online; backend lưu audio tạm và trả audio_url.
"""
from __future__ import annotations

import json
import time
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, Form, HTTPException
from fastapi.responses import FileResponse
from pydantic import ValidationError

from ..core.config import settings
from ..core.logging import get_logger
from ..repositories import conversation_repository as conv_repo
from ..repositories import vocab_repository as vocab_repo
from ..schemas.conversation import (
    AudioGenerationStatus,
    ConversationResult,
    JpLevel,
    Mode,
)
from ..services.gemini_service import GeminiService
from ..services.fish_audio_service import (
    AudioPayload,
    FishAudioService,
    add_wav_preroll,
    media_type_for_extension,
)
from ..services.lipsync_service import compute_mouth_cues

logger = get_logger("api.conversation")

router = APIRouter()

_gemini = GeminiService()
_fish_audio = FishAudioService()


def _audio_status_path(turn_id: str):
    return settings.TEMP_AUDIO_DIR / f"{turn_id}.status.json"


def _write_audio_status(turn_id: str, status: AudioGenerationStatus) -> None:
    settings.TEMP_AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    path = _audio_status_path(turn_id)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(
        json.dumps(status.model_dump(mode="json"), ensure_ascii=False),
        encoding="utf-8",
    )
    temporary.replace(path)


@router.get("/v1/audio/{turn_id}/status", response_model=AudioGenerationStatus)
async def get_audio_status(turn_id: str) -> AudioGenerationStatus:
    """Cho Flutter poll nhẹ trong khi Fish Audio đang chạy nền."""
    status_path = _audio_status_path(turn_id)
    if status_path.exists():
        try:
            return AudioGenerationStatus.model_validate_json(
                status_path.read_text(encoding="utf-8")
            )
        except Exception as exc:
            logger.warning("Không đọc được audio status %s: %s", turn_id, exc)

    turn = conv_repo.get_turn(turn_id)
    audio_path = Path(turn["audio_path"]) if turn and turn.get("audio_path") else None
    if audio_path and audio_path.exists():
        return AudioGenerationStatus(
            status="ready",
            audio_url=f"/v1/audio/{turn_id}",
            voice_mode="fish_audio",
        )
    if turn is None:
        raise HTTPException(404, "Lượt hội thoại không tồn tại")
    return AudioGenerationStatus()


@router.get("/v1/audio/{turn_id}")
async def get_audio(turn_id: str):
    """Trả audio Fish đã lưu tạm cho một turn."""
    turn = conv_repo.get_turn(turn_id)
    if turn is None or not turn.get("audio_path"):
        raise HTTPException(404, "Audio không tồn tại")

    path = Path(turn["audio_path"])
    try:
        path.resolve().relative_to(settings.TEMP_AUDIO_DIR.resolve())
    except (OSError, ValueError):
        logger.error("Từ chối audio path ngoài thư mục temp: %s", path)
        raise HTTPException(404, "Audio không tồn tại")
    if not path.exists():
        raise HTTPException(404, "Audio không tồn tại")

    extension = path.suffix.lstrip(".").lower()
    return FileResponse(
        path,
        media_type=media_type_for_extension(extension),
        filename=path.name,
    )


@router.post("/v1/conversation/turn", response_model=ConversationResult)
async def conversation_turn(
    background_tasks: BackgroundTasks,
    session_id: str = Form(default=""),
    mode: Mode = Form(default="free_talk"),
    jlpt_level: JpLevel = Form(default="N5"),
    scenario: str = Form(default=""),
    text: str = Form(default="", description="Transcript hoặc text người dùng"),
) -> ConversationResult:
    request_started = time.perf_counter()
    timing: dict = {}
    user_text = (text or "").strip()
    if not user_text:
        raise HTTPException(422, "Cần gửi transcript hoặc text.")

    # --- Session ---
    # Dùng session có sẵn nếu tồn tại; ngược lại tạo session mới.
    sid = session_id if session_id and conv_repo.get_session(session_id) else None
    if sid is None:
        sid = conv_repo.new_session(mode, jlpt_level, scenario or None)

    summary = conv_repo.get_session(sid).get("summary") or ""
    recent = conv_repo.get_recent_turns(sid, settings.GEMINI_MAX_TURNS)

    # --- Gemini (text only) ---
    t0 = time.perf_counter()
    try:
        out = _gemini.generate_turn(
            user_text,
            mode,
            jlpt_level,
            summary,
            recent,
            scenario or "",
        )
    except ValidationError:
        raise HTTPException(502, "Gemini trả JSON không đúng schema.")
    except Exception as exc:
        logger.error("Gemini lỗi: %s", exc)
        raise HTTPException(502, "Không gọi được Gemini.")
    timing["gemini_ms"] = int((time.perf_counter() - t0) * 1000)

    # Lưu text trước để phản hồi Flutter ngay; audio được tạo ở background.
    turn_id = conv_repo.add_turn(
        session_id=sid,
        transcript_ja=out.transcript_ja,
        reply_ja=out.reply_ja,
        correction_ja=out.correction_ja,
        explanation_vi=out.explanation_vi,
        emotion=out.emotion,
        audio_path=None,  # set sau khi ghi file (đặt tên theo turn_id)
    )

    # --- Lưu vocabulary ---
    for item in out.vocabulary:
        vid = vocab_repo.upsert_vocab(item)
        vocab_repo.link_turn_vocab(turn_id, vid)

    _write_audio_status(turn_id, AudioGenerationStatus())
    background_tasks.add_task(
        _generate_and_store_audio,
        turn_id,
        out.reply_ja,
        out.emotion,
    )
    timing["response_ms"] = int((time.perf_counter() - request_started) * 1000)

    return ConversationResult(
        turn_id=turn_id,
        session_id=sid,
        transcript_ja=out.transcript_ja,
        reply_ja=out.reply_ja,
        correction_ja=out.correction_ja,
        explanation_vi=out.explanation_vi,
        emotion=out.emotion,
        vocabulary=out.vocabulary,
        audio_url="",
        voice_mode="pending",
        mouth_cues=[],
        timing_ms=timing,
    )


async def _generate_and_store_audio(
    turn_id: str,
    reply_ja: str,
    emotion: str,
) -> None:
    """Tạo giọng sau khi response text đã được gửi về Flutter."""
    started = time.perf_counter()
    try:
        audio, voice_mode, mouth_cues, timing = await _generate_audio(
            reply_ja,
            emotion,
        )
        if not audio.data:
            raise RuntimeError("Không tạo được audio")

        audio_path = _save_audio_file(turn_id, audio)
        if audio_path is None:
            raise RuntimeError("Không lưu được audio")
        conv_repo.update_turn_audio(turn_id, str(audio_path))

        timing["audio_total_ms"] = int((time.perf_counter() - started) * 1000)
        _write_audio_status(
            turn_id,
            AudioGenerationStatus(
                status="ready",
                audio_url=f"/v1/audio/{turn_id}",
                voice_mode=voice_mode,
                mouth_cues=mouth_cues,
                timing_ms=timing,
            ),
        )
    except Exception as exc:
        logger.exception("Audio background fail cho turn %s", turn_id)
        _write_audio_status(
            turn_id,
            AudioGenerationStatus(
                status="error",
                voice_mode="none",
                error=str(exc),
                timing_ms={
                    "audio_total_ms": int((time.perf_counter() - started) * 1000)
                },
            ),
        )


async def _generate_audio(
    reply_ja: str, emotion: str = "neutral"
) -> tuple[AudioPayload, str, list, dict[str, int]]:
    """Tạo audio online bằng Fish Audio hoặc WAV mock khi chưa cấu hình key."""
    if not settings.ALLOW_MOCK and not _fish_audio.is_configured():
        raise RuntimeError("Fish Audio chưa được cấu hình")

    timing: dict[str, int] = {}
    if not _fish_audio.is_configured():
        audio = _fish_audio.mock_wav()
        timing["tts_ms"] = 0
        voice_mode = "mock"
    else:
        timing_tts = time.perf_counter()
        audio = await _fish_audio.synthesize(reply_ja, emotion)
        timing["tts_ms"] = int((time.perf_counter() - timing_tts) * 1000)
        logger.info("Fish Audio mất %d ms.", timing["tts_ms"])
        voice_mode = "fish_audio"

    # Dùng WAV mặc định để giữ lip-sync RMS. MP3/Opus vẫn phát được nhưng không
    # được giải mã lại ở backend nhằm tránh thêm ffmpeg/local audio processing.
    audio = add_wav_preroll(audio, settings.FISH_AUDIO_PREROLL_MS)
    mouth_cues = compute_mouth_cues(audio.data) if audio.extension == "wav" else []
    return audio, voice_mode, mouth_cues, timing


def _save_audio_file(turn_id: str, audio: AudioPayload) -> Path | None:
    """Lưu bytes Fish trả về với đúng phần mở rộng."""
    settings.TEMP_AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    path = settings.TEMP_AUDIO_DIR / f"{turn_id}.{audio.extension}"
    try:
        path.write_bytes(audio.data)
        logger.info("Audio saved: %s (%d bytes).", path.name, len(audio.data))
    except Exception as exc:
        logger.error("Không lưu được audio: %s", exc)
        return None
    return path
