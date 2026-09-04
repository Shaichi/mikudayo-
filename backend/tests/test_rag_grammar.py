"""Kiểm thử tính năng RAG Grammar Grounding (feat-rag-grammar)."""
import os
import tempfile
import unittest

# Đảm bảo cấu hình DB tạm trước khi import app modules
_tmp_dir = tempfile.TemporaryDirectory()
os.environ["DATA_DIR"] = _tmp_dir.name
os.environ["ALLOW_MOCK"] = "true"

from app.core.config import settings
from app.db.sqlite import init_db, get_conn, is_vec_available
from app.db.seed_grammar import seed_grammar, SEED_CHUNKS
from app.repositories import grammar_repository as grammar_repo
from app.services.gemini_service import GeminiService
from app.services.rag_grammar_service import RagGrammarService, _mock_embedding


class RagGrammarTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()

    def setUp(self):
        with get_conn() as conn:
            conn.execute("DELETE FROM grammar_chunks")
            try:
                conn.execute("DELETE FROM sqlite_sequence WHERE name='grammar_chunks'")
            except Exception:
                pass
            if is_vec_available():
                try:
                    conn.execute("DELETE FROM vec_grammar_chunks")
                except Exception:
                    pass

    def test_seed_grammar_inserts_chunks_and_vectors(self):
        inserted = seed_grammar(force=True)
        self.assertGreaterEqual(inserted, 5)
        self.assertEqual(grammar_repo.count_chunks(), len(SEED_CHUNKS))

        # Kiểm tra nội dung chunk đầu tiên
        with get_conn() as conn:
            first_row = conn.execute("SELECT id FROM grammar_chunks ORDER BY id ASC LIMIT 1").fetchone()
        self.assertIsNotNone(first_row)
        chunk = grammar_repo.get_chunk(first_row["id"])
        self.assertIsNotNone(chunk)
        self.assertEqual(chunk["jlpt_level"], "N5")
        self.assertIn("Trợ từ chỉ đích đến", chunk["title"])

    def test_knn_search_with_cosine_similarity_and_threshold(self):
        if not is_vec_available():
            self.skipTest("sqlite-vec extension is not available in this test environment.")

        # Tạo 2 vector đơn vị trực giao: vector A = [1, 0, 0, ...], vector B = [0, 1, 0, ...]
        dim = settings.RAG_EMBEDDING_DIM
        vec_a = [0.0] * dim
        vec_a[0] = 1.0

        vec_b = [0.0] * dim
        vec_b[1] = 1.0

        chunk_a_id = grammar_repo.add_chunk(
            title="Quy tắc A (Khớp 100%)",
            chunk_text="Nội dung A",
            jlpt_level="N5",
            embedding=vec_a,
        )
        chunk_b_id = grammar_repo.add_chunk(
            title="Quy tắc B (Trực giao / Khác)",
            chunk_text="Nội dung B",
            jlpt_level="N5",
            embedding=vec_b,
        )

        # Tìm kiếm bằng query vector chính là vec_a
        results = grammar_repo.search_knn(
            query_vector=vec_a,
            limit=5,
            level="N5",
            threshold=0.70,
        )

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["chunk_id"], chunk_a_id)
        self.assertAlmostEqual(results[0]["similarity"], 1.0, places=3)
        self.assertAlmostEqual(results[0]["distance"], 0.0, places=3)

    def test_prompt_injection_in_correction_mode(self):
        gemini = GeminiService()
        sample_chunks = [
            {
                "title": "Trợ từ に/へ với động từ di chuyển",
                "jlpt_level": "N5",
                "chunk_text": "Quy tắc: đi đến đâu dùng に hoặc へ, không dùng を.",
            }
        ]

        # 1. Mode correction: PHẢI có grounding và strict rule
        prompt_correction = gemini.build_prompt(
            mode="correction",
            level="N5",
            summary="",
            recent_turns=[],
            grounding_chunks=sample_chunks,
        )
        self.assertIn("# Grounding Knowledge", prompt_correction)
        self.assertIn("Authoritative grammar references for this turn", prompt_correction)
        self.assertIn("CRITICAL CORRECTION RULE", prompt_correction)
        self.assertIn("Trợ từ に/へ với động từ di chuyển", prompt_correction)
        self.assertIn("You SHALL only correct the user's sentence IF it explicitly violates", prompt_correction)

        # 2. Mode free_talk: KHÔNG chèn grounding
        prompt_freetalk = gemini.build_prompt(
            mode="free_talk",
            level="N5",
            summary="",
            recent_turns=[],
            grounding_chunks=sample_chunks,
        )
        self.assertIn("（なし）", prompt_freetalk)

    def test_rag_grammar_service_zero_crash_on_error(self):
        rag = RagGrammarService()
        # Ép mock error bằng text rỗng hoặc service fallback
        chunks = rag.retrieve_grounding_chunks(user_text="", level="N5")
        self.assertEqual(chunks, [])

    def test_rag_grammar_toggle_disabled(self):
        rag = RagGrammarService()
        original = settings.RAG_GRAMMAR_ENABLED
        try:
            settings.RAG_GRAMMAR_ENABLED = False
            chunks = rag.retrieve_grounding_chunks(user_text="学校を行きます", level="N5")
            self.assertEqual(chunks, [])
        finally:
            settings.RAG_GRAMMAR_ENABLED = original


if __name__ == "__main__":
    unittest.main()
