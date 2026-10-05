@echo off
chcp 65001 >nul
title EnglishAI - All-in-One Startup

echo ===============================================================
echo   KHOI DONG HE THONG ENGLISH AI (BACKEND + FRONTEND)
echo ===============================================================
echo.

echo [1/2] Dang khoi dong Backend FastAPI (AI Model tren GPU)...
start "EnglishAI - Backend Server (Port 8000)" cmd /k "cd /d D:\AI ENGLISH\backend && uvicorn main:app --reload --port 8000"

echo [2/2] Dang khoi dong Frontend Flutter (Giao dien App tren Edge)...
cd /d "D:\AI ENGLISH\english_ai"
flutter run -d edge

pause
