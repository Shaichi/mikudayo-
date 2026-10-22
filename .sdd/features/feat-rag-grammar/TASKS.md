# TASKS — `feat-rag-grammar`

Feature: `feat-rag-grammar` (Sửa lỗi ngữ pháp bằng Vector RAG & Grounding)  
Spec: `SPEC-feat-rag-grammar` (v0.1.0)  
Plan: `PLAN-feat-rag-grammar` (v1.0.0)  
Status: `COMPLETE`  

---

## Danh sách Task

| Task ID | Layer | Tiêu đề task | Dependencies | Files to modify | Verification Command | Status |
|---|---|---|---|---|---|---|
| `T001` | Core | Bổ sung biến cấu hình RAG Grammar trong `config.py` | None | `backend/app/core/config.py` | `python -m unittest backend/tests/test_backend_hardening.py -v` | DONE |
| `T002` | Infra | Nạp dynamic extension `sqlite-vec` và tạo bảng `grammar_chunks`, `vec_grammar_chunks` | None | `backend/app/db/sqlite.py` | `python -c "from app.db.sqlite import init_db; init_db()"` | DONE |
| `T003` | Repository | Viết `grammar_repository.py` hỗ trợ insert chunk, insert vector và KNN vector search | `T002` | `backend/app/repositories/grammar_repository.py` | `python -m unittest discover -s tests -v` | DONE |
| `T004` | Service | Viết `rag_grammar_service.py` gọi embedding API, timeout guard 100ms và fallback an toàn | `T001`, `T003` | `backend/app/services/rag_grammar_service.py` | `python -m unittest discover -s tests -v` | DONE |
| `T005` | Service | Cập nhật `gemini_service.py` chèn `[GROUNDING KNOWLEDGE]` và quy tắc Strict Grounding | None | `backend/app/services/gemini_service.py` | `python -m unittest discover -s tests -v` | DONE |
| `T006` | Interface/API | Nối luồng retrieval vào `conversation.py` khi `mode == "correction"` | `T004`, `T005` | `backend/app/api/conversation.py` | `python -m unittest discover -s tests -v` | DONE |
| `T007` | Data/Seed | Tạo hàm seed các điểm ngữ pháp N5-N3 chuẩn ban đầu vào database | `T003` | `backend/app/db/seed_grammar.py` | `python -c "from app.db.seed_grammar import seed_grammar; seed_grammar()"` | DONE |
| `T008` | Test | Viết bộ kiểm thử toàn diện `test_rag_grammar.py` xác minh vector search, grounding, fallback | `T001`–`T007` | `backend/tests/test_rag_grammar.py` | `python -m unittest backend/tests/test_rag_grammar.py -v` | DONE |

---

## AI Recommendation & Human Final Review

- **Status:** APPROVED
- **Decision:** Phê duyệt danh sách 8 task cho feat-rag-grammar.
- **Reviewer:** Human Director
- **Reviewed at:** 2026-09-04T20:37:00+07:00
- **Follow-up:** Bắt đầu thực thi T001 đến T008.
