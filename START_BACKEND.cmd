@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Miku AI - Gemini + Fish Audio

set "PROJECT_DIR=%~dp0"
set "BACKEND_DIR=%PROJECT_DIR%backend"
set "BACKEND_PYTHON=C:\Users\pc\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe"

echo ============================================================
echo  Miku AI backend
echo  Gemini:     online
echo  Fish Audio: online
echo  Backend:    http://127.0.0.1:8000
echo ============================================================
echo.

if not exist "%BACKEND_DIR%\app\main.py" (
    echo [ERROR] Khong tim thay backend tai:
    echo         %BACKEND_DIR%
    pause
    exit /b 1
)

if not exist "%BACKEND_PYTHON%" (
    if exist "%BACKEND_DIR%\.venv\Scripts\python.exe" (
        set "BACKEND_PYTHON=%BACKEND_DIR%\.venv\Scripts\python.exe"
    ) else (
        echo [ERROR] Khong tim thay Python cho FastAPI backend.
        echo         Hay tao backend\.venv va cai backend\requirements.txt.
        pause
        exit /b 1
    )
)

if not exist "%BACKEND_DIR%\.env" (
    echo [WARN] Chua co backend\.env.
    echo        Sao chep backend\.env.example thanh backend\.env,
    echo        sau do dien GEMINI_API_KEY va FISH_API_KEY.
    echo.
)

set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
cd /d "%BACKEND_DIR%"

echo [START] Dang khoi dong FastAPI backend...
echo [INFO] Khong khoi dong AivisSpeech, RVC, CUDA hay model local.
echo [INFO] Nhan Ctrl+C de dung backend.
echo.

"%BACKEND_PYTHON%" -m uvicorn app.main:app --host 0.0.0.0 --port 8000

set "BACKEND_EXIT=%errorlevel%"
echo.
echo Backend da dung hoac gap loi. Exit code: %BACKEND_EXIT%
pause
exit /b %BACKEND_EXIT%
