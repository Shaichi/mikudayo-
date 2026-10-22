# Avatar Live2D (dùng cá nhân)

Renderer 2D chạy trong WebView (avatar duy nhất của app), giao thức JS
(`emotion`, `speech` + `mouth_cues`, thông báo `loaded`/`error`).

- `index.html` — PixiJS 6 + pixi-live2d-display 0.4.0 (Cubism 4/5), tự điều khiển tham số.
- `lib/live2dcubismcore.min.js` — Live2D Cubism Core (mã "Redistributable Code" theo license Live2D).
- `model/` — **không commit** (xem `.gitignore`). Tạo bằng script chuẩn bị model:
  copy file từ gói gốc "VTS Model File" và hạ texture 4096→2048.
  Gói gốc nằm ngoài repo: `C:\Users\pc\Desktop\mikudayo-private\miku2d\`.

## Giấy phép model (Miku "いますぐ輪廻", Ruby_呜哔うび & 慈善小霓)
Chỉ dùng cá nhân, phi thương mại. Cấm đăng lại/chia sẻ file model, cấm tách/trích asset,
cấm kiếm tiền. Nguồn chính thức: ko-fi.com/rubybee. Không phát hành APK chứa model này.
Miku là nhân vật của Crypton (PCL: phi thương mại, miễn phí).

## Ánh xạ biểu cảm (tham số Cubism)
neutral · happy(MouthForm,Blush) · excited(+Star) · thinking(Brow,AngleZ,EyeBallY) ·
embarrassed(Blush,sideBlush,han) · sad(MouthForm-,Tears,Gloom1). Miệng: `ParamMouthOpenY`.
Watermark của model bị tắt bằng tham số `Watermark`=1 (toggle S+Y của tác giả).
