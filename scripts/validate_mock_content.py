"""Validate the IELTS mock-test content sets.

Scans ``backend/app/data/ielts_mock/*/`` and checks the structure described in
``docs/ielts_mock_test_contract.md``:

* ``meta.json`` has the required keys, a matching ``id``, a valid ``type`` and
  the four skills;
* listening has 4 parts and 40 unique questions numbered 1-40, each with a
  non-empty answer list, an explanation and a correctly shaped ``audio_url``;
* reading has 3 passages and 40 unique questions numbered 1-40 with answers and
  explanations;
* writing has Task 1 (150 words) and Task 2 (250 words) with non-empty prompts;
* speaking Part 1 has >= 3 topics x >= 4 questions, Part 2 has a cue card and
  >= 2 follow-ups, Part 3 has >= 4 questions;
* every JSON file parses, question IDs are globally unique and question
  numbers are unique within each skill.

Usage
-----
    python scripts/validate_mock_content.py
    python scripts/validate_mock_content.py --set academic_01

Exit code ``0`` = no errors (warnings allowed), ``1`` = at least one error.
The module is importable: ``validate_set(path)`` and ``validate_all(path)``
return JSON-serialisable report dicts.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA_DIR = ROOT / "backend" / "app" / "data" / "ielts_mock"

REQUIRED_SKILLS = ("listening", "reading", "writing", "speaking")
REQUIRED_FILES = (
    "meta.json",
    "listening.json",
    "reading.json",
    "writing.json",
    "speaking.json",
)
EXPECTED_MIN_WORDS = {1: 150, 2: 250}
EXPECTED_MINUTES = {1: 20, 2: 40}
EXPECTED_NUMBERS = set(range(1, 41))

_PART_NUMBER_RE = re.compile(r"(\d+)\s*$")


class SetReport:
    """Errors, warnings and counts collected while validating one set."""

    def __init__(self, set_id: str, directory: Path) -> None:
        self.set_id = set_id
        self.directory = Path(directory)
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.counts: dict[str, Any] = {}

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    @property
    def ok(self) -> bool:
        return not self.errors

    def as_dict(self) -> dict[str, Any]:
        return {
            "set_id": self.set_id,
            "directory": str(self.directory),
            "ok": self.ok,
            "errors": list(self.errors),
            "warnings": list(self.warnings),
            "counts": dict(self.counts),
        }


# ---------------------------------------------------------------------------
# Generic helpers
# ---------------------------------------------------------------------------


def _non_empty_str(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _short_list(values: list[Any], limit: int = 12) -> str:
    shown = [str(value) for value in values[:limit]]
    suffix = f" (+{len(values) - limit} more)" if len(values) > limit else ""
    return ", ".join(shown) + suffix


def _load_json(
    path: Path,
    report: SetReport,
    *,
    quiet_if_missing: bool = False,
) -> Any:
    if not path.is_file():
        if not quiet_if_missing:
            report.error(f"{path.name}: file not found")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        report.error(f"{path.name}: invalid JSON ({exc})")
    except OSError as exc:
        report.error(f"{path.name}: cannot read file ({exc})")
    return None


def _expected_audio_url(set_id: str, number: int) -> str:
    return f"/api/v1/speech/audio/ielts_{set_id}_part{number}.mp3"


def _part_number(part: dict[str, Any], fallback: int) -> int:
    match = _PART_NUMBER_RE.search(str(part.get("id") or ""))
    return int(match.group(1)) if match else fallback


def _check_question(
    question: Any,
    *,
    location: str,
    skill: str,
    report: SetReport,
    seen_ids: dict[str, str],
    numbers: set[int],
    option_keys: set[str],
    group_type: str | None,
) -> None:
    if not isinstance(question, dict):
        report.error(f"{location}: question is not a JSON object")
        return

    qid = question.get("id")
    if not _non_empty_str(qid):
        report.error(f"{location}: question has no non-empty 'id'")
        label = "?"
    else:
        label = str(qid).strip()
        if label in seen_ids:
            report.error(
                f"{location}: duplicate question id '{label}' "
                f"(already used at {seen_ids[label]})"
            )
        else:
            seen_ids[label] = location

    number = question.get("number")
    if isinstance(number, bool) or not isinstance(number, int):
        report.error(f"{location} ({label}): 'number' must be an integer")
    elif number not in EXPECTED_NUMBERS:
        report.error(f"{location} ({label}): number {number} outside 1-40")
    elif number in numbers:
        report.error(
            f"{location} ({label}): duplicate question number {number} in {skill}"
        )
    else:
        numbers.add(number)

    answer = question.get("answer")
    if not isinstance(answer, list):
        report.error(f"{location} ({label}): 'answer' must be a non-empty list")
    elif not [item for item in answer if isinstance(item, str) and item.strip()]:
        report.error(f"{location} ({label}): 'answer' list has no non-empty string")

    explanation = question.get("explanation")
    if not _non_empty_str(explanation):
        report.error(f"{location} ({label}): missing/empty 'explanation'")

    if not _non_empty_str(question.get("prompt")):
        report.warn(f"{location} ({label}): missing/empty 'prompt'")

    if group_type in {"mcq", "matching"} and option_keys:
        valid_keys = [
            item.strip().upper()
            for item in answer
            if isinstance(item, str) and item.strip()
        ] if isinstance(answer, list) else []
        if valid_keys and not all(key in option_keys for key in valid_keys):
            report.warn(
                f"{location} ({label}): answer {valid_keys} does not match any "
                f"option key {sorted(option_keys)}"
            )


def _check_groups(
    groups: Any,
    *,
    location: str,
    skill: str,
    report: SetReport,
    seen_ids: dict[str, str],
    group_ids: dict[str, str],
    numbers: set[int],
) -> int:
    """Validate a list of question groups and return the question count."""
    if not isinstance(groups, list) or not groups:
        report.error(f"{location}: missing or empty 'groups' list")
        return 0

    total = 0
    for index, group in enumerate(groups):
        group_location = f"{location} group[{index}]"
        if not isinstance(group, dict):
            report.error(f"{group_location}: group is not a JSON object")
            continue

        group_id = group.get("id")
        if _non_empty_str(group_id):
            group_id = str(group_id).strip()
            if group_id in group_ids:
                report.warn(
                    f"{group_location}: duplicate group id '{group_id}' "
                    f"(also at {group_ids[group_id]})"
                )
            else:
                group_ids[group_id] = group_location
        else:
            report.warn(f"{group_location}: group has no non-empty 'id'")

        group_type = group.get("type")
        if not _non_empty_str(group_type):
            report.warn(f"{group_location}: group has no 'type'")

        option_keys: set[str] = set()
        options = group.get("options")
        if isinstance(options, list):
            for option in options:
                if isinstance(option, dict) and option.get("key") is not None:
                    option_keys.add(str(option["key"]).strip().upper())

        questions = group.get("questions")
        if not isinstance(questions, list) or not questions:
            report.error(f"{group_location}: missing or empty 'questions' list")
            continue

        for q_index, question in enumerate(questions):
            _check_question(
                question,
                location=f"{group_location} q[{q_index}]",
                skill=skill,
                report=report,
                seen_ids=seen_ids,
                numbers=numbers,
                option_keys=option_keys,
                group_type=str(group_type).strip().lower() if group_type else None,
            )
            if isinstance(question, dict):
                total += 1

    return total


def _check_numbering(
    numbers: set[int],
    *,
    skill: str,
    total: int,
    report: SetReport,
) -> None:
    if total != 40:
        report.error(f"{skill}: expected exactly 40 questions, found {total}")
    missing = sorted(EXPECTED_NUMBERS - numbers)
    extra = sorted(numbers - EXPECTED_NUMBERS)
    if missing:
        report.error(
            f"{skill}: missing question numbers {_short_list(missing)}"
        )
    if extra:
        report.error(
            f"{skill}: question numbers outside 1-40 {_short_list(extra)}"
        )


# ---------------------------------------------------------------------------
# Per-skill validation
# ---------------------------------------------------------------------------


def _validate_meta(data: Any, set_id: str, report: SetReport) -> None:
    if not isinstance(data, dict):
        report.error("meta.json: root must be a JSON object")
        return

    for key in ("id", "type", "skills"):
        if key not in data:
            report.error(f"meta.json: missing required key '{key}'")

    if data.get("id") != set_id:
        report.error(
            f"meta.json: id {data.get('id')!r} does not match folder name {set_id!r}"
        )

    if data.get("type") not in {"academic", "general"}:
        report.error(
            f"meta.json: type must be 'academic' or 'general' "
            f"(got {data.get('type')!r})"
        )

    skills = data.get("skills")
    if not isinstance(skills, list):
        report.error("meta.json: 'skills' must be a list")
    else:
        normalised = [
            skill.strip().lower() for skill in skills if isinstance(skill, str)
        ]
        missing = [skill for skill in REQUIRED_SKILLS if skill not in normalised]
        if missing:
            report.error(f"meta.json: skills missing {_short_list(missing)}")
        unknown = [skill for skill in normalised if skill not in REQUIRED_SKILLS]
        if unknown:
            report.warn(f"meta.json: unknown skills {_short_list(unknown)}")
        if len(normalised) != len(set(normalised)):
            report.warn("meta.json: duplicate entries in 'skills'")

    for key in ("title", "description"):
        if not _non_empty_str(data.get(key)):
            report.warn(f"meta.json: missing/empty '{key}'")

    report.counts["type"] = data.get("type")


def _validate_listening(
    data: Any,
    set_id: str,
    report: SetReport,
    seen_ids: dict[str, str],
    group_ids: dict[str, str],
) -> None:
    if not isinstance(data, dict):
        report.error("listening.json: root must be a JSON object")
        return

    parts = data.get("parts")
    if not isinstance(parts, list):
        report.error("listening.json: 'parts' must be a list")
        return
    if len(parts) != 4:
        report.error(f"listening: expected 4 parts, found {len(parts)}")

    numbers: set[int] = set()
    total = 0
    for index, part in enumerate(parts, start=1):
        location = f"listening part[{index}]"
        if not isinstance(part, dict):
            report.error(f"{location}: part is not a JSON object")
            continue

        number = _part_number(part, index)
        if not _non_empty_str(part.get("id")):
            report.warn(f"{location}: part has no non-empty 'id'")

        expected_url = _expected_audio_url(set_id, number)
        audio_url = part.get("audio_url")
        if audio_url != expected_url:
            report.error(
                f"{location}: audio_url {audio_url!r} != expected {expected_url!r}"
            )

        if not _non_empty_str(part.get("transcript")):
            report.warn(
                f"{location}: missing/empty 'transcript' "
                "(audio generation will fail for this part)"
            )

        part_questions = _check_groups(
            part.get("groups"),
            location=location,
            skill="listening",
            report=report,
            seen_ids=seen_ids,
            group_ids=group_ids,
            numbers=numbers,
        )
        if part_questions != 10:
            report.warn(
                f"{location}: expected 10 questions, found {part_questions}"
            )
        total += part_questions

    _check_numbering(numbers, skill="listening", total=total, report=report)
    report.counts["listening"] = {"parts": len(parts), "questions": total}


def _validate_reading(
    data: Any,
    report: SetReport,
    seen_ids: dict[str, str],
    group_ids: dict[str, str],
) -> None:
    if not isinstance(data, dict):
        report.error("reading.json: root must be a JSON object")
        return

    passages = data.get("passages")
    if not isinstance(passages, list):
        report.error("reading.json: 'passages' must be a list")
        return
    if len(passages) != 3:
        report.error(f"reading: expected 3 passages, found {len(passages)}")

    numbers: set[int] = set()
    total = 0
    for index, passage in enumerate(passages, start=1):
        location = f"reading passage[{index}]"
        if not isinstance(passage, dict):
            report.error(f"{location}: passage is not a JSON object")
            continue
        if not _non_empty_str(passage.get("id")):
            report.warn(f"{location}: passage has no non-empty 'id'")
        if not _non_empty_str(passage.get("title")):
            report.warn(f"{location}: passage has no non-empty 'title'")
        if not _non_empty_str(passage.get("text")):
            report.warn(f"{location}: passage has no non-empty 'text'")

        total += _check_groups(
            passage.get("groups"),
            location=location,
            skill="reading",
            report=report,
            seen_ids=seen_ids,
            group_ids=group_ids,
            numbers=numbers,
        )

    _check_numbering(numbers, skill="reading", total=total, report=report)
    report.counts["reading"] = {"passages": len(passages), "questions": total}


def _validate_writing(data: Any, report: SetReport) -> None:
    if not isinstance(data, dict):
        report.error("writing.json: root must be a JSON object")
        return

    tasks = data.get("tasks")
    if not isinstance(tasks, list):
        report.error("writing.json: 'tasks' must be a list")
        return

    by_task: dict[int, dict[str, Any]] = {}
    min_words_seen: list[Any] = []
    for index, task in enumerate(tasks):
        location = f"writing task[{index}]"
        if not isinstance(task, dict):
            report.error(f"{location}: task is not a JSON object")
            continue

        task_number = task.get("task")
        if isinstance(task_number, bool) or task_number not in (1, 2):
            task_id = str(task.get("id") or "")
            if task_id.upper() in {"W1", "W2"}:
                task_number = int(task_id.upper()[1])
            else:
                report.error(
                    f"{location}: 'task' must be 1 or 2 (got {task_number!r})"
                )
                continue
        if task_number in by_task:
            report.error(f"{location}: duplicate Task {task_number}")
            continue
        by_task[task_number] = task
        min_words_seen.append(task.get("min_words"))

        expected_words = EXPECTED_MIN_WORDS[task_number]
        if task.get("min_words") != expected_words:
            report.error(
                f"{location} (Task {task_number}): min_words must be "
                f"{expected_words} (got {task.get('min_words')!r})"
            )

        if not _non_empty_str(task.get("prompt")):
            report.error(
                f"{location} (Task {task_number}): missing/empty 'prompt'"
            )

        if task.get("recommended_minutes") != EXPECTED_MINUTES[task_number]:
            report.warn(
                f"{location} (Task {task_number}): recommended_minutes is "
                f"{task.get('recommended_minutes')!r}, expected "
                f"{EXPECTED_MINUTES[task_number]}"
            )

        expected_id = f"W{task_number}"
        if str(task.get("id") or "").upper() != expected_id:
            report.warn(
                f"{location} (Task {task_number}): id should be '{expected_id}'"
            )

        sample = task.get("sample_answer")
        if not _non_empty_str(sample):
            report.warn(
                f"{location} (Task {task_number}): missing/empty 'sample_answer'"
            )

    for task_number in (1, 2):
        if task_number not in by_task:
            report.error(f"writing: missing Task {task_number}")

    report.counts["writing"] = {
        "tasks": len(tasks),
        "min_words": min_words_seen,
    }


def _validate_speaking(data: Any, report: SetReport) -> None:
    if not isinstance(data, dict):
        report.error("speaking.json: root must be a JSON object")
        return

    counts: dict[str, Any] = {}

    # Part 1: at least 3 topics, each with at least 4 questions.
    part1 = data.get("part1")
    topics = part1.get("topics") if isinstance(part1, dict) else None
    if not isinstance(topics, list) or len(topics) < 3:
        report.error(
            "speaking part1: expected at least 3 topics "
            f"(got {len(topics) if isinstance(topics, list) else 0})"
        )
        topics = topics if isinstance(topics, list) else []

    part1_questions = 0
    for index, topic in enumerate(topics):
        location = f"speaking part1 topic[{index}]"
        if not isinstance(topic, dict):
            report.error(f"{location}: topic is not a JSON object")
            continue
        if not _non_empty_str(topic.get("id")):
            report.warn(f"{location}: topic has no non-empty 'id'")
        if not _non_empty_str(topic.get("topic")):
            report.warn(f"{location}: topic has no non-empty 'topic' name")
        questions = topic.get("questions")
        if not isinstance(questions, list) or len(questions) < 4:
            report.error(
                f"{location}: expected at least 4 questions "
                f"(got {len(questions) if isinstance(questions, list) else 0})"
            )
            continue
        empty = [
            q_index
            for q_index, question in enumerate(questions)
            if not _non_empty_str(question)
        ]
        if empty:
            report.error(f"{location}: empty question(s) at index {_short_list(empty)}")
        part1_questions += len(questions)

    counts["part1_topics"] = len(topics)
    counts["part1_questions"] = part1_questions

    # Part 2: cue card + at least 2 follow-ups.
    part2 = data.get("part2")
    if not isinstance(part2, dict):
        report.error("speaking part2: missing or not an object")
    else:
        if not _non_empty_str(part2.get("cue_card")):
            report.error("speaking part2: missing/empty 'cue_card'")
        follow_ups = part2.get("follow_ups")
        if not isinstance(follow_ups, list) or len(follow_ups) < 2:
            report.error(
                "speaking part2: expected at least 2 follow_ups "
                f"(got {len(follow_ups) if isinstance(follow_ups, list) else 0})"
            )
            follow_up_count = len(follow_ups) if isinstance(follow_ups, list) else 0
        else:
            follow_up_count = len(follow_ups)
            empty = [
                index
                for index, question in enumerate(follow_ups)
                if not _non_empty_str(question)
            ]
            if empty:
                report.error(
                    "speaking part2: empty follow_up(s) at index "
                    f"{_short_list(empty)}"
                )
        prompts = part2.get("prompts")
        if not isinstance(prompts, list) or len(prompts) < 4:
            report.warn(
                "speaking part2: expected 4 cue-card prompts "
                f"(got {len(prompts) if isinstance(prompts, list) else 0})"
            )
        for key in ("prep_seconds", "speak_seconds"):
            if not isinstance(part2.get(key), int):
                report.warn(f"speaking part2: missing integer '{key}'")
        counts["part2_follow_ups"] = follow_up_count

    # Part 3: at least 4 discussion questions.
    part3 = data.get("part3")
    questions = part3.get("questions") if isinstance(part3, dict) else None
    if not isinstance(questions, list) or len(questions) < 4:
        report.error(
            "speaking part3: expected at least 4 questions "
            f"(got {len(questions) if isinstance(questions, list) else 0})"
        )
        part3_count = len(questions) if isinstance(questions, list) else 0
    else:
        part3_count = len(questions)
        empty = [
            index
            for index, question in enumerate(questions)
            if not _non_empty_str(question)
        ]
        if empty:
            report.error(
                f"speaking part3: empty question(s) at index {_short_list(empty)}"
            )
    counts["part3_questions"] = part3_count

    report.counts["speaking"] = counts


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def validate_set(set_dir: Path) -> dict[str, Any]:
    """Validate one content set folder and return a JSON-serialisable report."""
    set_dir = Path(set_dir)
    report = SetReport(set_dir.name, set_dir)

    if not set_dir.is_dir():
        report.error(f"Set directory not found: {set_dir}")
        return report.as_dict()

    missing_files = [
        name for name in REQUIRED_FILES if not (set_dir / name).is_file()
    ]
    if missing_files:
        report.error(f"Missing required file(s): {_short_list(missing_files)}")
    missing = set(missing_files)

    meta = _load_json(
        set_dir / "meta.json", report, quiet_if_missing="meta.json" in missing
    )
    if meta is not None:
        _validate_meta(meta, set_dir.name, report)

    seen_ids: dict[str, str] = {}
    group_ids: dict[str, str] = {}

    listening = _load_json(
        set_dir / "listening.json",
        report,
        quiet_if_missing="listening.json" in missing,
    )
    if listening is not None:
        _validate_listening(
            listening, set_dir.name, report, seen_ids, group_ids
        )

    reading = _load_json(
        set_dir / "reading.json",
        report,
        quiet_if_missing="reading.json" in missing,
    )
    if reading is not None:
        _validate_reading(reading, report, seen_ids, group_ids)

    writing = _load_json(
        set_dir / "writing.json",
        report,
        quiet_if_missing="writing.json" in missing,
    )
    if writing is not None:
        _validate_writing(writing, report)

    speaking = _load_json(
        set_dir / "speaking.json",
        report,
        quiet_if_missing="speaking.json" in missing,
    )
    if speaking is not None:
        _validate_speaking(speaking, report)

    return report.as_dict()


def validate_all(
    data_dir: Path = DEFAULT_DATA_DIR,
    only: str | None = None,
) -> list[dict[str, Any]]:
    """Validate every set under ``data_dir`` (or only ``only``)."""
    data_dir = Path(data_dir)
    if not data_dir.is_dir():
        report = SetReport("(content root)", data_dir)
        report.error(f"Content directory not found: {data_dir}")
        return [report.as_dict()]

    all_dirs = sorted(path for path in data_dir.iterdir() if path.is_dir())
    if only:
        set_dirs = [path for path in all_dirs if path.name == only]
        if not set_dirs:
            report = SetReport(only, data_dir / only)
            available = [path.name for path in all_dirs]
            report.error(
                f"Set '{only}' not found under {data_dir}. "
                f"Available: {_short_list(available) if available else 'none'}"
            )
            return [report.as_dict()]
    else:
        set_dirs = all_dirs

    if not set_dirs:
        report = SetReport("(content root)", data_dir)
        report.error(f"No content sets found under {data_dir}")
        return [report.as_dict()]

    return [validate_set(path) for path in set_dirs]


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _format_counts(report: dict[str, Any]) -> list[str]:
    counts = report.get("counts") or {}
    lines: list[str] = []

    listening = counts.get("listening")
    if isinstance(listening, dict):
        lines.append(
            f"listening: {listening.get('parts', 0)} parts, "
            f"{listening.get('questions', 0)} questions"
        )

    reading = counts.get("reading")
    if isinstance(reading, dict):
        lines.append(
            f"reading: {reading.get('passages', 0)} passages, "
            f"{reading.get('questions', 0)} questions"
        )

    writing = counts.get("writing")
    if isinstance(writing, dict):
        min_words = "/".join(str(value) for value in writing.get("min_words", []))
        lines.append(
            f"writing: {writing.get('tasks', 0)} tasks"
            + (f" ({min_words} words)" if min_words else "")
        )

    speaking = counts.get("speaking")
    if isinstance(speaking, dict):
        lines.append(
            f"speaking: {speaking.get('part1_topics', 0)} part-1 topics "
            f"({speaking.get('part1_questions', 0)} questions), "
            f"{speaking.get('part2_follow_ups', 0)} part-2 follow-ups, "
            f"{speaking.get('part3_questions', 0)} part-3 questions"
        )

    return lines


def _print_report(report: dict[str, Any]) -> None:
    status = "OK" if report.get("ok") else "FAIL"
    print(f"[{status}] {report.get('set_id')}")

    for line in _format_counts(report):
        print(f"  {line}")

    for message in report.get("errors", []):
        print(f"  ERROR: {message}")
    for message in report.get("warnings", []):
        print(f"  WARN:  {message}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate IELTS mock-test content sets.",
    )
    parser.add_argument(
        "--set",
        dest="set_id",
        default=None,
        help="Validate only this set id, e.g. academic_01 (default: all sets).",
    )
    parser.add_argument(
        "--data-dir",
        default=None,
        help=(
            "Content root directory (default: "
            "backend/app/data/ielts_mock)."
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    data_dir = Path(args.data_dir) if args.data_dir else DEFAULT_DATA_DIR

    reports = validate_all(data_dir, args.set_id)
    for report in reports:
        _print_report(report)
        print()

    error_count = sum(len(report.get("errors", [])) for report in reports)
    warning_count = sum(len(report.get("warnings", [])) for report in reports)
    print(
        f"Checked {len(reports)} set(s): "
        f"{error_count} error(s), {warning_count} warning(s)."
    )
    return 0 if error_count == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
