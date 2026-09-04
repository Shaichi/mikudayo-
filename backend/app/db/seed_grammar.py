"""Seed data ngữ pháp chuẩn JLPT N5–N3 cho RAG grounding (feat-rag-grammar)."""
from __future__ import annotations

from ..core.logging import get_logger
from ..repositories import grammar_repository as grammar_repo
from ..services.rag_grammar_service import RagGrammarService

logger = get_logger("seed_grammar")

SEED_CHUNKS = [
    {
        "title": "Trợ từ chỉ đích đến của động từ di chuyển (に / へ vs を)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Các động từ chỉ sự di chuyển như 行く (đi), 来る (đến), 帰る (trở về) "
            "sử dụng trợ từ 「に」 hoặc 「へ」 để chỉ điểm đến.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 学校を行きます (Sai: dùng を chỉ đích đến)\n"
            "○ 学校へ行きます / 学校に行きます (Đúng)\n"
            "× 日本を行きたい (Sai: dùng を)\n"
            "○ 日本に行きたい / 日本へ行きたい (Đúng)\n"
            "【Giải thích tiếng Việt】: Điểm đến của động từ di chuyển bắt buộc đi với trợ từ に hoặc へ, tuyệt đối không dùng trợ từ を."
        ),
    },
    {
        "title": "Trợ từ nơi diễn ra hành động (で vs に)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Trợ từ 「で」 dùng để chỉ địa điểm nơi hành động diễn ra. "
            "Trợ từ 「に」 dùng để chỉ địa điểm tồn tại của người/vật (đi với ある, いる) hoặc điểm đến.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× レストランにご飯を食べる (Sai: dùng に nơi hành động)\n"
            "○ レストランでご飯を食べる (Đúng)\n"
            "× 教室に勉強します (Sai: dùng に nơi hành động)\n"
            "○ 教室で勉強します (Đúng)\n"
            "【Giải thích tiếng Việt】: Nơi diễn ra hành động (như ăn cơm, học bài) phải dùng trợ từ 「で」, không dùng 「に」."
        ),
    },
    {
        "title": "Trợ từ đối tượng của sở thích và khả năng (が vs を với 好き/上手)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Các tính từ đuôi na chỉ sở thích, khả năng như 好き (thích), 嫌い (ghét), 上手 (giỏi), 下手 (kém) "
            "đi với trợ từ 「が」 để chỉ đối tượng được nhắm tới, không dùng trợ từ 「を」.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 日本語を好きです (Sai: dùng を với 好き)\n"
            "○ 日本語が好きです (Đúng)\n"
            "× アニメを上手です (Sai: dùng を với 上手)\n"
            "○ アニメの絵を描くのが上手です / 日本語が上手です (Đúng)\n"
            "【Giải thích tiếng Việt】: Đối tượng của 好き (thích) hay 上手 (giỏi) phải dùng trợ từ 「が」, không dùng 「を」."
        ),
    },
    {
        "title": "Mẫu câu xin phép (〜てもいいですか vs 〜てもだめ)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Để xin phép làm một việc gì đó, sử dụng thể て của động từ kết hợp với 「もいいですか」.\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 写真を撮るもいいですか (Sai: chưa chia thể て)\n"
            "○ 写真を撮ってもいいですか (Đúng)\n"
            "× ここに座るがいいですか (Sai: dùng がいいですか)\n"
            "○ ここに座ってもいいですか (Đúng)\n"
            "【Giải thích tiếng Việt】: Khi xin phép lịch sự trong tiếng Nhật, động từ phải chia về thể て + もいいですか."
        ),
    },
    {
        "title": "Mong muốn làm hành động (〜たい) vs Mong muốn có vật (〜がほしい)",
        "jlpt_level": "N5",
        "source": "curated",
        "chunk_text": (
            "【Quy tắc ngữ pháp】: Muốn thực hiện một HÀNH ĐỘNG gì đó: Động từ bỏ ます + たい (như 食べたい, 行きたい). "
            "Muốn CÓ một vật thể gì đó: Danh từ + がほしい (như 車がほしい, 水がほしい).\n"
            "【Lỗi sai thường gặp (Anti-patterns)】:\n"
            "× 車を買うがほしい (Sai: kết hợp động từ với ほしい)\n"
            "○ 車を買いたい / 車がほしい (Đúng)\n"
            "【Giải thích tiếng Việt】: Muốn làm hành động dùng đuôi 「〜たい」, muốn có đồ vật dùng 「〜がほしい」."
        ),
    },
]


def seed_grammar(force: bool = False) -> int:
    """Nạp dữ liệu ngữ pháp mẫu ban đầu vào database nếu chưa có."""
    total = grammar_repo.count_chunks()
    if total > 0 and not force:
        logger.debug("Đã có %d chunks ngữ pháp trong DB, bỏ qua seed.", total)
        return total

    rag_service = RagGrammarService()
    inserted = 0

    for item in SEED_CHUNKS:
        # Sinh vector embedding cho nội dung chunk
        embedding = rag_service.embed_text(item["chunk_text"], task_type="RETRIEVAL_DOCUMENT")
        chunk_id = grammar_repo.add_chunk(
            title=item["title"],
            chunk_text=item["chunk_text"],
            jlpt_level=item["jlpt_level"],
            source=item["source"],
            embedding=embedding,
        )
        inserted += 1
        logger.info("Đã seed grammar chunk %d: %s", chunk_id, item["title"])

    return inserted
