# PLAN — `feat-rag-grammar`

ID: `PLAN-feat-rag-grammar`  
Version: `1.0.0`  
Feature slug: `feat-rag-grammar`  
Status: `APPROVED`  
Owner: `AI Agent & Human Director`  
Approvers: `Human Director`  
Created/updated: `2026-09-04T20:37:00+07:00`  
Spec reference: `.sdd/features/feat-rag-grammar/SPEC.md` (v0.1.0)  

---

## 1. Architectural Approach

Áp dụng Clean Architecture cho luồng RAG sửa ngữ pháp:
1. **Infrastructure Layer (`db/sqlite.py`):**
   - Nạp dynamic extension `sqlite-vec` vào kết nối `_connect()`. Nếu không có hoặc lỗi, graceful degradation (log WARNING, đặt cờ `vec_available = False`).
   - Tạo bảng `grammar_chunks` (metadata) và bảng ảo `vec_grammar_chunks` (`vec0(embedding float[768] distance_metric=cosine)`).
2. **Repository Layer (`repositories/grammar_repository.py`):**
   - Lưu trữ chunk ngữ pháp và vector embedding.
   - Tìm kiếm KNN theo cosine distance kết hợp lọc theo `jlpt_level`.
3. **Service Layer (`services/rag_grammar_service.py` & `gemini_service.py`):**
   - `RagGrammarService`: gọi `client.models.embed_content(model="gemini-embedding-001", contents=query, config=EmbedContentConfig(output_dimensionality=768, task_type="RETRIEVAL_QUERY"))`.
   - Có timeout guard 100ms: nếu chậm hoặc lỗi, trả về danh sách rỗng để không block user turn.
   - Khi ở `mode="correction"`, nếu có chunk với similarity $\ge 0.70$, inject vào System Instruction kèm Strict Grounding Rule.
4. **Interface / API Layer (`api/conversation.py`):**
   - Trong `_handle_turn`, khi `mode == "correction"` và `RAG_GRAMMAR_ENABLED=True`, gọi `rag_grammar_service.retrieve_chunks()`.
   - Chuyển `grounding_chunks` vào `gemini_service.generate_turn()`.
5. **Ingestion & Seeding (`scripts/ingest_grammar.py`):**
   - Bộ dữ liệu mẫu ban đầu (Seed corpus) cho các điểm ngữ pháp N5-N3 hay nhầm lẫn nhất (Trợ từ に/へ/で/を, てもいい vs てはいけない, から vs ので).

---

## 2. Components & Layer Mapping

| Component | Layer | Path | Trách nhiệm |
|---|---|---|---|
| `_connect` & `_migrate` | Infra | `backend/app/db/sqlite.py` | Load `sqlite-vec` extension; tạo bảng `grammar_chunks` và `vec_grammar_chunks`. |
| `GrammarRepository` | Repository | `backend/app/repositories/grammar_repository.py` | CRUD chunks và thực hiện KNN vector search với cosine distance. |
| `RagGrammarService` | Service | `backend/app/services/rag_grammar_service.py` | Embed user utterance và truy vấn top-k chunks đạt ngưỡng 0.70. |
| `GeminiService` | Service | `backend/app/services/gemini_service.py` | Inject `[GROUNDING KNOWLEDGE]` và áp dụng Strict Grounding Rule. |
| `_handle_turn` | Interface | `backend/app/api/conversation.py` | Kích hoạt retrieval khi `mode == "correction"`. |
| `Settings` | Core | `backend/app/core/config.py` | Cấu hình `RAG_GRAMMAR_ENABLED`, `RAG_SIMILARITY_THRESHOLD`, `RAG_TIMEOUT_SECONDS`. |

---

## 3. Data Flow

```text
POST /v1/conversation/turn (mode="correction", text="学校を行きます")
  │
  ├── 1. RagGrammarService.retrieve_grounding(user_text, level="N5")
  │       ├── Call Gemini Embedding: gemini-embedding-001 (task_type=RETRIEVAL_QUERY, dim=768)
  │       ├── Query sqlite-vec:
  │       │     SELECT g.id, g.title, g.chunk_text, distance
  │       │     FROM vec_grammar_chunks v
  │       │     JOIN grammar_chunks g ON g.id = v.chunk_id
  │       │     WHERE v.embedding MATCH ? AND k = 3
  │       └── Filter: (1 - distance) >= 0.70 AND g.jlpt_level <= 'N5'
  │
  ├── 2. GeminiService.generate_turn(..., grounding_chunks=chunks)
  │       └── Prompt:
  │             # Grounding Knowledge (Strict Rule)
  │             Chunk: "Động từ di chuyển dùng に/へ, không dùng を..."
  │             Rule: Only correct if the mistake matches a provided chunk. Otherwise correction_ja: null.
  │       └── Output JSON:
  │             { "reply_ja": "...", "correction_ja": "学校へ行きます", "explanation_vi": "..." }
  │
  └── 3. API Response trả về Flutter với câu sửa chuẩn xác, không đoán mò
```

---

## 4. Verification Commands

1. **Unit Test Vector Engine & Fallbacks:**
   ```powershell
   python -m unittest backend/tests/test_rag_grammar.py -v
   ```
2. **Full Test Suite:**
   ```powershell
   cd backend; python -m unittest discover -s tests -v
   ```

---

## AI Agent Recommendation & Human Final Review

- **Status:** APPROVED
- **Decision:** Duyệt kiến trúc và luồng dữ liệu cho feat-rag-grammar.
- **Reviewer:** Human Director
- **Reviewed at:** 2026-09-04T20:37:00+07:00
- **Follow-up:** /add-execute --feature=feat-rag-grammar
