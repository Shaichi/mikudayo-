"""Endpoints history + vocabulary."""
from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, HTTPException, Query

from ..repositories import conversation_repository as conv_repo
from ..repositories import vocab_repository as vocab_repo
from ..core.config import settings
from ..schemas.conversation import (
    DeleteResult,
    SessionRecord,
    TurnRecord,
    VocabularyRecord,
)

router = APIRouter()


@router.get("/v1/sessions", response_model=list[SessionRecord])
def list_sessions(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> list[SessionRecord]:
    sessions = conv_repo.list_sessions(limit=limit, offset=offset)
    return [SessionRecord(**s) for s in sessions]


@router.get("/v1/sessions/{sid}/turns", response_model=list[TurnRecord])
def get_turns(
    sid: str,
    limit: int = Query(default=200, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
) -> list[TurnRecord]:
    if not conv_repo.get_session(sid):
        raise HTTPException(404, "Session không tồn tại")
    turns = conv_repo.list_turns(sid, limit=limit, offset=offset)
    return [TurnRecord(**t) for t in turns]


@router.delete("/v1/sessions/{sid}", response_model=DeleteResult)
def delete_session(sid: str) -> DeleteResult:
    turns = conv_repo.list_turns(sid, limit=2000) if conv_repo.get_session(sid) else []
    ok = conv_repo.delete_session(sid)
    if ok:
        temp_root = settings.TEMP_AUDIO_DIR.resolve()
        for turn in turns:
            audio_path = turn.get("audio_path")
            if not audio_path:
                continue
            path = Path(audio_path)
            try:
                path.resolve().relative_to(temp_root)
                if path.exists():
                    path.unlink()
            except (OSError, ValueError):
                pass
            status_path = settings.TEMP_AUDIO_DIR / f"{turn['id']}.status.json"
            try:
                status_path.unlink(missing_ok=True)
            except OSError:
                pass
    return DeleteResult(deleted=ok, session_id=sid)


@router.get("/v1/vocabulary", response_model=list[VocabularyRecord])
def list_vocabulary(
    limit: int = Query(default=200, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
) -> list[VocabularyRecord]:
    vocabulary = vocab_repo.list_vocab(limit=limit, offset=offset)
    return [VocabularyRecord(**v) for v in vocabulary]
