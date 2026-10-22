# Feature Specification — `feat-rag-vocab`

ID: `SPEC-feat-rag-vocab`  
Version: `0.1.0-draft`  
Lifecycle record: `FEATURE_STATUS.md`  
Owner: `AI Agent & Human Director`  
Approvers: `Human Director`  
Created/updated: `2026-09-04T20:25:00+07:00`  
Context reference: `.sdd/features/feat-rag-vocab/CONTEXT.md`  
Risk: `LOW`  
Complexity: `LOW`  
Spec depth: `DETAILED`  
Autonomy: `GUIDED`  
Execution topology: `SINGLE_AGENT`  
Classifier/date: `AI Agent, 2026-09-04T20:25:00+07:00`  
Classification reason/override approval: `Cá nhân hóa từ vựng dựa trên bảng vocabulary nội bộ của SQLite; rủi ro thấp, không phụ thuộc external vector DB.`

---

## 1. Context and Goal

- **Business pain:** Miku đề xuất từ vựng ngẫu nhiên, không nhớ các từ người học chưa thuộc (`review_count < 3`), gây lãng phí cơ hội củng cố từ vựng trong các buổi học tiếp theo.
- **Outcome:** Tự động truy xuất danh sách 3–5 từ vựng người học cần ôn tập từ SQLite và gợi ý vào prompt của Gemini để Miku chủ động sử dụng trong câu trả lời một cách tự nhiên.
- **Baseline -> target:** Tỷ lệ xuất hiện từ cần ôn tập trong gợi ý từ vựng tăng từ **0% lên $\ge 60\%$** khi người học có từ vựng `review_count < 3`.

---

## 2. Actors and Roles

| Actor | Allowed actions | Prohibited actions | Trust boundary |
|---|---|---|---|
| **Vocab Repository** | Đọc danh sách từ vựng `review_count < 3`; cập nhật tăng `review_count` khi từ xuất hiện trong lượt. | Không xóa từ vựng; không sửa trường `first_seen_at`. | Internal DB layer (`repositories/vocab_repository.py`). |
| **Gemini Prompt Builder** | Format danh sách candidate vocab vào System Instruction. | Không bắt buộc Miku dùng từ gượng ép nếu không hợp ngữ cảnh. | Internal Service layer (`services/gemini_service.py`). |
| **Gemini Model** | Chọn lọc lồng ghép 1–2 từ candidate vào `reply_ja` và trả trong JSON `vocabulary`. | Không trả từ ngoài schema `SCHEMA_JSON`. | External LLM API. |

---

## 3. Functional Requirements — EARS

| ID | EARS type | Requirement | Priority | Rationale |
|---|---|---|---|---|
| `FR-001` | Ubiquitous | The `VocabRepository` SHALL provide a query method `get_reinforcement_candidates(level: str, limit: int = 5)` returning vocabulary items with `review_count < 3` ordered by `review_count ASC, last_seen_at ASC`. | MUST | Lấy chính xác các từ người học yếu nhất hoặc lâu chưa gặp nhất. |
| `FR-002` | Event-driven | WHEN generating a turn prompt, the `GeminiService` SHALL fetch reinforcement candidates and inject them into the system instruction under `[VOCABULARY REINFORCEMENT TARGETS]`. | MUST | Cung cấp ngữ cảnh mục tiêu để Miku chủ động sử dụng từ. |
| `FR-003` | State-driven | WHILE candidate words are provided in the prompt, the Gemini service SHOULD integrate at least one candidate word into `reply_ja` and include it in `vocabulary` output IF it naturally fits the conversation context. | SHOULD | Khuyến khích củng cố từ vựng tự nhiên, tránh gượng ép. |
| `FR-004` | Event-driven | WHEN Gemini returns a structured output containing vocabulary items, the conversation service SHALL increment `review_count` by 1 and update `last_seen_at` for any matching words in the SQLite database. | MUST | Ghi nhận tiến độ học tập của người học. |
| `FR-005` | Optional | WHERE `VOCAB_REINFORCEMENT_ENABLED=false` is set in configuration, the system SHALL bypass candidate retrieval and prompt injection. | MAY | Cho phép bật/tắt tính năng linh hoạt. |
| `ERR-001` | Unwanted | IF the `vocabulary` table has no items with `review_count < 3` matching the level, THEN the prompt builder SHALL NOT inject the reinforcement section and SHALL proceed with standard conversation prompt. | MUST | Đảm bảo hoạt động trơn tru cho người học mới hoặc khi đã thuộc hết từ vựng. |
| `ERR-002` | Unwanted | IF the database query fails or times out (>50ms), THEN the system SHALL log a warning and proceed without candidate injection without failing the turn. | MUST | Không bao giờ làm crash turn hội thoại vì lỗi phụ trợ. |

---

## 4. Non-Functional Requirements

| ID | Quality attribute | Metric / Threshold | Measurement method | Failure consequence |
|---|---|---|---|---|
| `NFR-001` | **Performance** | Database query time $\le 5\text{ ms}$ | SQLite timing log | Không ảnh hưởng đến tốc độ phản hồi chung. |
| `NFR-002` | **Reliability** | Zero 500 error khi DB rỗng hoặc lỗi | Unit & integration tests | Hội thoại luôn thông suốt. |
| `NFR-003` | **Maintainability** | Không thay đổi API Contract JSON với Flutter | Pydantic schema validation | Flutter client không cần sửa đổi. |

---

## 5. Data Model and Schema

Tận dụng bảng SQLite `vocabulary` hiện có trong [backend/app/db/sqlite.py](file:///C:/Users/pc/Desktop/mikudayo/backend/app/db/sqlite.py):
```sql
-- Đã tồn tại sẵn:
-- vocabulary(id, word, reading, meaning_vi, jlpt_level, review_count, first_seen_at, last_seen_at)
-- Đảm bảo có index để query siêu tốc:
CREATE INDEX IF NOT EXISTS idx_vocab_review_level ON vocabulary(review_count, jlpt_level, last_seen_at);
```

---

## 6. Acceptance Criteria (BDD)

### `AC-001`: Đề xuất từ vựng cần ôn tập vào prompt
- **Given:** Người học có từ `りんご` (táo) trong DB với `review_count = 1`, `level = N5`.
- **When:** Người học gửi câu hỏi về đồ ăn: `「好きな果物は何ですか」`.
- **Then:** Prompt gửi sang Gemini có chứa gợi ý từ `りんご`, và Gemini ưu tiên dùng từ `りんご` trong câu trả lời.

### `AC-002`: Tăng `review_count` sau khi được ôn tập
- **Given:** Từ `りんご` có `review_count = 1`.
- **When:** Gemini trả về output có chứa `word: "りんご"` trong danh sách `vocabulary`.
- **Then:** Bản ghi `りんご` trong SQLite được cập nhật `review_count = 2` và `last_seen_at` là thời điểm hiện tại.

### `AC-003`: Xử lý mượt mà khi DB chưa có từ vựng nào
- **Given:** Bảng `vocabulary` hoàn toàn trống rỗng (học viên mới toanh).
- **When:** Người học trò chuyện turn đầu tiên.
- **Then:** Prompt không có phần candidate vocab, hội thoại diễn ra bình thường, từ mới đầu tiên được tạo với `review_count = 1`.

---

## 7. Out of Scope

- Không can thiệp sửa lỗi ngữ pháp (thuộc `feat-rag-grammar`).
- Không thêm giao diện flashcard trên Flutter trong feature này.
- Không dùng vector embeddings.

---

## Definition of Done (DoD)

- [x] Đầy đủ 8 thành phần đặc tả theo SDD.
- [x] EARS requirements bao phủ cả happy path và unwanted path (`ERR-001`, `ERR-002`).
- [x] NFR đo lường được ($\le 5\text{ ms}$).
- [x] BDD Acceptance Criteria rõ ràng.

---

## AI Agent Recommendation

- **Status:** PENDING HUMAN REVIEW
- **Scope:** Feature `feat-rag-vocab` — Đặc tả kỹ thuật cho cá nhân hóa từ vựng.
- **Recommendation:** Phê duyệt `SPEC.md` để triển khai ngay qua `/sdd-plan --feature=feat-rag-vocab`. Feature này hoàn toàn độc lập và có thể hoàn thành trọn vẹn trước khi làm `feat-rag-grammar`.
- **Required human decision:** Phê duyệt SPEC.md qua `/sdd-review`.

---

## Human Final Review

- **Status:** PENDING
- **Decision:** _leave empty until a human reviews_
- **Reviewer:** _leave empty until a human reviews_
- **Reviewed at:** _leave empty until a human reviews_
- **Follow-up:** /sdd-plan --feature=feat-rag-vocab
