# 🚀 HƯỚNG DẪN CHẠY BACKEND — Miku Japanese Conversation

Hướng dẫn chạy **backend FastAPI** (port 8000) và 2 engine giọng nói phụ trợ.
Dành cho máy Windows đã cài sẵn môi trường (Python 3.11, Flutter, Git).

---

## 1. Backend gồm những gì?

Backend không chỉ là 1 process — gồm **3 phần** chạy song song:

| # | Thành phần | Port | Chức năng | Khi thiếu |
|---|---|---|---|---|
| 1 | **Backend chính** (`app.main:app`) | `8000` | Nhận request từ app, gọi Gemini, Whisper, lưu SQLite, gọi TTS | App không kết nối được |
| 2 | **VOICEVOX** (app desktop) | `50021` | Đọc text thành giọng (TTS) | Fallback WAV beep, không nghe được tiếng |
| 3 | **RVC worker** (`rvc_worker:app`) | `8010` | Đổi giọng VOICEVOX thành giọng Miku | Fallback về giọng VOICEVOX gốc |

Pipeline đầy đủ khi chạy thật:

```
mic (Flutter) → POST /v1/conversation/turn ──▶ Whisper STT ──▶ Gemini (trả lời)
                                                                    │
                        wav giọng Miku ◀── RVC (8010) ◀── VOICEVOX ◀┘
```

---

## 2. Chạy Backend chính (port 8000)

### Bước 1 — Chuẩn bị `.env`

```bash
cd backend
copy .env.example .env        # Windows
# cp .env.example .env        # Linux/macOS
```

Sửa file `.env`:

- `GEMINI_API_KEY` → điền key từ [Google AI Studio](https://aistudio.google.com/apikey).
  Bỏ trống → **mock mode** (trả lời mẫu, không gọi Gemini thật).
- `GEMINI_MODEL` → mặc định `gemini-3.5-flash-lite` (text-only, nhanh/nhẹ). Xem mục 6.4.
- `WHISPER_MODEL` → `small` (~500MB) là vừa. Cân nhắc: `tiny` nhanh hơn nhưng kém chính xác hơn.

> ⚠️ **Tuyệt đối KHÔNG commit `.env`** lên Git — chứa API key. `.gitignore` đã chặn sẵn.

### Bước 2 — Cài dependencies

Trên máy này **không cần tạo venv riêng** (python chung của hermes/uv đã có sẵn `faster-whisper`).
Nếu máy khác / môi trường sạch:

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows
pip install -r requirements.txt
pip install faster-whisper    # STT (tải model lần đầu ~500MB, tự động)
```

### Bước 3 — Chạy

```bash
cd backend
# Backend chính PHẢI dùng hermes venv (có uvicorn):
"C:\Users\pc\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- `--host 0.0.0.0` → cho phép **điện thoại cùng Wi-Fi** kết nối (dùng IP máy). Chỉ muốn local: `--host 127.0.0.1`.
- **KHÔNG dùng `python` (PATH) hay uv `python.exe`** cho backend — môi trường đó **không có uvicorn** (lỗi `No module named uvicorn`). Backend chạy bằng **hermes venv**.
- **KHÔNG dùng `--reload`** — nó tạo 2 process song sinh (reloader cha + worker con) giữ cùng 1 port, lãng phí ~580MB RAM. Dừng hẳn rồi khởi động lại nếu sửa code.

### Bước 4 — Kiểm tra

```bash
curl http://127.0.0.1:8000/health
```

Kết quả mong đợi (3 engine thật):

```json
{"status":"ok","gemini":true,"voicevox":true,"rvc":true,"mode":"live","model":"gemini-3.5-flash-lite"}
```

- `"mode":"mock"` → chưa có GEMINI_API_KEY.
- `"voicevox":false` → VOICEVOX chưa mở (xem mục 3).
- `"rvc":false` → RVC worker chưa chạy (xem mục 4).

Test 1 lượt hội thoại bằng text (tiếng Nhật):

```bash
curl -X POST http://127.0.0.1:8000/v1/conversation/turn \
  -F "text=こんにちは" -F "mode=free_talk" -F "jlpt_level=N5"
```

> 💡 **Lưu ý curl + tiếng Nhật:** console Windows đôi khi gửi UTF-8 sai → trả reply lệch.
> Nếu nghi ngờ, test bằng Python:
> ```bash
> cd backend && PYTHONIOENCODING=utf-8 python -c "import requests,json; r=requests.post('http://127.0.0.1:8000/v1/conversation/turn',data={'mode':'free_talk','jlpt_level':'N5'},files={'text':(None,'こんにちは')},timeout=60); print(json.dumps(r.json(),ensure_ascii=False,indent=2))"
> ```

---

## 3. Chạy VOICEVOX (port 50021)

VOICEVOX là **app desktop riêng**, không phải lệnh backend:

1. Mở **VOICEVOX** (đã cài tại [voicevox.hiroshiba.jp](https://voicevox.hiroshiba.jp/)).
2. Đợi app load xong → tự mở engine ở `http://127.0.0.1:50021`.

Kiểm tra:

```bash
curl -sS -o /dev/null -w "VOICEVOX HTTP %{http_code}\n" http://127.0.0.1:50021/
# VOICEVOX HTTP 200
```

Đổi giọng nếu muốn: sửa `VOICEVOX_SPEAKER_ID` trong `.env` (mặc định `0`).

---

## 4. Chạy RVC worker (port 8010)

RVC cần **môi trường Python 3.10 riêng** (fairseq cũ không chạy trên 3.11).
Máy này đã có `.venv-rvc` sẵn.

```bash
cd backend
.venv-rvc\Scripts\python.exe -m uvicorn rvc_worker:app --host 127.0.0.1 --port 8010
```

> ⚠️ **Không chạy `python rvc_worker.py`** — file không có `__main__`, sẽ thoát im lặng.
> Phải qua uvicorn. **Không dùng `--reload`** (tránh 2 process cùng port 8010).
> Lần header đầu sau khi khởi động: `/health` báo `model:"not-loaded"` ~6s rồi
> `miku_mellow_rvc.pth`; convert đầu tiên ~24s (cold→warm), sau ~2.5s/lượt.

Nếu chưa có `.venv-rvc` (máy khác):

```bash
cd backend
python -m venv .venv-rvc      # Python 3.10 (kiểm tra: python3.10 --version)
.venv-rvc\Scripts\activate
pip install rvc-python fastapi uvicorn python-multipart
# Nếu omegaconf lỗi metadata → giới hạn: pip install "pip<=24.0" rồi cài lại
```

Model Miku đặt trong `backend/models/` (đã gitignore):

```
backend/models/
  miku_mellow_rvc.pth      # model chính
  miku_mellow_rvc.index    # tùy chọn
```

Kiểm tra:

```bash
curl http://127.0.0.1:8010/health
# {"status":"ok","model":"miku_mellow_rvc.pth"}
```

> 🧊 Lần convert đầu tiên chậm (~60s cold→warm vì load GPU). Sau đó ~2.5s/lượt.

---

## 5. Tóm tắt — Thứ tự khởi động gợi ý

| Thứ tự | Lệnh / Hành động | Port |
|---|---|---|
| 1 | Mở app **VOICEVOX** | 50021 |
| 2 | `cd backend && .venv-rvc\Scripts\python.exe -m uvicorn rvc_worker:app --host 127.0.0.1 --port 8010` | 8010 |
| 3 | `cd backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000` | 8000 |
| 4 | `curl http://127.0.0.1:8000/health` → cả 3 `true` | — |
| 5 | Mở app Flutter → **Cài đặt** → server URL → **Kiểm tra máy chủ** | — |

---

## 6. Troubleshooting

### 6.1 Lỗi `address already in use` port 8000
Có backend cũ chưa tắt (đặc biệt nếu từng chạy `--reload`). Kiểm tra + kill:

```powershell
# Xem process nào đang chiếm port 8000
Get-NetTCPConnection -LocalPort 8000 | Select-Object OwningProcess

# Kill process backend cũ (thay PID bằng số ở trên)
Stop-Process -Id <PID> -Force
```

Hoặc kill hết process `app.main:app`:
```powershell
Get-CimInstance Win32_Process | Where-Object {$_.CommandLine -match 'app.main:app'} | Stop-Process
```

### 6.2 Điện thoại không kết nối được backend
1. Backend phải chạy `--host 0.0.0.0` (mục 2.3).
2. App đặt server URL = `http://<IP máy>:8000` (xem IP: `ipconfig`, mục IPv4).
3. Cùng một **Wi-Fi**.
4. Windows Firewall cho phép port 8000 (chạy **PowerShell Administrator**):
   ```powershell
   New-NetFirewallRule -DisplayName "Miku Backend 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
   ```
5. Vẫn fail → tắt tạm Windows Firewall để test (bật lại sau).

### 6.3 Báo "Không nghe rõ bạn nói gì" (400)
- Whisper không transcribe được audio (quá nhỏ / rỗng / nhiễu).
- Nói gần mic hơn, chậm rãi, đủ tiếng.
- Kiểm tra model Whisper: `WHISPER_MODEL=small` trong `.env`, tải xong ~500MB.

### 6.4 Lỗi liên quan model Gemini
| Model | Vấn đề |
|---|---|
| `gemini-2.5-flash` | **404** với key mới |
| `gemini-3.5-flash-lite` | ✅ **Khuyến nghị** — text-only (nhanh/nhẹ/quota rộng). KHÔNG nhận audio → đã chuyển qua Whisper nên OK |
| `gemini-3-flash-preview` | Hỗ trợ audio nhưng **hết quota 20/ngày** (429) |

Đổi model trong `backend/.env` → `GEMINI_MODEL=...` → restart backend.

### 6.5 RVC worker thoát im lặng / lỗi model
- Chạy đúng cách: `.venv-rvc\Scripts\python.exe -m uvicorn rvc_worker:app --host 127.0.0.1 --port 8010`.
- Model phải nằm trong `backend/models/` (`miku_mellow_rvc.pth`).
- Convert fail → app tự fallback về giọng VOICEVOX gốc (`voice_mode:"rvc_fallback"`), không crash.

### 6.6 Push GitHub lỗi "Failed to connect github.com port 443"
Mạng chặn HTTP/2. Fix (đã set sẵn ở repo này):

```bash
git config http.version HTTP/1.1
```

### 6.7 Log tiếng Việt ra ký tự lạ / UnicodeEncodeError
Console Windows cp1252 không in được tiếng Việt/Nhật. Đã fix trong code
(`core/logging.py`). Nếu tự chạy script: đặt `PYTHONIOENCODING=utf-8`.

---

## 7. Dừng backend

- Ctrl+C trong terminal đang chạy uvicorn.
- RVC worker, VOICEVOX: đóng cửa sổ / app tương ứng.
- Xóa data test khi cần (server tự tạo lại):
  ```bash
  rm -rf backend/data/miku.db backend/data/audio backend/temp
  ```
