"""Kiểm thử tính năng cá nhân hóa từ vựng (feat-rag-vocab)."""
import os
import tempfile
import unittest
from pathlib import Path

# Đảm bảo cấu hình DB tạm trước khi import app modules
_tmp_dir = tempfile.TemporaryDirectory()
os.environ["DATA_DIR"] = _tmp_dir.name
os.environ["ALLOW_MOCK"] = "true"

from app.db.sqlite import init_db, get_conn
from app.repositories import vocab_repository as vocab_repo
from app.repositories import conversation_repository as conv_repo
from app.services.gemini_service import GeminiService
from app.schemas.conversation import VocabItem, Mode, JpLevel


class VocabReinforcementTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()

    def setUp(self):
        with get_conn() as conn:
            conn.execute("DELETE FROM turn_vocabulary")
            conn.execute("DELETE FROM turns")
            conn.execute("DELETE FROM sessions")
            conn.execute("DELETE FROM vocabulary")

    def test_get_reinforcement_candidates_filters_by_review_count_and_level(self):
        with get_conn(immediate=True) as conn:
            # Word 1: N5, review_count = 1 (cần ôn tập)
            conn.execute(
                "INSERT INTO vocabulary (word, reading, meaning_vi, jlpt_level, first_seen_at, review_count) "
                "VALUES ('りんご', 'ringo', 'quả táo', 'N5', '2026-09-01T00:00:00', 1)"
            )
            # Word 2: N5, review_count = 2 (cần ôn tập)
            conn.execute(
                "INSERT INTO vocabulary (word, reading, meaning_vi, jlpt_level, first_seen_at, review_count) "
                "VALUES ('みかん', 'mikan', 'quả quýt', 'N5', '2026-09-02T00:00:00', 2)"
            )
            # Word 3: N5, review_count = 3 (đã thuộc, không gợi ý)
            conn.execute(
                "INSERT INTO vocabulary (word, reading, meaning_vi, jlpt_level, first_seen_at, review_count) "
                "VALUES ('本', 'hon', 'sách', 'N5', '2026-09-03T00:00:00', 3)"
            )
            # Word 4: N3, review_count = 1 (quá cấp độ N5)
            conn.execute(
                "INSERT INTO vocabulary (word, reading, meaning_vi, jlpt_level, first_seen_at, review_count) "
                "VALUES ('経済', 'keizai', 'kinh tế', 'N3', '2026-09-04T00:00:00', 1)"
            )

        # Lấy candidate cho cấp độ N5
        candidates_n5 = vocab_repo.get_reinforcement_candidates(level="N5", limit=5, max_review=3)
        words_n5 = [c["word"] for c in candidates_n5]
        self.assertIn("りんご", words_n5)
        self.assertIn("みかん", words_n5)
        self.assertNotIn("本", words_n5)       # review_count >= 3
        self.assertNotIn("経済", words_n5)    # level N3 > N5

        # Từ có review_count = 1 phải đứng trước từ có review_count = 2
        self.assertEqual(words_n5[0], "りんご")
        self.assertEqual(words_n5[1], "みかん")

        # Lấy candidate cho cấp độ N3 (được phép lấy cả N5 và N3)
        candidates_n3 = vocab_repo.get_reinforcement_candidates(level="N3", limit=5, max_review=3)
        words_n3 = [c["word"] for c in candidates_n3]
        self.assertIn("経済", words_n3)
        self.assertIn("りんご", words_n3)

    def test_build_prompt_injects_candidate_vocab(self):
        gemini = GeminiService()
        candidates = [
            {"word": "りんご", "reading": "ringo", "meaning_vi": "quả táo"},
            {"word": "猫", "reading": "neko", "meaning_vi": "con mèo"},
        ]
        prompt = gemini.build_prompt(
            mode="free_talk",
            level="N5",
            summary="",
            recent_turns=[],
            candidate_vocab=candidates,
        )
        self.assertIn("# Vocabulary reinforcement targets", prompt)
        self.assertIn("りんご (ringo): quả táo", prompt)
        self.assertIn("猫 (neko): con mèo", prompt)
        self.assertIn("The learner is currently practicing these words", prompt)

    def test_build_prompt_without_candidates_uses_placeholder(self):
        gemini = GeminiService()
        prompt = gemini.build_prompt(
            mode="free_talk",
            level="N5",
            summary="",
            recent_turns=[],
            candidate_vocab=[],
        )
        self.assertIn("# Vocabulary reinforcement targets", prompt)
        self.assertIn("（なし）", prompt)

    def test_add_turn_increments_review_count(self):
        # Tạo sẵn từ với review_count = 1
        vocab_id = vocab_repo.upsert_vocab(VocabItem(word="水", reading="mizu", meaning_vi="nước"))
        with get_conn() as conn:
            row = conn.execute("SELECT review_count FROM vocabulary WHERE id=?", (vocab_id,)).fetchone()
            self.assertEqual(row["review_count"], 1)

        # Thêm turn mới có từ "水"
        sid = conv_repo.new_session("free_talk", "N5")
        conv_repo.add_turn_with_vocabulary(
            session_id=sid,
            transcript_ja="水をください",
            reply_ja="はい、どうぞ！",
            correction_ja=None,
            explanation_vi=None,
            emotion="happy",
            gesture="nod",
            difficulty="N5",
            vocabulary=[{"word": "水", "reading": "みず", "meaning_vi": "nước"}],
        )

        with get_conn() as conn:
            row = conn.execute("SELECT review_count FROM vocabulary WHERE id=?", (vocab_id,)).fetchone()
            # review_count phải tăng lên 2
            self.assertEqual(row["review_count"], 2)


if __name__ == "__main__":
    unittest.main()
