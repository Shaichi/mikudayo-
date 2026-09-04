"""Repository cho sổ từ vựng và cài đặt."""
from __future__ import annotations

from typing import Optional

from ..db.sqlite import get_conn
from ..schemas.conversation import VocabItem


def upsert_vocab(item: VocabItem) -> int:
    """Thêm từ mới; nếu đã tồn tại thì tăng review_count."""
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with get_conn(immediate=True) as conn:
        row = conn.execute("SELECT id FROM vocabulary WHERE word=?", (item.word,)).fetchone()
        if row:
            conn.execute(
                """UPDATE vocabulary
                   SET review_count = review_count + 1,
                       last_seen_at = ?,
                       reading=COALESCE(NULLIF(?, ''), reading),
                       meaning_vi=COALESCE(NULLIF(?, ''), meaning_vi)
                   WHERE id=?""",
                (now, item.reading, item.meaning_vi, row["id"]),
            )
            return row["id"]
        cur = conn.execute(
            """INSERT INTO vocabulary
               (word, reading, meaning_vi, first_seen_at, last_seen_at, review_count)
               VALUES (?,?,?,?,?,1)""",
            (item.word, item.reading, item.meaning_vi, now, now),
        )
        return int(cur.lastrowid)


def link_turn_vocab(turn_id: str, vocab_id: int) -> None:
    with get_conn() as conn:
        conn.execute(
            "INSERT OR IGNORE INTO turn_vocabulary (turn_id, vocab_id) VALUES (?,?)",
            (turn_id, vocab_id),
        )


def list_vocab(limit: int | None = None, offset: int = 0) -> list[dict]:
    limit = max(1, min(limit or 1000, 2000))
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM vocabulary ORDER BY first_seen_at DESC LIMIT ? OFFSET ?",
            (limit, max(0, offset)),
        ).fetchall()
    return [dict(r) for r in rows]


def get_reinforcement_candidates(
    level: str = "N5",
    limit: int = 5,
    max_review: int = 3,
) -> list[dict]:
    """Lấy danh sách các từ vựng người học cần ôn tập (review_count < max_review).

    Ưu tiên:
    1. review_count tăng dần (từ chưa thuộc hoặc ít gặp nhất)
    2. thời gian gặp gần nhất (lâu chưa gặp)
    3. cấp độ JLPT phù hợp
    """
    levels_map = {
        "N5": ("N5",),
        "N4": ("N5", "N4"),
        "N3": ("N5", "N4", "N3"),
    }
    allowed_levels = levels_map.get((level or "N5").upper().strip(), ("N5",))
    placeholders = ",".join("?" for _ in allowed_levels)
    limit = max(1, min(limit, 20))

    with get_conn() as conn:
        query = f"""
            SELECT id, word, reading, meaning_vi, jlpt_level, review_count, first_seen_at, last_seen_at
            FROM vocabulary
            WHERE review_count < ?
              AND (jlpt_level IN ({placeholders}) OR jlpt_level IS NULL OR jlpt_level = '')
            ORDER BY review_count ASC, COALESCE(last_seen_at, first_seen_at) ASC, id ASC
            LIMIT ?
        """
        params = [max_review, *allowed_levels, limit]
        rows = conn.execute(query, params).fetchall()

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
