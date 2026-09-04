"""Seed data từ vựng cốt lõi JLPT N5–N3 cho tính năng ôn tập cá nhân hóa (feat-rag-vocab)."""
from __future__ import annotations

from datetime import datetime, timezone

from ..core.logging import get_logger
from ..db.sqlite import get_conn

logger = get_logger("seed_vocab")

SEED_VOCAB = [
    # === JLPT N5 ===
    {"word": "食べる", "reading": "たべる", "meaning_vi": "ăn", "jlpt_level": "N5"},
    {"word": "飲む", "reading": "のむ", "meaning_vi": "uống", "jlpt_level": "N5"},
    {"word": "行く", "reading": "いく", "meaning_vi": "đi", "jlpt_level": "N5"},
    {"word": "来る", "reading": "くる", "meaning_vi": "đến", "jlpt_level": "N5"},
    {"word": "友達", "reading": "ともだち", "meaning_vi": "bạn bè", "jlpt_level": "N5"},
    {"word": "勉強", "reading": "べんきょう", "meaning_vi": "học tập", "jlpt_level": "N5"},
    {"word": "家族", "reading": "かぞく", "meaning_vi": "gia đình", "jlpt_level": "N5"},
    {"word": "時間", "reading": "じかん", "meaning_vi": "thời gian", "jlpt_level": "N5"},
    {"word": "楽しい", "reading": "たのしい", "meaning_vi": "vui vẻ", "jlpt_level": "N5"},
    {"word": "天気", "reading": "てんき", "meaning_vi": "thời tiết", "jlpt_level": "N5"},

    # === JLPT N4 ===
    {"word": "準備", "reading": "じゅんび", "meaning_vi": "chuẩn bị", "jlpt_level": "N4"},
    {"word": "相談", "reading": "そうだん", "meaning_vi": "thảo luận, trao đổi", "jlpt_level": "N4"},
    {"word": "経験", "reading": "けいけん", "meaning_vi": "kinh nghiệm", "jlpt_level": "N4"},
    {"word": "約束", "reading": "やくそく", "meaning_vi": "lời hứa, hẹn ước", "jlpt_level": "N4"},
    {"word": "複雑", "reading": "ふくざつ", "meaning_vi": "phức tạp", "jlpt_level": "N4"},
    {"word": "案内", "reading": "あんない", "meaning_vi": "hướng dẫn, dẫn đường", "jlpt_level": "N4"},
    {"word": "遠慮", "reading": "えんりょ", "meaning_vi": "khách sáo, ngại ngùng", "jlpt_level": "N4"},
    {"word": "故障", "reading": "こしょう", "meaning_vi": "hỏng hóc, sự cố", "jlpt_level": "N4"},
    {"word": "危険", "reading": "きけん", "meaning_vi": "nguy hiểm", "jlpt_level": "N4"},
    {"word": "連絡", "reading": "れんらく", "meaning_vi": "liên lạc, thông báo", "jlpt_level": "N4"},

    # === JLPT N3 ===
    {"word": "影響", "reading": "えいきょう", "meaning_vi": "ảnh hưởng", "jlpt_level": "N3"},
    {"word": "緊張", "reading": "きんちょう", "meaning_vi": "căng thẳng, hồi hộp", "jlpt_level": "N3"},
    {"word": "満足", "reading": "まんぞく", "meaning_vi": "hài lòng, thỏa mãn", "jlpt_level": "N3"},
    {"word": "解決", "reading": "かいけつ", "meaning_vi": "giải quyết", "jlpt_level": "N3"},
    {"word": "努力", "reading": "どりょく", "meaning_vi": "nỗ lực, cố gắng", "jlpt_level": "N3"},
    {"word": "変化", "reading": "へんか", "meaning_vi": "sự biến đổi, thay đổi", "jlpt_level": "N3"},
    {"word": "目的", "reading": "もくてき", "meaning_vi": "mục đích", "jlpt_level": "N3"},
    {"word": "状況", "reading": "じょうきょう", "meaning_vi": "tình huống, bối cảnh", "jlpt_level": "N3"},
    {"word": "成功", "reading": "せいこう", "meaning_vi": "thành công", "jlpt_level": "N3"},
    {"word": "感謝", "reading": "かんしゃ", "meaning_vi": "cảm kích, biết ơn", "jlpt_level": "N3"},
]


def seed_vocab(force: bool = False) -> int:
    """Nạp danh sách từ vựng nền tảng JLPT N5-N3 ban đầu nếu chưa có."""
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")

    with get_conn(immediate=True) as conn:
        existing_words = {
            row["word"] for row in conn.execute("SELECT word FROM vocabulary").fetchall()
        }

        inserted = 0
        for item in SEED_VOCAB:
            if item["word"] in existing_words and not force:
                continue

            conn.execute(
                """INSERT INTO vocabulary
                   (word, reading, meaning_vi, jlpt_level, first_seen_at, last_seen_at, review_count)
                   VALUES (?, ?, ?, ?, ?, ?, 0)""",
                (item["word"], item["reading"], item["meaning_vi"], item["jlpt_level"], now, now),
            )
            inserted += 1

    if inserted > 0:
        logger.info("Đã seed %d từ vựng chuẩn JLPT N5-N3 vào DB", inserted)
    return inserted
