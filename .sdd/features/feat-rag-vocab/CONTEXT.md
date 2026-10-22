# CONTEXT — `feat-rag-vocab`

> Feature: **Cá nhân hóa từ vựng từ Learner Memory** cho pipeline hội thoại của Miku.  
> Được tách ra từ feature tổng `feat-rag-grounding` theo quyết định phân rã kiến trúc của Human Director.  
> Profile binding: **core-only baseline** (FastAPI, SQLite `vocabulary` table, Gemini `google-genai`).

---

## 1. Problem

### 1.1 Vấn đề nghiệp vụ
1. **Từ vựng đề xuất chưa có tính cá nhân hóa:**
   - Hiện tại, Gemini tự chọn ngẫu nhiên 0–4 từ trong câu trả lời `reply_ja` để đưa vào trường `vocabulary`.
   - Hệ thống không đối chiếu với vốn từ hiện tại của người học. Nếu người học đã biết một từ rất rõ nhưng Miku vẫn liên tục "dạy lại", hoặc người học vừa học một từ mới hôm qua nhưng không bao giờ được Miku gợi ý lại để thực hành, việc ghi nhớ sẽ kém hiệu quả.
2. **Lãng phí dữ liệu đã thu thập:**
   - Database SQLite (`backend/data/miku.db`) đã có sẵn bảng `vocabulary` với các trường: `word`, `reading`, `meaning_vi`, `jlpt_level`, `first_seen_at`, `review_count`.
   - Tuy nhiên, trường `review_count` hiện tại chỉ được ghi nhận một chiều mà chưa bao giờ được đọc ngược lại để phục vụ cho các lượt hội thoại tiếp theo.

### 1.2 Mong muốn người dùng (User pain)
- *"Mình muốn Miku nhắc lại những từ mình mới học hoặc hay quên để mình nhớ lâu hơn."*
- *"Mình không muốn Miku cứ giải thích đi giải thích lại những từ quá dễ mà mình đã thuộc làu."*

### 1.3 Phạm vi ngoài (Out of scope)
- Chưa can thiệp vào sửa lỗi ngữ pháp RAG (đây là phạm vi của `feat-rag-grammar`).
- Chưa triển khai thuật toán ngắt quãng Spaced Repetition phức tạp (như SM-2 hay FSRS); chỉ dùng ngưỡng đếm đơn giản `review_count`.
- Không thay đổi giao diện màn hình từ vựng trên Flutter.

---

## 2. Domain Glossary

| Thuật ngữ | Định nghĩa |
|---|---|
| **Learner Memory (Vocab)** | Kho từ vựng cá nhân của người học được lưu trữ trong bảng `vocabulary` SQLite cục bộ. |
| **Weak Vocabulary** | Các từ vựng người học đã từng gặp nhưng chưa thành thạo (được định nghĩa ban đầu là `review_count < 3`). |
| **Candidate Vocab** | Danh sách 3–6 từ vựng yếu được backend truy vấn ra và đưa vào prompt để gợi ý Miku sử dụng trong câu trả lời. |
| **Active Reinforcement** | Hành vi Miku lồng ghép khéo léo từ vựng yếu vào câu trả lời để người học tiếp xúc tự nhiên trong ngữ cảnh hội thoại. |

---

## 3. Entity / State

### 3.1 Thực thể hiện tại (Tận dụng nguyên trạng)
Bảng `vocabulary` trong SQLite:
- `id`: INTEGER PK.
- `word`: TEXT NOT NULL.
- `reading`: TEXT.
- `meaning_vi`: TEXT.
- `jlpt_level`: TEXT ('N5', 'N4', 'N3').
- `review_count`: INTEGER DEFAULT 1.
- `first_seen_at`: TEXT ISO-8601.
- `last_seen_at`: TEXT ISO-8601.

### 3.2 Luồng dữ liệu (Data Flow)
```text
User gửi turn (level: N5)
  → Backend truy vấn SQLite: SELECT word, reading, meaning_vi FROM vocabulary WHERE review_count < 3 AND jlpt_level <= 'N5' ORDER BY review_count ASC, last_seen_at ASC LIMIT 5
  → Inject vào Prompt: [CANDIDATE VOCABULARY TO REINFORCE]
  → Gemini sinh reply_ja có chứa từ candidate (nếu tự nhiên) và trả về trong trường vocabulary
  → Backend cập nhật review_count = review_count + 1 cho các từ xuất hiện trong output
```

---

## 4. Business Rules

1. **Ưu tiên từ chưa thuộc:** Chỉ chọn các từ có `review_count < 3` để làm candidate. Từ đã có `review_count >= 3` được coi là đã thuộc tạm thời, không chủ động nhồi nhét.
2. **Khớp trình độ (Level guard):** Chỉ chọn các từ có cấp độ $\le$ cấp độ hội thoại hiện tại (`jlpt_level`) của session.
3. **Không cưỡng ép làm mất tự nhiên:** Prompt chỉ hướng dẫn Miku *"nếu phù hợp ngữ cảnh thì sử dụng 1–2 từ trong danh sách; nếu không hợp ngữ cảnh thì trả lời tự nhiên, không gượng ép"*.
4. **Cập nhật tần suất lặp lại:** Khi Miku thực sự sử dụng từ candidate trong `vocabulary` của turn, `review_count` của từ đó trong DB sẽ được tăng thêm 1 và cập nhật `last_seen_at`.
5. **Zero-latency penalty:** Truy vấn SQLite nội bộ bảng `vocabulary` (vài trăm bản ghi) phải hoàn thành trong $< 5\text{ ms}$, hoàn toàn không ảnh hưởng đến thời gian phản hồi.

---

## 5. Stakeholder & Decision Maker

| Vai trò | Người | Trách nhiệm |
|---|---|---|
| **Human Director** | Chủ dự án | Duyệt phạm vi tách nhỏ feature, approve CONTEXT và SPEC. |
| **Backend Service** | `services/gemini_service.py` & `repositories/vocab_repository.py` | Thực thi truy vấn candidate vocab và inject prompt. |
| **Learner** | Người dùng app Android | Người thụ hưởng trải nghiệm từ vựng được cá nhân hóa. |

---

## 6. Constraints

- **Tech Constraint:**
  - Không thêm package hay dependency mới ngoài stack có sẵn (`fastapi`, `sqlite3`, `pydantic`, `google-genai`).
  - Không thay đổi contract JSON giữa Backend và Flutter (`ConversationResult.vocabulary`).
- **Business Constraint:**
  - Tính năng phải tắt/bật được qua cấu hình (hoặc fallback mượt mà nếu bảng từ vựng rỗng).

---

## 7. Open Questions & Quyết định (Resolved)

1. **Q1: Khi bảng từ vựng rỗng (người học mới toanh) thì xử lý thế nào?**
   - *Quyết định:* Nếu không có từ nào thoả mãn `review_count < 3`, candidate list rỗng `[]`, Gemini hoạt động theo chế độ mặc định tự do (không bị ảnh hưởng).
2. **Q2: Số lượng candidate tối đa gửi vào prompt là bao nhiêu?**
   - *Quyết định:* Giới hạn 5 từ (LIMIT 5). Tránh làm loãng prompt hoặc khiến model bị phân tâm.
3. **Q3: Có cần phân biệt từ vựng theo chủ đề (tag) không?**
   - *Quyết định:* Chưa cần ở giai đoạn này. Chỉ lọc theo `jlpt_level` và độ ưu tiên `review_count ASC` là đủ hiệu quả và đơn giản.

---

## 8. Definition of Done (DoD cho CONTEXT)

- [x] Phân tách rõ ràng bài toán cá nhân hóa từ vựng, không bị trộn lẫn với vector search sửa ngữ pháp.
- [x] Domain glossary rõ nghĩa, luồng nghiệp vụ xác định rõ ràng.
- [x] Đầy đủ ràng buộc kỹ thuật và nghiệp vụ.
- [x] Không còn câu hỏi mở tồn đọng.

---

## AI Agent Recommendation

- **Status:** PENDING HUMAN REVIEW
- **Scope:** Feature `feat-rag-vocab` — Context Discovery cho cá nhân hóa từ vựng.
- **Recommendation:**
  - Approve `CONTEXT.md` để tiến hành lập đặc tả `SPEC.md`.
  - Feature này có mức độ rủi ro cực thấp (Low Risk, Low Complexity), có thể triển khai và kiểm thử rất nhanh mà không đụng tới external vector database.
- **Evidence:**
  - Bảng `vocabulary` trong [backend/app/db/sqlite.py](file:///C:/Users/pc/Desktop/mikudayo/backend/app/db/sqlite.py) đã có sẵn trường `review_count`, `last_seen_at`.
  - [backend/app/repositories/vocab_repository.py](file:///C:/Users/pc/Desktop/mikudayo/backend/app/repositories/vocab_repository.py) đã có sẵn các hàm thao tác với vocabulary.
- **Risks and assumptions:**
  - Rủi ro duy nhất: Gemini có thể bỏ qua candidate nếu câu chuyện đi lệch chủ đề (đây là hành vi được chấp nhận để đảm bảo hội thoại tự nhiên).
- **Required human decision:** Phê duyệt CONTEXT.md để chuyển sang viết SPEC.md.

---

## Human Final Review

- **Status:** PENDING
- **Decision:** _leave empty until a human reviews_
- **Reviewer:** _leave empty until a human reviews_
- **Reviewed at:** _leave empty until a human reviews_
- **Follow-up:** /sdd-spec --feature=feat-rag-vocab
