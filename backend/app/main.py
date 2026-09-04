"""FastAPI app — Miku Japanese Conversation backend.

Khởi động:  uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
(Khi test bằng điện thoại cùng LAN: --host 0.0.0.0 --port 8000)
"""
from __future__ import annotations

import hmac
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware

from .api import conversation, health, history
from .core.config import settings
from .core.logging import setup_logging
from .db.sqlite import init_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    settings.validate()
    init_db()
    try:
        from .db.seed_grammar import seed_grammar
        seed_grammar()
    except Exception as exc:
        logger.warning("Không seed được grammar: %s", exc)
    conversation.cleanup_temp_audio()
    await conversation.recover_audio_jobs()
    try:
        yield
    finally:
        await conversation.shutdown_services()


app = FastAPI(
    title=settings.APP_NAME,
    version="0.1.0",
    description="Backend luyện nói tiếng Nhật với trợ lý ảo — Phase 1 (text chat).",
    lifespan=lifespan,
)

# The Flutter mobile client does not need CORS, but web/desktop clients do.
# Wildcard origins are only accepted in development and never with credentials.
app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.CORS_ORIGINS),
    allow_credentials=bool(settings.CORS_ORIGINS and "*" not in settings.CORS_ORIGINS),
    allow_methods=["*"],
    allow_headers=["*"],
)

if settings.TRUSTED_HOSTS and "*" not in settings.TRUSTED_HOSTS:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=list(settings.TRUSTED_HOSTS))


class SafetyMiddleware(BaseHTTPMiddleware):
    """Small dependency-free guard for request size, auth and local rate limits."""

    def __init__(self, app):
        super().__init__(app)
        self._hits: dict[str, list[float]] = {}

    @staticmethod
    def _client_key(request) -> str:
        # Do not trust X-Forwarded-For unless a trusted proxy is configured.
        return request.client.host if request.client else "unknown"

    @staticmethod
    def _provided_token(request) -> str:
        header = request.headers.get("authorization", "")
        if header.lower().startswith("bearer "):
            return header[7:].strip()
        return request.headers.get("x-api-key", "").strip()

    async def dispatch(self, request, call_next):
        request_id = request.headers.get("x-request-id", "").strip()[:100]
        if not request_id:
            request_id = f"req-{int(time.time() * 1000):x}"
        request.state.request_id = request_id

        if request.method != "OPTIONS":
            content_length = request.headers.get("content-length")
            try:
                too_large = content_length is not None and int(content_length) > settings.MAX_BODY_BYTES
            except ValueError:
                too_large = True
            if too_large:
                response = JSONResponse(status_code=413, content={"detail": "Request quá lớn."})
                response.headers["X-Request-ID"] = request_id
                return response

            if request.url.path.startswith("/v1") and settings.REQUIRE_AUTH:
                supplied = self._provided_token(request)
                if not settings.API_TOKEN or not hmac.compare_digest(supplied, settings.API_TOKEN):
                    response = JSONResponse(status_code=401, content={"detail": "Cần API token."})
                    response.headers["WWW-Authenticate"] = "Bearer"
                    response.headers["X-Request-ID"] = request_id
                    return response

            if (
                request.url.path.startswith("/v1")
                and not request.url.path.endswith("/status")
                and settings.RATE_LIMIT_REQUESTS > 0
            ):
                now = time.monotonic()
                key = self._client_key(request)
                recent = [
                    stamp for stamp in self._hits.get(key, [])
                    if now - stamp < settings.RATE_LIMIT_WINDOW_SECONDS
                ]
                if len(recent) >= settings.RATE_LIMIT_REQUESTS:
                    response = JSONResponse(status_code=429, content={"detail": "Quá nhiều yêu cầu."})
                    response.headers["Retry-After"] = str(settings.RATE_LIMIT_WINDOW_SECONDS)
                    response.headers["X-Request-ID"] = request_id
                    self._hits[key] = recent
                    return response
                recent.append(now)
                self._hits[key] = recent

        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response


app.add_middleware(SafetyMiddleware)

app.include_router(health.router)
app.include_router(conversation.router)
app.include_router(history.router)


@app.get("/")
def root() -> dict:
    return {
        "app": settings.APP_NAME,
        "docs": "/docs",
        "health": "/health",
        "input": "text-only",
    }
