# Feature Specification — `feat-rag-grammar`

ID: `SPEC-feat-rag-grammar`  
Version: `0.1.0-draft`  
Lifecycle record: `FEATURE_STATUS.md`  
Owner: `AI Agent & Human Director`  
Approvers: `Human Director`  
Created/updated: `2026-09-04T20:25:00+07:00`  
Context reference: `.sdd/features/feat-rag-grammar/CONTEXT.md`  
Risk: `MEDIUM`  
Complexity: `MEDIUM`  
Spec depth: `DETAILED`  
Autonomy: `GUIDED`  
Execution topology: `SINGLE_AGENT`  
Classifier/date: `AI Agent, 2026-09-04T20:25:00+07:00`  
Classification reason/override approval: `Tích hợp in-process SQLite vector engine (sqlite-vec) và Google gemini-embedding-001 để sửa lỗi ngữ pháp chuẩn xác và triệt tiêu ảo giác.`

---

## 1. Context and Goal

- **Business pain:** Chế độ sửa lỗi (`correction`) thường xuyên mắc lỗi ảo giác (sửa câu đúng thành sai hoặc bịa quy tắc không chuẩn) do Gemini không có tài liệu đối chiếu.
- **Outcome:** Chỉ sửa câu khi phát hiện lỗi sai rõ ràng khớp với tài liệu ngữ pháp (CC-BY); triệt tiêu 100% việc đoán mò khi câu của người học đúng hoặc không có tài liệu liên quan.
- **Baseline -> target:** Tỷ lệ ảo giác sửa sai (Correction hallucination rate) giảm từ ~15% xuống **0%** cho các mẫu câu có trong corpus.

---

## 2. Actors and Roles

| Actor | Allowed actions | Prohibited actions | Trust boundary |
|---|---|---|---|
| **RAG Retrieval Engine** | Tạo vector truy vấn qua `gemini-embedding-001`; tìm kiếm KNN trên bảng ảo `vec0` của `sqlite-vec`; lọc theo `jlpt_level`. | Không sửa đổi dữ liệu người học; không block hội thoại quá 120ms. | Internal backend service (`services/rag_grammar_service.py`). |
| **Gemini Service** | Đọc grounding chunks trong System Prompt để xuất JSON sửa lỗi chính xác. | Không tự ý sáng tác quy tắc ngoài tài liệu cung cấp. | External AI service (Google AI Studio). |
| **Corpus Ingestion CLI** | Nạp các đoạn ngữ pháp mở (CC-BY) vào `knowledge_chunks` và nhúng vector vào `vec_knowledge_chunks`. | Không nạp tài liệu thương mại có bản quyền; không chứa PII. | Internal CLI tool (`scripts/ingest_grammar.py`). |

---

## 3. Functional Requirements — EARS

| ID | EARS type | Requirement | Priority | Rationale |
|---|---|---|---|---|
| `FR-001` | Ubiquitous | The RAG grammar engine SHALL store document embeddings in an in-process `sqlite-vec` virtual table using 768 float dimensions and cosine distance metric. | MUST | Giữ tính gọn nhẹ, zero-cost, chạy hoàn toàn trong file SQLite cục bộ. |
| `FR-002` | Event-driven | WHEN a user utterance is received in `correction` mode, the engine SHALL embed the utterance using `gemini-embedding-001` with `task_type="RETRIEVAL_QUERY"` and `output_dimensionality=768`. | MUST | Biểu diễn ngữ nghĩa câu nói của học viên để đối chiếu lỗi sai. |
| `FR-003` | Event-driven | WHEN searching for relevant grammar rules, the engine SHALL retrieve at most $k=3$ chunks with cosine similarity $\ge 0.70$ and `jlpt_level <= user_level + 1`. | MUST | Lọc bỏ dữ liệu rác, chỉ giữ lại tài liệu thực sự liên quan và phù hợp trình độ. |
| `FR-004` | Event-driven | WHEN relevant chunks are found, the prompt builder SHALL inject a `[GROUNDING KNOWLEDGE]` section containing the grammar rule, common mistakes (anti-patterns), and Vietnamese explanation into Gemini's prompt. | MUST | Cung cấp căn cứ sư phạm chuẩn xác cho Gemini. |
| `FR-005` | State-driven | WHILE `[GROUNDING KNOWLEDGE]` is present in the prompt, the Gemini service SHALL correct the user utterance ONLY IF the mistake matches a rule in the provided chunks; otherwise it SHALL return `correction_ja: null` and `explanation_vi: null`. | MUST | Khóa an toàn triệt tiêu hiện tượng đoán mò và sửa bậy. |
| `FR-006` | Optional | WHERE `RAG_GRAMMAR_ENABLED=false` is set in configuration, the system SHALL bypass vector retrieval and continue with standard ungrounded prompt. | MAY | Cho phép tắt tính năng khi chạy offline hoặc kiểm thử. |
| `ERR-001` | Unwanted | IF the embedding API call times out (>100ms) or returns an error (429/500), THEN the engine SHALL log a warning and return an empty chunk list without failing the turn request. | MUST | Đảm bảo tính sẵn sàng (Resilience), không làm gián đoạn hội thoại. |
| `ERR-002` | Unwanted | IF no retrieved chunk reaches the 0.70 similarity threshold, THEN the prompt builder SHALL NOT include the `[GROUNDING KNOWLEDGE]` section in the prompt. | MUST | Tránh gây nhiễu cho mô hình khi câu của người học không có tài liệu liên quan. |
| `ERR-003` | Unwanted | IF the `sqlite-vec` extension fails to load at application startup, THEN the system SHALL log an error, disable RAG grammar dynamically, and continue running in legacy mode. | MUST | Ngăn ngừa crash toàn bộ server. |

---

## 4. Non-Functional Requirements

| ID | Quality attribute | Metric / Threshold | Measurement method | Failure consequence |
|---|---|---|---|---|
| `NFR-001` | **Performance** | Retrieval Latency (Embed + Search) P95 $\le 120\text{ ms}$ | Timing log nội bộ | Làm tăng độ trễ phản hồi của Miku. |
| `NFR-002` | **Reliability** | 100% Request thành công (Zero 500 do RAG) | Automated network failure test | Gián đoạn trải nghiệm người dùng. |
| `NFR-003` | **Resource Usage** | Disk overhead $\le 15\text{ MB}$ cho 1,000 chunks; RAM $\le 30\text{ MB}$ | OS process inspection | Tốn tài nguyên bộ nhớ. |

---

## 5. Data Model

### 5.1 Bảng Metadata: `grammar_chunks`
```sql
CREATE TABLE IF NOT EXISTS grammar_chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,              -- 'tae_kim', 'tanaka', 'curated'
    jlpt_level TEXT NOT NULL,          -- 'N5', 'N4', 'N3'
    title TEXT NOT NULL,               -- 'Trợ từ に/へ với động từ di chuyển'
    chunk_text TEXT NOT NULL,          -- Quy tắc + ví dụ đúng + ví dụ sai
    created_at TEXT NOT NULL           -- ISO-8601
);
```

### 5.2 Bảng Vector: `vec_grammar_chunks`
```sql
CREATE VIRTUAL TABLE IF NOT EXISTS vec_grammar_chunks USING vec0(
    chunk_id INTEGER PRIMARY KEY,
    embedding float[768] distance_metric=cosine
);
```

---

## 6. Acceptance Criteria (BDD)

### `AC-001`: Sửa đúng lỗi ngữ pháp khi có trong Corpus (Positive Path)
- **Given:** Có chunk ngữ pháp: *"Động từ di chuyển dùng に/へ, không dùng を"*.
- **When:** Người học ở mode `correction` nói: `「学校を行きます」`.
- **Then:**
  1. Retrieval trích xuất chunk tương ứng với cosine similarity $\ge 0.70$.
  2. Gemini trả `correction_ja: "学校へ行きます"` và `explanation_vi` giải thích dùng `に/へ` thay vì `を`.

### `AC-002`: Không sửa bậy khi câu của học viên đúng (Negative Path)
- **Given:** Người học nói câu đúng: `「明日友達と映画を見に行きます」`.
- **When:** Hệ thống tìm kiếm vector.
- **Then:** Gemini trả về `correction_ja: null` và `explanation_vi: null`.

### `AC-003`: Fallback trơn tru khi Embedding API gặp sự cố
- **Given:** Mất kết nối internet đến Google Embedding API.
- **When:** Người học gửi câu nói ở mode `correction`.
- **Then:** Backend bắt lỗi trong vòng $< 120\text{ ms}$, tiếp tục gọi Gemini sinh phản hồi bình thường với HTTP 200.

---

## 7. Out of Scope

- Không re-ranking bằng Cross-Encoder (Phase 1-2).
- Không hiển thị badge "grounding source" lên giao diện chat Flutter (chỉ log debug).
- Không ingest tài liệu có bản quyền thương mại.

---

## Definition of Done (DoD)

- [x] Đủ 8 thành phần đặc tả theo SDD.
- [x] EARS bao phủ đầy đủ happy path và unwanted path.
- [x] NFR đo lường được ($\le 120\text{ ms}$).
- [x] Tiêu chí BDD rõ ràng, có negative path chống ảo giác.

---

## AI Agent Recommendation

- **Status:** PENDING HUMAN REVIEW
- **Scope:** Feature `feat-rag-grammar` — Đặc tả kỹ thuật cho sửa ngữ pháp RAG.
- **Recommendation:** Phê duyệt `SPEC.md` sau khi hoàn thành `feat-rag-vocab` để triển khai theo lộ trình 2 pha an toàn.
- **Required human decision:** Phê duyệt SPEC.md qua `/sdd-review`.

---

## Human Final Review

- **Status:** PENDING
- **Decision:** _leave empty until a human reviews_
- **Reviewer:** _leave empty until a human reviews_
- **Reviewed at:** _leave empty until a human reviews_
- **Follow-up:** /sdd-plan --feature=feat-rag-grammar
