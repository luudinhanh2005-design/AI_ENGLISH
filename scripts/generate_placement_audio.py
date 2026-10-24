"""Pre-render the placement listening bank with edge-tts.

Usage:
    python scripts/generate_placement_audio.py
    python scripts/generate_placement_audio.py --force
    python scripts/generate_placement_audio.py --only ls_a1_01 ls_a2_03

Files are written to ``backend/storage/audio/placement_<item_id>.mp3`` and are
served by ``GET /api/v1/speech/audio/{filename}``.  The backend also generates
missing files on demand, but pre-rendering makes the first test instant.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA_FILE = ROOT / "backend" / "app" / "data" / "placement" / "listening.json"
AUDIO_DIR = ROOT / "backend" / "storage" / "audio"
VOICE = "en-US-AvaNeural"
RATE = "-2%"

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


async def _render(edge_tts: Any, item: dict[str, Any], force: bool) -> tuple[str, str]:
    item_id = str(item["id"])
    target = AUDIO_DIR / f"placement_{item_id}.mp3"
    if target.exists() and target.stat().st_size > 800 and not force:
        return item_id, "skipped"
    text = str(item.get("transcript") or "").strip()
    if not text:
        return item_id, "no-transcript"
    for attempt in range(3):
        try:
            communicate = edge_tts.Communicate(text, VOICE, rate=RATE)
            await communicate.save(str(target))
            if target.exists() and target.stat().st_size > 800:
                return item_id, "ok"
        except Exception as exc:  # noqa: BLE001 - retry network/tts errors
            if attempt == 2:
                return item_id, f"error: {exc}"
            await asyncio.sleep(1.5 * (attempt + 1))
    return item_id, "failed"


async def main_async(force: bool, only: set[str]) -> int:
    try:
        import edge_tts  # noqa: PLC0415
    except ImportError:
        print("Thiếu edge-tts. Cài bằng: pip install edge-tts")
        return 2

    payload = json.loads(DATA_FILE.read_text(encoding="utf-8"))
    items = [
        item
        for item in payload.get("items", [])
        if not only or str(item.get("id")) in only
    ]
    if not items:
        print("Không có item nào để tạo audio.")
        return 1

    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    semaphore = asyncio.Semaphore(3)

    async def worker(item: dict[str, Any]) -> tuple[str, str]:
        async with semaphore:
            return await _render(edge_tts, item, force)

    results = await asyncio.gather(*(worker(item) for item in items))
    ok = sum(1 for _, status in results if status == "ok")
    skipped = sum(1 for _, status in results if status == "skipped")
    failed = [(item_id, status) for item_id, status in results if status.startswith("error")]
    for item_id, status in failed:
        print(f"  FAIL {item_id}: {status}")
    print(f"Done: {ok} created, {skipped} skipped, {len(failed)} failed.")
    return 0 if not failed else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="Re-render existing files")
    parser.add_argument("--only", nargs="*", default=[], help="Only these item ids")
    args = parser.parse_args()
    return asyncio.run(main_async(args.force, set(args.only)))


if __name__ == "__main__":
    sys.exit(main())
