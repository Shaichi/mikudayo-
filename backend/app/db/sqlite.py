"""Kết nối SQLite và schema tối thiểu theo tài liệu.

Tables: sessions, turns, vocabulary, turn_vocabulary, settings.
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
    id             TEXT PRIMARY KEY,
    session_id     TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    transcript_ja  TEXT,
    reply_ja       TEXT NOT NULL,
    correction_ja  TEXT,
    explanation_vi TEXT,
    emotion        TEXT NOT NULL DEFAULT 'neutral',
    audio_path     TEXT,
    created_at     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS vocabulary (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    word          TEXT NOT NULL,
    reading       TEXT,
    meaning_vi    TEXT,
    first_seen_at TEXT NOT NULL,
    review_count  INTEGER NOT NULL DEFAULT 0
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
    conn = sqlite3.connect(settings.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db() -> None:
    conn = _connect()
    try:
        conn.executescript(_SCHEMA)
        conn.commit()
        logger.info("DB ready at %s", settings.DB_PATH)
    finally:
        conn.close()


@contextmanager
def get_conn() -> Iterator[sqlite3.Connection]:
    conn = _connect()
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def close_db() -> None:
    # SQLite không cần đóng global connection; hàm giữ cho API ổn định.
    pass
