# Feature Specification — `feat-rag-grounding`

ID: `SPEC-feat-rag-grounding`  
Version: `0.1.0-draft`  
Lifecycle record: `FEATURE_STATUS.md`  
Owner: `AI Agent & Human Director`  
Approvers: `Human Director`  
Created/updated: `2026-09-04T20:20:00+07:00`  
Context reference: `.sdd/features/feat-rag-grounding/CONTEXT.md` (APPROVED)  
Risk: `MEDIUM`  
Complexity: `MEDIUM`  
Spec depth: `DETAILED` (Đủ 8 thành phần — do tích hợp external embedding API, latency budget và in-process SQLite vector engine)  
Autonomy: `GUIDED`  
Execution topology: `SINGLE_AGENT`  
Classifier/date: `AI Agent, 2026-09-04T20:20:00+07:00`  
Classification reason/override approval: `Tích hợp RAG in-process với sqlite-vec và gemini-embedding-001 vào pipeline hội thoại; yêu cầu khống chế latency nghiêm ngặt và zero-crash fallback.`

> Chỉ implementation từ spec `APPROVED & LOCKED` v1.0.0 trở lên. Mọi thay đổi sau khóa cần change request, impact analysis, version bump và re-review.

---

## 0. Clarification-First Analysis & Approved Assumptions

| Phân loại | Điểm phân tích | Quyết định / Assumption đã duyệt | Ảnh hưởng kiến trúc & kiểm thử |
|---|---|---|---|
| **1. Business logic gaps** | Xử lý thế nào khi câu nói của user đúng hoặc không có chunk ngữ pháp liên quan trong Knowledge Base? | **Strict Null Fallback:** Khi cosine similarity < 0.70 hoặc không có chunk khớp, hệ thống không inject grounding chunk và Gemini **bắt buộc trả `correction_ja: null`**. | Ngăn chặn 100% việc Gemini tự đoán mò hoặc bịa lỗi sai khi câu của học viên không có lỗi. |
| **1. Business logic gaps** | Đề xuất từ vựng khi Miku không nói từ mới nào trong lượt? | **Empty Array Contract:** Nếu không có từ vựng N5-N3 phù hợp cần dạy, Gemini trả `vocabulary: []`. | Giữ vững contract JSON hiện tại của `GeminiTurnOutput`. |
| **2. Technical constraints** | Latency budget cho bước Retrieval là bao nhiêu ms? | **Budget = 120ms:** Quá trình embed query + sqlite-vec KNN search tối đa 120ms (P95). Nếu timeout, tự động fallback sang prompt không grounding. | Không phá vỡ trải nghiệm thời gian thực (< 1.5s tổng thời gian turn). |
| **2. Technical constraints** | Kích thước vector và hàm khoảng cách? | **Dimension = 768, Metric = Cosine Distance:** Cấu hình `output_dimensionality=768` với `gemini-embedding-001`, tìm kiếm bằng hàm khoảng cách cosine trong `sqlite-vec`. | Tối ưu dung lượng RAM và tốc độ quét vector trong SQLite. |
| **3. Edge cases** | Xử lý khi mất mạng, API Key hết quota hoặc Google Embedding trả 429/500? | **Zero-crash Graceful Degradation:** Bắt ngoại lệ, log WARNING, tiếp tục pipeline với prompt chuẩn (không grounding). | API `/v1/conversation/turn` không bao giờ 500 do lỗi của subsystem RAG. |
| **3. Edge cases** | SQLite lock khi vừa ghi turn vừa truy vấn vector? | **WAL Mode & In-memory KNN:** SQLite chạy WAL mode (`PRAGMA journal_mode=WAL`), đọc virtual table `vec0` không chặn ghi. | An toàn tuyệt đối cho single-instance demo. |

---

## 1. Context and Goal

- **Business pain:**
  1. Khi người học nói câu dài hoặc phức tạp, Gemini (`gemini-3.5-flash-lite`) thường tự bịa sửa ngữ pháp không đúng (hallucination) hoặc bỏ sót lỗi do thiếu nguồn tham chiếu chuẩn xác.
  2. Từ vựng gợi ý mang tính ngẫu nhiên theo `jlpt_level`, chưa ưu tiên các từ người học hay quên hoặc chưa thuộc (`review_count < 3`).
  3. Lời giải thích bằng tiếng Việt (`explanation_vi`) đôi khi dùng thuật ngữ chưa chuẩn sư phạm JLPT.
- **Outcome:**
  1. Loại bỏ hiện tượng sửa sai ngữ pháp cho các điểm ngữ pháp N5–N3 đã được nạp vào Knowledge Base (Grounding precision đạt 100% đối với các lỗi có trong corpus).
  2. Tự động ưu tiên đề xuất từ vựng từ `vocabulary` table của người học có `review_count < 3`.
  3. Toàn bộ quá trình RAG diễn ra in-process, không làm tăng latency tổng của turn quá 120ms.
- **Baseline -> target:**
  - Tỷ lệ ảo giác sửa sai (Correction hallucination rate): ~15% $\rightarrow$ **0%** đối với các mẫu câu có trong corpus.
  - Tỷ lệ từ vựng cá nhân hóa (Personalized vocab ratio): 0% $\rightarrow$ **$\ge 70\%$** (khi user có từ vựng `review_count < 3`).
  - Retrieval P95 latency: N/A $\rightarrow$ **$\le 120\text{ ms}$**.
- **Dependencies & Technology Binding:**
  - `google-genai>=1.0` (dùng model `gemini-embedding-001`, tận dụng `GEMINI_API_KEY`).
  - `sqlite-vec>=0.1.0` (in-process C SQLite extension, virtual table `vec0`).
  - Database: `backend/data/miku.db` (SQLite).

---

## 2. Actors and Roles

| Actor | Allowed actions | Prohibited actions | Trust boundary |
|---|---|---|---|
| **Learner (Mobile App)** | Gửi transcript text tiếng Nhật kèm `mode` (`correction`, `free_talk`, `roleplay`) và `jlpt_level`. | Không gọi trực tiếp Embedding API; không truy cập trực tiếp SQLite vector table. | Untrusted client (Android). Mọi request phải qua validation tại FastAPI endpoints. |
| **RAG Retrieval Service** | Tạo vector query từ transcript user; truy vấn top-k chunks từ `sqlite-vec`; lọc theo metadata level/source. | Không chỉnh sửa dữ liệu transcript user; không gọi TTS; không block pipeline quá 120ms. | Trusted internal backend service (`services/rag_service.py`). |
| **Gemini Service** | Đọc grounding chunks được inject vào prompt để sinh structured JSON output theo `SCHEMA_JSON`. | Không tự ý sửa ngoài quy tắc grounding; không tạo JSON sai schema. | External AI service (Google AI Studio). |
| **Knowledge Base Admin (Script)** | Chạy CLI tool nội bộ để ingest corpus ngữ pháp mở (CC-BY) vào SQLite vector table. | Không ingest tài liệu thương mại có bản quyền (Genki, Shin Kanzen); không chứa PII. | Local CLI maintenance only (`scripts/ingest_corpus.py`). |

Out-of-scope actors: Cloud vector DBs (Pinecone, Chroma Cloud) — không sử dụng trong feature này.

---

## 3. Functional Requirements — EARS

Nghĩa vụ: `SHALL/SHALL NOT` là bắt buộc; `SHOULD/SHOULD NOT` cần lý do giải trình; `MAY` là tùy chọn.

| ID | EARS type | Requirement | Priority | Rationale |
|---|---|---|---|---|
| `FR-001` | Ubiquitous | The RAG service SHALL use `sqlite-vec` in-process virtual table with 768-dimensional float vectors and cosine distance metric. | MUST | Đảm bảo hiệu năng cao, zero-dependency ngoài và đồng bộ với kiến trúc SQLite của dự án. |
| `FR-002` | Event-driven | WHEN a user turn request is received in `correction` mode, the RAG service SHALL generate an embedding vector of the user transcript using `gemini-embedding-001` with `task_type="RETRIEVAL_QUERY"` and `output_dimensionality=768`. | MUST | Cung cấp vector biểu diễn ngữ nghĩa chính xác của câu nói người học để tìm kiếm lỗi ngữ pháp. |
| `FR-003` | Event-driven | WHEN similarity search is performed, the RAG service SHALL retrieve at most $k=3$ grammar chunks that have cosine similarity $\ge 0.70$ and match `jlpt_level <= user_level + 1`. | MUST | Ngăn chặn việc đưa tài liệu không liên quan hoặc vượt quá trình độ vào prompt. |
| `FR-004` | Event-driven | WHEN relevant grammar chunks are found, the prompt builder SHALL inject a `[GROUNDING KNOWLEDGE]` section containing the grammar rule, anti-patterns, and Vietnamese explanation into Gemini's system instruction. | MUST | Ép Gemini bám vào tài liệu chuẩn mực khi nhận xét câu của học viên. |
| `FR-005` | State-driven | WHILE `[GROUNDING KNOWLEDGE]` is present in the prompt, the Gemini service SHALL correct the user utterance ONLY IF the mistake matches a rule in the provided chunks; otherwise it SHALL set `correction_ja: null` and `explanation_vi: null`. | MUST | Triệt tiêu 100% ảo giác tự đoán mò lỗi sai. |
| `FR-006` | Event-driven | WHEN building prompt for turn reply, the vocabulary selector SHALL retrieve words from `vocabulary` table where `review_count < 3` and inject them as candidate targets for Miku's reply. | MUST | Cá nhân hóa việc học, ưu tiên ôn tập từ người học chưa nhớ. |
| `FR-007` | Optional | WHERE `RAG_ENABLED=false` is set in backend configuration, the conversation pipeline SHALL bypass embedding and retrieval, falling back to standard prompt generation. | MUST | Cho phép tắt RAG ngay lập tức khi bảo trì hoặc chạy test unit nhanh mà không cần mạng. |
| `ERR-001` | Unwanted | IF the Google Embedding API call fails (network timeout > 100ms, HTTP 429, or HTTP 5xx), THEN the RAG service SHALL log a warning and return an empty chunk list within latency budget without failing the turn request. | MUST | Đảm bảo tính sẵn sàng (Resilience), không làm gián đoạn hội thoại của người học. |
| `ERR-002` | Unwanted | IF no retrieved chunk satisfies the similarity threshold of 0.70, THEN the prompt builder SHALL NOT include the `[GROUNDING KNOWLEDGE]` section in the system instruction. | MUST | Tránh làm nhiễu ngữ cảnh của LLM khi không có tài liệu liên quan. |
| `ERR-003` | Unwanted | IF `sqlite-vec` extension cannot be loaded at startup, THEN the backend SHALL log a critical error, set `RAG_ENABLED=false` automatically, and continue operating in legacy mode. | MUST | Ngăn ngừa crash toàn bộ server nếu môi trường thiếu thư viện phụ trợ. |

---

## 4. Non-Functional Requirements

| ID | Quality attribute | Load / Environment | Metric / Threshold | Measurement method | Failure consequence |
|---|---|---|---|---|---|
| `NFR-001` | **Performance** | Single-turn request on Local LAN / Tailscale | Retrieval Latency (Embed + Search) P95 $\le 120\text{ ms}$ | Timing decorator trên `rag_service.retrieve_chunks()` | Làm chậm phản hồi tổng của Miku, vi phạm text-first budget. |
| `NFR-002` | **Availability** | Mất mạng hoặc Embedding API bị lỗi rate-limit | 100% Turn Request thành công (Zero 500 error do RAG) | Automated integration test giả lập lỗi mạng khi gọi API | Crash hội thoại, trải nghiệm người dùng bị đứt đoạn. |
| `NFR-003` | **Security & Privacy** | Mọi request hội thoại | Không gửi thông tin PII ra ngoài; không lưu audio; API key chỉ đọc từ `core/config.py` | Code audit & network inspection | Lộ dữ liệu riêng tư của người học hoặc rò rỉ API key. |
| `NFR-004` | **Resource Usage** | 1,000 grammar chunks N5–N3 | Kích thước file `miku.db` tăng $\le 15\text{ MB}$; RAM sử dụng thêm $\le 30\text{ MB}$ | Đo kích thước disk và memory profile của tiến trình Python | Tốn tài nguyên trên thiết bị chạy server nhỏ. |
| `NFR-005` | **Maintainability** | Clean Architecture layout | RAG logic nằm hoàn toàn trong `services/` và `repositories/`, không làm thay đổi schema của `turns` hay endpoint contract | Unit test & layer check | Phá vỡ tính độc lập giữa các tầng kiến trúc. |

---

## 5. Data Model and Contracts

### 5.1 Bảng Metadata: `knowledge_chunks` (SQLite Table)

```sql
CREATE TABLE IF NOT EXISTS knowledge_chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,              -- 'jlpt_grammar', 'learner_memory', 'vocab_freq'
    lang TEXT NOT NULL DEFAULT 'ja',   -- 'ja', 'vi', 'mixed'
    jlpt_level TEXT NOT NULL,          -- 'N5', 'N4', 'N3'
    title TEXT NOT NULL,               -- vd: 'Trợ từ に/へ với động từ di chuyển'
    chunk_text TEXT NOT NULL,          -- Nội dung quy tắc + anti-patterns
    metadata_json TEXT NOT NULL,       -- {"anti_patterns": [...], "tags": [...]}
    created_at TEXT NOT NULL           -- ISO-8601 timestamp
);
```

### 5.2 Bảng Vector: `vec_knowledge_chunks` (sqlite-vec Virtual Table)

```sql
CREATE VIRTUAL TABLE IF NOT EXISTS vec_knowledge_chunks USING vec0(
    chunk_id INTEGER PRIMARY KEY,
    embedding float[768] distance_metric=cosine
);
```

### 5.3 Internal Service Data Contract: `GroundingResult` (Pydantic Schema)

```python
class GroundingChunk(BaseModel):
    chunk_id: int
    title: str
    jlpt_level: str
    chunk_text: str
    similarity_score: float

class RetrievalResult(BaseModel):
    chunks: list[GroundingChunk] = []
    latency_ms: float = 0.0
    fallback: bool = False
```

---

## 6. Error and Failure Handling

| ID | Trigger | Response / Error handling | Side effect | Retry / Idempotency | Observability | Recovery | AC |
|---|---|---|---|---|---|---|---|
| `ERR-001` | Google Embedding API timeout (>100ms) | Trả về `RetrievalResult(chunks=[], fallback=True)` | Không có | Không retry trong luồng thời gian thực; tiếp tục turn | Log `WARNING: RAG embedding timeout, falling back` | Pipeline tiếp tục với prompt thường | `AC-004` |
| `ERR-002` | Quota Gemini API 429 Too Many Requests | Trả về `RetrievalResult(chunks=[], fallback=True)` | Không có | Bỏ qua grounding cho turn hiện tại | Log `WARNING: Embedding quota exceeded` | Pipeline tiếp tục với prompt thường | `AC-004` |
| `ERR-003` | Lỗi nạp extension `sqlite-vec` | Set `RAG_ENABLED=false` | Tắt RAG runtime | Không | Log `ERROR: Failed to load sqlite-vec extension` | Chuyển toàn bộ sang legacy prompt | `AC-005` |
| `ERR-004` | Không có chunk nào đạt score $\ge 0.70$ | Không chèn `[GROUNDING KNOWLEDGE]` vào prompt | Không có | Không | Log `DEBUG: No relevant chunks found for query` | Gemini phản hồi tự nhiên, `correction_ja: null` | `AC-002` |

---

## 7. Acceptance Criteria (BDD)

### `AC-001`: Sửa đúng ngữ pháp khi phát hiện lỗi có trong Corpus (Positive Path)
- **Given:** Hệ thống có chunk ngữ pháp về trợ từ di chuyển: *"Đi đến đâu dùng trợ từ に hoặc へ, không dùng を"*.
- **When:** Người học ở mode `correction` nói: `「私は学校を行きます」` (dùng sai `を`).
- **Then:** 
  1. RAG service trích xuất thành công chunk tương ứng với cosine similarity $\ge 0.70$.
  2. Gemini trả về `correction_ja: "私は学校へ行きます"` (hoặc `「学校に行きます」`).
  3. `explanation_vi` giải thích ngắn gọn về việc dùng trợ từ `に/へ` thay vì `を`.

### `AC-002`: Tuyệt đối không sửa bậy khi câu của người học đúng (Negative Path / Anti-Hallucination)
- **Given:** Người học ở mode `correction` nói một câu đúng: `「明日友達と映画を見に行きます」`.
- **When:** Hệ thống tiến hành embedding và kiểm tra grounding.
- **Then:**
  1. Nếu không có chunk lỗi sai nào vượt ngưỡng similarity, hoặc chunk tìm thấy xác nhận câu đúng.
  2. Gemini trả về `correction_ja: null` và `explanation_vi: null`.
  3. Miku phản hồi tự nhiên bằng tiếng Nhật trong `reply_ja`.

### `AC-003`: Ưu tiên cá nhân hóa từ vựng có `review_count < 3`
- **Given:** Bảng `vocabulary` của user có từ `宿題` (shukudai - bài tập) với `review_count = 1` (chưa thuộc).
- **When:** Người học trò chuyện về chủ đề trường học ở cấp độ `N5`.
- **Then:**
  1. Hệ thống inject gợi ý từ `宿題` vào candidate list của Gemini prompt.
  2. Trường `vocabulary` trong JSON đầu ra của Gemini ưu tiên chứa từ `宿題` nếu ngữ cảnh câu nói phù hợp.

### `AC-004`: Khả năng chịu lỗi khi Embedding API gặp sự cố (Resilience Fallback)
- **Given:** Mạng bị ngắt kết nối đến Google Embedding API hoặc API bị 429.
- **When:** Người học gửi turn hội thoại mới.
- **Then:**
  1. Quá trình retrieval bắt lỗi trong vòng $< 120\text{ ms}$, không văng uncaught exception.
  2. Request `/v1/conversation/turn` vẫn trả về HTTP 200 thành công với câu trả lời bình thường từ Gemini.

### `AC-005`: Tắt tính năng RAG qua biến môi trường
- **Given:** Cấu hình `RAG_ENABLED=false` trong `backend/.env`.
- **When:** Khởi động backend và gửi request hội thoại.
- **Then:**
  1. RAG service hoàn toàn không gọi `gemini-embedding-001` và không truy vấn `sqlite-vec`.
  2. Server hoạt động như baseline ban đầu.

---

## 8. Out of Scope

- **Không xây dựng Crawler tự động:** Không viết web scraper để tự động crawl dữ liệu trên mạng; dữ liệu ban đầu chỉ ingest từ corpus tĩnh được tuyển chọn kỹ (CC-BY).
- **Không Re-ranking bằng Cross-Encoder:** Không tích hợp mô hình BERT/Cross-Encoder nặng nề ở Phase 1–2 để giữ latency dưới 120ms.
- **Không thay đổi Flutter UI hiển thị grounding:** UI di động không đổi; kết quả grounding chỉ trả trong payload debug nội bộ hoặc log backend.
- **Không phân tán Multi-node:** Không kết nối đến các vector database cloud ngoài (như Pinecone, Milvus, Qdrant).

---

## Definition of Done (DoD)

- [x] Đã chạy Clarification-First; 6 giả định và khoảng trống kỹ thuật đã được làm rõ và duyệt.
- [x] Spec Depth đã chọn (`DETAILED`) và lý do đã được nêu rõ.
- [x] Đủ 8 thành phần bắt buộc: Context, Actors, Functional, NFR, Data, Error, Acceptance, Out of Scope.
- [x] Mọi Functional Requirement tuân thủ đúng 5 mẫu chuẩn EARS (`Ubiquitous`, `Event-driven`, `State-driven`, `Optional`, `Unwanted`).
- [x] Mọi Happy Path đều có ít nhất một Unwanted EARS (`ERR-001` đến `ERR-003`) tương ứng.
- [x] Không có từ ngữ mơ hồ; NFR có giá trị đo lường rõ ràng (Latency $\le 120\text{ ms}$, Threshold $= 0.70$).
- [x] Đã khớp binding `gemini-embedding-001` và `sqlite-vec` theo Architecture Profile.

---

## AI Agent Recommendation

- **Status:** PENDING HUMAN REVIEW
- **Scope:** Feature `feat-rag-grounding` — Đặc tả kỹ thuật chi tiết (SPEC.md) cho tính năng RAG Grounding pipeline.
- **Recommendation:**
  - Phê duyệt `SPEC.md` để chuyển trạng thái sang `APPROVED & LOCKED` (v1.0.0).
  - Chuyển sang Pha 2: Lập kế hoạch thực thi kiến trúc bằng lệnh `/sdd-plan --feature=feat-rag-grounding`.
- **Evidence:**
  - [CONTEXT.md](file:///C:/Users/pc/Desktop/mikudayo/.sdd/features/feat-rag-grounding/CONTEXT.md) đã được duyệt ngày 2026-09-04 với 7 quyết định kỹ thuật rõ ràng.
  - Tra cứu Tavily xác nhận `gemini-embedding-001` là model chuẩn GA của Google GenAI SDK hiện có trong repo (`google-genai>=1.0`).
  - `sqlite-vec` là pure C in-process vector engine, đảm bảo không phá vỡ kiến trúc SQLite độc lập của dự án.
- **Risks and assumptions:**
  - Latency của Google Embedding API phụ thuộc vào đường truyền quốc tế (đã có cơ chế timeout 100ms và fallback an toàn).
  - Cần script ingest corpus ban đầu cho các mẫu câu N5-N3 cơ bản.
- **Alternatives considered:**
  - **ChromaDB / Pinecone:** Loại bỏ do quá nặng hoặc phát sinh chi phí/vendor lock-in.
  - **Re-ranking Cross-Encoder:** Loại bỏ ở Phase 1-2 do tốn thêm 100-200ms CPU.
- **Required human decision:**
  1. Duyệt toàn bộ 8 phần của SPEC.md và các tiêu chí chấp thuận (AC-001 đến AC-005).
  2. Ghi nhận phê duyệt qua `/sdd-review` để khóa Spec (`APPROVED & LOCKED`).

---

## Human Final Review

- **Status:** PENDING
- **Decision:** _leave empty until a human reviews_
- **Reviewer:** _leave empty until a human reviews_
- **Reviewed at:** _leave empty until a human reviews_
- **Follow-up:**
  - Nếu APPROVED: Khóa Spec thành v1.0.0 (`APPROVED & LOCKED`) và chạy `/sdd-plan --feature=feat-rag-grounding`.
  - Nếu REVISE: Sửa đổi các mục requirement/NFR theo yêu cầu.
  - Nếu REJECTED: Đóng spec và xem xét lại phương án thiết kế.
