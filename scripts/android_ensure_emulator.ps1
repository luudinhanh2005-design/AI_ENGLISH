# Ensures the englishai_pixel33 Android emulator is running and fully booted.
# Used as a VS Code preLaunchTask so pressing F5 starts the emulator first.
$ErrorActionPreference = 'Stop'

$Sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$Adb = Join-Path $Sdk 'platform-tools\adb.exe'
$Emulator = Join-Path $Sdk 'emulator\emulator.exe'
# Android 13 image: lighter and compatible with older CPUs (the Android 36 AVD
# hangs with "QEMU2 CPU thread hanging" on this machine).
$Avd = 'englishai_pixel33'
$DeviceTimeoutSeconds = 180
$BootTimeoutMinutes = 5

if (-not (Test-Path $Adb)) { throw "adb not found at $Adb" }
if (-not (Test-Path $Emulator)) { throw "emulator not found at $Emulator" }

function Get-RunningEmulatorId {
    foreach ($line in (& $Adb devices)) {
        if ($line -match '^(emulator-\d+)\s+device') { return $Matches[1] }
    }
    return $null
}

function Test-EmulatorProcessAlive {
    return [bool](Get-Process -Name 'emulator', 'qemu-system-x86_64', 'qemu-system-x86_64-headless' -ErrorAction SilentlyContinue)
}

$device = Get-RunningEmulatorId
if (-not $device) {
    Write-Host "Starting Android emulator '$Avd' ..."

    # Kill orphan emulator/qemu processes from a previous crash.
    Get-Process -Name 'emulator*', 'qemu-system*' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Clear stale lock files left behind by a previous crash.
    $avdDir = Join-Path $env:USERPROFILE ".android\avd\$Avd.avd"
    if (Test-Path $avdDir) {
        Get-ChildItem $avdDir -Filter '*.lock' -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop } catch { }
        }
    }

    Start-Process -FilePath $Emulator -ArgumentList @(
        '-avd', $Avd,
        '-gpu', 'swiftshader_indirect',
        '-memory', '2048',
        '-cores', '2',
        '-no-boot-anim',
        '-no-snapshot-load'
    ) | Out-Null

    Write-Host "Waiting for the device to appear (max ${DeviceTimeoutSeconds}s) ..."
    $deadline = (Get-Date).AddSeconds($DeviceTimeoutSeconds)
    do {
        Start-Sleep -Seconds 3
        $device = Get-RunningEmulatorId
        if (-not $device -and -not (Test-EmulatorProcessAlive)) {
            throw "Emulator process exited before the device came online. Try 'Wipe Data' / 'Cold Boot' for AVD '$Avd' in Android Studio, or use a lower API level AVD."
        }
    } while (-not $device -and (Get-Date) -lt $deadline)

    if (-not $device) {
        throw "Emulator did not come online within ${DeviceTimeoutSeconds} seconds."
    }
}

Write-Host "Waiting for Android to finish booting ($device) ..."
$deadline = (Get-Date).AddMinutes($BootTimeoutMinutes)
$boot = ''
do {
    Start-Sleep -Seconds 3
    $boot = (& $Adb -s $device shell getprop sys.boot_completed 2>$null | Out-String).Trim()
} while ($boot -ne '1' -and (Get-Date) -lt $deadline)

if ($boot -ne '1') { throw "Emulator did not finish booting within $BootTimeoutMinutes minutes." }

Write-Host "Emulator ready: $(Get-RunningEmulatorId)"
