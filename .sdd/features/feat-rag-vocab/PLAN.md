# PLAN — `feat-rag-vocab`

ID: `PLAN-feat-rag-vocab`  
Version: `1.0.0`  
Feature slug: `feat-rag-vocab`  
Status: `APPROVED`  
Owner: `AI Agent & Human Director`  
Approvers: `Human Director`  
Created/updated: `2026-09-04T20:34:00+07:00`  
Spec reference: `.sdd/features/feat-rag-vocab/SPEC.md` (v0.1.0)  

---

## 1. Architectural Approach

Áp dụng mô hình Clean Architecture hiện có của dự án:
1. **Infrastructure Layer (`db/sqlite.py`):**
   - Đảm bảo bảng `vocabulary` có index hỗ trợ truy vấn `(review_count, id)` và thêm cột `jlpt_level` (nếu chưa có) qua additive migration.
2. **Repository Layer (`repositories/vocab_repository.py`):**
   - Cung cấp hàm `get_reinforcement_candidates(level: str, limit: int = 5, max_review: int = 3) -> list[dict]`.
3. **Service Layer (`services/gemini_service.py`):**
   - Mở rộng `build_prompt` và `generate_turn` để nhận `candidate_vocab`.
   - Thêm chỉ dẫn sư phạm trong `SYSTEM_PROMPT_TEMPLATE`: Miku chủ động dùng 1–2 từ candidate trong `reply_ja` và đưa vào output `vocabulary` nếu tự nhiên.
4. **Interface / API Adapter (`api/conversation.py`):**
   - Trong `_handle_turn`, truy vấn candidate vocab trước khi gọi Gemini.
   - Thêm cờ `VOCAB_REINFORCEMENT_ENABLED` trong `core/config.py`.

---

## 2. Components & Layer Mapping

| Component | Layer | Path | Trách nhiệm |
|---|---|---|---|
| `_migrate` | Infra | `backend/app/db/sqlite.py` | Additive migration tạo index và bổ sung cột `jlpt_level` an toàn. |
| `get_reinforcement_candidates` | Repository | `backend/app/repositories/vocab_repository.py` | Truy vấn các từ `review_count < 3` ưu tiên số lần review ít nhất. |
| `build_prompt` & `generate_turn` | Service | `backend/app/services/gemini_service.py` | Format section `[VOCABULARY REINFORCEMENT TARGETS]` vào prompt. |
| `_handle_turn` | Interface/API | `backend/app/api/conversation.py` | Điều phối lấy candidate $\rightarrow$ truyền Gemini $\rightarrow$ lưu kết quả. |
| `Settings` | Core | `backend/app/core/config.py` | Đọc cấu hình `VOCAB_REINFORCEMENT_ENABLED`, `VOCAB_REINFORCEMENT_LIMIT`. |

---

## 3. Data Flow

```text
POST /v1/conversation/turn
  │
  ├── 1. vocab_repo.get_reinforcement_candidates(level=jlpt_level, limit=5)
  │       └── SELECT word, reading, meaning_vi FROM vocabulary WHERE review_count < 3 ...
  │
  ├── 2. gemini_service.generate_turn(..., candidate_vocab=candidates)
  │       └── Prompt: "The learner is currently practicing: [word (reading): meaning_vi]..."
  │       └── Gemini output JSON: { "reply_ja": "...", "vocabulary": [...] }
  │
  └── 3. conv_repo.add_turn_with_vocabulary(..., vocabulary=out.vocabulary)
          └── Tự động UPDATE vocabulary SET review_count = review_count + 1 cho các từ xuất hiện
```

---

## 4. Risks & Mitigations

1. **Risk:** Truy vấn SQLite làm chậm request.
   - **Mitigation:** Tạo index `idx_vocabulary_review_count`. Số lượng từ vựng người học < 5,000 dòng, thời gian query $< 2\text{ ms}$.
2. **Risk:** Gemini gượng ép chèn từ vào ngữ cảnh không phù hợp.
   - **Mitigation:** Chỉ dẫn trong prompt nhấn mạnh: *"Only incorporate if natural to the dialogue; do NOT force words if irrelevant"*.
3. **Risk:** Bảng từ vựng rỗng hoặc lỗi kết nối.
   - **Mitigation:** Bọc `try..except`, trả về danh sách rỗng `[]`, không ảnh hưởng đến luồng hội thoại chính.

---

## 5. Verification Commands

1. **Unit Test Repository & Service:**
   ```powershell
   python -m unittest backend/tests/test_vocab_reinforcement.py -v
   ```
2. **Full Backend Test Suite:**
   ```powershell
   cd backend; python -m unittest discover -s tests -v
   ```

---

## AI Agent Recommendation & Human Final Review

- **Status:** APPROVED
- **Decision:** Duyệt kiến trúc và luồng dữ liệu cho feat-rag-vocab. Triển khai theo 4 task.
- **Reviewer:** Human Director
- **Reviewed at:** 2026-09-04T20:34:00+07:00
- **Follow-up:** /add-execute --feature=feat-rag-vocab
