@echo off
chcp 65001 >nul
title EnglishAI - All-in-One Startup
setlocal

echo ===============================================================
echo   KHOI DONG HE THONG ENGLISH AI (BACKEND + FRONTEND)
echo ===============================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "PY=python"
if exist "%SCRIPT_DIR%backend\venv\Scripts\python.exe" set "PY=%SCRIPT_DIR%backend\venv\Scripts\python.exe"

echo [1/2] Backend FastAPI - http://localhost:8000
start "EnglishAI - Backend (8000)" cmd /k "cd /d "%SCRIPT_DIR%backend" && "%PY%" -m uvicorn main:app --reload --port 8000"

echo [2/2] Flutter app - http://localhost:5173 (Edge)
cd /d "%SCRIPT_DIR%english_ai"
call flutter pub get
call flutter run -d edge --web-hostname localhost --web-port 5173 --dart-define=GOOGLE_CLIENT_ID=116869668249-h8j2sit4nft1mrt08rdi993m2rcntapn.apps.googleusercontent.com

pause
