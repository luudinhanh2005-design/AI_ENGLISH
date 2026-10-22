$ScriptDir = $PSScriptRoot

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "  🚀 KHỞI ĐỘNG HỆ THỐNG ENGLISH AI (BACKEND + FRONTEND)" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/2] Đang khởi động Backend FastAPI (Port 8000)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$ScriptDir\backend'; python -m uvicorn main:app --reload --port 8000"

Write-Host "[2/2] Đang khởi động Frontend Flutter (Giao diện App trên Edge)..." -ForegroundColor Yellow
Set-Location "$ScriptDir\english_ai"
flutter run -d edge --web-hostname localhost --web-port 5000 --dart-define=GOOGLE_CLIENT_ID=116869668249-h8j2sit4nft1mrt08rdi993m2rcntapn.apps.googleusercontent.com
