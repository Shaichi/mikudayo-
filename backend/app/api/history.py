"""Endpoints history + vocabulary."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException

from ..repositories import conversation_repository as conv_repo
from ..repositories import vocab_repository as vocab_repo
from ..schemas.conversation import (
    DeleteResult,
    SessionRecord,
    TurnRecord,
    VocabularyRecord,
)

router = APIRouter()


@router.get("/v1/sessions", response_model=list[SessionRecord])
def list_sessions() -> list[SessionRecord]:
    return [SessionRecord(**s) for s in conv_repo.list_sessions()]


@router.get("/v1/sessions/{sid}/turns", response_model=list[TurnRecord])
def get_turns(sid: str) -> list[TurnRecord]:
    if not conv_repo.get_session(sid):
        raise HTTPException(404, "Session không tồn tại")
    return [TurnRecord(**t) for t in conv_repo.list_turns(sid)]


@router.delete("/v1/sessions/{sid}", response_model=DeleteResult)
def delete_session(sid: str) -> DeleteResult:
    ok = conv_repo.delete_session(sid)
    return DeleteResult(deleted=ok, session_id=sid)


@router.get("/v1/vocabulary", response_model=list[VocabularyRecord])
def list_vocabulary() -> list[VocabularyRecord]:
    return [VocabularyRecord(**v) for v in vocab_repo.list_vocab()]
