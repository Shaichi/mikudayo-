# TASKS — `feat-rag-vocab`

Feature: `feat-rag-vocab` (Cá nhân hóa từ vựng từ Learner Memory)  
Spec: `SPEC-feat-rag-vocab` (v0.1.0)  
Plan: `PLAN-feat-rag-vocab` (v1.0.0)  
Status: `COMPLETE`  

---

## Danh sách Task

| Task ID | Layer | Tiêu đề task | Dependencies | Files to modify | Verification Command | Status |
|---|---|---|---|---|---|---|
| `T001` | Infra | Bổ sung index `idx_vocabulary_review_count` và cột `jlpt_level` nếu thiếu | None | `backend/app/db/sqlite.py` | `python -m unittest backend/tests/test_backend_hardening.py -v` | DONE |
| `T002` | Repository | Viết hàm `get_reinforcement_candidates` trong `vocab_repository.py` | `T001` | `backend/app/repositories/vocab_repository.py` | `python -m unittest discover -s tests -v` | DONE |
| `T003` | Service | Cập nhật `build_prompt` và `generate_turn` nhận `candidate_vocab` | None | `backend/app/services/gemini_service.py` | `python -m unittest discover -s tests -v` | DONE |
| `T004` | Interface/API | Nối pipeline lấy candidate vocab trong `conversation.py` và bổ sung cấu hình trong `config.py` | `T002`, `T003` | `backend/app/api/conversation.py`, `backend/app/core/config.py` | `python -m unittest discover -s tests -v` | DONE |
| `T005` | Test | Viết unit test trọn vẹn `test_vocab_reinforcement.py` xác minh candidate, prompt injection và review_count increment | `T004` | `backend/tests/test_vocab_reinforcement.py` | `python -m unittest backend/tests/test_vocab_reinforcement.py -v` | DONE |

---

## AI Recommendation & Human Final Review

- **Status:** APPROVED
- **Decision:** Phê duyệt danh sách 5 task độc lập có thể thực thi tuần tự và kiểm chứng tự động.
- **Reviewer:** Human Director
- **Reviewed at:** 2026-09-04T20:34:00+07:00
- **Follow-up:** Bắt đầu thực thi T001 đến T005.
