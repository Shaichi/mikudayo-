"""Cấu hình logging cho backend."""
from __future__ import annotations

import logging
import sys

from .config import settings


def setup_logging() -> None:
    level = logging.DEBUG if settings.DEBUG else logging.INFO
    handlers: list[logging.Handler] = [logging.StreamHandler(sys.stdout)]

    logging.basicConfig(
        level=level,
        format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        datefmt="%H:%M:%S",
        handlers=handlers,
    )
    # Giảm ồn từ thư viện bên ngoài
    for noisy in ("httpx", "httpcore", "uvicorn.access"):
        logging.getLogger(noisy).setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
