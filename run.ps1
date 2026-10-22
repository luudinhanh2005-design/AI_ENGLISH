#Requires -Version 5.1
<#
.SYNOPSIS
    Starts the FastAPI backend and the Flutter web app.

.DESCRIPTION
    Safe to run repeatedly:
      * reuses an already-healthy backend instead of opening a duplicate one
      * stops an old Flutter web server on the requested port before starting
      * falls back to the next free port when another program owns it

.PARAMETER Port
    Backend port. Default 8000.

.PARAMETER WebPort
    Flutter web port. Default 5173.

.PARAMETER Help
    Show this help.
#>
[CmdletBinding()]
param(
    [int]$Port = 8000,
    [int]$WebPort = 5173,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$BackendDir = Join-Path $ScriptDir 'backend'
$AppDir = Join-Path $ScriptDir 'english_ai'
$GoogleClientId = '116869668249-h8j2sit4nft1mrt08rdi993m2rcntapn.apps.googleusercontent.com'

function Write-Step([string]$Text) { Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host "    $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "    $Text" -ForegroundColor Yellow }

function Test-Backend([int]$BackendPort) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing `
            -Uri "http://127.0.0.1:$BackendPort/health" -TimeoutSec 2
        return ($response.StatusCode -eq 200 -and $response.Content -match 'EnglishAI')
    } catch {
        return $false
    }
}

function Resolve-WebPort([int]$Preferred) {
    for ($candidate = $Preferred; $candidate -le $Preferred + 10; $candidate++) {
        $listener = Get-NetTCPConnection -LocalPort $candidate -State Listen `
            -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $listener) { return $candidate }

        $owner = Get-CimInstance Win32_Process `
            -Filter "ProcessId = $($listener.OwningProcess)" -ErrorAction SilentlyContinue
        $commandLine = if ($owner) { [string]$owner.CommandLine } else { '' }
        $processName = if ($owner) { [string]$owner.Name } else { 'unknown process' }
        $isFlutter = (
            $commandLine -match 'flutter_tools\.snapshot' -or
            $commandLine -match 'flutter run' -or
            ($processName -match '^dart(vm)?\.exe$' -and $commandLine -match 'run -d edge')
        )

        if ($isFlutter) {
            Write-Step "Dang dung Flutter web cu tren cong $candidate (PID $($listener.OwningProcess))"
            & taskkill.exe /PID $listener.OwningProcess /T /F | Out-Null
            for ($i = 0; $i -lt 20; $i++) {
                Start-Sleep -Milliseconds 250
                if (-not (Get-NetTCPConnection -LocalPort $candidate -State Listen `
                        -ErrorAction SilentlyContinue)) {
                    return $candidate
                }
            }
            Write-Warn "Server cu chua nha cong $candidate, thu cong tiep theo."
        } else {
            Write-Warn "Cong $candidate dang bi $processName dung, thu cong tiep theo."
        }
    }

    throw "Khong tim thay cong web trong khoang $Preferred..$($Preferred + 10)."
}

if ($Help) {
    Write-Host @"
EnglishAI - backend + Flutter web

  run.bat                 Start backend and web app
  run.bat -WebPort 5174   Use another web port
  run.bat -Help

The script reuses a running backend and restarts an old Flutter web server.
"@
    exit 0
}

if (-not (Test-Path (Join-Path $BackendDir 'main.py'))) {
    throw "Backend not found at $BackendDir"
}
if (-not (Test-Path $AppDir)) {
    throw "Flutter app not found at $AppDir"
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'flutter not found in PATH. Install Flutter SDK first.'
}

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "  KHOI DONG HE THONG ENGLISH AI (BACKEND + FRONTEND)" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# --- Backend ---------------------------------------------------------------
if (Test-Backend $Port) {
    Write-Step "Backend da chay san - dung lai http://localhost:$Port"
} else {
    Write-Step "Khoi dong backend - http://localhost:$Port"
    $Python = if (Test-Path (Join-Path $BackendDir 'venv\Scripts\python.exe')) {
        Join-Path $BackendDir 'venv\Scripts\python.exe'
    } else {
        'python'
    }
    $backendCommand = "`$Host.UI.RawUI.WindowTitle = 'EnglishAI - Backend ($Port)'; " +
        "Set-Location -LiteralPath '$BackendDir'; " +
        "& '$Python' -m uvicorn main:app --reload --host 127.0.0.1 --port $Port"
    Start-Process powershell.exe -ArgumentList @('-NoExit', '-Command', $backendCommand) | Out-Null

    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Backend $Port) {
            $ready = $true
            break
        }
    }
    if ($ready) {
        Write-Ok "Backend san sang."
    } else {
        Write-Warn "Backend chua san sang sau 30 giay. Kiem tra cua so backend."
    }
}

# --- Frontend --------------------------------------------------------------
$WebPort = Resolve-WebPort $WebPort
Write-Step "Flutter web - http://localhost:$WebPort (Edge)"
Write-Host ""

$exitCode = 0
Push-Location $AppDir
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter pub get failed'
    }

    & flutter run -d edge --web-hostname localhost --web-port $WebPort `
        "--dart-define=GOOGLE_CLIENT_ID=$GoogleClientId"
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

exit $exitCode
