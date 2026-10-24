"""Generate the IELTS mock-test listening audio files with edge-tts.

Each part of ``listening.json`` is rendered into a single flat mp3 file placed
in ``backend/storage/audio`` so that the existing
``GET /api/v1/speech/audio/{filename}`` route can serve it:

    backend/storage/audio/ielts_<set_id>_part<N>.mp3

Usage
-----
    python scripts/generate_listening_audio.py --set academic_01
    python scripts/generate_listening_audio.py --set academic_01 --part 2
    python scripts/generate_listening_audio.py --set academic_01 --force

Exit codes: ``0`` success, ``1`` content/IO error, ``2`` missing edge-tts.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA_ROOT = ROOT / "backend" / "app" / "data" / "ielts_mock"
AUDIO_DIR = ROOT / "backend" / "storage" / "audio"

DEFAULT_VOICE = "en-GB-SoniaNeural"
DEFAULT_RATE = "+0%"

AUDIO_FILENAME_TEMPLATE = "ielts_{set_id}_part{number}.mp3"
AUDIO_URL_TEMPLATE = "/api/v1/speech/audio/ielts_{set_id}_part{number}.mp3"

INSTALL_HINT = (
    "edge-tts is not installed. Install it with:\n"
    "    pip install edge-tts\n"
    "Everything else in the project already uses edge-tts, so no other "
    "dependency is required."
)


class ContentError(RuntimeError):
    """Raised when the listening content is missing or malformed."""


class MissingDependencyError(RuntimeError):
    """Raised when edge-tts is not importable."""


def _load_edge_tts() -> Any:
    try:
        import edge_tts  # noqa: PLC0415 - optional dependency, imported lazily
    except ImportError as exc:  # pragma: no cover - depends on environment
        raise MissingDependencyError(INSTALL_HINT) from exc
    return edge_tts


def audio_filename(set_id: str, number: int) -> str:
    return AUDIO_FILENAME_TEMPLATE.format(set_id=set_id, number=number)


def expected_audio_url(set_id: str, number: int) -> str:
    return AUDIO_URL_TEMPLATE.format(set_id=set_id, number=number)


def part_number(part: dict[str, Any], fallback: int) -> int:
    """Return the 1-based part number (``L2`` -> 2, otherwise list position)."""
    part_id = str(part.get("id") or "")
    match = re.search(r"(\d+)\s*$", part_id)
    if match:
        return int(match.group(1))
    return fallback


def load_listening(set_id: str, data_root: Path = DATA_ROOT) -> dict[str, Any]:
    """Load ``listening.json`` for a set, raising a friendly ``ContentError``."""
    path = Path(data_root) / set_id / "listening.json"
    if not path.is_file():
        available = sorted(
            item.name
            for item in Path(data_root).iterdir()
            if item.is_dir()
        ) if Path(data_root).is_dir() else []
        hint = f" Available sets: {', '.join(available)}." if available else ""
        raise ContentError(f"Listening file not found: {path}.{hint}")

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ContentError(f"Invalid JSON in {path}: {exc}") from exc

    if not isinstance(data, dict):
        raise ContentError(f"{path} must contain a JSON object.")
    parts = data.get("parts")
    if not isinstance(parts, list) or not parts:
        raise ContentError(f"{path} has no 'parts' list.")
    return data


def _format_size(size_bytes: int) -> str:
    if size_bytes >= 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.2f} MB"
    if size_bytes >= 1024:
        return f"{size_bytes / 1024:.1f} KB"
    return f"{size_bytes} B"


async def generate_part(
    part: dict[str, Any],
    number: int,
    set_id: str,
    *,
    audio_dir: Path = AUDIO_DIR,
    force: bool = False,
    voice: str = DEFAULT_VOICE,
    rate: str = DEFAULT_RATE,
) -> dict[str, Any]:
    """Render one listening part to mp3.

    Returns a result dict with ``number``, ``path``, ``status``
    (``generated``/``skipped``), ``size`` and ``chars``.  Raises
    ``ContentError`` when the transcript is missing and
    ``MissingDependencyError`` when edge-tts is unavailable.
    """
    transcript = part.get("transcript")
    if not isinstance(transcript, str) or not transcript.strip():
        raise ContentError(
            f"Part {number}: 'transcript' is missing or empty - cannot generate audio."
        )
    text = transcript.replace("\x00", " ").strip()

    target_dir = Path(audio_dir)
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / audio_filename(set_id, number)

    if target.exists() and not force:
        return {
            "number": number,
            "path": target,
            "status": "skipped",
            "size": target.stat().st_size,
            "chars": len(text),
        }

    edge_tts = _load_edge_tts()
    tmp_path = target.with_name(target.name + ".tmp")
    try:
        communicate = edge_tts.Communicate(text, voice=voice, rate=rate)
        await communicate.save(str(tmp_path))
        if not tmp_path.is_file() or tmp_path.stat().st_size == 0:
            raise ContentError(
                f"Part {number}: edge-tts produced no audio "
                "(check the network connection and try again)."
            )
        tmp_path.replace(target)
    finally:
        if tmp_path.exists():
            try:
                tmp_path.unlink()
            except OSError:
                pass

    return {
        "number": number,
        "path": target,
        "status": "generated",
        "size": target.stat().st_size,
        "chars": len(text),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate IELTS mock-test listening audio (one mp3 per part).",
    )
    parser.add_argument(
        "--set",
        required=True,
        dest="set_id",
        help="Content set id, e.g. academic_01 (folder under backend/app/data/ielts_mock).",
    )
    parser.add_argument(
        "--part",
        type=int,
        default=None,
        help="Only generate one part (1-4). Default: all parts.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing mp3 files.",
    )
    parser.add_argument(
        "--voice",
        default=DEFAULT_VOICE,
        help=f"edge-tts voice name (default: {DEFAULT_VOICE}).",
    )
    parser.add_argument(
        "--rate",
        default=DEFAULT_RATE,
        help=f"edge-tts speaking rate (default: {DEFAULT_RATE}).",
    )
    return parser


async def _run(args: argparse.Namespace) -> int:
    try:
        _load_edge_tts()
    except MissingDependencyError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    if args.part is not None and not 1 <= args.part <= 4:
        print(f"--part must be between 1 and 4 (got {args.part}).", file=sys.stderr)
        return 1

    try:
        data = load_listening(args.set_id, DATA_ROOT)
    except ContentError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    parts: list[dict[str, Any]] = data["parts"]
    numbered: list[tuple[int, dict[str, Any]]] = []
    for index, part in enumerate(parts, start=1):
        if not isinstance(part, dict):
            print(f"ERROR: part #{index} is not a JSON object.", file=sys.stderr)
            return 1
        numbered.append((part_number(part, index), part))

    numbers = [number for number, _ in numbered]
    if len(set(numbers)) != len(numbers):
        print(f"ERROR: duplicate part numbers in listening.json: {numbers}", file=sys.stderr)
        return 1

    selected = [
        (number, part)
        for number, part in numbered
        if args.part is None or number == args.part
    ]
    if not selected:
        print(
            f"ERROR: part {args.part} not found (available: "
            f"{', '.join(str(n) for n in numbers)}).",
            file=sys.stderr,
        )
        return 1

    print(
        f"Set '{args.set_id}': {len(selected)} part(s) -> {AUDIO_DIR}",
        flush=True,
    )
    print(f"Voice: {args.voice}  Rate: {args.rate}", flush=True)

    generated = 0
    skipped = 0
    failed = 0

    for number, part in selected:
        title = part.get("title") or f"Part {number}"
        expected_url = expected_audio_url(args.set_id, number)
        actual_url = part.get("audio_url")
        if actual_url != expected_url:
            print(
                f"  WARN part {number}: audio_url is {actual_url!r}, "
                f"expected {expected_url!r}.",
                flush=True,
            )

        chars = len(str(part.get("transcript") or "").strip())
        print(
            f"  Part {number} ({title}): {chars:,} characters of transcript.",
            flush=True,
        )
        try:
            result = await generate_part(
                part,
                number,
                args.set_id,
                audio_dir=AUDIO_DIR,
                force=args.force,
                voice=args.voice,
                rate=args.rate,
            )
        except ContentError as exc:
            print(f"  FAIL part {number}: {exc}", file=sys.stderr, flush=True)
            failed += 1
            continue
        except Exception as exc:  # noqa: BLE001 - report and continue other parts
            print(f"  FAIL part {number}: {exc}", file=sys.stderr, flush=True)
            failed += 1
            continue

        if result["status"] == "skipped":
            skipped += 1
            print(
                f"  SKIP part {number}: {result['path'].name} already exists "
                f"({_format_size(result['size'])}). Use --force to overwrite.",
                flush=True,
            )
        else:
            generated += 1
            print(
                f"  OK   part {number}: {result['path'].name} "
                f"({_format_size(result['size'])})",
                flush=True,
            )

    print(
        f"Done: {generated} generated, {skipped} skipped, {failed} failed.",
        flush=True,
    )
    return 0 if failed == 0 else 1


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return asyncio.run(_run(args))
    except KeyboardInterrupt:
        print("Interrupted.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
