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


def list_sessions(limit: int | None = None, offset: int = 0) -> list[dict]:
    limit = max(1, min(limit or 200, 1000))
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT s.*, COUNT(t.id) AS turn_count
            FROM sessions s LEFT JOIN turns t ON t.session_id = s.id
            GROUP BY s.id ORDER BY s.created_at DESC, s.id DESC
            LIMIT ? OFFSET ?
            """,
            (limit, max(0, offset)),
        ).fetchall()
    return [dict(r) for r in rows]


def delete_session(sid: str) -> bool:
    with get_conn() as conn:
        cur = conn.execute("DELETE FROM sessions WHERE id=?", (sid,))
    return cur.rowcount > 0


def get_turn_by_request_id(request_id: str) -> Optional[dict]:
    if not request_id:
        return None
    with get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM turns WHERE client_request_id=?", (request_id,)
        ).fetchone()
    return dict(row) if row else None


def add_turn(
    session_id: str,
    transcript_ja: str,
    reply_ja: str,
    correction_ja: Optional[str],
    explanation_vi: Optional[str],
    emotion: str,
    audio_path: Optional[str] = None,
    gesture: str = "none",
    difficulty: str = "N5",
    client_request_id: Optional[str] = None,
) -> str:
    tid = str(uuid.uuid4())
    with get_conn() as conn:
        conn.execute(
            """INSERT INTO turns
               (id, session_id, transcript_ja, reply_ja, correction_ja,
                explanation_vi, emotion, gesture, difficulty, audio_path,
                client_request_id, created_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (tid, session_id, transcript_ja, reply_ja, correction_ja,
             explanation_vi, emotion, gesture, difficulty, audio_path,
             client_request_id, _now()),
        )
    return tid


def add_turn_with_vocabulary(
    *,
    session_id: str,
    transcript_ja: str,
    reply_ja: str,
    correction_ja: Optional[str],
    explanation_vi: Optional[str],
    emotion: str,
    gesture: str,
    difficulty: str,
    vocabulary: list[dict],
    client_request_id: Optional[str] = None,
) -> str:
    """Insert a turn and its vocabulary links in one write transaction."""
    tid = str(uuid.uuid4())
    now = _now()
    with get_conn(immediate=True) as conn:
        conn.execute(
            """INSERT INTO turns
               (id, session_id, transcript_ja, reply_ja, correction_ja,
                explanation_vi, emotion, gesture, difficulty, client_request_id,
                created_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
            (tid, session_id, transcript_ja, reply_ja, correction_ja,
             explanation_vi, emotion, gesture, difficulty, client_request_id, now),
        )
        seen_words = set()
        for item in vocabulary:
            word = str(item.get("word", "")).strip()
            if not word or word in seen_words:
                continue
            seen_words.add(word)

            row = conn.execute(
                "SELECT id FROM vocabulary WHERE word=? ORDER BY id LIMIT 1",
                (word,),
            ).fetchone()
            if row:
                vocab_id = int(row["id"])
                conn.execute(
                    """UPDATE vocabulary
                       SET review_count=review_count + 1,
                           last_seen_at=?,
                           reading=COALESCE(NULLIF(?, ''), reading),
                           meaning_vi=COALESCE(NULLIF(?, ''), meaning_vi)
                       WHERE id=?""",
                    (now, str(item.get("reading", "")), str(item.get("meaning_vi", "")), vocab_id),
                )
            else:
                level_str = (difficulty or "N5").upper().strip()
                cur = conn.execute(
                    """INSERT INTO vocabulary
                       (word, reading, meaning_vi, jlpt_level, first_seen_at, last_seen_at, review_count)
                       VALUES (?,?,?,?,?,?,1)""",
                    (word, item.get("reading") or "", item.get("meaning_vi") or "", level_str, now, now),
                )
                vocab_id = int(cur.lastrowid)
            conn.execute(
                "INSERT OR IGNORE INTO turn_vocabulary (turn_id, vocab_id) VALUES (?,?)",
                (tid, vocab_id),
            )
    return tid


def list_turns(session_id: str, limit: int | None = None, offset: int = 0) -> list[dict]:
    limit = max(1, min(limit or 1000, 2000))
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM turns WHERE session_id=? ORDER BY created_at ASC, id ASC LIMIT ? OFFSET ?",
            (session_id, limit, max(0, offset)),
        ).fetchall()
    return [dict(r) for r in rows]


def get_turn(turn_id: str) -> Optional[dict]:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM turns WHERE id=?", (turn_id,)).fetchone()
    return dict(row) if row else None


def get_turn_vocabulary(turn_id: str) -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute(
            """SELECT v.* FROM vocabulary v
               JOIN turn_vocabulary tv ON tv.vocab_id=v.id
               WHERE tv.turn_id=? ORDER BY v.id""",
            (turn_id,),
        ).fetchall()
    return [dict(row) for row in rows]


def update_turn_audio(turn_id: str, audio_path: str | None) -> None:
    with get_conn() as conn:
        conn.execute("UPDATE turns SET audio_path=? WHERE id=?", (audio_path, turn_id))


def clear_audio_paths(paths: list[str]) -> None:
    if not paths:
        return
    placeholders = ",".join("?" for _ in paths)
    with get_conn() as conn:
        conn.execute(
            f"UPDATE turns SET audio_path=NULL WHERE audio_path IN ({placeholders})",
            paths,
        )


def update_session_summary(session_id: str, summary: str) -> None:
    with get_conn() as conn:
        conn.execute("UPDATE sessions SET summary=? WHERE id=?", (summary, session_id))


def get_recent_turns(session_id: str, limit: int) -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute(
            """SELECT transcript_ja, reply_ja, correction_ja
               FROM turns WHERE session_id=?
               ORDER BY created_at DESC, id DESC LIMIT ?""",
            (session_id, limit),
        ).fetchall()
    return list(reversed([dict(r) for r in rows]))


def list_pending_audio_turns(since: str, limit: int = 100) -> list[dict]:
    """Find recent turns whose audio job was interrupted by a process restart."""
    with get_conn() as conn:
        rows = conn.execute(
            """SELECT id, reply_ja, emotion FROM turns
               WHERE audio_path IS NULL AND created_at >= ?
               ORDER BY created_at ASC, id ASC LIMIT ?""",
            (since, max(1, min(limit, 500))),
        ).fetchall()
    return [dict(row) for row in rows]
