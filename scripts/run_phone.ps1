#Requires -Version 5.1
<#
.SYNOPSIS
    Runs EnglishAI on a real phone with one command.

.DESCRIPTION
    Default (Android over USB):
      * finds the connected physical Android device through adb
      * forwards the phone's localhost:8000 to the computer with `adb reverse`
      * starts the backend if needed
      * runs Flutter with API_BASE_URL=http://127.0.0.1:8000

    Wi-Fi mode (Android or iPhone on the same network):
      * detects the computer LAN IPv4
      * starts the backend on 0.0.0.0
      * runs Flutter with API_BASE_URL=http://<computer-ip>:8000

.PARAMETER Wifi
    Use the computer's LAN IP instead of USB/adb reverse. Required for iPhone.

.PARAMETER HostIp
    Computer LAN IPv4 for --Wifi. Auto-detected when omitted.

.PARAMETER Device
    Flutter device id / adb serial. Auto-detected when omitted.

.PARAMETER Port
    Backend port. Default 8000.

.PARAMETER NoBackend
    Do not start the backend (it is already running).

.EXAMPLE
    run_phone.bat

.EXAMPLE
    run_phone.bat --wifi

.EXAMPLE
    run_phone.bat --wifi 192.168.1.10 --device "iPhone cua Minh"

.EXAMPLE
    run_phone.bat --device R58M123456A
#>
[CmdletBinding()]
param(
    [switch]$Wifi,
    [string]$HostIp = '',
    [string]$Device = '',
    [int]$Port = 8000,
    [switch]$NoBackend,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $ScriptDir
$BackendDir = Join-Path $RepoRoot 'backend'
$AppDir = Join-Path $RepoRoot 'english_ai'
$GoogleClientId = '116869668249-h8j2sit4nft1mrt08rdi993m2rcntapn.apps.googleusercontent.com'

function Write-Step([string]$Text) { Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host "    $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "    $Text" -ForegroundColor Yellow }
function Fail([string]$Text) {
    Write-Host $Text -ForegroundColor Red
    exit 1
}

function Show-Help {
    Write-Host @"
EnglishAI - chay tren dien thoai that

  run_phone.bat                       Android qua USB (khuyen nghi)
  run_phone.bat --wifi                Dien thoai/iPhone cung Wi-Fi
  run_phone.bat --wifi 192.168.1.10   Chi dinh IP may tinh
  run_phone.bat --device R58M123456A  Chi dinh thiet bi
  run_phone.bat --no-backend          Backend da chay san
  run_phone.bat --help

Luu y:
  * Android USB: bat Developer options -> USB debugging, cam cap va chap nhan RSA.
  * iPhone / Wi-Fi: dien thoai va may tinh phai cung mang; mo port 8000 tren firewall.
"@
}

if ($Help) {
    Show-Help
    exit 0
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Fail 'flutter not found in PATH. Install Flutter SDK first.'
}
if (-not (Test-Path (Join-Path $BackendDir 'main.py'))) {
    Fail "Backend not found at $BackendDir"
}
if (-not (Test-Path $AppDir)) {
    Fail "Flutter app not found at $AppDir"
}

# --- Locate adb -------------------------------------------------------------
$Sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME }
       elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
       else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }

$Adb = Join-Path $Sdk 'platform-tools\adb.exe'
if (-not (Test-Path $Adb)) {
    $adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($adbCommand) {
        $Adb = $adbCommand.Source
    } else {
        Fail 'adb not found. Install Android SDK platform-tools or add adb to PATH.'
    }
}

function Get-PhysicalAndroidDevices {
    $result = @()
    foreach ($line in (& $Adb devices -l 2>$null)) {
        if ($line -match '^(\S+)\s+device\b') {
            $serial = $Matches[1]
            if ($serial -like 'emulator-*') { continue }
            $result += [pscustomobject]@{
                Serial = $serial
                Detail = $line
            }
        }
    }
    return $result
}

function Get-LanIPv4 {
    try {
        $address = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and
                $_.InterfaceAlias -notmatch '(?i)Loopback|vEthernet|Virtual|Bluetooth|WSL|Docker'
            } |
            Sort-Object InterfaceMetric |
            Select-Object -First 1 -ExpandProperty IPAddress
        if ($address) { return $address }
    } catch { }

    try {
        $adapters = Get-CimInstance Win32_NetworkAdapterConfiguration `
            -Filter 'IPEnabled = True' -ErrorAction Stop
        foreach ($adapter in $adapters) {
            foreach ($address in @($adapter.IPAddress)) {
                if ($address -match '^\d+\.\d+\.\d+\.\d+$' -and
                    $address -notmatch '^(127\.|169\.254\.)') {
                    return $address
                }
            }
        }
    } catch { }

    return ''
}

function Test-Backend([string]$BaseUrl) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing `
            -Uri "$BaseUrl/health" -TimeoutSec 2
        return ($response.StatusCode -eq 200 -and $response.Content -match 'EnglishAI')
    } catch {
        return $false
    }
}

# --- Pick the phone ---------------------------------------------------------
$androidDevices = @(Get-PhysicalAndroidDevices)
$targetSerial = ''

if ($Wifi) {
    if (-not $HostIp) { $HostIp = Get-LanIPv4 }
    if (-not $HostIp) {
        $HostIp = Read-Host 'Nhap IPv4 cua may tinh (vi du 192.168.1.10)'
    }
    if ($HostIp -notmatch '^\d+\.\d+\.\d+\.\d+$') {
        Fail "IP khong hop le: $HostIp"
    }
} else {
    if ($Device) {
        $selected = $androidDevices | Where-Object { $_.Serial -eq $Device }
        if (-not $selected) {
            Fail "Khong tim thay thiet bi Android '$Device' qua USB. Chay: adb devices"
        }
        $targetSerial = $selected.Serial
    } elseif ($androidDevices.Count -gt 0) {
        $targetSerial = $androidDevices[0].Serial
    } else {
        $message = @'
Khong tim thay dien thoai Android qua USB.
  1. Bat Developer options -> USB debugging tren dien thoai.
  2. Cam cap USB va chap nhan hop thoai RSA.
  3. Kiem tra: adb devices
  4. Hoac chay bang Wi-Fi: run_phone.bat --wifi
'@
        Fail $message
    }
}

if ($Wifi) {
    $apiUrl = "http://${HostIp}:$Port"
} else {
    $apiUrl = "http://127.0.0.1:$Port"
}

# --- Start the backend if needed -------------------------------------------
$localHealth = "http://127.0.0.1:$Port"
$wifiHealth = if ($Wifi) { "http://${HostIp}:$Port" } else { $localHealth }
$healthBase = $localHealth

if (-not $NoBackend -and -not (Test-Backend $localHealth)) {
    Write-Step "Khoi dong backend tren port $Port"
    $Python = if (Test-Path (Join-Path $BackendDir 'venv\Scripts\python.exe')) {
        Join-Path $BackendDir 'venv\Scripts\python.exe'
    } else {
        'python'
    }
    $bindHost = '0.0.0.0'
    $backendCommand = "Set-Location -LiteralPath '$BackendDir'; & '$Python' -m uvicorn main:app --reload --host $bindHost --port $Port"
    Start-Process powershell.exe -ArgumentList @('-NoExit', '-Command', $backendCommand) | Out-Null

    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Backend $localHealth) { $ready = $true; break }
    }
    if ($ready) {
        if ($Wifi) {
            if (Test-Backend $wifiHealth) {
                Write-Ok "Backend san sang: $wifiHealth"
            } else {
                Write-Warn "Backend da chay nhung chua truy cap duoc qua $wifiHealth."
                Write-Warn "Mo firewall port $Port hoac kiem tra IP may tinh."
            }
        } else {
            Write-Ok "Backend san sang: $localHealth"
        }
    } else {
        Write-Warn "Backend chua san sang. Kiem tra cua so backend."
    }
} elseif ($NoBackend) {
    if (Test-Backend $localHealth) {
        Write-Ok "Dung backend dang chay san tai $localHealth"
    } else {
        Write-Warn "Khong thay backend tai $localHealth. Kiem tra lai hoac bo --no-backend."
    }
} elseif ($Wifi) {
    if (Test-Backend $wifiHealth) {
        Write-Ok "Backend dang chay san: $wifiHealth"
    } else {
        Write-Warn "Backend dang chay nhung khong truy cap duoc qua $wifiHealth."
        Write-Warn "Hay chay backend voi --host 0.0.0.0 va mo firewall port $Port."
    }
}

# --- USB port forwarding ----------------------------------------------------
if (-not $Wifi) {
    Write-Step "Chuyen localhost:$Port cua dien thoai ve may tinh"
    & $Adb -s $targetSerial reverse "tcp:$Port" "tcp:$Port" | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Fail "adb reverse that bai. Thu lai cap USB hoac dung: run_phone.bat --wifi"
    }
    Write-Ok "Da bat adb reverse cho $targetSerial"
}

# --- Find the Flutter device id --------------------------------------------
$flutterDevice = $Device
if (-not $flutterDevice -and $targetSerial) {
    $flutterDevice = $targetSerial
}
if (-not $flutterDevice) {
    try {
        $raw = (& flutter devices --machine 2>$null | Out-String)
        $devices = $raw | ConvertFrom-Json
        $phone = $devices |
            Where-Object {
                $_.targetPlatform -match '^(android|ios)' -and
                -not $_.emulator -and
                $_.id -notmatch '^(chrome|edge|web-server)'
            } |
            Select-Object -First 1
        if ($phone) { $flutterDevice = $phone.id }
    } catch { }
}
if (-not $flutterDevice) {
    Fail "Khong tim thay thiet bi Flutter. Chay 'flutter devices' va dung --device <id>."
}

Write-Host ''
Write-Host '===============================================================' -ForegroundColor Cyan
Write-Host '  ENGLISH AI - DIEN THOAI THAT' -ForegroundColor Green
Write-Host '===============================================================' -ForegroundColor Cyan
Write-Host "  Thiet bi : $flutterDevice"
Write-Host "  API      : $apiUrl"
Write-Host "  Backend  : $healthBase"
if (-not $Wifi) { Write-Host "  USB      : adb reverse tcp:$Port -> tcp:$Port" }
Write-Host ''

# --- Run --------------------------------------------------------------------
$exitCode = 0
Push-Location $AppDir
try {
    Write-Step 'flutter pub get'
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

    Write-Step "flutter run -d $flutterDevice"
    & flutter run -d $flutterDevice `
        "--dart-define=API_BASE_URL=$apiUrl" `
        "--dart-define=GOOGLE_CLIENT_ID=$GoogleClientId"
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $exitCode

