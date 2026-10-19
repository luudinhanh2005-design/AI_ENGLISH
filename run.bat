@echo off
chcp 65001 >nul
title EnglishAI - All-in-One Startup

echo ===============================================================
echo   KHOI DONG HE THONG ENGLISH AI (BACKEND + FRONTEND)
echo ===============================================================
echo.

set "SCRIPT_DIR=%~dp0"

echo [1/2] Dang khoi dong Backend FastAPI...
start "EnglishAI - Backend Server (Port 5000)" cmd /k "cd /d "%SCRIPT_DIR%backend" && python -m uvicorn main:app --reload --port 5000"

echo [2/2] Dang khoi dong Frontend Flutter (Giao dien App tren Edge)...
cd /d "%SCRIPT_DIR%english_ai"
flutter run -d edge --web-hostname localhost --web-port 5000 --dart-define=GOOGLE_CLIENT_ID=892889764828-daqcip49ndh8n02sdstrjs170jm7l5pn.apps.googleusercontent.com

pause
