"""RVC voice-conversion worker — chạy RIÊNG (port 8010).

Dùng model chuyển giọng để biến giọng VOICEVOX thành giọng Miku-like.

Yêu cầu môi trường:
- Python 3.10 (fairseq cũ không chạy trên 3.11) — venv riêng `.venv-rvc`.
- Đã cài: `pip install rvc-python fastapi uvicorn python-multipart`.

Chạy:
    backend\.venv-rvc\Scripts\python.exe backend\rvc_worker.py
    (hoặc uvicorn rvc_worker:app --host 127.0.0.1 --port 8010)

Model: đặt .pth (+ .index tuỳ chọn) trong backend/models/.
  - Model hiện tại: miku_mellow_rvc.pth + miku_mellow_rvc.index (giọng Miku mellow).
  - Đổi model: sửa MODEL_PATH / INDEX_PATH ở dưới, hoặc gửi `model` param trong
    POST /convert (tên file trong thư mục models).

API (khớp rvc_service.py của backend chính):
  GET  /health          -> {"status":"ok","model":"..."}
  POST /convert         multipart: file=<source.wav>, model=<tên model (mặc định)>
                        -> trả wav đã chuyển giọng (audio/wav)
"""
from __future__ import annotations

import io
import os
import sys
import time

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import Response

MODELS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")
MODEL_PATH = os.path.join(MODELS_DIR, "miku_mellow_rvc.pth")
INDEX_PATH = os.path.join(MODELS_DIR, "miku_mellow_rvc.index")
INDEX_PATH = INDEX_PATH if os.path.exists(INDEX_PATH) else ""


def _pick_device() -> str:
    """Tự chọn cuda:0 nếu có GPU, ngược lại cpu."""
    try:
        import torch

        return "cuda:0" if torch.cuda.is_available() else "cpu"
    except Exception:
        return "cpu"


DEVICE = os.environ.get("RVC_DEVICE", "") or _pick_device()

app = FastAPI(title="RVC worker", version="1.0")
_infer = None


def _get_infer():
    """Load RVCInference lười (lần gọi đầu), giữ warm."""
    global _infer
    if _infer is None:
        from rvc_python.infer import RVCInference

        print(f"[rvc] loading model: {MODEL_PATH} (device={DEVICE})", flush=True)
        t0 = time.time()
        _infer = RVCInference(device=DEVICE)
        _infer.load_model(MODEL_PATH, index_path=INDEX_PATH)
        # rmvpe không cần fairseq, tốt cho giọng nói + ổn định hơn harvest.
        _infer.f0method = "rmvpe"
        print(f"[rvc] model loaded in {time.time()-t0:.1f}s", flush=True)
    return _infer


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "model": os.path.basename(MODEL_PATH) if _infer else "not-loaded"}


@app.post("/convert")
async def convert(file: UploadFile = File(...), model: str = Form("")):
    data = await file.read()
    infer = _get_infer()

    in_path = os.path.join(MODELS_DIR, "_input.wav")
    out_path = os.path.join(MODELS_DIR, "_output.wav")
    with open(in_path, "wb") as f:
        f.write(data)

    t0 = time.time()
    infer.set_params(f0up_key=0, f0method="rmvpe")
    infer.infer_file(in_path, out_path)
    dt = time.time() - t0

    with open(out_path, "rb") as f:
        out = f.read()
    print(f"[rvc] convert OK: {len(data)} -> {len(out)} bytes in {dt:.2f}s", flush=True)
    return Response(content=out, media_type="audio/wav")
