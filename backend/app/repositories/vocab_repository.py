"""Repository cho sổ từ vựng và cài đặt."""
from __future__ import annotations

from typing import Optional

from ..db.sqlite import get_conn
from ..schemas.conversation import VocabItem


def upsert_vocab(item: VocabItem) -> int:
    """Thêm từ mới; nếu đã tồn tại thì tăng review_count."""
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with get_conn() as conn:
        row = conn.execute("SELECT id FROM vocabulary WHERE word=?", (item.word,)).fetchone()
        if row:
            conn.execute(
                "UPDATE vocabulary SET review_count = review_count + 1, reading=?, meaning_vi=? WHERE id=?",
                (item.reading, item.meaning_vi, row["id"]),
            )
            return row["id"]
        cur = conn.execute(
            "INSERT INTO vocabulary (word, reading, meaning_vi, first_seen_at) VALUES (?,?,?,?)",
            (item.word, item.reading, item.meaning_vi, now),
        )
        return int(cur.lastrowid)


def link_turn_vocab(turn_id: str, vocab_id: int) -> None:
    with get_conn() as conn:
        conn.execute(
            "INSERT OR IGNORE INTO turn_vocabulary (turn_id, vocab_id) VALUES (?,?)",
            (turn_id, vocab_id),
        )


def list_vocab() -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM vocabulary ORDER BY first_seen_at DESC"
        ).fetchall()
    return [dict(r) for r in rows]


def get_setting(key: str, default: Optional[str] = None) -> Optional[str]:
    with get_conn() as conn:
        row = conn.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
    return row["value"] if row else default


def set_setting(key: str, value: str) -> None:
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO settings (key, value) VALUES (?,?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (key, value),
        )
