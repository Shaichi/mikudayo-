"""Cấu hình logging cho backend."""
from __future__ import annotations

import logging
import sys

from .config import settings


def setup_logging() -> None:
    level = logging.DEBUG if settings.DEBUG else logging.INFO
    # Dùng UTF-8 thay vì mặc định (Windows console cp1252 không in được tiếng
    # Việt/tiếng Nhật → tránh UnicodeEncodeError làm log rối).
    handler = logging.StreamHandler(sys.stdout)
    handler.setStream(sys.stdout)
    try:
        import io

        if sys.stdout is not None and hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        handler.stream = sys.stdout
    except Exception:
        pass

    logging.basicConfig(
        level=level,
        format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        datefmt="%H:%M:%S",
        handlers=[handler],
    )
    # Giảm ồn từ thư viện bên ngoài
    for noisy in ("httpx", "httpcore", "uvicorn.access"):
        logging.getLogger(noisy).setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
