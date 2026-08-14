"""FastAPI app — Miku Japanese Conversation backend.

Khởi động:  uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
(Khi test bằng điện thoại cùng LAN: --host 0.0.0.0 --port 8000)
"""
from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api import conversation, health, history
from .core.config import settings
from .core.logging import setup_logging
from .db.sqlite import init_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    init_db()
    yield


app = FastAPI(
    title=settings.APP_NAME,
    version="0.1.0",
    description="Backend luyện nói tiếng Nhật với trợ lý ảo — Phase 1 (text chat).",
    lifespan=lifespan,
)

# Cho phép Flutter (web/desktop) gọi local
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
