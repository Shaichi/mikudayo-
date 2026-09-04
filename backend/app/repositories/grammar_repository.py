"""Repository cho quản lý và tìm kiếm vector ngữ pháp (feat-rag-grammar)."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from ..core.config import settings
from ..core.logging import get_logger
from ..db.sqlite import get_conn, is_vec_available

logger = get_logger("grammar_repo")

_LEVEL_ORDER = {
    "N5": ("N5",),
    "N4": ("N5", "N4"),
    "N3": ("N5", "N4", "N3"),
}


def add_chunk(
    title: str,
    chunk_text: str,
    jlpt_level: str = "N5",
    source: str = "curated",
    embedding: Optional[list[float]] = None,
) -> int:
    """Thêm một đoạn kiến thức ngữ pháp và vector embedding tương ứng."""
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    level = jlpt_level.upper().strip() if jlpt_level else "N5"

    with get_conn(immediate=True) as conn:
        cur = conn.execute(
            """INSERT INTO grammar_chunks (source, jlpt_level, title, chunk_text, created_at)
               VALUES (?, ?, ?, ?, ?)""",
            (source, level, title, chunk_text, now),
        )
        chunk_id = int(cur.lastrowid)

        if embedding and is_vec_available():
            import math
            if any(math.isnan(x) or math.isinf(x) for x in embedding) or not any(x != 0.0 for x in embedding):
                logger.warning("Bỏ qua lưu vector không hợp lệ (zero hoặc NaN/Inf) cho chunk %d", chunk_id)
            else:
                try:
                    import sqlite_vec

                    vec_bytes = sqlite_vec.serialize_float32(embedding)
                    conn.execute(
                        "INSERT INTO vec_grammar_chunks (chunk_id, embedding) VALUES (?, ?)",
                        (chunk_id, vec_bytes),
                    )
                except Exception as exc:
                    logger.warning("Không thể lưu vector cho chunk %d: %s", chunk_id, exc)

    return chunk_id


def get_chunk(chunk_id: int) -> Optional[dict]:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT id, source, jlpt_level, title, chunk_text, created_at FROM grammar_chunks WHERE id=?",
            (chunk_id,),
        ).fetchone()
    return dict(row) if row else None


def count_chunks() -> int:
    with get_conn() as conn:
        row = conn.execute("SELECT COUNT(*) AS total FROM grammar_chunks").fetchone()
    return int(row["total"]) if row else 0


def search_knn(
    query_vector: list[float],
    limit: int = 3,
    level: str = "N5",
    threshold: float = 0.70,
) -> list[dict]:
    """Tìm kiếm k-nearest neighbors theo cosine distance và lọc theo ngưỡng tương đồng."""
    if not is_vec_available() or not query_vector:
        return []

    import math
    if any(math.isnan(x) or math.isinf(x) for x in query_vector) or not any(x != 0.0 for x in query_vector):
        return []

    try:
        import sqlite_vec
    except ImportError:
        return []

    normalized_level = (level or "N5").upper().strip()
    allowed_levels = _LEVEL_ORDER.get(normalized_level, ("N5", "N4", "N3"))
    limit = max(1, min(limit, 10))

    try:
        query_bytes = sqlite_vec.serialize_float32(query_vector)
    except Exception as exc:
        logger.error("Lỗi serialize query vector: %s", exc)
        return []

    # Quét top-k từ bảng ảo vec0 (quét tối thiểu 50 để tránh hiện tượng starvation)
    fetch_k = min(max(50, limit * 5), 100)

    with get_conn() as conn:
        try:
            rows = conn.execute(
                """
                SELECT v.chunk_id, v.distance, g.title, g.chunk_text, g.jlpt_level, g.source
                FROM vec_grammar_chunks v
                JOIN grammar_chunks g ON g.id = v.chunk_id
                WHERE v.embedding MATCH ? AND k = ?
                ORDER BY v.distance ASC
                """,
                (query_bytes, fetch_k),
            ).fetchall()
        except Exception as exc:
            logger.warning("Lỗi truy vấn vec_grammar_chunks: %s", exc)
            return []

    results = []
    for r in rows:
        if r["distance"] is None:
            continue
        try:
            distance = float(r["distance"])
        except (TypeError, ValueError):
            continue
        # Với cosine distance trong sqlite-vec: distance in [0, 2].
        # similarity = 1 - distance. Khi hoàn toàn giống nhau: distance=0 -> similarity=1.0.
        similarity = max(0.0, 1.0 - distance)
        chunk_level = str(r["jlpt_level"]).upper()

        if similarity >= threshold and chunk_level in allowed_levels:
            results.append({
                "chunk_id": int(r["chunk_id"]),
                "title": str(r["title"]),
                "chunk_text": str(r["chunk_text"]),
                "jlpt_level": chunk_level,
                "source": str(r["source"]),
                "distance": distance,
                "similarity": similarity,
            })
            if len(results) >= limit:
                break

    return results

