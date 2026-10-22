#!/usr/bin/env bash
# EnglishAI - starts the FastAPI backend and the Flutter app on macOS/Linux.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

PYTHON="python3"
if [ -x "$ROOT/backend/venv/bin/python" ]; then
  PYTHON="$ROOT/backend/venv/bin/python"
fi

echo "=== EnglishAI - backend + Flutter ==="
echo "[1/2] Backend FastAPI - http://localhost:8000"
(
  cd "$ROOT/backend"
  "$PYTHON" -m uvicorn main:app --reload --port 8000
) &
BACKEND_PID=$!
trap 'kill "$BACKEND_PID" 2>/dev/null || true' EXIT

sleep 2
echo "[2/2] Flutter app - device: ${FLUTTER_DEVICE:-chrome}"
cd "$ROOT/english_ai"
flutter pub get
flutter run -d "${FLUTTER_DEVICE:-chrome}"
