# CONTEXT — `feat-rag-grammar`

> Feature: **Sửa lỗi ngữ pháp bằng Vector RAG & Grounding** cho Miku Japanese Conversation.  
> Được tách ra từ feature tổng `feat-rag-grounding` theo quyết định phân rã kiến trúc của Human Director.  
> Profile binding: **core-only baseline** (FastAPI, SQLite + `sqlite-vec`, Gemini `gemini-embedding-001` qua `google-genai`).

---

## 1. Problem

### 1.1 Vấn đề nghiệp vụ
1. **Correction mode hay ảo giác (hallucinate) hoặc sửa sai:**
   - Khi người học nói câu dài, phức tạp hoặc chứa nhiều trợ từ N5–N3, Gemini thiếu nguồn đối chiếu chuẩn xác nên đôi khi sửa sai hoặc bắt lỗi những cấu trúc vốn dĩ đúng.
2. **Giải thích tiếng Việt (`explanation_vi`) chưa đồng nhất:**
   - Giải thích lỗi sai chưa bám theo thuật ngữ chuẩn sư phạm của các giáo trình tiếng Nhật phổ biến.

### 1.2 Mong muốn người dùng
- *"Mình muốn Miku chỉ sửa khi mình thực sự sai, và giải thích đúng quy tắc thay vì đoán mò."*
- *"Nếu câu của mình đúng, Miku đừng tự bịa lỗi để sửa."*

### 1.3 Phạm vi ngoài (Out of scope)
- Không bao gồm cá nhân hóa từ vựng (đã được tách riêng thành `feat-rag-vocab`).
- Không dùng mô hình Re-ranking Cross-Encoder nặng nề ở giai đoạn này.
- Không crawl dữ liệu từ các trang web bản quyền thương mại.

---

## 2. Domain Glossary

| Thuật ngữ | Định nghĩa |
|---|---|
| **Grammar Chunk** | Đoạn tài liệu chứa: Tên mẫu ngữ pháp, Cấu trúc, Quy tắc sử dụng, Các lỗi sai thường gặp (Anti-patterns) và Giải thích tiếng Việt. |
| **Strict Grounding Rule** | Quy tắc bắt buộc Gemini: Chỉ sửa khi lỗi sai khớp với tài liệu; nếu không có tài liệu chứng minh thì bắt buộc trả `correction_ja: null`. |
| **sqlite-vec** | SQLite C-extension in-process cho phép lưu trữ và tìm kiếm vector tương đồng (KNN) ngay trong file SQLite. |
| **gemini-embedding-001** | Model embedding chuẩn thế hệ mới của Google (GA 07/2025, thay thế `text-embedding-004` đã deprecated 01/2026), cấu hình 768 chiều. |

---

## 3. Tech Stack & Quyết định kỹ thuật đã chốt

1. **Embedding Model:** Google `gemini-embedding-001` (dùng chung `GEMINI_API_KEY`, SDK `google-genai>=1.0`, `output_dimensionality=768`).
2. **Vector Engine:** `sqlite-vec` (in-process virtual table `vec0` trong `miku.db`).
3. **Corpus nguồn:** Chỉ sử dụng tài liệu ngữ pháp giấy phép mở CC-BY / CC-BY-NC (Tae Kim's Guide, Tanaka Corpus) hoặc curated checklist do team biên soạn.
4. **Similarity Threshold:** $\ge 0.70$. Dưới ngưỡng này coi như không tìm thấy tài liệu, không nhồi context vào prompt.
5. **Latency Budget:** Retrieval P95 $\le 120\text{ ms}$; timeout 100ms tự động fallback an toàn.

---

## 4. Definition of Done (DoD cho CONTEXT)

- [x] Phân tách chuyên biệt bài toán vector search sửa ngữ pháp.
- [x] Tech stack được kiểm chứng và cập nhật mới nhất (Tavily evidence).
- [x] Đầy đủ ràng buộc và cơ chế chống ảo giác.

---

## AI Agent Recommendation

- **Status:** PENDING HUMAN REVIEW
- **Scope:** Feature `feat-rag-grammar` — Context Discovery cho sửa ngữ pháp RAG.
- **Recommendation:** Phê duyệt `CONTEXT.md` để tiến hành lập đặc tả `SPEC.md`. Feature này sẽ được triển khai sau khi hoàn thành `feat-rag-vocab`.
- **Required human decision:** Phê duyệt CONTEXT.md qua `/sdd-review`.

---

## Human Final Review

- **Status:** PENDING
- **Decision:** _leave empty until a human reviews_
- **Reviewer:** _leave empty until a human reviews_
- **Reviewed at:** _leave empty until a human reviews_
- **Follow-up:** /sdd-spec --feature=feat-rag-grammar
