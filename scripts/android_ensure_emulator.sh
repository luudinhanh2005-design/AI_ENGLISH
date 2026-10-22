#!/usr/bin/env bash
# Starts (and if needed creates) a lightweight Android emulator on macOS/Linux,
# then waits until Android has fully booted.
#
# Mirrors scripts/android_ensure_emulator.ps1:
#   * picks cores/memory/resolution from the host
#   * uses the host GPU when available (works with integrated graphics)
#   * no quick-boot snapshots by default (avoids a ~2 GB RAM image)
#   * creates the AVD automatically from an installed system image
#   * reuses an already-running emulator instead of killing it
#
# Usage:
#   ./scripts/android_ensure_emulator.sh
#   ./scripts/android_ensure_emulator.sh --avd englishai_light --gpu host --headless
set -euo pipefail

AVD="${ENGLISHAI_AVD:-englishai_light}"
GPU="${ENGLISHAI_GPU:-auto}"
MEMORY=0
CORES=0
WIDTH=0
HEIGHT=0
DENSITY=0
HEADLESS=0
SNAPSHOT=0
FORCE_CREATE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --avd) AVD="$2"; shift 2 ;;
    --gpu) GPU="$2"; shift 2 ;;
    --memory) MEMORY="$2"; shift 2 ;;
    --cores) CORES="$2"; shift 2 ;;
    --width) WIDTH="$2"; shift 2 ;;
    --height) HEIGHT="$2"; shift 2 ;;
    --density) DENSITY="$2"; shift 2 ;;
    --headless) HEADLESS=1; shift ;;
    --snapshot) SNAPSHOT=1; shift ;;
    --force-create) FORCE_CREATE=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

OS="$(uname -s)"
ARCH_RAW="$(uname -m)"

case "$OS" in
  Darwin) DEFAULT_SDK="$HOME/Library/Android/sdk" ;;
  *)      DEFAULT_SDK="$HOME/Android/Sdk" ;;
esac
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$DEFAULT_SDK}}"
ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"
AVDMANAGER="$SDK/cmdline-tools/latest/bin/avdmanager"
[ -x "$AVDMANAGER" ] || AVDMANAGER="$SDK/tools/bin/avdmanager"

[ -x "$ADB" ] || { echo "adb not found at $ADB. Install Android SDK platform-tools." >&2; exit 1; }
[ -x "$EMULATOR" ] || { echo "emulator not found at $EMULATOR. Install the Android Emulator package." >&2; exit 1; }

case "$ARCH_RAW" in
  arm64|aarch64) ARCH="arm64-v8a" ;;
  *)             ARCH="x86_64" ;;
esac

# --- Host profile -----------------------------------------------------------
if [ "$CORES" -le 0 ]; then
  if [ "$OS" = "Darwin" ]; then CPU_COUNT="$(sysctl -n hw.ncpu)"
  else CPU_COUNT="$(nproc 2>/dev/null || echo 4)"; fi
  if [ "$CPU_COUNT" -ge 8 ]; then CORES=4
  elif [ "$CPU_COUNT" -ge 4 ]; then CORES=2
  else CORES=1; fi
fi

if [ "$OS" = "Darwin" ]; then
  RAM_BYTES="$(sysctl -n hw.memsize)"
else
  RAM_BYTES="$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) * 1024 ))"
fi
RAM_GB=$(( RAM_BYTES / 1073741824 ))

if [ "$MEMORY" -le 0 ]; then
  if [ "$RAM_GB" -ge 8 ]; then MEMORY=2048; else MEMORY=1536; fi
fi

if [ "$WIDTH" -le 0 ]; then
  if [ "$RAM_GB" -lt 6 ] || [ "$CPU_COUNT" -lt 4 ]; then
    WIDTH=540; HEIGHT=960; DENSITY=240
  else
    WIDTH=720; HEIGHT=1280; DENSITY=320
  fi
fi

# --- Helpers ----------------------------------------------------------------
running_serial() {
  "$ADB" devices 2>/dev/null | awk '/^emulator-[0-9]+[[:space:]]+device/ {print $1; exit}'
}

wait_for_boot() {
  local serial="$1" deadline=$(( $(date +%s) + 300 )) boot=""
  while [ "$(date +%s)" -lt "$deadline" ]; do
    sleep 3
    boot="$("$ADB" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n')"
    [ "$boot" = "1" ] && return 0
  done
  return 1
}

# --- Reuse a running emulator ----------------------------------------------
if SERIAL="$(running_serial)" && [ -n "$SERIAL" ]; then
  NAME="$("$ADB" -s "$SERIAL" emu avd name 2>/dev/null | head -n1 | tr -d '\r')"
  echo "Emulator $SERIAL is already running (AVD '${NAME:-unknown}')."
  wait_for_boot "$SERIAL" || { echo "Android did not finish booting in 5 minutes." >&2; exit 1; }
  echo "Emulator ready: $SERIAL"
  exit 0
fi

# --- Create the AVD when missing -------------------------------------------
IMAGE="system-images;android-29;default;$ARCH"
IMAGE_DIR="$SDK/system-images/android-29/default/$ARCH"
AVD_DIR="$HOME/.android/avd/$AVD.avd"

if [ "$FORCE_CREATE" -eq 1 ] && [ -d "$AVD_DIR" ]; then
  echo "Removing existing AVD '$AVD' (--force-create) ..."
  "$AVDMANAGER" delete avd -n "$AVD" >/dev/null 2>&1 || true
  rm -rf "$AVD_DIR" "$HOME/.android/avd/$AVD.ini"
fi

if [ ! -d "$AVD_DIR" ]; then
  if [ ! -d "$IMAGE_DIR" ]; then
    cat >&2 <<EOF
System image '$IMAGE' is not installed.

Install it with:
  "$SDK/cmdline-tools/latest/bin/sdkmanager" "platform-tools" "emulator" "$IMAGE"
EOF
    exit 1
  fi
  echo "Creating AVD '$AVD' from $IMAGE ..."
  printf 'no\n' | "$AVDMANAGER" create avd -n "$AVD" -k "$IMAGE" --force >/dev/null
fi

# --- Lightweight configuration ---------------------------------------------
CONFIG="$AVD_DIR/config.ini"
TMP="$(mktemp)"
grep -vE '^[[:space:]]*(hw\.ramSize|hw\.cpu\.ncore|hw\.sdCard|hw\.gpu\.enabled|hw\.gpu\.mode|hw\.lcd\.width|hw\.lcd\.height|hw\.lcd\.density|vm\.heapSize)[[:space:]]*=' "$CONFIG" >"$TMP" || true
cat >>"$TMP" <<EOF
hw.ramSize = $MEMORY
hw.cpu.ncore = $CORES
hw.sdCard = no
hw.gpu.enabled = yes
hw.gpu.mode = auto
hw.lcd.width = $WIDTH
hw.lcd.height = $HEIGHT
hw.lcd.density = $DENSITY
vm.heapSize = 256
EOF
mv "$TMP" "$CONFIG"

# Stale locks from a previous crash (target AVD only).
find "$AVD_DIR" -maxdepth 1 -name '*.lock' -exec rm -rf {} + 2>/dev/null || true

# --- Acceleration check -----------------------------------------------------
ACCEL="$("$EMULATOR" -accel-check 2>&1 || true)"
if echo "$ACCEL" | grep -q 'is installed and usable'; then
  echo "Acceleration: $(echo "$ACCEL" | tr '\n' ' ')"
elif echo "$ACCEL" | grep -qiE 'not installed|not usable|failed|disabled'; then
  cat >&2 <<EOF
Hardware acceleration is NOT available:
$ACCEL

  * Linux: enable VT-x/AMD-V in the BIOS and install KVM (kvm group).
  * macOS: Hypervisor.framework is required (available on Intel and Apple Silicon).
EOF
  exit 1
else
  echo "Warning: could not confirm acceleration support: $ACCEL" >&2
fi

# --- Launch -----------------------------------------------------------------
LOG_DIR="${TMPDIR:-/tmp}/englishai-emulator"
mkdir -p "$LOG_DIR"
ARGS=(-avd "$AVD" -gpu "$GPU" -memory "$MEMORY" -cores "$CORES" -no-boot-anim)

if [ "$SNAPSHOT" -eq 0 ]; then
  ARGS+=(-no-snapshot -no-snapstorage -no-snapshot-save \
         -feature -FastSnapshotV1 -feature -QuickbootFileBacked -feature -DownloadableSnapshot)
fi
[ "$HEADLESS" -eq 1 ] && ARGS+=(-no-window)

echo "Starting AVD '$AVD' (GPU=$GPU, ${WIDTH}x${HEIGHT}, ${CORES} cores, ${MEMORY} MB RAM, snapshot=$([ "$SNAPSHOT" -eq 1 ] && echo on || echo off)) ..."
nohup "$EMULATOR" "${ARGS[@]}" >"$LOG_DIR/stdout.log" 2>&1 &

echo "Waiting for the device to come online (max 240s) ..."
DEADLINE=$(( $(date +%s) + 240 ))
SERIAL=""
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  sleep 3
  SERIAL="$(running_serial)"
  [ -n "$SERIAL" ] && break
done

[ -n "$SERIAL" ] || { echo "Emulator did not come online within 240 seconds. See $LOG_DIR/stdout.log" >&2; exit 1; }

echo "Waiting for Android to finish booting ($SERIAL) ..."
wait_for_boot "$SERIAL" || { echo "Android did not finish booting in 5 minutes." >&2; exit 1; }

echo "Emulator ready: $SERIAL"
