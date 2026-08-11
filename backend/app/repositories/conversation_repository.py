"""Repository cho hội thoại (sessions + turns)."""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from ..db.sqlite import get_conn


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def new_session(mode: str, jlpt_level: str, scenario: Optional[str] = None) -> str:
    sid = str(uuid.uuid4())
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO sessions (id, mode, jlpt_level, scenario, created_at) VALUES (?,?,?,?,?)",
            (sid, mode, jlpt_level, scenario, _now()),
        )
    return sid


def get_session(sid: str) -> Optional[dict]:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM sessions WHERE id=?", (sid,)).fetchone()
    return dict(row) if row else None


def list_sessions() -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT s.*, COUNT(t.id) AS turn_count
            FROM sessions s LEFT JOIN turns t ON t.session_id = s.id
            GROUP BY s.id ORDER BY s.created_at DESC
            """
        ).fetchall()
    return [dict(r) for r in rows]


def delete_session(sid: str) -> bool:
    with get_conn() as conn:
        cur = conn.execute("DELETE FROM sessions WHERE id=?", (sid,))
    return cur.rowcount > 0


def add_turn(
    session_id: str,
    transcript_ja: str,
    reply_ja: str,
    correction_ja: Optional[str],
    explanation_vi: Optional[str],
    emotion: str,
    audio_path: Optional[str] = None,
) -> str:
    tid = str(uuid.uuid4())
    with get_conn() as conn:
        conn.execute(
            """INSERT INTO turns
               (id, session_id, transcript_ja, reply_ja, correction_ja,
                explanation_vi, emotion, audio_path, created_at)
               VALUES (?,?,?,?,?,?,?,?,?)""",
            (tid, session_id, transcript_ja, reply_ja, correction_ja,
             explanation_vi, emotion, audio_path, _now()),
        )
    return tid


def list_turns(session_id: str) -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM turns WHERE session_id=? ORDER BY created_at ASC",
            (session_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def get_turn(turn_id: str) -> Optional[dict]:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM turns WHERE id=?", (turn_id,)).fetchone()
    return dict(row) if row else None


def update_turn_audio(turn_id: str, audio_path: str | None) -> None:
    with get_conn() as conn:
        conn.execute("UPDATE turns SET audio_path=? WHERE id=?", (audio_path, turn_id))


def update_session_summary(session_id: str, summary: str) -> None:
    with get_conn() as conn:
        conn.execute("UPDATE sessions SET summary=? WHERE id=?", (summary, session_id))


def get_recent_turns(session_id: str, limit: int) -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute(
            """SELECT transcript_ja, reply_ja, correction_ja
               FROM turns WHERE session_id=?
               ORDER BY created_at DESC LIMIT ?""",
            (session_id, limit),
        ).fetchall()
    return list(reversed([dict(r) for r in rows]))
