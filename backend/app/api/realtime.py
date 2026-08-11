"""Phase 6 — Realtime scaffold (RESEARCH ONLY, theo mục 14.1 tài liệu).

Gemini Live hiện là Preview, dùng stateful WebSocket; audio input PCM 16-bit
16 kHz, output PCM 16-bit 24 kHz [S7][S24]. Push-to-talk vẫn là sản phẩm chính
(mục 14: "Realtime là experimental; chỉ merge nếu latency/ổn định tốt").

Module này chỉ là *khung* để thử sau khi MVP ổn định — không dùng trong sản
phẩm hiện tại. Hướng sẽ là:

    Flutter stream mic ──(WSS)──▶ FastAPI /v2/live ──(stateful WSS)──▶ Gemini Live
                                        │
                                        ▼
    RVC realtime ──(WSS PCM 24kHz)──▶ Flutter phát + lip-sync

Lưu ý:
- FastAPI WebSocket cần `pip install websockets` (thường đã có theo uvicorn[standard]).
- Không merge path này nếu latency (Gemini + TTS + RVC) chưa đạt < ~1s.
- Keep push-to-talk là mặc định; realtime là nhánh experimental riêng.
"""
from __future__ import annotations

import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v2", tags=["realtime"])

# PCM params theo tài liệu mục 14.1.
LIVE_INPUT_RATE = 16000
LIVE_OUTPUT_RATE = 24000
LIVE_INPUT_BYTES = LIVE_INPUT_RATE * 2  # PCM16 mono, ~1 giây buffer


@router.websocket("/live")
async def live(ws: WebSocket) -> None:
    """Khung realtime — hiện CHƯA có Gemini Live thật.

    Skeleton: nhận audio PCM từ Flutter, echo lại một phản hồi text test để
    xác nhận đường truyền WSS hoạt động. Khi triển khai thật, thay phần
    `await _echo(ws)` bằng một client Gemini Live stateful WebSocket.
    """
    await ws.accept()
    logger.info("Realtime WS connected")
    try:
        # Vòng lặp chính: nhận binary (PCM) hoặc text (event).
        while True:
            message = await ws.receive()
            if message["type"] == "websocket.disconnect":
                break
            if message["type"] == "websocket.receive":
                if "bytes" in message:
                    await _handle_pcm(ws, message["bytes"])
                else:
                    await _handle_event(ws, message.get("text", ""))
    except WebSocketDisconnect:
        logger.info("Realtime WS disconnected")
    except Exception as exc:  # noqa: BLE001 — giữ kết nối sống nếu 1 frame lỗi
        logger.warning("Realtime WS error: %s", exc)
    finally:
        try:
            await ws.close()
        except Exception:  # noqa: BLE001
            pass


async def _handle_pcm(ws: WebSocket, chunk: bytes) -> None:
    """Nhận chunk PCM 16 kHz → (tương lai) đẩy lên Gemini Live.

    Hiện chỉ đếm độ dài để test round-trip; không lưu raw audio.
    """
    n_frames = len(chunk) // 2
    logger.debug("PCM chunk: %d frames", n_frames)
    # Test round-trip: gửi lại một text acknowledgment (đủ để Flutter xác nhận WSS).
    await ws.send_json({"type": "pcm.ack", "frames": n_frames})


async def _handle_event(ws: WebSocket, text: str) -> None:
    """Xử lý event text từ Flutter (start/stop/keepalive)."""
    logger.debug("WS event: %s", text)
    await ws.send_json({"type": "event.ack", "event": text})
