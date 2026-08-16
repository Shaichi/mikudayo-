# Thiết kế: Cử động & gesture cho avatar Miku (Android/Unity)

> Ngày: 2026-08-16 · Trạng thái: đã duyệt bởi chủ dự án · Phạm vi: **chỉ Android/Unity**

## 1. Mục tiêu

Avatar Miku hiện chỉ có: biểu cảm gương mặt theo emotion, nháy mắt, lip-sync
viseme, và idle thủ tục nhẹ (`MikuRelaxedPose`). Mục tiêu của thiết kế này là
thêm hai nhóm cử động:

1. **Idle đa dạng hơn** — đổi thế tay/thân ngẫu nhiên, head-gaze nhẹ, để Miku
   đỡ đơ khi chờ.
2. **Phản ứng theo sự kiện** — gesture thân/tay theo ngữ cảnh: vẫy tay khi
   chào, vỗ tay khi vui, chống cằm khi chờ giọng nói, cúi đầu khi buồn...

Không làm: desktop/web (`VrmAvatar`), audio microphone, thay đổi camera/framing.

## 2. Kiến trúc tổng thể

```text
Gemini ──(reply, emotion, gesture mới)──> FastAPI ──> Flutter
                                                        │
   Sự kiện app: mở hội thoại → wave                     │
              chờ TTS → thinking pose                   ▼
                                              UnitySendMessage
                                        "PlayGesture" / "StopGesture"
                                                        │
                                                        ▼
                                   MikuAvatarBridge.PlayGesture
                                                        │
                          ┌─────────────────────────────┼───────────────┐
                          ▼                             ▼               ▼
                 VRMA clip (VRoid/BOOTH)     Idle pool procedural    MikuRelaxedPose
                 wave, clap, sad, thinking   (đổi thế tay ngẫu        (thở/lắc đầu
                 phát qua UniVRM, blend      nhiên + head-gaze)       — giữ nguyên)
```

Nguyên tắc xếp chồng:

- `MikuRelaxedPose` (thở, lắc/ nghiêng đầu, đung đưa thân) **giữ nguyên làm
  lớp nền**, chạy mọi lúc, không sửa hành vi hiện tại.
- Component mới `MikuGestureController` xếp chồng lên lớp nền: khi có gesture
  thì fade-in clip, phát, fade-out về idle.
- Gesture phải nằm gọn trong khung dọc hiện tại (mặt → đùi): tay cử động
  trước ngực/eo, không vung rộng, không di chuyển chân.

## 3. Nguồn animation: VRMA (không dùng Mixamo)

Lý do chọn VRMA thay vì Mixamo (đã bàn và chốt với chủ dự án):

- VRMA là định dạng animation chuẩn của hệ VRM — khớp trực tiếp humanoid của
  model Miku, **không cần retarget** (Mixamo phải qua Humanoid retarget và dễ
  lệch vai/khuỷu).
- UniVRM (đã có sẵn trong project Unity) import `.vrma` native, không cài thêm.
- Không phụ thuộc tài khoản Adobe; Mixamo đang bị Adobe bỏ dần.
- Lịch sử dự án đã từng thử làm tay procedural IK rồi revert (log 27-29) —
  clip có mocap thật giảm rủi ro này cho cử động tay/thân.

Nguồn file miễn phí đã khảo sát (phải kiểm tra terms từng file trước khi dùng;
file cấm thương mại/giới hạn thì loại):

- VRoid official: 7 `.vrma` miễn phí trên BOOTH (credit: ピクシブ株式会社
  VRoidプロジェクト).
- Bộ sample tham khảo chứa đúng các động tác cần: `Goodbye` (vẫy tay),
  `Clapping`, `Thinking`, `Sad`, `LookAround`, `Relax`, `Surprised`
  (github.com/tk256ailab/vrm-viewer).

Danh sách gesture dự kiến (tên lệnh ↔ nguồn clip có thể đổi khi import):

| Tên lệnh | Động tác | Trigger chính |
|---|---|---|
| `wave` | vẫy tay chào | mở hội thoại / câu chào |
| `clap` | vỗ tay nhỏ | emotion happy/excited |
| `sad` | cúi/đầu ủ rũ | emotion sad |
| `thinking` | chống cằm/nghiêng đầu | chờ Fish Audio sinh giọng |
| `surprise` | giật mình nhẹ | emotion surprised (nếu Gemini trả) |
| `nod` | gật đầu | Gemini chọn khi đồng ý |

## 4. Phía Unity

### 4.1 Asset

- Kéo các file `.vrma` đã chọn vào project (UniVRM import tự động).
- Clip nào chứa bước chân/di chuyển thì bỏ phần chân hoặc không dùng.
- Chỉ lấy track xương; track mặt của VRMA **không dùng** — biểu cảm + lip-sync
  vẫn đi đường riêng hiện có (`FaceController`, `Vrm10MouthCueDriver`).

### 4.2 `MikuGestureController.cs` (mới)

- Nắm `Vrm10Instance` của model.
- `Play(name)`: nạp clip VRMA, phát qua cơ chế VRM Animation của UniVRM,
  **blend weight 0→1 trong ~0.3s khi vào và 1→0 khi ra** (VRMA là full-body,
  phát thẳng sẽ đá bay lớp idle).
- `Stop()`: fade-out ngay về idle.
- Clip phát xong tự trả về; không dùng animator state machine phức tạp.

### 4.3 Idle đa dạng (mở rộng `MikuRelaxedPose`)

- Pool 3-4 thế tay/thân (tay buông, tay trước eo, chống cằm...) đổi ngẫu nhiên
  mỗi 8–20 giây, blend bằng `Quaternion.Slerp` chậm.
- Head-gaze: đầu thỉnh thoảng quay đi rồi quay lại camera (procedural, không
  dùng VRMA `LookAround` — rẻ hơn và lặp vô hạn).
- Biên độ nhỏ vì khung dọc zoom gần — cử động lớn đưa tay ra khỏi màn hình.
- Vẫn rebuild offset từ rest pose mỗi frame như hiện tại (không drift).

### 4.4 `MikuAvatarBridge.cs` — thêm 2 lệnh string

Giữ API chỉ-string hiện có (UnitySendMessage):

- `PlayGesture(string json)` — payload `{"gesture":"wave"}`.
- `StopGesture(string)` — cắt về idle.

### 4.5 Rủi ro & bước verify đầu tiên

UniVRM trong project phải hỗ trợ import VRMA ở **editor** (không chỉ runtime
load). Đây là **bước làm đầu tiên và verify riêng**: nếu phiên bản UniVRM quá
cũ, nâng UniVRM trước khi làm bất cứ gì khác — nâng UniVRM có thể ảnh hưởng
scene/export hiện tại nên phải test scene vẫn chạy sau khi nâng.

Fallback nếu VRMA không hoạt động: procedural cho từng gesture (chất lượng tay
kém hơn — đã từng bị revert trước đây, chỉ dùng khi không còn lựa chọn).

### 4.6 Build pipeline (như cũ)

Mọi asset + script mới phải vào scene Unity, rồi chạy prepare + export
(lệnh đầy đủ ở `HANDOFF.md` mục 7), sau đó mới build Flutter.

## 5. Phía Flutter

### 5.1 Model

`lib/data/models/conversation_turn.dart`: thêm enum `MikuGesture`
(`none, wave, nod, clap, sad, thinking, surprise`) + `fromApi` fallback `none`,
theo đúng pattern `MikuEmotion.fromApi`.

### 5.2 Bridge

- `lib/avatar/avatar_controller.dart`: thêm `playGesture` / `stopGesture` vào
  state.
- `lib/avatar/unity_avatar.dart`: gửi `UnitySendMessage("MikuAvatarBridge",
  "PlayGesture", jsonEncode({'gesture': ...}))` / `"StopGesture"`, theo pattern
  `_lastEmotion` hiện tại.
- `lib/avatar/live2d_bridge.dart` / desktop: nhận nhưng ignore (không đụng).

### 5.3 Logic kích hoạt (`conversation_view_model.dart`)

| Sự kiện | Gesture | Ghi chú |
|---|---|---|
| Mở hội thoại / câu chào đầu tiên | `wave` | phát 1 lần, không lặp |
| Bắt đầu chờ Fish Audio (`voice_mode=pending`) | `thinking` | |
| Nhận xong text+emotion mỗi lượt | `gesture` từ Gemini; nếu `none` → map emotion | gửi `StopGesture` trước khi phát audio mới để cắt `thinking` |

Map emotion fallback: `happy/excited → clap`, `sad → sad`,
`thinking → thinking`, còn lại → `none`.

### 5.4 Chống spam (logic nằm ở Flutter, Unity cứ nhận là phát)

- Đang có gesture chạy → bỏ qua lệnh mới (trừ `StopGesture`).
- Gesture lặp cùng loại liên tiếp → bỏ lượt thứ hai.

## 6. Phía Backend

### 6.1 Gemini prompt (`backend/app/services/gemini_service.py`)

- Thêm 1 dòng prompt: chọn `gesture` từ enum
  `[none, wave, nod, clap, sad, thinking, surprise]` theo ngữ cảnh câu trả lời
  (chào → wave, khen → clap, đồng ý → nod...), cho phép `none` để không lạm dụng.
- Schema JSON + `required` thêm `gesture`.
- Mock fallback (khi không có Gemini / `ALLOW_MOCK`) trả `gesture: none`.

### 6.2 API

- `backend/app/schemas/conversation.py`: response thêm trường `gesture: str`,
  default `"none"`.
- `backend/app/api/conversation.py`: pass-through từ kết quả Gemini.
- **Không lưu thêm cột DB** — gesture là hiệu ứng tức thời, không cần lịch sử.

## 7. Thứ tự thực hiện

1. **Unity: verify UniVRM đọc được VRMA ở editor** (rủi ro lớn nhất, làm trước,
   verify riêng, kể cả việc nâng UniVRM nếu cần).
2. Unity: `MikuGestureController` + 2 lệnh bridge + idle pool
   (`MikuRelaxedPose`) → chuẩn bị asset VRMA → prepare/export.
3. Flutter: enum + bridge + view model + map emotion.
4. Backend: thêm `gesture` vào Gemini prompt/schema + mock.
5. Build APK, cài máy thật (ADB `8a855606`), tune từng gesture bằng mắt.

## 8. Tiêu chí nghiệm thu (trên máy thật)

- Idle: thế tay/thân đổi được ít nhất 2 kiểu trong 30 giây chờ, không giật,
  không drift.
- Mở hội thoại: Miku vẫy tay 1 lần.
- Chờ TTS: chống cằm/nghiêng đầu cho tới khi có audio; audio về thì cắt mượt.
- Trả lời happy/excited: vỗ tay; sad: cúi đầu; các gesture không văng tay ra
  ngoài khung dọc.
- Sau vài lượt liên tiếp không crash, không kẹt pose.

## 9. Ngoài phạm vi

- Desktop/web `VrmAvatar`.
- Thêm gesture vượt quá danh sách mục 3 (sau này thêm clip là mở rộng được).
- Thay camera/framing, resize avatar, bất kỳ thay đổi nào đụng quy tắc cấm
  trong `CLAUDE.md`.
