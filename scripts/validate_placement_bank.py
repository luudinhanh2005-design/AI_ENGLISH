"""Validate the CEFR placement content bank before shipping it.

Usage:
    python scripts/validate_placement_bank.py

Exit code 0 means the bank is structurally sound and balanced.
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "backend" / "app" / "data" / "placement"

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

LEVELS = ["A1", "A2", "B1", "B2", "C1", "C2"]
RECEPTIVE = {
    "listening": "ls",
    "reading": "rd",
    "use_of_english": "ue",
}
EXPECTED_RECEPTIVE = {level: 5 for level in LEVELS}
EXPECTED_WRITING = 2
EXPECTED_SPEAKING = 3


def load(name: str) -> dict[str, Any]:
    path = DATA_DIR / name
    if not path.exists():
        raise AssertionError(f"Thiếu file: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise AssertionError(f"JSON lỗi trong {path}: {exc}") from exc


def validate_receptive(skill: str, prefix: str, payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    items = payload.get("items") or []
    counts = Counter()
    seen: set[str] = set()
    for index, item in enumerate(items, start=1):
        item_id = str(item.get("id") or "")
        label = item_id or f"{skill}#{index}"
        if not item_id:
            errors.append(f"{skill}: item #{index} thiếu id")
        if item_id in seen:
            errors.append(f"{skill}: id trùng {item_id}")
        seen.add(item_id)
        if not item_id.startswith(f"{prefix}_"):
            errors.append(f"{label}: id phải bắt đầu bằng '{prefix}_'")
        if item.get("skill") != skill:
            errors.append(f"{label}: skill phải là '{skill}'")
        level = str(item.get("level") or "")
        if level not in LEVELS:
            errors.append(f"{label}: level không hợp lệ ({level})")
            continue
        counts[level] += 1

        options = item.get("options") or []
        if len(options) < 3:
            errors.append(f"{label}: cần ít nhất 3 lựa chọn")
        keys = [str(option.get("key") or "") for option in options]
        if len(keys) != len(set(keys)):
            errors.append(f"{label}: option key bị trùng")
        answer = item.get("answer") or []
        if not answer:
            errors.append(f"{label}: thiếu answer")
        for key in answer:
            if str(key) not in keys and item.get("type") not in {"short_answer"}:
                errors.append(f"{label}: answer '{key}' không có trong options")

        if skill == "listening":
            if not item.get("transcript"):
                errors.append(f"{label}: listening thiếu transcript")
            if not item.get("audio_url"):
                errors.append(f"{label}: listening thiếu audio_url")
        if skill == "reading":
            passage = item.get("passage") or {}
            if not passage.get("text"):
                errors.append(f"{label}: reading thiếu passage.text")
            if len(str(passage.get("text", "")).split()) < 30:
                errors.append(f"{label}: passage quá ngắn")

        if not item.get("explanation_vi"):
            errors.append(f"{label}: thiếu explanation_vi")

    for level in LEVELS:
        if counts[level] != EXPECTED_RECEPTIVE[level]:
            errors.append(
                f"{skill}: level {level} có {counts[level]} câu, cần {EXPECTED_RECEPTIVE[level]}"
            )
    return errors


def validate_writing(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    tasks = payload.get("tasks") or []
    counts = Counter()
    seen: set[str] = set()
    for index, task in enumerate(tasks, start=1):
        task_id = str(task.get("id") or "")
        label = task_id or f"writing#{index}"
        if not task_id:
            errors.append(f"writing: task #{index} thiếu id")
        if task_id in seen:
            errors.append(f"writing: id trùng {task_id}")
        seen.add(task_id)
        if not task_id.startswith("wr_"):
            errors.append(f"{label}: id phải bắt đầu bằng 'wr_'")
        level = str(task.get("level") or "")
        if level not in LEVELS:
            errors.append(f"{label}: level không hợp lệ")
            continue
        counts[level] += 1
        if not task.get("prompt"):
            errors.append(f"{label}: thiếu prompt")
        min_words = int(task.get("min_words") or 0)
        max_words = int(task.get("max_words") or 0)
        if min_words <= 0 or max_words < min_words:
            errors.append(f"{label}: giới hạn từ không hợp lệ")
        if int(task.get("time_minutes") or 0) <= 0:
            errors.append(f"{label}: time_minutes phải > 0")
    for level in LEVELS:
        if counts[level] != EXPECTED_WRITING:
            errors.append(
                f"writing: level {level} có {counts[level]} đề, cần {EXPECTED_WRITING}"
            )
    return errors


def validate_speaking(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    tasks = payload.get("tasks") or []
    counts = Counter()
    seen: set[str] = set()
    for index, task in enumerate(tasks, start=1):
        task_id = str(task.get("id") or "")
        label = task_id or f"speaking#{index}"
        if not task_id:
            errors.append(f"speaking: task #{index} thiếu id")
        if task_id in seen:
            errors.append(f"speaking: id trùng {task_id}")
        seen.add(task_id)
        if not task_id.startswith("sp_"):
            errors.append(f"{label}: id phải bắt đầu bằng 'sp_'")
        level = str(task.get("level") or "")
        if level not in LEVELS:
            errors.append(f"{label}: level không hợp lệ")
            continue
        counts[level] += 1
        if not task.get("prompt"):
            errors.append(f"{label}: thiếu prompt")
        if int(task.get("prep_seconds") or 0) <= 0:
            errors.append(f"{label}: prep_seconds phải > 0")
        if int(task.get("response_seconds") or 0) <= 0:
            errors.append(f"{label}: response_seconds phải > 0")
        if task.get("type") == "read_aloud" and not task.get("reference_text"):
            errors.append(f"{label}: read_aloud thiếu reference_text")
    for level in LEVELS:
        if counts[level] != EXPECTED_SPEAKING:
            errors.append(
                f"speaking: level {level} có {counts[level]} nhiệm vụ, cần {EXPECTED_SPEAKING}"
            )
    return errors


def validate_manifest(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    modes = payload.get("modes") or {}
    for mode in ("quick", "standard", "full"):
        config = modes.get(mode)
        if not isinstance(config, dict):
            errors.append(f"manifest: thiếu mode '{mode}'")
            continue
        if int(config.get("stages") or 0) <= 0:
            errors.append(f"manifest: mode {mode} stages phải > 0")
        if int(config.get("items_per_stage") or 0) <= 0:
            errors.append(f"manifest: mode {mode} items_per_stage phải > 0")
    cut_scores = payload.get("cut_scores") or {}
    for level in ("A2", "B1", "B2", "C1", "C2"):
        if level not in cut_scores:
            errors.append(f"manifest: thiếu cut score '{level}'")
    if not payload.get("exam_mapping"):
        errors.append("manifest: thiếu exam_mapping")
    return errors


def main() -> int:
    print(f"Placement data: {DATA_DIR}")
    errors: list[str] = []
    try:
        errors += validate_manifest(load("manifest.json"))
        for skill, prefix in RECEPTIVE.items():
            errors += validate_receptive(skill, prefix, load(f"{skill}.json"))
        errors += validate_writing(load("writing.json"))
        errors += validate_speaking(load("speaking.json"))
        can_do = load("can_do.json")
        for level in LEVELS:
            descriptors = (can_do.get("descriptors") or {}).get(level) or {}
            for skill in ("listening", "reading", "use_of_english", "writing", "speaking"):
                if not descriptors.get(skill):
                    errors.append(f"can_do: {level}/{skill} thiếu mô tả")
    except AssertionError as exc:
        print(f"ERROR: {exc}")
        return 1

    if errors:
        print(f"\n{len(errors)} lỗi:")
        for error in errors:
            print(f" - {error}")
        return 1

    print("OK: 90 câu tiếp nhận, 12 đề viết, 18 nhiệm vụ nói, manifest và can-do hợp lệ.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
