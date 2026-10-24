"""Validate the local A1-C2 grammar JSON assets.

Usage:
    python scripts/validate_grammar.py

Exit code 0 = all checks passed, 1 = at least one error.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "english_ai" / "assets" / "data" / "grammar"
LEVELS = ["A1", "A2", "B1", "B2", "C1", "C2"]
FILES = {level: DATA / f"{level.lower()}.json" for level in LEVELS}

REQUIRED_STRINGS = [
    "id",
    "title",
    "title_vi",
    "level",
    "category",
    "description",
    "formula_affirmative",
    "formula_negative",
    "formula_question",
]
REQUIRED_LISTS = ["time_markers", "usage_rules", "examples", "common_mistakes", "quiz"]

errors: list[str] = []
warnings: list[str] = []
global_questions: dict[str, tuple[str, str, int]] = {}


def err(message: str) -> None:
    errors.append(message)


def warn(message: str) -> None:
    warnings.append(message)


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        err(f"Missing file: {path}")
    except json.JSONDecodeError as exc:
        err(f"Invalid JSON in {path}: {exc}")
    return None


def validate_lesson(level: str, index: int, lesson: dict, curriculum: dict) -> None:
    where = f"{level}[{index}]"
    if not isinstance(lesson, dict):
        err(f"{where}: lesson is not an object")
        return
    lesson_id = str(lesson.get("id", "?"))

    blob = json.dumps(lesson, ensure_ascii=False).lower()
    for token in ("todo", "lorem ipsum", "placeholder", "\ufffd"):
        if token in blob:
            err(f"{where} ({lesson_id}): forbidden placeholder/mojibake token {token!r}")

    for key in REQUIRED_STRINGS:
        value = lesson.get(key)
        if not isinstance(value, str) or not value.strip():
            err(f"{where}: missing/empty string field '{key}'")

    expected = curriculum.get(lesson.get("id"))
    if expected is None:
        err(f"{where}: id '{lesson.get('id')}' is not in curriculum.json")
    else:
        for key in ("title", "title_vi", "level", "category"):
            if lesson.get(key) != expected.get(key):
                err(
                    f"{where}: '{key}' mismatch for {lesson.get('id')}: "
                    f"{lesson.get(key)!r} != {expected.get(key)!r}"
                )

    if lesson.get("level") != level:
        err(f"{where}: level is {lesson.get('level')!r}, expected {level!r}")

    for key in REQUIRED_LISTS:
        value = lesson.get(key)
        if not isinstance(value, list) or not value:
            err(f"{where}: missing/empty list field '{key}'")

    time_markers = lesson.get("time_markers", [])
    if isinstance(time_markers, list) and not (3 <= len(time_markers) <= 6):
        err(f"{where}: time_markers must have 3-6 items, got {len(time_markers)}")

    for key in ("usage_rules", "common_mistakes"):
        value = lesson.get(key, [])
        if isinstance(value, list) and not (3 <= len(value) <= 5):
            err(f"{where}: {key} must have 3-5 items, got {len(value)}")

    for key in ("time_markers", "usage_rules", "common_mistakes"):
        value = lesson.get(key, [])
        if isinstance(value, list):
            for j, item in enumerate(value):
                if not isinstance(item, str) or not item.strip():
                    err(f"{where}.{key}[{j}]: empty/non-string item")

    examples = lesson.get("examples", [])
    if isinstance(examples, list):
        if not (3 <= len(examples) <= 5):
            err(f"{where}: examples must have 3-5 items, got {len(examples)}")
        for j, example in enumerate(examples):
            if not isinstance(example, dict):
                err(f"{where}.examples[{j}]: not an object")
                continue
            for key in ("english", "vietnamese"):
                if not isinstance(example.get(key), str) or not example[key].strip():
                    err(f"{where}.examples[{j}]: missing/empty '{key}'")

    quiz = lesson.get("quiz", [])
    if isinstance(quiz, list):
        if len(quiz) != 5:
            err(f"{where}: quiz must have exactly 5 questions, got {len(quiz)}")
        seen_questions: set[str] = set()
        for j, question in enumerate(quiz):
            qwhere = f"{where}.quiz[{j}]"
            if not isinstance(question, dict):
                err(f"{qwhere}: not an object")
                continue
            text = question.get("question")
            if not isinstance(text, str) or not text.strip():
                err(f"{qwhere}: missing/empty question")
            elif text.strip().lower() in seen_questions:
                err(f"{qwhere}: duplicate question text")
            else:
                key = text.strip().lower()
                seen_questions.add(key)
                if key in global_questions:
                    other_level, other_lesson, other_index = global_questions[key]
                    err(
                        f"{qwhere}: duplicate of {other_level} "
                        f"{other_lesson} quiz[{other_index}]"
                    )
                else:
                    global_questions[key] = (level, lesson_id, j)

            options = question.get("options")
            if not isinstance(options, list) or len(options) != 4:
                err(f"{qwhere}: options must be a list of exactly 4 strings")
            else:
                if any(not isinstance(o, str) or not o.strip() for o in options):
                    err(f"{qwhere}: options contain empty/non-string values")
                if len(set(options)) != 4:
                    err(f"{qwhere}: options must be unique")

            correct = question.get("correct_index")
            if not isinstance(correct, int) or not (0 <= correct <= 3):
                err(f"{qwhere}: correct_index must be an integer 0-3")

            explanation = question.get("explanation")
            if not isinstance(explanation, str) or not explanation.strip():
                err(f"{qwhere}: missing/empty explanation")


def main() -> int:
    curriculum_raw = load_json(DATA / "curriculum.json")
    if curriculum_raw is None:
        print("\n".join(errors))
        return 1
    curriculum = {item["id"]: item for item in curriculum_raw if isinstance(item, dict)}
    if len(curriculum) != len(curriculum_raw):
        err("curriculum.json contains duplicate ids")

    expected_counts = {level: 0 for level in LEVELS}
    for item in curriculum.values():
        level = item.get("level")
        if level not in expected_counts:
            err(f"curriculum.json: invalid level {level!r} for {item.get('id')}")
        else:
            expected_counts[level] += 1

    all_ids: set[str] = set()
    total_lessons = 0
    total_quiz = 0
    total_examples = 0

    for level in LEVELS:
        path = FILES[level]
        data = load_json(path)
        if data is None:
            continue
        if not isinstance(data, list):
            err(f"{path.name}: top-level value must be an array")
            continue
        if len(data) != expected_counts[level]:
            err(
                f"{path.name}: expected {expected_counts[level]} lessons, "
                f"got {len(data)}"
            )
        total_lessons += len(data)
        for index, lesson in enumerate(data):
            if isinstance(lesson, dict):
                lesson_id = lesson.get("id")
                if lesson_id in all_ids:
                    err(f"{path.name}[{index}]: duplicate id {lesson_id!r}")
                elif isinstance(lesson_id, str):
                    all_ids.add(lesson_id)
                total_quiz += len(lesson.get("quiz", [])) if isinstance(lesson.get("quiz"), list) else 0
                total_examples += len(lesson.get("examples", [])) if isinstance(lesson.get("examples"), list) else 0
            validate_lesson(level, index, lesson, curriculum)

    missing_ids = set(curriculum) - all_ids
    extra_ids = all_ids - set(curriculum)
    for lesson_id in sorted(missing_ids):
        err(f"Missing lesson from JSON files: {lesson_id}")
    for lesson_id in sorted(extra_ids):
        err(f"Unexpected lesson id in JSON files: {lesson_id}")

    if total_lessons != 96:
        err(f"Total lessons must be 96, got {total_lessons}")
    if total_quiz != 480:
        err(f"Total quiz questions must be 480 (5 x 96), got {total_quiz}")

    print(f"Lessons: {total_lessons}/96")
    print(f"Quiz questions: {total_quiz}/480")
    print(f"Examples: {total_examples}")
    for level in LEVELS:
        print(f"  {level}: {expected_counts[level]} expected")
    if warnings:
        print("\nWarnings:")
        for message in warnings:
            print(f"  - {message}")
    if errors:
        print(f"\n{len(errors)} error(s):")
        for message in errors:
            print(f"  - {message}")
        return 1
    print("\nAll grammar checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
