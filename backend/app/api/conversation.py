"""Endpoint POST /v1/conversation/turn — pipeline hội thoại (Phase 1–5).

Luồng MVP (mục 5.1):
1. Nhận text (Phase 1) hoặc audio (Phase 2) + mode + level.
2. Ghép system prompt + session context, gọi Gemini.
3. Gemini trả JSON (transcript, reply, correction, explanation, emotion, vocab).
4. Lưu turn vào SQLite.
5. Phase 3+: TTS (VOICEVOX) -> RVC -> lip-sync -> lưu wav -> trả audio_url.
   RVC fail -> fallback source.wav; VOICEVOX không chạy -> mock wav.
"""
from __future__ import annotations

import time

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import ValidationError

from ..core.config import settings
from ..core.logging import get_logger
from ..repositories import conversation_repository as conv_repo
from ..repositories import vocab_repository as vocab_repo
from ..schemas.conversation import (
    ConversationResult,
    JpLevel,
    Mode,
)
from ..services.gemini_service import GeminiService
from ..services.lipsync_service import compute_mouth_cues
from ..services.rvc_service import RvcService
from ..services.voicevox_service import VoicevoxService

logger = get_logger("api.conversation")

router = APIRouter()

_gemini = GeminiService()
_voicevox = VoicevoxService()
_rvc = RvcService()


@router.get("/v1/audio/{turn_id}")
async def get_audio(turn_id: str):
    """Trả wav của một turn (đặt tên theo turn_id trong temp/)."""
    path = settings.TEMP_AUDIO_DIR / f"{turn_id}.wav"
    if not path.exists():
        raise HTTPException(404, "Audio không tồn tại")
    return FileResponse(path, media_type="audio/wav", filename=f"{turn_id}.wav")


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
    audio_data: bytes | None = None
    audio_mime = "audio/wav"

    if audio is not None and audio.filename:
        data = await audio.read()
        if len(data) > settings.MAX_AUDIO_BYTES:
            raise HTTPException(413, "Audio quá lớn")
        timing["upload_bytes"] = len(data)
        audio_data = data
        # Phase 2: Gemini audio understanding sẽ transcribe từ audio_data.
        user_text = ""
        logger.info("Nhận audio %s (%d bytes).", audio.filename, len(data))
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

    # --- Gemini (text hoặc audio) ---
    t0 = time.perf_counter()
    try:
        out = _gemini.generate_turn(
            user_text,
            mode,
            jlpt_level,
            summary,
            recent,
            scenario or "",
            audio_bytes=audio_data,
            audio_mime=audio_mime,
        )
    except ValidationError:
        raise HTTPException(502, "Gemini trả JSON không đúng schema.")
    except ValueError as exc:
        # Whisper không nghe được giọng nói → 400 với lời nhắc thân thiện.
        raise HTTPException(400, str(exc))
    except Exception as exc:
        logger.error("Gemini lỗi: %s", exc)
        raise HTTPException(502, "Không gọi được Gemini.")
    timing["gemini_ms"] = int((time.perf_counter() - t0) * 1000)

    # --- TTS + RVC + lip-sync (Phase 3–5) ---
    # VOICEVOX fail -> mock wav (UI vẫn chạy). RVC fail -> fallback source.wav.
    final_wav, voice_mode, mouth_cues = await _generate_audio(out.reply_ja)

    # --- Lưu turn (audio_path có thể None nếu không sinh được) ---
    turn_id = conv_repo.add_turn(
        session_id=sid,
        transcript_ja=out.transcript_ja,
        reply_ja=out.reply_ja,
        correction_ja=out.correction_ja,
        explanation_vi=out.explanation_vi,
        emotion=out.emotion,
        audio_path=None,  # set sau khi ghi file (đặt tên theo turn_id)
    )

    # --- Lưu audio (tên file = turn_id) ---
    audio_path = None
    if final_wav:
        audio_path = _save_audio_file(turn_id, final_wav)
        conv_repo.update_turn_audio(turn_id, str(audio_path) if audio_path else None)

    # --- Lưu vocabulary ---
    for item in out.vocabulary:
        vid = vocab_repo.upsert_vocab(item)
        vocab_repo.link_turn_vocab(turn_id, vid)

    timing["total_ms"] = sum(v for k, v in timing.items() if isinstance(v, int))

    audio_url = f"/v1/audio/{turn_id}" if audio_path else ""

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
        mouth_cues=mouth_cues,
        timing_ms=timing,
    )


async def _generate_audio(reply_ja: str) -> tuple[bytes | None, str, list]:
    """Tạo audio cho reply: VOICEVOX -> RVC -> lipsync.

    Trả về (final_wav, voice_mode, mouth_cues). Không bao giờ fail toàn request:
    - VOICEVOX không chạy -> mock wav, voice_mode="mock".
    - VOICEVOX chạy, RVC không -> voice_mode="voicevox".
    - VOICEVOX + RVC chạy -> voice_mode="rvc".
    - RVC fail -> fallback source.wav, voice_mode="rvc_fallback".
    """
    if not settings.ALLOW_MOCK and not _voicevox.is_available():
        # Không cho mock mà engine cũng không có -> bỏ audio.
        return None, "none", []

    # VOICEVOX không chạy -> dùng mock wav trực tiếp (không gọi network,
    # tránh treo request). Orchestration: VOICEVOX fail -> vẫn hoạt động.
    voicevox_available = _voicevox.is_available()
    if not voicevox_available:
        source_wav = _voicevox.mock_wav()
    else:
        timing_tts = time.perf_counter()
        source_wav = await _voicevox.synthesize(reply_ja)
        logger.info("VOICEVOX mất %d ms.", int((time.perf_counter() - timing_tts) * 1000))

    voice_mode = "voicevox" if voicevox_available else "mock"

    # RVC (chỉ khi engine VOICEVOX có thật + worker chạy).
    final_wav = source_wav
    if _rvc.check_health():
        timing_rvc = time.perf_counter()
        final_wav = await _rvc.convert(source_wav)
        if final_wav != source_wav:
            voice_mode = "rvc"
        else:
            voice_mode = "rvc_fallback"
        logger.info("RVC mất %d ms.", int((time.perf_counter() - timing_rvc) * 1000))

    # Lưu wav vào temp/ — gọi sau khi có turn_id để đặt tên theo turn.
    mouth_cues = compute_mouth_cues(final_wav)
    return final_wav, voice_mode, mouth_cues


def _save_audio_file(turn_id: str, wav: bytes) -> object:
    """Ghi wav vào settings.TEMP_AUDIO_DIR với tên = turn_id."""
    settings.TEMP_AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    path = settings.TEMP_AUDIO_DIR / f"{turn_id}.wav"
    try:
        path.write_bytes(wav)
        logger.info("Audio saved: %s (%d bytes).", path.name, len(wav))
    except Exception as exc:
        logger.error("Không lưu được audio: %s", exc)
        return None
    return path
