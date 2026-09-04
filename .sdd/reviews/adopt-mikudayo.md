# Adoption Review — Miku Japanese Conversation (`adopt-mikudayo`)

> Tạo bởi skill `/sdd-adopt` ngày 2026-09-04.
> Theo `.claude/skills/_shared/ai-review-protocol.md`.
> Adoption **KHÔNG thay đổi source hiện có** — chỉ thêm `.sdd/` +
> `AGENTS.md`. Mọi quyết định dưới đây cần Human Final Review.

## AI Agent Recommendation

- **Status:** PENDING HUMAN REVIEW
- **Scope:** Adoption SDD + ADD cho repository Miku Japanese Conversation
  (Flutter + FastAPI + Unity 6000.3.3f1, VRM 1.0 avatar).
- **Recommendation:**
  - Approve `.sdd/architecture-profile.md` §1–§10 như ground truth
    (evidence HIGH confidence từ manifest, lockfile, source, HANDOFF.md,
    CLAUDE.md).
  - Resolve 10 PENDING HUMAN REVIEW items ở §11 trước khi chạy
    `/sdd-plan` cho bất kỳ feature nào.
  - Sau khi resolve, chuyển profile sang `Status: APPROVED` qua
    `/sdd-review`; skill downstream sẽ dùng binding đã chốt.
  - Reverse Spec (nếu cần) chỉ chạy khi chỉ rõ `--reverse-feature=<slug>`
    và `--path=<module-path>`; hiện chưa khoanh vùng module legacy.

- **Evidence:**
  - `backend/requirements.txt` — fastapi 0.115+, google-genai 1.0+, httpx
    0.27+, pydantic 2.8+.
  - `backend/app/services/gemini_service.py` — dùng `google.genai` SDK,
    structured schema JSON, fallback mock khi thiếu key.
  - `backend/app/services/fish_audio_service.py` — REST client Fish Audio
    `/v1/tts`, retry/backoff, MIME sniff, mock WAV.
  - `backend/app/db/sqlite.py` — sqlite3 stdlib, WAL, additive migrations.
  - `backend/app/main.py` — SafetyMiddleware (auth + body cap + rate limit).
  - `pubspec.yaml` — Riverpod 2.6.1, http 1.6.0, just_audio 0.10.6,
    speech_to_text 7.4.0, flutter_embed_unity 2.0.0, webview_flutter 4.14.1.
  - `android/app/src/main/AndroidManifest.xml` — portrait, adjustNothing,
    RECORD_AUDIO + INTERNET.
  - `unity/MikuAvatar/ProjectSettings/ProjectVersion.txt` — 6000.3.3f1.
  - `unity/MikuAvatar/Packages/manifest.json` — UniVRM 0.127.2,
    UniTask 2.5.4, URP 17.3.0 (XUNG ĐỘT với `unity/README.md` claim
    Built-in RP).
  - `unity/MikuAvatar/Assets/Mikudayo/Resources/vrma_gestures/*.vrma.bytes`
    — 6 clip (wave/clap/thinking/sad/surprise/nod).
  - `HANDOFF.md` + `CLAUDE.md` — đã chốt TTS = Fish Audio online, không
    local TTS/RVC/CUDA, không upload audio mic, locale `ja-JP` hardcode.

- **Risks and assumptions:**
  - **Conflict render pipeline:** `unity/README.md` nói Built-in RP, nhưng
    manifest thực tế cài URP 17.3.0 (xem `UniversalRenderPipelineGlobalSettings.asset`
    + `URPProjectSettings.asset`). Nếu cập nhật README sẽ khớp manifest;
    ngược lại cần revert URP.
  - **NDK pin:** `27.2.12479018` trong `android/app/build.gradle.kts`,
    HANDOFF.md §10 lưu ý không đổi khi chưa test Unity + Flutter cùng lúc.
  - **Single-instance backend:** rate-limit in-memory, không có
    ASGI worker manager. OK cho demo LAN/Tailscale, KHÔNG đủ cho public.
  - **Auth:** flat `API_TOKEN` không có rotation/JWT/role; production cần
    thay thế nếu mở rộng.
  - **Không có CI:** `.github/` không tồn tại; mọi verification là manual.
  - **Repository dirty:** HANDOFF.md §11 liệt kê nhiều file chưa commit
    + `tailscale-setup-*.msi/.exe` ở root — không được tự động dọn.
  - **Spec drift giữa README cũ và manifest thực tế** có thể lặp lại ở
    file tài liệu khác (CHANGELOG, BACKEND_GUIDE.md).

- **Alternatives considered:**
  - **Bỏ qua adoption, tiếp tục ad-hoc:** giữ status quo nhưng không có
    binding để gate SPEC/PLAN/TASKS. Bị loại vì HANDOFF đã có dấu hiệu
    drift (URP vs Built-in, NDK vs upstream).
  - **Adopt full RFC ngay để rewrite sang Clean Architecture:** scope quá
    lớn cho một adoption pass; source hiện đã có layering gần Clean
    (API → Service → Repo → DB; Flutter feature-first + Riverpod).
    Reverse Spec + RFC nên đi sau adoption này.
  - **Tự động detect stack qua `package.json` style file:** repo không
    có `package.json`; phải parse `pubspec.yaml` + `requirements.txt` +
    `Packages/manifest.json` + `ProjectVersion.txt`. Đã làm đúng cách.

- **Required human decision:**
  1. Approve các binding HIGH confidence trong `architecture-profile.md`
     §2–§6.
  2. Quyết định 10 PENDING items ở §11 (xem danh sách cụ thể dưới).
  3. Xác nhận scope guard trong `AGENTS.md` (path + tool cấm).
  4. (Tuỳ chọn) chỉ định module Reverse Spec đầu tiên (ví dụ
     `backend/app/services/fish_audio_service.py` hoặc
     `lib/features/conversation/conversation_view_model.dart`).

## Human Final Review

- **Status:** PENDING
- **Decision:** _leave empty until a human reviews_
- **Reviewer:** _leave empty until a human reviews_
- **Reviewed at:** _leave empty until a human reviews_
- **Follow-up:**
  - Nếu APPROVED: chuyển profile sang trạng thái APPROVED, đặt lịch
    `/sdd-context` cho feature đầu tiên.
  - Nếu REVISE: agent sẽ tạo recommendation mới với evidence bổ sung.
  - Nếu REJECTED: adoption bị huỷ; giữ `.sdd/` ở chế độ skeleton.

## PENDING HUMAN REVIEW — Danh sách cần quyết định

1. Render pipeline: update `unity/README.md` cho khớp URP 17.3.0
   (manifest + asset), hay revert URP về Built-in?
2. Có chấp nhận single-instance backend cho production / public release,
   hay yêu cầu ASGI worker + reverse proxy + TLS terminator?
3. Auth: giữ flat `API_TOKEN` cho demo LAN, hay nâng cấp lên JWT /
   session / role-based trước khi mở rộng?
4. CI/CD: có muốn thiết lập workspace Windows (Unity 6000.3.3f1 + Android
   SDK + NDK + Flutter) và GitHub Actions để chạy `flutter analyze`,
   `flutter test`, `python -m unittest`, hay giữ manual?
5. SQLite: giữ 1 file `miku.db` với WAL + busy_timeout, hay chuyển sang
   PostgreSQL/Postgres + Alembic khi scale?
6. Routing Flutter: giữ `MaterialApp.home + Navigator.push` với
   `MikuRouter` constants, hay migrate sang `go_router` named routes?
7. Tách `api/conversation.py` (fat controller) thành UseCase layer khi
   thêm phase mới, hay giữ MVP-level?
8. Dọn `tailscale-setup-*.msi/.exe` ở root: xoá, ignore vĩnh viễn, hay
   giữ ngoài source?
9. `GEMINI_MAX_TURNS=8` heuristic vs token-based truncation: cần user-
   facing setting hay auto theo model quota?
10. Release checklist cho production: document hóa `REQUIRE_AUTH=true`,
    `ALLOW_MOCK=false`, `FISH_API_KEY` + `TRUSTED_HOSTS` bắt buộc, voice
    license check.