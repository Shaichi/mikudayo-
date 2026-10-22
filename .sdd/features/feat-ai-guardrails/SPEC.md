# Feature Specification — `feat-ai-guardrails`

ID: `SPEC-feat-ai-guardrails`
Version: `0.1.0-draft`
Owner: `AI Agent & Human Director`
Approvers: `Human Director` (đồng ý bằng lời ngày 2026-10-21)
Risk: `MEDIUM` · Complexity: `MEDIUM` · Autonomy: `GUIDED`
Điều chỉnh: **thay thế phần truy xuất của `feat-rag-grammar` ở chế độ `correction`** (xem §1).

## 1. Bối cảnh và mục tiêu

Đo bằng `backend/tests/eval` (Gemini thật, 2026-10-21):

- RAG ngữ pháp trả **0 chunk** ở mọi ca. Độ tương đồng embedding của câu đúng và câu sai
  cùng nằm trong 0.54–0.68, thấp hơn ngưỡng 0.7 và không phân biệt được hai nhóm.
  Hạ ngưỡng chỉ đưa chunk sai chủ đề cho Gemini.
- Câu đúng `雨が降るから、傘を持ってください` vẫn bị "sửa" (ảo giác).
- Không có hậu kiểm đầu ra, không retry, 429 của Gemini thành 502.
- `scenario` do người dùng nhập được ghép thẳng vào system prompt.

Mục tiêu: chế độ correction chỉ sửa khi có lỗi được xác minh; mọi đầu ra qua hậu kiểm xác định;
lỗi nhà cung cấp được xử lý rõ ràng.

## 2. Yêu cầu (EARS)

| ID | Yêu cầu |
|---|---|
| R1 | Khi `mode=correction` và `AI_ERROR_DETECTION_ENABLED=true`, backend SHALL gọi bước phát hiện lỗi (temperature 0) trả `{has_error, error_type, quote}` trước khi sinh câu trả lời. |
| R2 | Khi bước phát hiện báo `has_error=false` hoặc thất bại, backend SHALL ép `correction_ja` và `explanation_vi` bằng null. |
| R3 | Khi `has_error=true`, backend SHALL tra chunk ngữ pháp theo `error_type` (bảng cố định, không dùng khoảng cách vector) và đưa chunk cùng `quote` vào prompt. |
| R4 | Bước phát hiện SHALL bỏ qua khác biệt do nhận dạng giọng nói (đồng âm, chọn kanji, dấu câu); chỉ báo lỗi ngữ pháp. |
| R5 | Guardrail SHALL: ép `difficulty` = level phiên; cắt reply quá 90 ký tự ở ranh giới câu; null correction trùng nguyên văn câu người học; null explanation khi không có correction; bỏ từ vựng không xuất hiện trong reply; bỏ gesture nếu lượt trước đã có gesture; null correction ngoài mode correction. |
| R6 | Khi reply không phải tiếng Nhật (tỉ lệ ký tự JA < 0.6) hoặc lộ nội dung prompt, backend SHALL sinh lại tối đa 1 lần kèm gợi ý lỗi; nếu vẫn lỗi SHALL dùng câu dự phòng cố định. |
| R7 | Khi Gemini trả JSON sai schema, backend SHALL thử lại 1 lần trước khi trả lỗi. |
| R8 | Khi Gemini trả 429, backend SHALL trả HTTP 503 kèm `Retry-After`, không trả 502. |
| R9 | `scenario` SHALL được chuẩn hóa (bỏ xuống dòng/ký tự điều khiển, cắt độ dài) và đặt trong prompt dưới nhãn dữ liệu không đáng tin. |
| R10 | Chế độ correction SHALL dùng temperature ≤ 0.3. |

## 3. Ngoài phạm vi

Đổi model, đổi TTS, avatar/Unity, UI Flutter.

## 4. Nghiệm thu

- `python -m unittest discover -s tests` xanh, có test offline cho guardrail và pipeline correction.
- `python -X utf8 -m tests.eval.run_eval`: `co-ok-*` không còn correction; `co-bad-*` có correction và explanation.
- Ghi số liệu trước/sau vào `HANDOFF.md`.
