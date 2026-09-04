"""Dịch vụ RAG Grammar Grounding (feat-rag-grammar).

Chịu trách nhiệm:
1. Sinh vector embedding cho câu nói người học qua Google gemini-embedding-001.
2. Truy vấn top-k chunk ngữ pháp từ grammar_repository qua sqlite-vec.
3. Áp dụng timeout guard (120ms) và zero-crash fallback để không bao giờ làm lỗi request.
"""
from __future__ import annotations

import math
import time
from typing import Optional

from ..core.config import settings
from ..core.logging import get_logger
from ..db.sqlite import is_vec_available
from ..repositories import grammar_repository as grammar_repo

logger = get_logger("rag_grammar")


def _mock_embedding(text: str, dim: int = 768) -> list[float]:
    """Sinh vector giả lập có tính tất định dựa trên hash của text (cho mock/test)."""
    import hashlib

    seed_bytes = hashlib.sha256(text.encode("utf-8")).digest()
    vals = []
    for i in range(dim):
        b = seed_bytes[i % len(seed_bytes)]
        val = (b / 255.0) - 0.5
        vals.append(val)
    # Chuẩn hóa về vector đơn vị (unit vector) cho cosine distance
    norm = math.sqrt(sum(x * x for x in vals)) or 1.0
    return [x / norm for x in vals]


class RagGrammarService:
    def __init__(self) -> None:
        self._client: Optional[object] = None
        self._mock = settings.ALLOW_MOCK and not bool(settings.GEMINI_API_KEY)

        if not self._mock and settings.GEMINI_API_KEY:
            try:
                from google import genai
                from google.genai import types

                self._client = genai.Client(api_key=settings.GEMINI_API_KEY)
                self._types = types
                logger.info("RagGrammarService ready (model=%s)", settings.RAG_EMBEDDING_MODEL)
            except Exception as exc:
                if settings.ALLOW_MOCK:
                    logger.warning("Không khởi tạo được GenAI Client cho embedding — dùng mock: %s", exc)
                    self._mock = True
                else:
                    logger.error("Lỗi khởi tạo GenAI Client: %s", exc)

    @property
    def is_available(self) -> bool:
        return settings.RAG_GRAMMAR_ENABLED and is_vec_available()

    def embed_text(self, text: str, task_type: str = "RETRIEVAL_QUERY") -> Optional[list[float]]:
        """Gọi API Google gemini-embedding-001 để lấy vector 768 chiều."""
        cleaned = text.strip()
        if not cleaned:
            return None

        if self._mock or self._client is None:
            return _mock_embedding(cleaned, settings.RAG_EMBEDDING_DIM)

        try:
            config = self._types.EmbedContentConfig(
                task_type=task_type,
                output_dimensionality=settings.RAG_EMBEDDING_DIM,
            )
            response = self._client.models.embed_content(
                model=settings.RAG_EMBEDDING_MODEL,
                contents=cleaned,
                config=config,
            )
            if response and response.embeddings:
                return list(response.embeddings[0].values)
            return None
        except Exception as exc:
            logger.warning("Lỗi khi gọi embedding API: %s", exc)
            return None

    def retrieve_grounding_chunks(self, user_text: str, level: str = "N5") -> list[dict]:
        """Truy xuất các chunk ngữ pháp liên quan kèm bảo vệ timeout."""
        if not self.is_available:
            return []

        start = time.perf_counter()
        try:
            vector = self.embed_text(user_text, task_type="RETRIEVAL_QUERY")
            if not vector:
                return []

            # Kiểm tra xem có bị quá timeout budget không
            elapsed = time.perf_counter() - start
            if elapsed > settings.RAG_TIMEOUT_SECONDS:
                logger.warning("RAG embedding vượt timeout (%.3fs > %.3fs), fallback.", elapsed, settings.RAG_TIMEOUT_SECONDS)
                return []

            chunks = grammar_repo.search_knn(
                query_vector=vector,
                limit=settings.RAG_TOP_K,
                level=level,
                threshold=settings.RAG_SIMILARITY_THRESHOLD,
            )
            logger.debug("RAG tìm thấy %d chunks ngữ pháp trong %.3fs.", len(chunks), time.perf_counter() - start)
            return chunks
        except Exception as exc:
            logger.exception("Lỗi không mong muốn trong RAG retrieval: %s", exc)
            return []
