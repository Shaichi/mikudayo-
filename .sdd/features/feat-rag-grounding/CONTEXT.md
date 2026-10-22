# CONTEXT — `feat-rag-grounding`

> Feature: **RAG grounding cho Gemini conversation pipeline** của Miku
> Japanese Conversation.
> Profile binding: **core-only baseline** (`architecture-profile.md` đang
> `PENDING HUMAN REVIEW`; CONTEXT không bind HTTP framework, ORM, vector
> DB cụ thể — chỉ ghi những binding nào chưa resolve liên quan feature).

## 1. Problem

### 1.1 Vấn đề nghiệp vụ

1. **Correction mode hay "sửa không đúng" hoặc bỏ sót.**
   - Gemini `gemini-3.5-flash-lite` với prompt hiện tại không có nguồn
     grammar chuẩn; model hay hallucinate correction hoặc trả
     `correction_ja=null` khi câu sai dài (rule phụ thuộc N5/N4).
   - Evidence: `HANDOFF.md §5.4` lưu ý hệ gesture phụ thuộc Gemini
     response; tương tự correction text cũng dễ sai.
2. **Vocabulary trả về chưa cá nhân hóa.**
   - Hiện chọn từ theo `jlpt_level` literal. User nói N5 nhưng đã biết
     ~80% N4 thì vẫn nhận từ quá dễ; hoặc ngược lại.
   - `vocabulary` table đã có (`review_count`, `first_seen_at`) nhưng
     chưa được dùng để rank lại từ vựng đề xuất.
3. **Lịch sử hội thoại chưa được nhớ xuyên session.**
   - `recent_turns` (8 turn cuối) đưa vào prompt, nhưng nếu learner nói
     cùng chủ đề sau 5 phút, model không nhớ mistake trước đó.
4. **Giải thích tiếng Việt (`explanation_vi`) chưa có nguồn chuẩn.**
   - Hiện model tự generate; đôi khi dùng thuật ngữ sai hoặc giải thích
     theo cách không chuẩn JLPT pedagogy.

### 1.2 Mong muốn người dùng (user pain)

- "Mình muốn Miku sửa câu sai **đúng quy tắc** thay vì đoán."
- "Mình muốn từ vựng Miku gợi ý **phù hợp trình độ thật** của mình."
- "Mình muốn Miku nhớ mình hay quên particle `は/が` và nhắc lại."
- "Mình muốn giải thích tiếng Việt dùng đúng thuật ngữ giáo trình."

### 1.3 Mong muốn không thuộc phạm vi feature này

- Thay đổi TTS engine (giữ Fish Audio online).
- Thay đổi speech recognizer (giữ Google trên Android).
- Avatar / gesture pipeline (giữ nguyên).
- Lưu trữ audio user (giữ text-only).

---

## 2. Domain glossary

| Thuật ngữ | Định nghĩa |
|---|---|
| **RAG** | Retrieval-Augmented Generation: trước khi gọi LLM, retrieval top-k tài liệu liên quan từ knowledge base, inject vào prompt làm grounding. |
| **Grounding** | Khi LLM có tài liệu nguồn kèm, giảm hallucination vì câu trả lời phải bám vào nguồn. |
| **Knowledge base** | Tập tài liệu đã embed thành vector + metadata, dùng để retrieval. Trong feature này gồm 2 phần: (1) public corpus grammar/vocab, (2) `vocabulary` table của chính user. |
| **Correction chunk** | Một đoạn corpus giải thích một grammar point / một mistake pattern (vd: 「は」vs「が」, trợ từ cuối câu, mẫu `〜てもいい`). |
| **Learner memory** | Vector index của `vocabulary` table + các `correction_ja` lịch sử, dùng để personalize retrieval. |
| **Retrieval latency budget** | Ngưỡng thời gian retrieval chấp nhận được trước khi phá text-first contract (hiện Fish Audio background ~ vài trăm ms → cùng ngưỡng). |
| **Background retrieval** | Retrieval chạy sau khi response text đã trả; không block user. |
| **Idempotency key** | `client_request_id` đã có — không thay đổi. |
| **Re-rank** | Sau retrieval top-k, sắp xếp lại bằng model nhỏ hơn (vd: cross-encoder) để tăng precision. Tùy chọn. |

---

## 3. Entity / state

### 3.1 Knowledge base entry (mới)

- `corpus_id`: integer PK.
- `source`: enum [`jlpt_grammar`, `learner_memory`, `vocab_freq`].
- `lang`: enum [`ja`, `vi`, `mixed`].
- `chunk_text`: TEXT (raw content).
- `embedding_blob`: BLOB (vector embedding).
- `metadata_json`: TEXT JSON (grammar tag, JLPT level, mistake pattern, etc.).
- `created_at`: ISO-8601 timestamp.

### 3.2 Retrieval request (mới, runtime)

- `turn_id`: FK → `turns.id`.
- `query_text`: TEXT (transcript user + emotion context).
- `top_k`: small integer (mặc định 5–10).
- `filters_json`: TEXT JSON (vd: `{"jlpt_level":"N5","source":"grammar"}`).
- `results_json`: TEXT JSON (top-k chunks + scores) — không lưu vĩnh viễn
  trong phase này; chỉ log debug.

### 3.3 State hiện tại không đổi

- `sessions`, `turns`, `vocabulary`, `turn_vocabulary`, `settings` giữ
  nguyên schema; chỉ thêm view/procedure nếu cần.
- Gemini structured output (`SCHEMA_JSON`) giữ nguyên enum +
  `response_schema`. Có thể thêm field `grounding_chunks` ở response
  cho debugging.

---

## 4. Business rule (chưa phải solution kỹ thuật)

1. Correction mode phải có ít nhất 1 grammar chunk trong prompt context
   trước khi gọi Gemini. Nếu retrieval trả `[]`, fallback về prompt
   cũ (không phá caller contract).
2. Vocabulary đề xuất ưu tiên từ learner chưa thuộc
   (`vocabulary.review_count < 3`) trước khi cho Gemini chọn.
3. Knowledge base KHÔNG lưu câu có chứa PII ngoài transcript user
   (`turns.transcript_ja`); chỉ dùng metadata + chunk từ public corpus.
4. Public corpus chỉ ingest từ nguồn có license cho phép
   (CC-BY / CC-BY-SA / public domain) — ghi rõ attribution trong
   knowledge base và trong README.
5. Retrieval KHÔNG block text-first response: nếu retrieval chậm hơn
   `RETRIEVAL_BUDGET_MS`, response text vẫn trả với prompt không có
   grounding (giảm chất lượng nhưng giữ contract).
6. RAG **không** thay đổi TTS / avatar / mic — chỉ chạm `services/`
   layer của backend và (tuỳ chọn) một số chỗ trong Flutter UI để
   hiển thị "grounding source" cho learner.

---

## 5. Stakeholder & decision maker

| Vai trò | Người | Trách nhiệm |
|---|---|---|
| Human Director | chủ dự án (bạn) | Chốt scope RAG, accept trade-off latency / cost / privacy, approve profile + CONTEXT. |
| Tech Lead | _chưa chỉ định_ | Review architecture binding (embedding provider, vector store), RFC nếu schema DB thay đổi. |
| Learner (user app) | End-user Android | Người chịu ảnh hưởng trực tiếp nếu correction / vocab kém chính xác hơn. |
| Gemini (provider) | Google AI Studio | Output correctness phụ thuộc grounding. |
| Embedding provider | Google AI Studio | Dùng `gemini-embedding-001` (qua SDK `google-genai>=1.0` hiện có); thay thế `text-embedding-004` đã deprecated 01/2026. |
| Vector store | SQLite extension | `sqlite-vec` (in-process virtual table `vec0`), local-first, zero-cost. |

---

## 6. Constraint

### 6.1 Tech constraint

- Phải khớp `architecture-profile.md` binding đã approved (hiện chưa).
- Không thêm HTTP framework / ORM / migration tool ngoài stack đã ghi.
- Không phá text-first contract.
- Không upload audio mic (giữ constraint `CLAUDE.md`).
- Không nhúng API key vào Flutter APK.
- Python ≥ 3.10 (đã bind).
- FastAPI + uvicorn (đã bind) — retrieval có thể chạy async trong cùng
  process hoặc background task.

### 6.2 Business constraint

- Tính năng RAG phải tắt được (`RAG_ENABLED=false`) khi key / vector
  store chưa sẵn sàng; backend phải chạy như cũ.
- Attribution cho public corpus phải hiển thị trong app (màn hình
  Settings hoặc About) và trong `BACKEND_GUIDE.md`.
- Nếu embedding provider / vector store vendor đổi giá hoặc ngừng
  dịch vụ, migration path phải documented.

### 6.3 Time / scope constraint

- Phase 1: vocabulary personalization (chỉ index `vocabulary` table)
  — ưu tiên cao, ít rủi ro, không cần ingest corpus ngoài.
- Phase 2: correction grounding từ public corpus (CC-BY grammar) —
  ưu tiên trung bình, cần ingest + license check.
- Phase 3 (out of scope): streaming response, voice-correction realtime,
  semantic log monitoring.

---

## 7. Open question & Quyết định giải pháp (Resolved)

1. **Embedding provider** — **Google `gemini-embedding-001`**.
   - *Quyết định:* Chọn Google `gemini-embedding-001` (dùng chung `GEMINI_API_KEY` và SDK `google-genai>=1.0` hiện có).
   - *Tech check (Tavily evidence):* Google đã chính thức **khai tử `text-embedding-004` vào ngày 14/01/2026**. Flagship model hiện tại là `gemini-embedding-001` (GA tháng 7/2025), hỗ trợ >100 ngôn ngữ, top MTEB Multilingual, sequence length 2048 tokens. Cấu hình output dimension `output_dimensionality=768` để đồng bộ kích thước vector và tiết kiệm bộ nhớ.
2. **Vector store** — **`sqlite-vec` (in-process)**.
   - *Quyết định:* Sử dụng `sqlite-vec` (v0.1.0+ qua `pip install sqlite-vec`).
   - *Lý do:* Chạy in-process dạng C extension của SQLite (`backend/app/db/sqlite.py`), tương thích hoàn toàn trên Windows/Linux, zero-dependency, zero-cost, không cần daemon/server riêng (như Pinecone hay Weaviate) hay container phụ (như ChromaDB), khớp hoàn hảo với single-instance architecture của dự án.
3. **Corpus nguồn được phép dùng** — **Learner Memory & Open Educational Resources (CC-BY/CC-BY-NC)**.
   - *Quyết định:*
     - **Phase 1:** Chỉ dùng `learner_memory` (từ `vocabulary` table của user trong SQLite) — hoàn toàn an toàn về bản quyền và dữ liệu riêng tư.
     - **Phase 2:** Chỉ ingest các nguồn ngữ pháp tiếng Nhật có giấy phép mở rõ ràng: **Tae Kim's Guide to Japanese Grammar** (Creative Commons BY-NC 3.0), **Tanaka Corpus** (CC-BY 2.0 FR), hoặc curated grammar checklist N5-N3 do chính team biên soạn. Tuyệt đối KHÔNG ingest tài liệu thương mại có bản quyền (Genki PDF, Shin Kanzen Master, Soumatome).
4. **Re-rank có cần không?** — **Không dùng ở Phase 1–2**.
   - *Quyết định:* Retrieval top-k đơn giản (k=3 đến 5) kết hợp metadata filtering (`jlpt_level`) qua `sqlite-vec` là đủ cho tập corpus nhỏ (< 1,000 grammar chunks, vài trăm từ vựng). Không thêm Cross-Encoder nhằm đảm bảo latency budget (< 50ms) và tránh tốn tài nguyên CPU.
5. **Hiển thị "grounding source" trong UI** — **Chưa hiển thị ở Phase 1–2 (Chỉ log debug nội bộ)**.
   - *Quyết định:* Giữ UI chat của Miku đơn giản, không làm rối màn hình học tập của learner. Grounding source/score chỉ lưu trong response debug payload hoặc internal log. Ở Phase 3 có thể cân nhắc thêm expandable chip "Xem giải thích ngữ pháp".
6. **Vocabulary personalization threshold** — **`review_count < 3`**.
   - *Quyết định:* Duyệt threshold `vocabulary.review_count < 3` làm định nghĩa từ vựng "chưa thuộc/cần ưu tiên ôn tập". Đây là trường đã có sẵn trong bảng SQLite `vocabulary`, tận dụng ngay mà không cần migration schema phức tạp trước khi phát triển hệ thống SRS riêng.
7. **Knowledge base entry cho lịch sử mistake** — **Phân kỳ Phase 1 / Phase 2**.
   - *Quyết định:*
     - **Phase 1:** Chỉ index `vocabulary` table cho vocabulary personalization.
     - **Phase 2:** Mở rộng learner memory để lưu các turn có `correction_ja != null` (gồm user utterance, mistake pattern, grammar tag) để Miku có thể nhắc lại các lỗi ngữ pháp hay gặp trong các buổi học tiếp theo.

---

## 8. DoD (Definition of Done cho CONTEXT)

- [x] Team hiểu problem, không nhầm với solution (đã phân tách rõ ràng).
- [x] Domain glossary rõ nghĩa (8 thuật ngữ + entity).
- [x] Tech / business / time constraint đã ghi.
- [x] Có decision maker rõ ràng (Human Director).
- [x] Open question quan trọng — Cả 7 câu hỏi ở §7 đã được giải quyết và chốt quyết định kỹ thuật cụ thể.

---

## 9. Approved Decisions & Assumptions

- A1. Embedding provider là Google `gemini-embedding-001` (dùng chung API key với Gemini, `output_dimensionality=768`; thay thế `text-embedding-004` đã deprecated 01/2026).
- A2. Vector store là `sqlite-vec` (in-process SQLite extension) cho Phase 1–2; chỉ chuyển sang managed/cloud khi corpus vượt 1GB hoặc kiến trúc multi-instance.
- A3. Public corpus chỉ dùng nguồn có license mở CC-BY/CC-BY-NC (Tae Kim, Tanaka Corpus); cấm ingest giáo trình thương mại.
- A4. Re-rank không dùng ở Phase 1–2 để tối ưu latency (< 50ms).
- A5. UI không hiển thị grounding source ở Phase 1–2; chỉ trả trong debug log/header.
- A6. Threshold vocabulary "chưa thuộc" = `review_count < 3` tận dụng schema hiện có.
- A7. Learner memory Phase 1 chỉ index `vocabulary` table; Phase 2 mở rộng lưu lịch sử mistake (`correction_ja`).

---

## AI Agent Recommendation

- **Status:** PENDING HUMAN REVIEW
- **Scope:** Feature `feat-rag-grounding` — context discovery cho RAG
  pipeline trong Miku Japanese Conversation backend.
- **Recommendation:**
  - Approve CONTEXT để chuyển sang `/sdd-spec --feature=feat-rag-grounding`.
  - Phase 1 (vocabulary personalization từ `vocabulary` table) chạy
    độc lập, không cần ingest corpus ngoài — risk thấp nhất.
  - Phase 2 (correction grounding từ public corpus CC-BY) ingest theo
    schema đã định nghĩa.
  - Sử dụng `gemini-embedding-001` (qua `google-genai` SDK đã có) và
    `sqlite-vec` in-process; không thêm dependency cloud rườm rà.
- **Evidence:**
  - `architecture-profile.md §2.1` — Gemini SDK `google-genai>=1.0` đã có trong repo.
  - Tavily web evidence: Google chính thức deprecated `text-embedding-004` vào 14/01/2026; model chuẩn thay thế là `gemini-embedding-001` (GA 07/2025).
  - Tavily web evidence: `sqlite-vec` là pure-C extension ổn định, đa nền tảng (Windows/Linux/macOS), cài đặt qua PyPI `sqlite-vec`.
  - `backend/app/db/sqlite.py` — `vocabulary` table đã có `review_count`, `first_seen_at` đủ dùng cho personalization Phase 1.
- **Risks and assumptions:**
  - `gemini-embedding-001` yêu cầu internet và quota Gemini (tuy nhiên chi phí $0.15/1M token rất rẻ và có free tier).
  - Public corpus license phải tuân thủ chặt chẽ CC-BY / CC-BY-NC.
  - In-process SQLite vector search đủ cho quy mô nhỏ; nếu scale cần trừu tượng hóa qua repository interface.
- **Alternatives considered:**
  - **OpenAI / Cohere Embeddings:** Bị loại vì đòi hỏi API key/billing mới, vi phạm ràng buộc không thêm vendor ngoài stack.
  - **ChromaDB / Pinecone:** Bị loại vì nặng nề hoặc đòi hỏi hạ tầng ngoài, không phù hợp single-instance SQLite.
  - **Re-ranking với Cross-Encoder:** Bị loại ở Phase 1-2 vì làm tăng latency đáng kể (>200ms).
- **Required human decision:**
  1. Duyệt CONTEXT.md với 7 quyết định kỹ thuật ở §7.
  2. Phê duyệt chuyển trạng thái sang lập SPEC.md.

## Human Final Review

- **Status:** APPROVED
- **Decision:** Duyệt problem, domain glossary, constraints và giải pháp cho 7 open question ở §7: chọn gemini-embedding-001 (thay thế text-embedding-004 đã deprecated 01/2026), sqlite-vec in-process cho vector store, corpus CC-BY và learner-memory, không re-rank Phase 1-2, log debug nội bộ, threshold vocab review_count < 3. Chấp thuận kết quả cập nhật CONTEXT.md và cho phép chuyển sang viết SPEC.md.
- **Reviewer:** Human Director
- **Reviewed at:** 2026-09-04T20:05:00+07:00
- **Follow-up:** /sdd-spec --feature=feat-rag-grounding