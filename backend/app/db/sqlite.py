"""SQLite connection, schema and small additive migrations.

The application keeps one short-lived connection per operation.  WAL mode,
busy_timeout and explicit rollback make this safe enough for the current
single-service deployment while keeping the repository easy to test.
"""
from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from typing import Iterator

from ..core.config import settings
from ..core.logging import get_logger

logger = get_logger("db")

_SCHEMA = """
CREATE TABLE IF NOT EXISTS sessions (
    id          TEXT PRIMARY KEY,
    mode        TEXT NOT NULL DEFAULT 'free_talk',
    jlpt_level  TEXT NOT NULL DEFAULT 'N5',
    scenario    TEXT,
    summary     TEXT,
    created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS turns (
    id                TEXT PRIMARY KEY,
    session_id        TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    transcript_ja     TEXT,
    reply_ja          TEXT NOT NULL,
    correction_ja     TEXT,
    explanation_vi    TEXT,
    emotion           TEXT NOT NULL DEFAULT 'neutral',
    gesture           TEXT NOT NULL DEFAULT 'none',
    difficulty        TEXT NOT NULL DEFAULT 'N5',
    audio_path        TEXT,
    client_request_id TEXT UNIQUE,
    created_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS vocabulary (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    word          TEXT NOT NULL,
    reading       TEXT,
    meaning_vi    TEXT,
    first_seen_at TEXT NOT NULL,
    review_count  INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS turn_vocabulary (
    turn_id  TEXT NOT NULL REFERENCES turns(id) ON DELETE CASCADE,
    vocab_id INTEGER NOT NULL REFERENCES vocabulary(id) ON DELETE CASCADE,
    PRIMARY KEY (turn_id, vocab_id)
);

CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
"""


def _connect() -> sqlite3.Connection:
    settings.DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(
        settings.DB_PATH,
        timeout=settings.DB_TIMEOUT_SECONDS,
        check_same_thread=False,
    )
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA synchronous = NORMAL")
    conn.execute(
        f"PRAGMA busy_timeout = {max(1000, int(settings.DB_TIMEOUT_SECONDS * 1000))}"
    )
    return conn


def _columns(conn: sqlite3.Connection, table: str) -> set[str]:
    return {row[1] for row in conn.execute(f"PRAGMA table_info({table})")}


def _migrate(conn: sqlite3.Connection) -> None:
    """Apply only additive, restart-safe migrations to existing databases."""
    columns = _columns(conn, "turns")
    additions = {
        "gesture": "TEXT NOT NULL DEFAULT 'none'",
        "difficulty": "TEXT NOT NULL DEFAULT 'N5'",
        "client_request_id": "TEXT",
    }
    for name, declaration in additions.items():
        if name not in columns:
            conn.execute(f"ALTER TABLE turns ADD COLUMN {name} {declaration}")

    # Old databases used 0 for a first vocabulary encounter.  Preserve all
    # rows while correcting only that impossible initial value.
    conn.execute("UPDATE vocabulary SET review_count = 1 WHERE review_count < 1")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_turns_session_created ON turns(session_id, created_at)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_sessions_created ON sessions(created_at)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_vocabulary_word ON vocabulary(word)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_turns_request_id ON turns(client_request_id)")
    try:
        conn.execute(
            """CREATE UNIQUE INDEX IF NOT EXISTS idx_turns_request_unique
               ON turns(client_request_id) WHERE client_request_id IS NOT NULL"""
        )
    except sqlite3.IntegrityError:
        # A legacy DB may contain duplicate keys from before idempotency was
        # introduced.  Keep it usable; new writes are still serialized.
        logger.warning("Bỏ qua unique index request_id vì DB cũ có dữ liệu trùng.")


def init_db() -> None:
    conn = _connect()
    try:
        conn.executescript(_SCHEMA)
        _migrate(conn)
        conn.commit()
        logger.info("DB ready at %s", settings.DB_PATH)
    finally:
        conn.close()


@contextmanager
def get_conn(*, immediate: bool = False) -> Iterator[sqlite3.Connection]:
    conn = _connect()
    try:
        if immediate:
            conn.execute("BEGIN IMMEDIATE")
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def close_db() -> None:
    # Connections are intentionally scoped to repository operations.
    pass
