# Architecture Profile — Miku Japanese Conversation (Brownfield)

> **PENDING HUMAN REVIEW** — Adoption của SDD + ADD cho repository có sẵn.
> Stack phát hiện dưới đây từ evidence rõ ràng của repo (manifest, lockfile, source, config).
> Không có `--stack` flag, không có profile được approved trước, không có CONSTITUTION.md.
> Mọi thay đổi profile phải do Human Director/Tech Lead review.

---

## 1. Tổng quan hệ thống

Hệ thống gồm 3 tiến trình/artefact riêng biệt:

1. **Flutter app (mobile-first)** — UI, mic recognizer, audio playback, điều khiển Unity.
2. **FastAPI backend** — orchestration, Gemini, Fish Audio proxy, SQLite, lipsync.
3. **Unity 6000.3.3f1 native module** — VRM 1.0 avatar, gesture VRMA, idle pool, blend shapes.

Pipeline thời gian thực:

```
Mic Android (Google SpeechRecognizer) → transcript text
  → Flutter ApiService (form-encoded POST)
  → FastAPI /v1/conversation/turn
    → Gemini structured JSON (synchronous)
    → SQLite (write turn + vocabulary)
    → BackgroundTask → Fish Audio REST (httpx)
    → WAV/MP3 preroll + RMS mouth cues (lipsync_service)
  → Poll /v1/audio/{turn_id}/status
  → just_audio playback + sendToUnity(PlayMouthCues|SetEmotion|PlayGesture)
```

Quyết định đã chốt với chủ dự án (xem `CLAUDE.md`, `HANDOFF.md`):
- TTS = **Fish Audio online only** (không model local, không CUDA, không RVC).
- Android = **Google SpeechRecognizer, không upload audio**.
- Mouth cues = WAV RMS (MP3/Opus trả mảng rỗng).
- Avatar = **portrait, không resize khi bàn phím mở**.

---

## 2. Runtime & framework

### 2.1 Python backend

| Item | Evidence | Confidence | Conflict |
|---|---|---|---|
| Runtime Python | `backend/pyproject.toml` `requires-python = ">=3.10"`; `START_BACKEND.cmd` dùng `hermes-agent\venv\Scripts\python.exe` (venv local) | HIGH | None |
| Web framework | `backend/requirements.txt` `fastapi>=0.115`, `uvicorn[standard]>=0.32`; `backend/app/main.py` `from fastapi import FastAPI` | HIGH | None |
| ASGI server | `uvicorn[standard]` + `START_BACKEND.cmd` chạy `python -m uvicorn app.main:app --host 0.0.0.0 --port 8000` | HIGH | None |
| Gemini SDK | `google-genai>=1.0` (`backend/app/services/gemini_service.py`: `from google import genai`; `from google.genai import types`) | HIGH | None |
| HTTP client | `httpx>=0.27` (`fish_audio_service.py`: `httpx.AsyncClient`) | HIGH | None |
| Validation | `pydantic>=2.8` (`schemas/conversation.py`, `services/gemini_service.py` dùng `ValidationError`, `model_validate_json`) | HIGH | None |
| Config loader | `python-dotenv>=1.0` (`core/config.py`: `load_dotenv`) | HIGH | None |
| Multipart | `python-multipart>=0.0.9` (FastAPI `Form(...)` parameters) | HIGH | None |

PENDING HUMAN REVIEW:
- Không có ASGI worker manager (gunicorn/uvicorn-workers) — chỉ 1 process qua `START_BACKEND.cmd`. Single-instance là intentional cho local LAN/Tailscale demo.
- Không có reverse proxy / TLS terminator được định nghĩa trong repo.

### 2.2 Flutter app

| Item | Evidence | Confidence | Conflict |
|---|---|---|---|
| Dart SDK | `pubspec.yaml` `sdk: ^3.11.5` | HIGH | None |
| Flutter | `flutter:` section trong `pubspec.yaml`; `.flutter-plugins-dependencies` | HIGH | None |
| State management | `flutter_riverpod: ^2.6.1`; providers: `avatarControllerProvider` (Notifier), `appSettingsProvider` (Notifier), `apiServiceProvider` (Provider), `settingsRepositoryProvider`, `speechRecognitionServiceProvider` | HIGH | None |
| HTTP | `http: ^1.6.0`; `lib/data/services/api_service.dart` dùng `http.Client` | HIGH | None |
| Local persistence | `shared_preferences: ^2.5.5`; `lib/data/repositories/settings_repository.dart` | HIGH | None |
| Speech-to-text | `speech_to_text: ^7.4.0`; `lib/data/services/speech_recognition_service.dart`; locale hardcoded `ja-JP` | HIGH | None |
| Audio playback | `just_audio: ^0.10.6`; `lib/data/services/audio_service.dart` | HIGH | None |
| WebView (desktop VRM) | `webview_flutter: ^4.14.1`, `webview_windows: ^0.4.0`; `lib/avatar/vrm_avatar.dart` | HIGH | None |
| Unity bridge | `flutter_embed_unity: 2.0.0`, `flutter_embed_unity_6000_0_android: 2.0.0` | HIGH | None |
| Lint | `analysis_options.yaml` include `package:flutter_lints/flutter.yaml`; `flutter_lints: ^6.0.0` (dev) | HIGH | None |
| Routing | Hardcoded route constants trong `lib/app/router.dart` (`MikuRouter`); `MaterialApp.home = HomeScreen()` trong `app/app.dart` (không dùng Navigator named routes) | MEDIUM | None |
| Navigator | `MaterialApp` mặc định (không dùng go_router, auto_route) | HIGH | None |

PENDING HUMAN REVIEW:
- Không dùng code generation (freezed/json_serializable) — model JSON là hand-written (`conversation_turn.dart`, `session_record.dart`, `vocabulary_record.dart`).

### 2.3 Unity (avatar)

| Item | Evidence | Confidence | Conflict |
|---|---|---|---|
| Editor version | `unity/MikuAvatar/ProjectSettings/ProjectVersion.txt` `6000.3.3f1`; `START_BACKEND.cmd` không khởi động Unity nhưng `HANDOFF.md mục 7` dùng `D:\Unity\Hub\Editor\6000.3.3f1\Editor\Unity.exe` | HIGH | None |
| Render pipeline | `Packages/manifest.json` `com.unity.render-pipelines.universal: 17.3.0`; `ProjectSettings/URPProjectSettings.asset`; `unity/README.md` cảnh báo "do not convert this project to URP" — README đã lỗi thời so với manifest thực tế | MEDIUM | **CONFLICT:** `unity/README.md` line 24–25 nói Built-in, manifest dùng URP 17.3.0. Cần confirm. |
| ChatDollKit | `Assets/ChatdollKit/Scripts/Model` (vendored copy v0.8.16, Apache-2.0) | HIGH | None |
| UniVRM | `com.vrmc.gltf` + `com.vrmc.vrm` từ `vrm-c/UniVRM.git v0.127.2` (MIT) | HIGH | None |
| UniTask | `com.cysharp.unitask` 2.5.4 (MIT) | HIGH | None |
| uLipSync | `com.hecomi.ulipsync` v3.1.0 (MIT) — không còn dùng trong MikuAvatar runtime, thay bằng Fish Audio mouth cues từ backend | MEDIUM | None |
| Gesture clips | `Assets/Mikudayo/Resources/vrma_gestures/{wave,clap,thinking,sad,surprise,nod}.vrma.bytes` (TextAsset) — clip VRMA từ `tk256ailab/vrm-viewer` (MIT, đổi tên `*.bytes`) | HIGH | None |
| Build target | Android (qua `MikuProjectSetup.PrepareEmbeddedScene` + `ProjectExporterBatchmode.ExportProject`); ARM64-only (`android/app/build.gradle.kts` `abiFilters += "arm64-v8a"`) | HIGH | None |
| Android NDK | `ndkVersion = "27.2.12479018"` (cố định trong `build.gradle.kts`) | HIGH | HANDOFF.md §10 lưu ý speech_to_text và jni muốn `28.2.13676358` — đã chốt KHÔNG đổi. |
| `minSdk` / `compileSdk` | `minSdk = 25`; `compileSdk = flutter.compileSdkVersion`; `targetSdk = flutter.targetSdkVersion` | HIGH | None |
| Java/Kotlin | JavaVersion.VERSION_17 + Kotlin JVM target 17 | HIGH | None |

---

## 3. Persistence

| Item | Evidence | Confidence | Conflict |
|---|---|---|---|
| Database | SQLite (`backend/app/db/sqlite.py`); WAL mode + `busy_timeout`; `PRAGMA foreign_keys = ON` | HIGH | None |
| Schema location | `_SCHEMA` string trong `db/sqlite.py`; migrations additive qua `_migrate` (`ALTER TABLE turns ADD COLUMN ...`) | HIGH | None |
| Migrations | Additive only, restart-safe, không dùng Alembic | HIGH | None |
| Data dir | `backend/data/` (gitignored); `backend/.env` `DATA_DIR=./data` | HIGH | None |
| Tables | `sessions`, `turns`, `vocabulary`, `turn_vocabulary`, `settings` | HIGH | None |
| ORM | **Không dùng ORM.** Truy vấn SQL thuần qua `sqlite3` stdlib | HIGH | None |
| Connection pattern | Short-lived connection per repo call (`get_conn()` context manager) | HIGH | None |
| Audio storage | `backend/temp/` (gitignored), `TEMP_TTL_SECONDS=3600` mặc định; `cleanup_temp_audio()` xóa file hết hạn | HIGH | None |
| Idempotency | `turns.client_request_id UNIQUE`; unique index partial `WHERE client_request_id IS NOT NULL` (best-effort nếu DB cũ có dup) | HIGH | None |
| Transaction mode | `get_conn(immediate=True)` cho write (BEGIN IMMEDIATE) | HIGH | None |

PENDING HUMAN REVIEW:
- Schema không có version table → không thể biết migration nào đã apply. Hiện tại additive migrations là đủ nhưng khi schema phình to nên thêm `schema_version`.
- WAL + busy_timeout ổn cho 1 process; concurrent writers (nếu scale) sẽ cần review.

---

## 4. Validation & API contract

| Item | Evidence | Confidence | Conflict |
|---|---|---|---|
| Request validation | Pydantic v2 (`schemas/conversation.py` `BaseModel` + `Field(min_length, max_length, ge, le)`) | HIGH | None |
| Form params | FastAPI `Form(default=...)` cho `text`, `mode`, `jlpt_level`, `scenario`, `session_id`, `client_request_id` | HIGH | None |
| Gemini structured output | `response_schema` (JSON schema dict, không phải Pydantic class) trong `gemini_service.py` `GenerateContentConfig` | HIGH | None |
| Gemini output validation | `GeminiTurnOutput.model_validate(data)` bắt `ValidationError` → trả 502 | HIGH | None |
| Gesture/Emotion enums | `Literal["none","wave","nod","clap","sad","thinking","surprise"]` (gesture); `Literal["neutral","happy","excited","thinking","embarrassed","sad"]` (emotion) | HIGH | None |
| Audio MIME types | `_MEDIA_TYPES = {wav, mp3, opus, pcm}` | HIGH | None |
| Dart parsing | Hand-written `fromJson` (không dùng freezed/json_serializable) | HIGH | None |

PENDING HUMAN REVIEW:
- Schema `nullable: True` cho `correction_ja` / `explanation_vi` được yêu cầu bởi Gemini API (ghi chú trong `gemini_service.py`) — đây là quirk đã document.

---

## 5. Auth, safety, resource limits

| Item | Evidence | Confidence | Conflict |
|---|---|---|---|
| Auth | `SafetyMiddleware` so sánh `Authorization: Bearer <token>` hoặc `X-API-Key` bằng `hmac.compare_digest` | HIGH | None |
| CORS | `CORSMiddleware` với `allow_origins` từ env; wildcard chỉ khi `ENVIRONMENT in {development, test}` | HIGH | None |
| Trusted hosts | `TrustedHostMiddleware` khi `TRUSTED_HOSTS` cổ đặt (không chứa `*`) | HIGH | None |
| Body size cap | `MAX_BODY_BYTES=65536` (64 KB) → trả 413 | HIGH | None |
| Rate limit | In-process per-IP counter (`SafetyMiddleware._hits`), 60 req / 60 s mặc định, trừ `/v1/.../status` | HIGH | None |
| Request ID | `X-Request-ID` echo + tự sinh | HIGH | None |
| Audio concurrency | `asyncio.Semaphore(AUDIO_MAX_CONCURRENCY=2)` | HIGH | None |
| Audio stale | `AUDIO_STALE_SECONDS=300`; `recover_audio_jobs` requeue job pending sau restart | HIGH | None |
| Production guard | `Settings.validate()` raises nếu production thiếu `API_TOKEN`/`FISH_API_KEY`/`TRUSTED_HOSTS` hoặc có `ALLOW_MOCK=true` | HIGH | None |

PENDING HUMAN REVIEW:
- Rate-limit state in-memory sẽ mất khi restart process; chấp nhận cho single-instance.
- `API_TOKEN` flat string — không có rotation/JWT/role-based. Đủ cho demo LAN/Tailscale; không đủ cho public deployment.

---

## 6. Testing

| Item | Evidence | Confidence | Conflict |
|---|---|---|---|
| Backend test runner | `python -m unittest discover -s tests -v` (`HANDOFF.md` + `CLAUDE.md`) | HIGH | None |
| Backend tests | `backend/tests/test_backend_hardening.py`, `test_conversation_contract.py`, `test_fish_audio_service.py`, `test_gesture_schema.py` | HIGH | None |
| Flutter test runner | `flutter analyze && flutter test` (`CLAUDE.md`) | HIGH | None |
| Flutter tests | `test/widget_test.dart`, `api_service_live_test.dart` (live backend), `avatar_gesture_test.dart`, `conversation_audio_status_test.dart`, `gesture_trigger_test.dart`, `speech_transcript_assembler_test.dart`, `ui_golden_test.dart` (goldens) | HIGH | None |
| Goldens | `test/goldens/` | HIGH | None |
| CI | Không có `.github/workflows` hoặc CI config nào trong repo | HIGH | None |
| Coverage config | Không có (`coverage/` đã gitignore) | HIGH | None |

PENDING HUMAN REVIEW:
- Một số test có tên `*_live_test.dart` yêu cầu backend đang chạy tại `127.0.0.1:8000`. Cần tag/filter rõ để CI có thể skip.
- Golden tests đang được commit — sẽ cần update khi UI thay đổi.

---

## 7. Build & lint commands

| Item | Evidence | Confidence | Conflict |
|---|---|---|---|
| Backend run | `START_BACKEND.cmd` (chạy uvicorn) hoặc `python -m uvicorn app.main:app --host 0.0.0.0 --port 8000` | HIGH | None |
| Backend venv priority | `C:\Users\pc\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe`; fallback `backend\.venv\Scripts\python.exe` | HIGH | None |
| Backend install | `python -m venv .venv && .venv\Scripts\python.exe -m pip install -r requirements.txt` (`BACKEND_GUIDE.md §2`) | HIGH | None |
| Backend test | `python -m unittest discover -s tests -v` (`BACKEND_GUIDE.md`, `CLAUDE.md`) | HIGH | None |
| Flutter deps | `flutter pub get` | HIGH | None |
| Flutter analyze | `flutter analyze` | HIGH | None |
| Flutter test | `flutter test` | HIGH | None |
| Flutter build APK | `flutter build apk --debug` (`HANDOFF.md §8`); APK ở `build/app/outputs/flutter-apk/app-debug.apk` | HIGH | None |
| Unity prepare | `Unity.exe -batchmode -nographics -buildTarget Android -projectPath ... -executeMethod Mikudayo.Avatar.Editor.MikuProjectSetup.PrepareEmbeddedScene -quit` (`HANDOFF.md §7`) | HIGH | None |
| Unity export | `Unity.exe ... -executeMethod ProjectExporterBatchmode.ExportProject -exportPath .../android_room/android/unityLibrary -quit` | HIGH | None |
| Lint (backend) | Không có linter riêng (`pyproject.toml` chỉ có setuptools config) | HIGH | None |

PENDING HUMAN REVIEW:
- Không có `Makefile`, `taskfile`, hay script chuẩn hoá cross-platform. Mỗi contributor phải nhớ lệnh từ HANDOFF.md.

---

## 8. Source layout (binding cho adoption)

### 8.1 Backend (Clean Architecture-ish)

```
backend/
  app/
    main.py                  FastAPI app, SafetyMiddleware, lifespan
    core/
      config.py              Settings (env-driven, validated)
      logging.py             setup_logging, get_logger
    api/
      conversation.py        POST /v1/conversation/turn, /v1/audio/...
      health.py              /health, /health/live
      history.py             /v1/sessions, /v1/vocabulary
    services/                Use cases (GeminiService, FishAudioService, compute_mouth_cues)
    schemas/                 Pydantic models = public contract
    repositories/            SQL adapters (conversation_repository, vocab_repository)
    db/
      sqlite.py              Connection + additive migrations
  tests/                     unitttest only
```

Layering đã có:
- API ↔ Services ↔ Repositories ↔ DB
- Schemas là boundary contract (Pydantic) cho cả input và output Gemini

PENDING HUMAN REVIEW:
- `api/conversation.py` orchestrates cả Services + Repositories + Audio lifecycle; có dấu hiệu "fat controller". Vẫn chấp nhận được vì scope MVP, nhưng nếu mở rộng nên tách UseCase layer.

### 8.2 Flutter (feature-first với data/avatar/app/core)

```
lib/
  main.dart                 Portrait lock, ProviderScope bootstrap
  app/
    app.dart                MaterialApp root
    router.dart             Route constants (không dùng named routes)
    theme.dart              MikuTheme
  avatar/
    avatar_controller.dart  Riverpod Notifier (emotion/gesture/speech state)
    unity_avatar.dart       flutter_embed_unity bridge
    vrm_avatar.dart         WebView + three-vrm (desktop fallback)
    live2d_bridge.dart      Noop/impl interface
    asset_http_server.dart  Local HTTP loopback cho VRM assets
  core/
    config/server_config.dart
    errors/api_exception.dart
  data/
    models/                 Hand-written DTOs
    repositories/           settings_repository.dart (SharedPreferences)
    services/               api_service.dart, speech_recognition_service.dart, audio_service.dart
  features/
    home/                   HomeScreen
    conversation/           conversation_screen.dart + conversation_view_model.dart
    history/                history_screen.dart
    vocabulary/             vocabulary_screen.dart
    settings/               settings_screen.dart
test/
  ...                       unit + widget + golden
```

PENDING HUMAN REVIEW:
- `data/services/speech_recognition_service.dart` chứa cả SpeechToText wrapper + `TranscriptAssembler` — đã viết test riêng cho assembler nhưng file mix concern.
- `features/conversation/conversation_view_model.dart` + `conversation_screen.dart` quá lớn (15K + 30K bytes). Khi thêm phase mới cần tách.

### 8.3 Unity (`Assets/Mikudayo/Runtime` + `Editor`)

```
Assets/Mikudayo/
  Runtime/
    MikuAvatarBridge.cs        Flutter ↔ Unity bridge (PlayGesture/StopGesture/SetEmotion/PlayMouthCues)
    MikuAvatarAutoDemo.cs       Auto-cycle demo trong Editor
    MikuAvatarSmokeCapture.cs   Smoke capture helper
    MikuGestureController.cs    Phát VRMA clips với fade in/out
    MikuIdlePool.cs            Idle biến thể + head glance (LateUpdate 10500)
    MikuRelaxedPose.cs         Pose mặc định (execution order 10000)
    MikuNaturalGestureController.cs
    MikuCameraFramer.cs        distanceMultiplier = 0.68f
    Vrm10/                      Adapt UniVRM 0.x → VRM 1.0
  Editor/
    MikuProjectSetup.cs         PrepareEmbeddedScene batchmode
    MikuGestureCaptureBuild.cs  Editor build helper
  Resources/
    vrma_gestures/*.vrma.bytes  Wave, clap, thinking, sad, surprise, nod
  Scenes/
    MikuAvatar.unity            Active scene
  Models/                       Private (gitignored), Miku.vrm
  Backgrounds/                  URP environment assets
  Rendering/                    URP asset config
```

---

## 9. CI / DevOps

| Item | Evidence | Confidence | Conflict |
|---|---|---|---|
| CI | Không có `.github/workflows`, `.circleci`, `azure-pipelines.yml`, hay `Jenkinsfile` | HIGH | None |
| Docker | Không có `Dockerfile`, `docker-compose.yml` cho backend | HIGH | None |
| Linting backend | Không có (black/ruff/mypy config) | HIGH | None |
| Pre-commit | Không có `.pre-commit-config.yaml` | HIGH | None |

PENDING HUMAN REVIEW:
- Mọi verification hiện là manual (`flutter analyze`, `python -m unittest`, ADB install).
- Khi bật automation, cần workspace Windows runner (Unity 6000.3.3f1 + Android SDK + NDK + Flutter).

---

## 10. Cross-cutting contracts

1. **Audio format pipeline:**
   - Backend `FishAudioService.audio_format` ∈ {wav, mp3, opus, pcm}.
   - WAV → `add_wav_preroll` (PCM silence prepend) → `compute_mouth_cues` (RMS window 50ms, percentile 95 normalize).
   - MP3/Opus → mouth cues = `[]`.
   - Media type mapping trong `_MEDIA_TYPES`.

2. **Idempotency:**
   - `client_request_id` (≤100 chars) → `turns.client_request_id UNIQUE` (partial index).
   - Re-send cùng request_id trả lại turn đã lưu, audio URL rỗng nếu chưa có.

3. **Gesture pipeline:**
   - Gemini response `gesture` ∈ enum 7 giá trị.
   - `MikuGesture.fromApi` fallback về `none`.
   - `UnityAvatar._sync` gửi `PlayGesture {gesture}` / `StopGesture` qua `flutter_embed_unity`.
   - `MikuGestureController` load `*.vrma.bytes` từ `Resources/vrma_gestures/`; clip thiếu → log warning no-op.

4. **Avatar lifecycle:**
   - `WidgetsBindingObserver` resume → `_startHandshake()` ping `_bridgeObject='MikuAvatarBridge'`.
   - Handshake `ready`/`pong` → replay latest emotion/gesture/speech state.

5. **Portrait & keyboard contract:**
   - `lib/main.dart` `DeviceOrientation.portraitUp`.
   - `AndroidManifest.xml` `screenOrientation="portrait"` + `windowSoftInputMode="adjustNothing"`.
   - `Scaffold.resizeToAvoidBottomInset = false`; translate composer bằng `Matrix4.translationValues(0, -viewInsetsOf().bottom, 0)`.

---

## 11. PENDING HUMAN REVIEW — Tổng hợp

Mọi quyết định sau đây yêu cầu Human Director/Tech Lead review trước khi chốt:

1. **Conflict render pipeline:** `unity/README.md` nói Built-in RP; manifest thực tế cài URP 17.3.0. Cần quyết định: (a) update README cho khớp manifest, hoặc (b) thực sự revert về Built-in.
2. **Single-instance backend:** chấp nhận cho demo LAN/Tailscale; nếu production hoá cần ASGI worker + reverse proxy + TLS.
3. **Auth:** flat `API_TOKEN` không đủ cho public deployment; cần JWT/session/role-based nếu mở rộng.
4. **CI:** chưa có automation. Cần workspace có Unity 6000.3.3f1 + Android SDK + NDK + Flutter.
5. **Schema migrations:** không có version table; chấp nhận cho MVP.
6. **Routing:** `MikuRouter` chỉ là constants; `MaterialApp.home = HomeScreen()` không dùng named routing — phù hợp với app hiện tại (chỉ 5 màn điều hướng qua `Navigator.push`).
7. **Fat controllers:** `api/conversation.py` và `conversation_view_model.dart` lớn; cần tách khi phase mới mở rộng.
8. **Tailscale installers:** `tailscale-setup-1.102.2-amd64.msi`, `tailscale-setup-latest.exe` đang ở root, không phải source app — quyết định: xoá / ignore / giữ trong `.gitignore`.
9. **Conversation context length:** `GEMINI_MAX_TURNS=8` là heuristic; cần user-facing setting hoặc token-based truncation.
10. **Mock Gemini/Fish:** `ALLOW_MOCK=true` chỉ dùng development; production validate đã chặn nhưng cần document cho release checklist.

---

## 12. Stack binding (tóm tắt một dòng)

`FastAPI + Pydantic v2 + SQLite + google-genai + httpx + Riverpod 2 + http + just_audio + speech_to_text + flutter_embed_unity + Unity 6000.3.3f1 (URP 17.3.0) + UniVRM 0.127.2 + ChatDollKit 0.8.16 (vendored) + UniTask + VRMA clips`

Không có profile approved trước, không có `--stack` flag → binding theo **repository evidence rõ ràng** (độ ưu tiên cao nhất trong sdd-adopt). Mọi conflict ở §11 phải resolve trước khi chuyển sang pha spec/plan.