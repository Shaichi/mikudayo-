# AGENTS.md — Scope guard cho sub-agent trong repository Miku Japanese Conversation

> File này giới hạn **path** và **tool** mà sub-agent / Agent tự động có
> thể chạm vào. Mọi thay đổi ngoài scope phải do Human Director review
> trước khi áp dụng.

## Scope được phép

### Backend (`backend/`)
- Sửa service, repository, schema khi binding đã approved.
- Chạy `python -m unittest discover -s tests -v`.
- Đọc/ghi `.env.example`, không đụng `backend/.env` thật.
- Cập nhật `BACKEND_GUIDE.md`, `backend/.env.example`, docstrings.

### Flutter (`lib/`, `test/`)
- Sửa UI / state / model / service.
- Chạy `flutter analyze && flutter test`.
- Cập nhật `pubspec.yaml` khi cần dependency (qua RFC nếu conflict).

### Avatar Live2D (`assets/web/live2d/`)
- Sửa `index.html` / `demo.html` (renderer WebView).
- Không commit `assets/web/live2d/model/` (license cấm phân phối lại).

## Scope bị cấm (trừ khi Human Director duyệt)

- `.env` thật, `tailscale-setup-*.msi`, `tailscale-setup-latest.exe`.
- `backend/data/`, `backend/temp/` (runtime SQLite / audio).
- `assets/web/live2d/model/` (private model).
- `.git/` (mọi thao tác phá huỷ).
- Xoá / reset / clean hàng loạt bất kỳ artifact nào.

## Tool restriction

- Bash: cấm `git reset --hard`, `git checkout -- <file>`, `git clean -fd`,
  `rm -rf` các thư mục scope bị cấm.
- Edit/Write: chỉ trong scope được phép. Mọi ngoài scope dừng tại
  `AI RECOMMENDATION: PENDING HUMAN REVIEW`.
- WebFetch / WebSearch: chỉ dùng cho URL thuộc `package:` pub.dev,
  `api.fish.audio`, Google AI docs, `flutter.dev`, `developer.android.com`,
  Live2D / pixi-live2d-display docs.

## Decision escalation

Mọi đề xuất thay đổi:
- `CONSTITUTION.md` → bắt buộc `/sdd-rfc --approve=<n>`.
- `architecture-profile.md` → `/sdd-review` sau khi Human Director review.
- Scope guard này → `/sdd-rfc` để sửa.

> Agent không tự sửa `AGENTS.md`.