#Requires -Version 5.1
<#
.SYNOPSIS
    Starts (and if needed creates) a lightweight Android emulator, then waits
    until Android has fully booted.

.DESCRIPTION
    Designed to be portable across contributor machines:
      * Picks a hardware profile from the host CPU / RAM (cores, memory, 720p or 540p).
      * Uses the host GPU when available (`-gpu auto`), so no dedicated GPU is required.
      * Disables quick-boot snapshots by default. The emulator otherwise writes a
        ~2 GB RAM snapshot on first boot, which is wasted disk for this project.
      * Verifies that CPU virtualisation (VT-x/AMD-V) is usable and prints clear
        instructions when it is not.
      * Reuses an already-running emulator instead of killing other instances.
      * Creates the AVD automatically from an installed system image when missing.

.PARAMETER Avd
    AVD name. Defaults to $env:ENGLISHAI_AVD or "englishai_light".

.PARAMETER Gpu
    Emulator GPU mode: auto (default), host, swiftshader_indirect, angle_indirect.

.PARAMETER Snapshot
    Enable quick-boot snapshots (faster boot, ~2 GB extra disk). Off by default.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/android_ensure_emulator.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/android_ensure_emulator.ps1 -Gpu host -Headless
#>
[CmdletBinding()]
param(
    [string]$Avd = $(if ($env:ENGLISHAI_AVD) { $env:ENGLISHAI_AVD } else { 'englishai_light' }),
    [string]$Gpu = $(if ($env:ENGLISHAI_GPU) { $env:ENGLISHAI_GPU } else { 'auto' }),
    [int]$Memory = 0,
    [int]$Cores = 0,
    [int]$Width = 0,
    [int]$Height = 0,
    [int]$Density = 0,
    [switch]$Headless,
    [switch]$Snapshot,
    [switch]$ForceCreate
)

$ErrorActionPreference = 'Stop'

# --- Locate the Android SDK -------------------------------------------------
$Sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME }
       elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
       else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }

$Adb     = Join-Path $Sdk 'platform-tools\adb.exe'
$Emulator = Join-Path $Sdk 'emulator\emulator.exe'
$AvdManager = Join-Path $Sdk 'cmdline-tools\latest\bin\avdmanager.bat'

if (-not (Test-Path $Adb))      { throw "adb not found at $Adb. Install Android SDK platform-tools." }
if (-not (Test-Path $Emulator)) { throw "emulator not found at $Emulator. Install the Android Emulator package." }

# --- Host hardware profile --------------------------------------------------
$cpuCount = [Environment]::ProcessorCount
if ($Cores -le 0) {
    $Cores = if ($cpuCount -ge 8) { 4 } elseif ($cpuCount -ge 4) { 2 } else { 1 }
}

$ramGB = 8
try {
    $ramBytes = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory
    if ($ramBytes) { $ramGB = [math]::Round($ramBytes / 1GB) }
} catch { }

if ($Memory -le 0) { $Memory = if ($ramGB -ge 8) { 2048 } else { 1536 } }

if ($Width -le 0) {
    if ($ramGB -lt 6 -or $cpuCount -lt 4) {
        $Width = 540; $Height = 960; $Density = 240
    } else {
        $Width = 720; $Height = 1280; $Density = 320
    }
}

# --- Helpers ----------------------------------------------------------------
function Get-RunningEmulator {
    param([string]$Serial)
    $output = & $Adb devices 2>$null
    foreach ($line in $output) {
        if ($line -match '^(emulator-\d+)\s+device') {
            $id = $Matches[1]
            if ($Serial -and $id -ne $Serial) { continue }
            $name = (& $Adb -s $id emu avd name 2>$null | Select-Object -First 1)
            return [pscustomobject]@{ Serial = $id; Avd = ($name | Out-String).Trim() }
        }
    }
    return $null
}

function Wait-ForBoot {
    param([string]$Serial, [int]$TimeoutMinutes = 5)
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    $boot = ''
    do {
        Start-Sleep -Seconds 3
        $boot = (& $Adb -s $Serial shell getprop sys.boot_completed 2>$null | Out-String).Trim()
    } while ($boot -ne '1' -and (Get-Date) -lt $deadline)
    return ($boot -eq '1')
}

function Set-AvdConfig {
    param([string]$Path, [hashtable]$Values)
    $lines = @(Get-Content $Path)
    foreach ($key in $Values.Keys) {
        $pattern = '^\s*' + [regex]::Escape($key) + '\s*='
        $lines = @($lines | Where-Object { $_ -notmatch $pattern })
    }
    $extra = @($Values.Keys | ForEach-Object { "$_ = $($Values[$_])" })
    Set-Content -Path $Path -Value ($lines + $extra) -Encoding ASCII
}

function Assert-Acceleration {
    $output = (& $Emulator -accel-check 2>&1 | Out-String)
    if ($output -match 'is installed and usable') {
        Write-Host ("Acceleration: " + ($output.Trim() -replace '\s+', ' '))
        return
    }
    if ($output -match 'not installed|not usable|failed|disabled|requires') {
        throw @"
Hardware acceleration is NOT available:
$($output.Trim())

Fix it with one of these:
  * Enable Intel VT-x / AMD-V (SVM) in the BIOS/UEFI.
  * Windows: install "Android Emulator Hypervisor Driver" (AEHD) or enable
    "Windows Hypervisor Platform" in Windows Features.
  * Then re-run this script.
"@
    }
    Write-Warning "Could not confirm acceleration support: $($output.Trim())"
}

# --- Already running? Reuse it ---------------------------------------------
$running = Get-RunningEmulator
if ($running) {
    if ($running.Avd -and $running.Avd -ne $Avd) {
        Write-Host "Using already-running emulator $($running.Serial) (AVD '$($running.Avd)'), not '$Avd'."
    } else {
        Write-Host "Emulator $($running.Serial) is already running (AVD '$Avd')."
    }
    if (-not (Wait-ForBoot -Serial $running.Serial)) {
        throw "Emulator $($running.Serial) is running but Android did not finish booting in 5 minutes."
    }
    Write-Host "Emulator ready: $($running.Serial)"
    exit 0
}

# --- Create the AVD when missing -------------------------------------------
$Arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64-v8a' } else { 'x86_64' }
$Image = "system-images;android-29;default;$Arch"
$ImageDir = Join-Path $Sdk "system-images\android-29\default\$Arch"
$AvdDir = Join-Path $env:USERPROFILE ".android\avd\$Avd.avd"

if ($ForceCreate -and (Test-Path $AvdDir)) {
    Write-Host "Removing existing AVD '$Avd' (-ForceCreate) ..."
    & $AvdManager delete avd -n $Avd 2>$null | Out-Null
    Remove-Item $AvdDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:USERPROFILE ".android\avd\$Avd.ini") -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $AvdDir)) {
    if (-not (Test-Path $ImageDir)) {
        throw @"
System image '$Image' is not installed.

Install it with:
  "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat" "platform-tools" "emulator" "$Image"

On Apple Silicon use arm64-v8a instead of x86_64.
"@
    }

    Write-Host "Creating AVD '$Avd' from $Image ..."
    $createOutput = 'no' | & $AvdManager create avd -n $Avd -k $Image --force 2>&1 | Out-String
    if (-not (Test-Path (Join-Path $AvdDir 'config.ini'))) {
        throw "Failed to create AVD '$Avd'.`n$createOutput"
    }
}

# --- Lightweight configuration ---------------------------------------------
$avdConfig = Join-Path $AvdDir 'config.ini'
Set-AvdConfig -Path $avdConfig -Values @{
    'hw.ramSize'      = "$Memory"
    'hw.cpu.ncore'    = "$Cores"
    'hw.sdCard'       = 'no'
    'hw.gpu.enabled'  = 'yes'
    'hw.gpu.mode'     = 'auto'
    'hw.lcd.width'    = "$Width"
    'hw.lcd.height'   = "$Height"
    'hw.lcd.density'  = "$Density"
    'vm.heapSize'     = '256'
}

# Clear stale lock files from a previous crash (target AVD only).
Get-ChildItem $AvdDir -Filter '*.lock' -Force -ErrorAction SilentlyContinue | ForEach-Object {
    try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop } catch { }
}

Assert-Acceleration

# --- Launch -----------------------------------------------------------------
$emulatorArgs = @(
    '-avd', $Avd,
    '-gpu', $Gpu,
    '-memory', "$Memory",
    '-cores', "$Cores",
    '-no-boot-anim'
)

# Light profile: no snapshots. Without this the emulator writes a ~2 GB RAM
# snapshot on first boot even when -no-snapshot is passed (emulator 36.x).
if (-not $Snapshot) {
    $emulatorArgs += @(
        '-no-snapshot',
        '-no-snapstorage',
        '-no-snapshot-save',
        '-feature', '-FastSnapshotV1',
        '-feature', '-QuickbootFileBacked',
        '-feature', '-DownloadableSnapshot'
    )
}
if ($Headless) { $emulatorArgs += '-no-window' }

$logDir = Join-Path $env:TEMP 'englishai-emulator'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stdout = Join-Path $logDir 'stdout.log'
$stderr = Join-Path $logDir 'stderr.log'

Write-Host "Starting AVD '$Avd' (GPU=$Gpu, ${Width}x${Height}, ${Cores} cores, ${Memory} MB RAM, snapshot=$(if ($Snapshot) {'on'} else {'off'})) ..."
Start-Process -FilePath $Emulator -ArgumentList $emulatorArgs `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr | Out-Null

Write-Host "Waiting for the device to come online (max 240s) ..."
$deadline = (Get-Date).AddSeconds(240)
$device = $null
do {
    Start-Sleep -Seconds 3
    $device = Get-RunningEmulator
    if (-not $device -and -not (Get-Process -Name 'emulator', 'qemu-system-x86_64', 'qemu-system-x86_64-headless' -ErrorAction SilentlyContinue)) {
        $tail = Get-Content $stderr -Tail 20 -ErrorAction SilentlyContinue
        throw "Emulator exited before the device came online.`n$($tail -join "`n")"
    }
} while (-not $device -and (Get-Date) -lt $deadline)

if (-not $device) {
    throw "Emulator did not come online within 240 seconds. See $stderr"
}

Write-Host "Waiting for Android to finish booting ($($device.Serial)) ..."
if (-not (Wait-ForBoot -Serial $device.Serial)) {
    throw "Android did not finish booting within 5 minutes. See $stderr"
}

Write-Host "Emulator ready: $($device.Serial)"
