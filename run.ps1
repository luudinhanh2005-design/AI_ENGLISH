# EnglishAI - starts the FastAPI backend and the Flutter web app.
$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "  KHOI DONG HE THONG ENGLISH AI (BACKEND + FRONTEND)" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

$Python = if (Test-Path (Join-Path $ScriptDir 'backend\venv\Scripts\python.exe')) {
    Join-Path $ScriptDir 'backend\venv\Scripts\python.exe'
} else {
    'python'
}

Write-Host "[1/2] Backend FastAPI - http://localhost:8000" -ForegroundColor Yellow
Start-Process powershell -ArgumentList '-NoExit', '-Command', "cd '$ScriptDir\backend'; & '$Python' -m uvicorn main:app --reload --port 8000"

Write-Host "[2/2] Flutter app - http://localhost:5173 (Edge)" -ForegroundColor Yellow
Set-Location (Join-Path $ScriptDir 'english_ai')
flutter pub get
flutter run -d edge --web-hostname localhost --web-port 5173 --dart-define=GOOGLE_CLIENT_ID=116869668249-h8j2sit4nft1mrt08rdi993m2rcntapn.apps.googleusercontent.com
