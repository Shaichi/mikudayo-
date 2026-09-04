"""Kiểm thử chuyên sâu các trường hợp biên, dữ liệu dị thường, concurrency và độ bền hệ thống."""
import asyncio
import os
import tempfile
import unittest
from datetime import datetime, timezone, timedelta
from unittest.mock import patch

# Cấu hình môi trường kiểm thử
_tmp_dir = tempfile.TemporaryDirectory()
os.environ["DATA_DIR"] = _tmp_dir.name
os.environ["ALLOW_MOCK"] = "true"

from app.core.config import settings
from app.db.sqlite import init_db, get_conn, is_vec_available
from app.repositories import grammar_repository as grammar_repo
from app.repositories import vocab_repository as vocab_repo
from app.repositories import conversation_repository as conv_repo
from app.services.rag_grammar_service import RagGrammarService
from app.services.lipsync_service import compute_mouth_cues
from app.services.fish_audio_service import FishAudioService
from app.api.conversation import get_audio_status
from app.api.health import health


class BoundaryAndEdgeCasesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()

    def setUp(self):
        with get_conn() as conn:
            conn.execute("DELETE FROM turn_vocabulary")
            conn.execute("DELETE FROM turns")
            conn.execute("DELETE FROM sessions")
            conn.execute("DELETE FROM vocabulary")
            conn.execute("DELETE FROM grammar_chunks")
            try:
                conn.execute("DELETE FROM sqlite_sequence WHERE name IN ('vocabulary', 'grammar_chunks')")
            except Exception:
                pass
            if is_vec_available():
                try:
                    conn.execute("DELETE FROM vec_grammar_chunks")
                except Exception:
                    pass

    def test_search_knn_zero_nan_and_inf_vectors_do_not_crash(self):
        """Query vector với giá trị 0, NaN hoặc Inf không bao giờ làm crash search_knn."""
        if not is_vec_available():
            self.skipTest("sqlite-vec extension is not available in this test environment.")

        # Thêm 1 chunk bình thường
        dim = settings.RAG_EMBEDDING_DIM
        normal_vec = [0.0] * dim
        normal_vec[0] = 1.0
        grammar_repo.add_chunk(title="Normal", chunk_text="Content", jlpt_level="N5", embedding=normal_vec)

        # 1. Query toàn zero
        res_zero = grammar_repo.search_knn([0.0] * dim, limit=3, level="N5")
        self.assertEqual(res_zero, [])

        # 2. Query có NaN
        nan_vec = [0.0] * dim
        nan_vec[0] = float("nan")
        res_nan = grammar_repo.search_knn(nan_vec, limit=3, level="N5")
        self.assertEqual(res_nan, [])

        # 3. Query có Inf
        inf_vec = [0.0] * dim
        inf_vec[0] = float("inf")
        res_inf = grammar_repo.search_knn(inf_vec, limit=3, level="N5")
        self.assertEqual(res_inf, [])

    def test_add_chunk_zero_vector_does_not_poison_index(self):
        """Thêm chunk với vector 0 hoặc NaN không được làm hỏng bảng vector."""
        if not is_vec_available():
            self.skipTest("sqlite-vec extension is not available in this test environment.")

        dim = settings.RAG_EMBEDDING_DIM
        # Thử thêm chunk với all-zero vector
        cid = grammar_repo.add_chunk(title="Zero Chunk", chunk_text="Zero", jlpt_level="N5", embedding=[0.0] * dim)
        self.assertGreater(cid, 0)

        # Thêm chunk chuẩn
        good_vec = [0.0] * dim
        good_vec[0] = 1.0
        grammar_repo.add_chunk(title="Good Chunk", chunk_text="Good", jlpt_level="N5", embedding=good_vec)

        # Query bình thường không bị crash bởi chunk lỗi
        query_vec = [0.0] * dim
        query_vec[0] = 1.0
        res = grammar_repo.search_knn(query_vec, limit=3, level="N5")
        self.assertIsInstance(res, list)
        self.assertGreaterEqual(len(res), 1)
        self.assertEqual(res[0]["title"], "Good Chunk")

    def test_grammar_and_vocab_level_none_and_whitespace_resilience(self):
        """level=None hoặc chứa khoảng trắng không gây lỗi AttributeError."""
        # Grammar repository
        res_grammar = grammar_repo.search_knn([0.1] * settings.RAG_EMBEDDING_DIM, limit=3, level=None)
        self.assertIsInstance(res_grammar, list)

        # Vocab repository
        res_vocab_none = vocab_repo.get_reinforcement_candidates(level=None, limit=5)
        self.assertIsInstance(res_vocab_none, list)

        res_vocab_ws = vocab_repo.get_reinforcement_candidates(level="  n4  ", limit=5)
        self.assertIsInstance(res_vocab_ws, list)

    def test_last_seen_at_is_updated_on_review(self):
        """Khi từ vựng được học lại, last_seen_at phải được cập nhật mốc thời gian mới."""
        sid = conv_repo.new_session("free_talk", "N5")
        word = "猫"

        # Lần 1: thêm mới
        conv_repo.add_turn_with_vocabulary(
            session_id=sid, transcript_ja="ねこ", reply_ja="かわいいね",
            correction_ja=None, explanation_vi=None, emotion="happy",
            gesture="nod", difficulty="N5",
            vocabulary=[{"word": word, "reading": "ねこ", "meaning_vi": "con mèo"}]
        )

        with get_conn() as conn:
            row1 = conn.execute("SELECT first_seen_at, last_seen_at, review_count FROM vocabulary WHERE word=?", (word,)).fetchone()
            self.assertIsNotNone(row1)
            self.assertEqual(row1["review_count"], 1)
            self.assertIsNotNone(row1["last_seen_at"])

        # Lần 2: gặp lại
        conv_repo.add_turn_with_vocabulary(
            session_id=sid, transcript_ja="猫が好き", reply_ja="私も！",
            correction_ja=None, explanation_vi=None, emotion="happy",
            gesture="nod", difficulty="N5",
            vocabulary=[{"word": word, "reading": "ねこ", "meaning_vi": "con mèo"}]
        )

        with get_conn() as conn:
            row2 = conn.execute("SELECT first_seen_at, last_seen_at, review_count FROM vocabulary WHERE word=?", (word,)).fetchone()
            self.assertEqual(row2["review_count"], 2)
            self.assertIsNotNone(row2["last_seen_at"])

    def test_session_difficulty_assigned_to_new_vocabulary(self):
        """Từ vựng mới phải nhận cấp độ JLPT từ session difficulty thay vì mặc định N5."""
        sid = conv_repo.new_session("free_talk", "N3")
        word = "経済"
        conv_repo.add_turn_with_vocabulary(
            session_id=sid, transcript_ja="経済", reply_ja="難しいですね",
            correction_ja=None, explanation_vi=None, emotion="thinking",
            gesture="tilt", difficulty="N3",
            vocabulary=[{"word": word, "reading": "けいざい", "meaning_vi": "kinh tế"}]
        )

        with get_conn() as conn:
            row = conn.execute("SELECT jlpt_level FROM vocabulary WHERE word=?", (word,)).fetchone()
            self.assertIsNotNone(row)
            self.assertEqual(row["jlpt_level"], "N3")

    def test_intra_turn_duplicate_vocabulary_does_not_inflate_review_count(self):
        """Từ vựng bị lặp lại nhiều lần trong cùng 1 turn chỉ tăng review_count đúng 1 lần."""
        sid = conv_repo.new_session("free_talk", "N5")
        word = "桜"
        conv_repo.add_turn_with_vocabulary(
            session_id=sid, transcript_ja="さくら", reply_ja="綺麗",
            correction_ja=None, explanation_vi=None, emotion="happy",
            gesture="wave", difficulty="N5",
            vocabulary=[
                {"word": word, "reading": "さくら", "meaning_vi": "hoa anh đào"},
                {"word": word, "reading": "さくら", "meaning_vi": "hoa anh đào"},
            ]
        )

        with get_conn() as conn:
            row = conn.execute("SELECT review_count FROM vocabulary WHERE word=?", (word,)).fetchone()
            self.assertIsNotNone(row)
            self.assertEqual(row["review_count"], 1)

    def test_lipsync_handles_negative_and_zero_window_ms(self):
        """window_ms âm hoặc 0 được chuẩn hóa an toàn, không raise Pydantic ValidationError."""
        wav = FishAudioService.mock_wav()
        cues_neg = compute_mouth_cues(wav.data, window_ms=-50)
        self.assertIsInstance(cues_neg, list)
        for cue in cues_neg:
            self.assertGreaterEqual(cue.t_ms, 0)
            self.assertGreaterEqual(cue.mouth, 0.0)

        cues_zero = compute_mouth_cues(wav.data, window_ms=0)
        self.assertIsInstance(cues_zero, list)

    def test_stale_turn_audio_status_returns_expired_error(self):
        """Turn quá cũ không còn file audio phải trả về status='error' thay vì pending vô tận."""
        sid = conv_repo.new_session("free_talk", "N5")
        tid = conv_repo.add_turn_with_vocabulary(
            session_id=sid, transcript_ja="古い", reply_ja="返事",
            correction_ja=None, explanation_vi=None, emotion="neutral",
            gesture="none", difficulty="N5", vocabulary=[]
        )
        old_time = (datetime.now(timezone.utc) - timedelta(seconds=settings.AUDIO_STALE_SECONDS + 60)).isoformat()
        with get_conn(immediate=True) as conn:
            conn.execute("UPDATE turns SET created_at=? WHERE id=?", (old_time, tid))

        status = asyncio.run(get_audio_status(tid))
        self.assertEqual(status.status, "error")
        self.assertEqual(status.error, "audio_expired")

    def test_health_endpoint_handles_missing_keys_gracefully(self):
        """Khi ALLOW_MOCK=false và thiếu API key, /health không throw 500 mà trả degraded."""
        with patch.object(settings, "ALLOW_MOCK", False), patch.object(settings, "GEMINI_API_KEY", ""):
            h = health()
            self.assertEqual(h.status, "degraded")
            self.assertFalse(h.gemini)
