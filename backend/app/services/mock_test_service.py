"""IELTS Mock Test service.

Responsibilities:
* load mock-test content from ``app/data/ielts_mock/<set_id>/``
* sanitize content before it reaches the client (no answer keys)
* grade listening/reading answers and map raw scores to IELTS bands
* orchestrate attempt lifecycle (works with or without a database)
* delegate writing/speaking evaluation to the AI services with local fallbacks

Everything in the grading section is a pure function so it can be unit tested
without FastAPI, a database, or the content files.
"""

from __future__ import annotations

import copy
import inspect
import json
import logging
import math
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Optional
from uuid import UUID, uuid4

import asyncio

from sqlalchemy.ext.asyncio import AsyncSession

from ..models.mock_test import MockTestAttempt

logger = logging.getLogger(__name__)

ALL_SKILLS: tuple[str, ...] = ("listening", "reading", "writing", "speaking")
SECTION_FILES: dict[str, str] = {skill: f"{skill}.json" for skill in ALL_SKILLS}
CONCEALED_KEYS: frozenset[str] = frozenset(
    {"answer", "alternatives", "explanation", "transcript", "sample_answer"}
)
MODES = {"strict", "practice"}


# ──────────────────────────────────────────────
# Errors
# ──────────────────────────────────────────────


class MockTestError(ValueError):
    """Base error for clean, client-safe mock-test failures."""


class MockTestNotFound(MockTestError):
    """Set or attempt could not be found (maps to HTTP 404)."""


class InvalidSkillError(MockTestError):
    """Skill is not part of the set/attempt (maps to HTTP 400)."""


class AttemptAccessDenied(MockTestError):
    """Attempt belongs to another user (maps to HTTP 403)."""


class IncompleteAttemptError(MockTestError):
    """Some planned sections have not been submitted (maps to HTTP 400)."""

    def __init__(self, missing: Iterable[str]):
        self.missing = list(missing)
        super().__init__(f"Missing section scores: {', '.join(self.missing)}")


# ──────────────────────────────────────────────
# Content loading
# ──────────────────────────────────────────────


def data_root() -> Path:
    """Directory holding mock-test sets, resolved relative to this file."""
    return Path(__file__).resolve().parent.parent / "data" / "ielts_mock"


def _read_json(path: Path) -> dict:
    if not path.is_file():
        raise MockTestNotFound(f"Missing mock-test file: {path.name}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise MockTestError(f"Invalid mock-test file: {path.name}") from exc
    if not isinstance(payload, dict):
        raise MockTestError(f"Invalid mock-test file: {path.name}")
    return payload


def _resolve_root(root: Path | str | None = None) -> Path:
    return Path(root) if root is not None else data_root()


def _safe_set_id(set_id: str) -> str:
    value = str(set_id or "").strip()
    if not value or not re.fullmatch(r"[A-Za-z0-9_\-]+", value):
        raise MockTestNotFound(f"Mock test set not found: {set_id}")
    return value


def _declared_skills(meta: dict) -> list[str]:
    """Skills declared by ``meta.json`` (canonical order, known skills only)."""
    raw = meta.get("skills")
    if isinstance(raw, list) and raw:
        skills = [str(skill).lower() for skill in raw if str(skill).lower() in ALL_SKILLS]
    else:
        skills = list(ALL_SKILLS)
    if not skills:
        skills = list(ALL_SKILLS)
    # Preserve canonical order for stable UI navigation.
    return [skill for skill in ALL_SKILLS if skill in skills]


def _section_payload(folder: Path, skill: str) -> dict:
    return _read_json(folder / SECTION_FILES[skill])


def _duration_seconds(section: Optional[dict]) -> int:
    if not isinstance(section, dict):
        return 0
    try:
        return int(section.get("duration_seconds") or 0)
    except (TypeError, ValueError):
        return 0


def _duration_minutes(meta: dict, folder: Path) -> int:
    total = 0
    listening = None
    for skill in ALL_SKILLS:
        try:
            section = _section_payload(folder, skill)
        except MockTestError:
            continue
        total += _duration_seconds(section)
        if skill == "listening":
            listening = section
    if listening is not None:
        try:
            total += int(listening.get("review_seconds") or 0)
        except (TypeError, ValueError):
            pass
    return int(math.ceil(total / 60)) if total else 0


def list_sets(root: Path | str | None = None) -> list[dict]:
    """Return lightweight summaries for every valid set folder."""
    base = _resolve_root(root)
    if not base.is_dir():
        return []

    summaries: list[dict] = []
    for folder in sorted(base.iterdir()):
        if not folder.is_dir() or not (folder / "meta.json").is_file():
            continue
        try:
            meta = _read_json(folder / "meta.json")
        except MockTestError:
            logger.warning("Skipping unreadable mock test folder: %s", folder)
            continue
        set_id = str(meta.get("id") or folder.name)
        summaries.append(
            {
                "id": set_id,
                "type": str(meta.get("type") or "academic"),
                "title": str(meta.get("title") or set_id),
                "description": str(meta.get("description") or ""),
                "duration_minutes": _duration_minutes(meta, folder),
                "skills": [
                    skill
                    for skill in _declared_skills(meta)
                    if (folder / SECTION_FILES[skill]).is_file()
                ]
                or _declared_skills(meta),
            }
        )
    return summaries


def get_set(set_id: str, root: Path | str | None = None) -> dict:
    """Load and merge all section files for one set (contains answer keys)."""
    base = _resolve_root(root)
    safe_id = _safe_set_id(set_id)
    folder = base / safe_id
    if not folder.is_dir() and base.is_dir():
        # Tolerate a meta id that differs from the folder name.
        for candidate in sorted(base.iterdir()):
            meta_path = candidate / "meta.json"
            if not candidate.is_dir() or not meta_path.is_file():
                continue
            try:
                candidate_meta = _read_json(meta_path)
            except MockTestError:
                continue
            if str(candidate_meta.get("id") or "") == safe_id:
                folder = candidate
                break
    if not folder.is_dir():
        raise MockTestNotFound(f"Mock test set not found: {set_id}")

    meta = _read_json(folder / "meta.json")
    skills = _declared_skills(meta)

    sections: dict[str, dict] = {}
    for skill in skills:
        # Deliberately strict: a declared section must exist on disk.
        sections[skill] = _section_payload(folder, skill)

    return {
        "id": str(meta.get("id") or safe_id),
        "type": str(meta.get("type") or "academic"),
        "title": str(meta.get("title") or safe_id),
        "description": str(meta.get("description") or ""),
        "skills": skills,
        "sections": sections,
    }


def sanitize_set(payload: dict) -> dict:
    """Deep copy a set and drop every answer-key field, at any depth."""
    clean = copy.deepcopy(payload)

    def _walk(node: Any) -> Any:
        if isinstance(node, dict):
            return {
                key: _walk(value)
                for key, value in node.items()
                if key not in CONCEALED_KEYS
            }
        if isinstance(node, list):
            return [_walk(item) for item in node]
        return node

    return _walk(clean)


# ──────────────────────────────────────────────
# Answer normalisation and grading (pure)
# ──────────────────────────────────────────────

_WHITESPACE_RE = re.compile(r"\s+")
_EDGE_PUNCT_RE = re.compile(r"^[^\w\s'\-]+|[^\w\s'\-]+$")
_WORD_RE = re.compile(r"[A-Za-z']+")

_TRUE_WORDS = {"true", "t", "yes", "y"}
_FALSE_WORDS = {"false", "f", "no", "n"}
_NOT_GIVEN_WORDS = {
    "not given",
    "notgiven",
    "not-mentioned",
    "not mentioned",
    "notmentioned",
    "ng",
}

_NUMBER_WORDS: dict[str, int] = {
    "zero": 0,
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "eleven": 11,
    "twelve": 12,
    "thirteen": 13,
    "fourteen": 14,
    "fifteen": 15,
    "sixteen": 16,
    "seventeen": 17,
    "eighteen": 18,
    "nineteen": 19,
    "twenty": 20,
    "thirty": 30,
    "forty": 40,
    "fifty": 50,
    "sixty": 60,
    "seventy": 70,
    "eighty": 80,
    "ninety": 90,
    "hundred": 100,
}

TFNG_TYPES = {"tfng", "ynng"}
CHOICE_TYPES = {
    "mcq",
    "matching",
    "matching_headings",
    "matching_information",
    "map_labelling",
}


def normalize_answer(text: Any) -> str:
    """Trim, lowercase, collapse whitespace and strip edge punctuation.

    Hyphens and apostrophes are preserved (e.g. ``don't``, ``not-mentioned``).
    """
    if text is None:
        return ""
    if isinstance(text, (list, tuple, set)):
        text = next(iter(text), "") if text else ""
    value = _WHITESPACE_RE.sub(" ", str(text).strip().lower())
    previous = None
    while value and value != previous:
        previous = value
        value = _EDGE_PUNCT_RE.sub("", value).strip()
    return value


def _as_answer_list(question: dict) -> list[str]:
    raw = question.get("answer")
    if isinstance(raw, (list, tuple)):
        values = [str(item) for item in raw if str(item).strip()]
    elif raw is None:
        values = []
    else:
        values = [str(raw)]
    extra = question.get("alternatives")
    if isinstance(extra, (list, tuple)):
        values.extend(str(item) for item in extra if str(item).strip())
    elif isinstance(extra, str) and extra.strip():
        values.append(extra)
    return values


def _numbers_match(left: str, right: str) -> bool:
    """Accept ``18`` for ``eighteen`` (and vice versa) for simple numbers."""
    def _as_number(value: str) -> Optional[int]:
        if value.isdigit():
            return int(value)
        return _NUMBER_WORDS.get(value)

    left_number = _as_number(left)
    right_number = _as_number(right)
    return left_number is not None and left_number == right_number


def _matches(candidate: str, expected: str) -> bool:
    if not candidate or not expected:
        return False
    if candidate == expected:
        return True
    return _numbers_match(candidate, expected)


def _option_pairs(question: dict) -> tuple[dict[str, str], dict[str, str]]:
    """Return ``key -> text`` and ``text -> key`` normalized option maps."""
    by_key: dict[str, str] = {}
    by_text: dict[str, str] = {}
    for option in question.get("options") or []:
        if not isinstance(option, dict):
            continue
        key = normalize_answer(option.get("key"))
        text = normalize_answer(option.get("text"))
        if key and text:
            by_key[key] = text
            by_text[text] = key
    return by_key, by_text


def grade_choice(question: dict, user_answer: Any) -> bool:
    """Grade MCQ/matching: accept the option key or the option text."""
    user = normalize_answer(user_answer)
    if not user:
        return False
    by_key, by_text = _option_pairs(question)
    accepted: set[str] = set()
    for expected in _as_answer_list(question):
        normalized = normalize_answer(expected)
        if not normalized:
            continue
        accepted.add(normalized)
        if normalized in by_key:
            accepted.add(by_key[normalized])
        if normalized in by_text:
            accepted.add(by_text[normalized])
    return any(_matches(user, value) for value in accepted)


def grade_completion(question: dict, user_answer: Any) -> bool:
    """Grade completion/short answer: accept answer[] plus alternatives[]."""
    user = normalize_answer(user_answer)
    if not user:
        return False
    for expected in _as_answer_list(question):
        if _matches(user, normalize_answer(expected)):
            return True
    return False


def canonical_boolean(value: Any, ynng: bool = False) -> str:
    """Map TFNG/YNNG variants to TRUE/FALSE or YES/NO/NOT GIVEN."""
    normalized = normalize_answer(value)
    if normalized in _TRUE_WORDS:
        return "YES" if ynng else "TRUE"
    if normalized in _FALSE_WORDS:
        return "NO" if ynng else "FALSE"
    if normalized in _NOT_GIVEN_WORDS:
        return "NOT GIVEN"
    return normalized.upper()


def grade_boolean(question: dict, user_answer: Any, ynng: bool = False) -> bool:
    user = canonical_boolean(user_answer, ynng=ynng)
    if not user:
        return False
    return any(
        user == canonical_boolean(expected, ynng=ynng)
        for expected in _as_answer_list(question)
    )


def grade_question(group_type: str, question: dict, user_answer: Any) -> bool:
    """Dispatch grading for one question based on its group type."""
    group = (group_type or "").lower()
    if group in TFNG_TYPES:
        return grade_boolean(question, user_answer, ynng=group == "ynng")
    if question.get("options"):
        return grade_choice(question, user_answer)
    return grade_completion(question, user_answer)


# ──────────────────────────────────────────────
# Band tables (pure)
# ──────────────────────────────────────────────

# (minimum raw score, band), descending
_LISTENING_BANDS: tuple[tuple[int, float], ...] = (
    (39, 9.0), (37, 8.5), (35, 8.0), (32, 7.5), (30, 7.0),
    (26, 6.5), (23, 6.0), (18, 5.5), (16, 5.0), (13, 4.5),
    (10, 4.0), (8, 3.5), (6, 3.0), (4, 2.5), (0, 2.0),
)

_ACADEMIC_READING_BANDS: tuple[tuple[int, float], ...] = (
    (39, 9.0), (37, 8.5), (35, 8.0), (33, 7.5), (30, 7.0),
    (27, 6.5), (23, 6.0), (19, 5.5), (15, 5.0), (13, 4.5),
    (10, 4.0), (8, 3.5), (6, 3.0), (4, 2.5), (0, 2.0),
)

_GENERAL_READING_BANDS: tuple[tuple[int, float], ...] = (
    (40, 9.0), (39, 8.5), (37, 8.0), (36, 7.5), (34, 7.0),
    (32, 6.5), (30, 6.0), (27, 5.5), (23, 5.0), (19, 4.5),
    (15, 4.0), (12, 3.5), (8, 3.0), (5, 2.5), (0, 2.0),
)


def _lookup_band(table: tuple[tuple[int, float], ...], raw: int) -> float:
    for minimum, band in table:
        if raw >= minimum:
            return band
    return table[-1][1]


def raw_to_band(skill: str, test_type: str, raw: int) -> float:
    """Map a raw score (0-40) to the official IELTS band for the skill."""
    normalized_skill = (skill or "").lower()
    try:
        score = int(raw)
    except (TypeError, ValueError):
        score = 0
    score = max(0, min(40, score))

    if normalized_skill == "listening":
        return _lookup_band(_LISTENING_BANDS, score)
    if normalized_skill == "reading":
        if (test_type or "").lower().startswith("gen"):
            return _lookup_band(_GENERAL_READING_BANDS, score)
        return _lookup_band(_ACADEMIC_READING_BANDS, score)
    raise ValueError(f"raw_to_band does not grade skill: {skill}")


def round_to_half(value: float) -> float:
    """Round to the nearest 0.5 with .25 going up (IELTS overall rule)."""
    return math.floor(float(value) * 2 + 0.5 + 1e-9) / 2


def overall_band(scores: dict[str, float] | Iterable[Optional[float]]) -> float:
    """Mean of the provided skill bands, rounded to the nearest 0.5."""
    if isinstance(scores, dict):
        values = [score for score in scores.values() if score is not None]
    else:
        values = [score for score in scores if score is not None]
    if not values:
        return 0.0
    mean = sum(float(score) for score in values) / len(values)
    return max(0.0, min(9.0, round_to_half(mean)))


# ──────────────────────────────────────────────
# Section grading
# ──────────────────────────────────────────────


def _section_groups(set_data: dict, skill: str) -> list[dict]:
    section = (set_data.get("sections") or {}).get(skill) or {}
    if skill == "listening":
        containers = section.get("parts") or []
    elif skill == "reading":
        containers = section.get("passages") or []
    else:
        containers = []
    groups: list[dict] = []
    for container in containers:
        if isinstance(container, dict):
            groups.extend(
                group
                for group in container.get("groups") or []
                if isinstance(group, dict)
            )
    return groups


def _user_answer(answers: dict, question: dict) -> Any:
    question_id = str(question.get("id") or "")
    if question_id and question_id in answers:
        return answers[question_id]
    number = question.get("number")
    if number is not None:
        for key in (str(number), number):
            if key in answers:
                return answers[key]
    return ""


def grade_section(
    set_id: str,
    skill: str,
    answers: dict[str, Any] | None,
    *,
    root: Path | str | None = None,
    set_data: Optional[dict] = None,
) -> dict:
    """Grade listening/reading and return the contract ``SectionScore``."""
    normalized_skill = (skill or "").lower()
    if normalized_skill not in {"listening", "reading"}:
        raise ValueError("grade_section only supports listening and reading")

    data = set_data if set_data is not None else get_set(set_id, root=root)
    test_type = str(data.get("type") or "academic")
    user_answers = answers or {}
    if not isinstance(user_answers, dict):
        raise MockTestError("Answers must be a mapping of question id to answer")

    details: list[dict] = []
    for group in _section_groups(data, normalized_skill):
        group_type = str(group.get("type") or "")
        group_options = group.get("options") or []
        for question in group.get("questions") or []:
            if not isinstance(question, dict):
                continue
            # Options live on the group in the content contract.
            effective = question
            if group_options and not question.get("options"):
                effective = {**question, "options": group_options}
            accepted = _as_answer_list(effective)
            correct_answer = accepted[0] if accepted else ""
            user = _user_answer(user_answers, question)
            is_correct = grade_question(group_type, effective, user)
            details.append(
                {
                    "question_id": str(question.get("id") or ""),
                    "number": int(question.get("number") or 0),
                    "user_answer": "" if user is None else str(user),
                    "correct_answer": correct_answer,
                    "is_correct": is_correct,
                    "explanation": str(question.get("explanation") or ""),
                }
            )

    details.sort(key=lambda item: item["number"])
    total = len(details)
    raw = sum(1 for item in details if item["is_correct"])
    band = raw_to_band(normalized_skill, test_type, raw)
    return {
        "skill": normalized_skill,
        "band": band,
        "raw_score": raw,
        "total": total,
        "criteria": {},
        "comment": f"{raw}/{total} correct. Estimated IELTS band {band:.1f}.",
        "details": details,
        "strengths": [],
        "improvements": [],
        "corrections": [],
        "extra": {"test_type": test_type},
    }


# ──────────────────────────────────────────────
# Writing evaluation (delegated with heuristic fallback)
# ──────────────────────────────────────────────

_COHESIVE_DEVICES = (
    "however", "therefore", "moreover", "furthermore", "in addition",
    "on the other hand", "in contrast", "consequently", "as a result",
    "for example", "for instance", "firstly", "secondly", "finally",
    "although", "while", "because", "in conclusion", "to sum up",
    "nevertheless", "overall", "besides", "meanwhile",
)

_WRITING_CRITERIA = ("task_achievement", "coherence", "lexical", "grammar")


def _word_list(text: str) -> list[str]:
    return _WORD_RE.findall(text or "")


def _clamp_band(value: float) -> float:
    return max(0.0, min(9.0, round_to_half(value)))


def _heuristic_writing_evaluation(task: dict, text: str) -> dict:
    """Local estimate used when the LLM evaluator is unavailable."""
    words = _word_list(text)
    word_count = len(words)
    minimum = int(task.get("min_words") or 150)
    if word_count == 0:
        return {
            "task_band": 1.0,
            "criteria": {criterion: 1.0 for criterion in _WRITING_CRITERIA},
            "comment": "No answer was submitted for this task.",
            "strengths": [],
            "improvements": ["Write a full response of at least "
                             f"{minimum} words."],
            "corrections": [],
            "word_count": 0,
        }

    paragraphs = [p for p in re.split(r"\n\s*\n|\n", text) if p.strip()]
    paragraph_count = max(1, len(paragraphs))
    sentences = [s for s in re.split(r"[.!?]+", text) if s.strip()]
    sentence_count = max(1, len(sentences))
    lower_words = [word.lower() for word in words]
    unique_ratio = len(set(lower_words)) / word_count
    long_ratio = sum(1 for word in lower_words if len(word) > 6) / word_count
    lower_text = (text or "").lower()
    cohesive_count = sum(lower_text.count(device) for device in _COHESIVE_DEVICES)
    average_sentence = word_count / sentence_count
    ratio = word_count / max(1, minimum)

    if ratio >= 1.0:
        task_band = 6.0 + (0.5 if ratio >= 1.15 else 0.0)
    elif ratio >= 0.8:
        task_band = 5.5
    elif ratio >= 0.6:
        task_band = 5.0
    elif ratio >= 0.4:
        task_band = 4.5
    else:
        task_band = 3.5

    coherence = 4.5
    coherence += 0.5 if paragraph_count >= 3 else 0.0
    coherence += 0.5 if paragraph_count >= 4 else 0.0
    coherence += 0.5 if cohesive_count >= 3 else 0.0
    coherence += 0.5 if cohesive_count >= 6 else 0.0

    lexical = 4.5
    lexical += 0.5 if unique_ratio >= 0.5 else 0.0
    lexical += 0.5 if unique_ratio >= 0.62 else 0.0
    lexical += 0.5 if long_ratio >= 0.2 else 0.0
    lexical += 0.5 if long_ratio >= 0.3 else 0.0

    grammar = 4.5
    grammar += 0.5 if 12 <= average_sentence <= 26 else 0.0
    grammar += 0.5 if sentence_count >= 6 else 0.0
    grammar += 0.5 if word_count >= minimum * 1.1 else 0.0
    grammar += 0.5 if "," in text and ";" in text else 0.0

    criteria = {
        "task_achievement": _clamp_band(task_band),
        "coherence": _clamp_band(coherence),
        "lexical": _clamp_band(lexical),
        "grammar": _clamp_band(grammar),
    }
    task_band = _clamp_band(sum(criteria.values()) / len(criteria))

    strengths: list[str] = []
    improvements: list[str] = []
    if word_count >= minimum:
        strengths.append(
            f"Met the minimum length requirement ({word_count}/{minimum} words)."
        )
    else:
        improvements.append(
            f"Expand the answer to at least {minimum} words "
            f"(currently {word_count})."
        )
    if paragraph_count >= 3:
        strengths.append("Organised the answer into clear paragraphs.")
    else:
        improvements.append("Use 3-5 paragraphs with one central idea each.")
    if cohesive_count >= 3:
        strengths.append("Used linking devices to connect ideas.")
    else:
        improvements.append(
            "Add cohesive devices (however, therefore, in addition) to link ideas."
        )
    if unique_ratio < 0.5:
        improvements.append("Vary vocabulary to avoid repeating the same words.")

    return {
        "task_band": task_band,
        "criteria": criteria,
        "comment": (
            f"Heuristic estimate: {word_count} words, {paragraph_count} "
            f"paragraph(s), {cohesive_count} cohesive device(s), lexical "
            f"variety {unique_ratio:.0%}."
        ),
        "strengths": strengths,
        "improvements": improvements,
        "corrections": [],
        "word_count": word_count,
    }


def _extract_band(result: dict, *names: str) -> Optional[float]:
    criteria = result.get("criteria") if isinstance(result.get("criteria"), dict) else {}
    scores = result.get("scores") if isinstance(result.get("scores"), dict) else {}
    for name in names:
        for container in (result, criteria, scores):
            for key in (name, f"{name}_band", f"{name}_score"):
                if key not in container:
                    continue
                value = container[key]
                if isinstance(value, dict):
                    value = value.get("band", value.get("score"))
                try:
                    if value is not None:
                        return _clamp_band(float(value))
                except (TypeError, ValueError):
                    continue
    return None


def _first_text(result: dict, *keys: str) -> str:
    for key in keys:
        value = result.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def _string_list(result: dict, *keys: str) -> list[str]:
    for key in keys:
        value = result.get(key)
        if isinstance(value, list):
            return [str(item) for item in value if str(item).strip()]
    return []


def _adapt_writing_result(result: dict, task: dict, text: str) -> dict:
    heuristic = _heuristic_writing_evaluation(task, text)
    bands = {
        "task_achievement": _extract_band(
            result, "task_achievement", "task_response"
        ),
        "coherence": _extract_band(result, "coherence", "coherence_cohesion"),
        "lexical": _extract_band(result, "lexical", "lexical_resource"),
        "grammar": _extract_band(
            result, "grammar", "grammatical_range", "grammatical_range_accuracy"
        ),
    }
    overall = _extract_band(result, "overall", "band", "overall_band")
    for criterion, band in bands.items():
        if band is None:
            bands[criterion] = heuristic["criteria"].get(criterion, overall or 4.0)
    # Contract: task band is the average of the four criteria, rounded to 0.5.
    task_band = _clamp_band(sum(bands.values()) / len(bands))

    return {
        "task_band": _clamp_band(task_band),
        "criteria": bands,
        "comment": _first_text(
            result,
            "comment",
            "feedback",
            "general_comment",
            "overall_comment",
            "examiner_comment",
        ) or heuristic["comment"],
        "strengths": _string_list(result, "strengths", "what_went_well"),
        "improvements": _string_list(
            result, "improvements", "suggestions", "areas_for_improvement"
        ),
        "corrections": result.get("corrections")
        if isinstance(result.get("corrections"), list)
        else [],
        "word_count": len(_word_list(text)),
    }


def _build_evaluator_kwargs(fn: Any, task: dict, text: str) -> dict:
    values = {
        "prompt": str(task.get("prompt") or ""),
        "instruction": str(task.get("prompt") or ""),
        "question": str(task.get("prompt") or ""),
        "topic": str(task.get("prompt") or ""),
        "essay": text,
        "text": text,
        "answer": text,
        "content": text,
        "user_text": text,
        "submission": text,
        "response": text,
        "task": task.get("task") or 1,
        "task_number": task.get("task") or 1,
        "task_id": task.get("id"),
        "min_words": task.get("min_words"),
        "visual": task.get("visual"),
        "guidance": task.get("guidance"),
        "word_count": len(_word_list(text)),
    }
    try:
        signature = inspect.signature(fn)
    except (TypeError, ValueError):
        return {"text": text}
    parameters = signature.parameters
    if any(p.kind is inspect.Parameter.VAR_KEYWORD for p in parameters.values()):
        return values
    kwargs = {name: values[name] for name in parameters if name in values}
    return kwargs or {"text": text}


async def _evaluate_writing_task(task: dict, text: str) -> dict:
    try:
        from .ielts_writing_service import evaluate_ielts_writing
    except Exception:  # ImportError or broken module: use local heuristic
        return _heuristic_writing_evaluation(task, text)

    try:
        result = evaluate_ielts_writing(**_build_evaluator_kwargs(
            evaluate_ielts_writing, task, text
        ))
        if inspect.isawaitable(result):
            result = await result
    except Exception:
        logger.warning("Writing evaluator failed; using heuristic", exc_info=True)
        return _heuristic_writing_evaluation(task, text)

    if not isinstance(result, dict):
        return _heuristic_writing_evaluation(task, text)
    return _adapt_writing_result(result, task, text)


async def grade_writing(set_data: dict, answers: dict[str, str] | None) -> dict:
    section = (set_data.get("sections") or {}).get("writing") or {}
    tasks = sorted(
        [task for task in section.get("tasks") or [] if isinstance(task, dict)],
        key=lambda task: int(task.get("task") or 0),
    )
    user_answers = answers or {}
    task_results: list[dict] = []
    total_words = 0
    total_min_words = 0

    for index, task in enumerate(tasks, start=1):
        task_id = str(task.get("id") or f"W{task.get('task') or index}")
        text = str(user_answers.get(task_id) or "")
        result = await _evaluate_writing_task(task, text)
        total_words += int(result.get("word_count") or len(_word_list(text)))
        total_min_words += int(task.get("min_words") or 0)
        task_results.append(
            {
                "task_id": task_id,
                "task_number": int(task.get("task") or index),
                **result,
            }
        )

    if not task_results:
        band = 1.0
        criteria = {criterion: 1.0 for criterion in _WRITING_CRITERIA}
        comment = "No writing tasks were found for this set."
        weighted: dict[str, float] = criteria
    else:
        core = [item for item in task_results if item["task_number"] == 1]
        extended = [item for item in task_results if item["task_number"] == 2]
        if core and extended:
            task1_band = float(core[0]["task_band"])
            task2_band = float(extended[0]["task_band"])
            band = _clamp_band((task1_band + task2_band * 2) / 3)
            weighted = {}
            # Task 1 is graded on task_achievement, Task 2 on task_response.
            task2_criterion_key = "task_response"
            for criterion in _WRITING_CRITERIA:
                task1_value = float(core[0]["criteria"].get(criterion, task1_band))
                task2_value = float(
                    extended[0]["criteria"].get(task2_criterion_key, task2_band)
                )
                weighted[criterion] = _clamp_band(
                    (task1_value + task2_value * 2) / 3
                )
        else:
            band = _clamp_band(
                sum(item["task_band"] for item in task_results) / len(task_results)
            )
            weighted = {
                criterion: _clamp_band(
                    sum(
                        float(item["criteria"].get(criterion, item["task_band"]))
                        for item in task_results
                    )
                    / len(task_results)
                )
                for criterion in _WRITING_CRITERIA
            }
        comment = " ".join(
            f"{item['task_id']}: {item['comment']}" for item in task_results
        ).strip()

    strengths: list[str] = []
    improvements: list[str] = []
    corrections: list[Any] = []
    for item in task_results:
        strengths.extend(item.get("strengths") or [])
        improvements.extend(item.get("improvements") or [])
        corrections.extend(item.get("corrections") or [])

    return {
        "skill": "writing",
        "band": band,
        "raw_score": total_words,
        "total": total_min_words,
        "criteria": weighted,
        "comment": comment,
        "details": [],
        "strengths": _dedupe(strengths),
        "improvements": _dedupe(improvements),
        "corrections": corrections,
        "extra": {"tasks": task_results, "word_count": total_words},
    }


def _dedupe(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        text = str(value).strip()
        if text and text not in seen:
            seen.add(text)
            result.append(text)
    return result


# ──────────────────────────────────────────────
# Speaking evaluation (delegated with heuristic fallback)
# ──────────────────────────────────────────────


def _speaking_fallback(payload: dict) -> dict:
    part1 = payload.get("part1_qa") or []
    part3 = payload.get("part3_qa") or []
    follow_up = payload.get("follow_up_qa") or []
    part2 = str(payload.get("part2_answer") or "")

    texts = [
        str(item.get("answer") or "")
        for item in list(part1) + list(part3) + list(follow_up)
        if isinstance(item, dict)
    ]
    texts.append(part2)
    combined = " ".join(text for text in texts if text.strip())
    words = _word_list(combined)
    total = len(words)
    lower_words = [word.lower() for word in words]
    unique_ratio = len(set(lower_words)) / total if total else 0.0

    if total == 0:
        band = 1.0
    elif total < 15:
        band = 2.0
    elif total < 35:
        band = 3.0
    elif total < 75:
        band = 4.0
    elif total < 140:
        band = 5.0
    elif total < 200:
        band = 5.5
    else:
        band = 6.0 + (0.5 if unique_ratio >= 0.5 else 0.0)

    band = _clamp_band(band)
    criteria = {
        "fluency": band,
        "lexical": band,
        "grammar": band,
        "pronunciation": band,
    }
    return {
        "band": band,
        "criteria": criteria,
        "comment": (
            f"Heuristic estimate based on {total} words across all parts. "
            "The AI examiner was unavailable."
        ),
        "strengths": [] if total == 0 else [
            f"Produced {total} words across the speaking test."
        ],
        "improvements": [
            "Extend answers with reasons and examples.",
            "Use a wider range of linking words and topic vocabulary.",
        ] if total < 140 else [],
        "corrections": [],
        "word_count": total,
        "extra": {"cefr_level": None, "follow_up_qa": follow_up},
    }


def _adapt_speaking_result(result: dict, payload: dict) -> dict:
    fallback = _speaking_fallback(payload)
    criteria = {
        "fluency": _extract_band(result, "fluency", "fluency_band", "fluency_coherence"),
        "lexical": _extract_band(result, "lexical", "lexical_band", "lexical_resource"),
        "grammar": _extract_band(result, "grammar", "grammar_band", "grammatical_range"),
        "pronunciation": _extract_band(result, "pronunciation", "pronunciation_band"),
    }
    overall = _extract_band(result, "overall", "overall_band", "band")
    for criterion, band in criteria.items():
        if band is None:
            criteria[criterion] = fallback["criteria"][criterion]
    band = overall or _clamp_band(sum(criteria.values()) / len(criteria))

    return {
        "skill": "speaking",
        "band": _clamp_band(band),
        "raw_score": int(fallback["word_count"]),
        "total": 0,
        "criteria": criteria,
        "comment": _first_text(
            result,
            "examiner_comment",
            "comment",
            "feedback",
            "general_comment",
        ) or fallback["comment"],
        "details": [],
        "strengths": _string_list(result, "strengths", "what_went_well")
        or fallback["strengths"],
        "improvements": _string_list(
            result, "improvements", "suggestions", "areas_for_improvement"
        ) or fallback["improvements"],
        "corrections": result.get("corrections")
        if isinstance(result.get("corrections"), list)
        else [],
        "extra": {
            "cefr_level": result.get("cefr_level"),
            "band8_samples": result.get("band8_samples") or [],
            "follow_up_qa": payload.get("follow_up_qa") or [],
            "part1_qa": payload.get("part1_qa") or [],
            "part2_answer": payload.get("part2_answer") or "",
            "part3_qa": payload.get("part3_qa") or [],
            "word_count": fallback["word_count"],
        },
    }


async def grade_speaking(payload: dict, set_data: Optional[dict] = None) -> dict:
    payload = payload or {}
    speaking = ((set_data or {}).get("sections") or {}).get("speaking") or {}
    topic = str(payload.get("topic") or "").strip()
    if not topic:
        cue_card = (speaking.get("part2") or {}).get("cue_card")
        topic = str(cue_card or (set_data or {}).get("title") or "IELTS Speaking")

    part1_qa = [item for item in payload.get("part1_qa") or [] if isinstance(item, dict)]
    part3_qa = [item for item in payload.get("part3_qa") or [] if isinstance(item, dict)]
    part2_answer = str(payload.get("part2_answer") or "")

    try:
        from .ai_service import AIService
    except Exception:
        return _adapt_speaking_result({}, payload)

    try:
        result = await asyncio.wait_for(
            AIService.evaluate_ielts_speaking(
                topic, part1_qa, part2_answer, part3_qa
            ),
            timeout=60.0,
        )
        if inspect.isawaitable(result):
            result = await result
    except Exception:
        logger.warning("Speaking evaluator failed; using heuristic", exc_info=True)
        return _adapt_speaking_result({}, payload)

    if not isinstance(result, dict):
        return _adapt_speaking_result({}, payload)
    return _adapt_speaking_result(result, payload)


# ──────────────────────────────────────────────
# Attempt lifecycle / persistence
# ──────────────────────────────────────────────

# In-memory fallback used when get_db() yields None (in-memory mode).
_MEMORY_ATTEMPTS: dict[UUID, dict] = {}


def reset_memory_attempts() -> None:
    """Clear the in-memory attempt store (used by tests)."""
    _MEMORY_ATTEMPTS.clear()


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, datetime):
        moment = value
        if moment.tzinfo is None:
            moment = moment.replace(tzinfo=timezone.utc)
        return moment.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
    return str(value)


def _as_uuid(value: Any) -> UUID:
    try:
        return value if isinstance(value, UUID) else UUID(str(value))
    except (TypeError, ValueError, AttributeError) as exc:
        raise MockTestNotFound(f"Attempt not found: {value}") from exc


def _deep(value: Any) -> Any:
    return copy.deepcopy(value)


def _record_from_row(row: MockTestAttempt) -> dict:
    return {
        "id": row.id,
        "user_id": row.user_id,
        "set_id": row.set_id,
        "test_type": row.test_type or "academic",
        "mode": row.mode or "strict",
        "status": row.status or "in_progress",
        "started_at": row.started_at,
        "completed_at": row.completed_at,
        "section_started_at": _deep(row.section_started_at or {}),
        "section_scores": _deep(row.section_scores or {}),
        "raw_scores": _deep(row.raw_scores or {}),
        "answers": _deep(row.answers or {}),
        "flagged": _deep(row.flagged or {}),
        "overall_band": row.overall_band,
        "xp_awarded": int(row.xp_awarded or 0),
    }


def _apply_record(row: MockTestAttempt, record: dict) -> None:
    row.user_id = record["user_id"]
    row.set_id = record["set_id"]
    row.test_type = record["test_type"]
    row.mode = record["mode"]
    row.status = record["status"]
    row.started_at = record["started_at"]
    row.completed_at = record["completed_at"]
    row.section_started_at = _deep(record["section_started_at"])
    row.section_scores = _deep(record["section_scores"])
    row.raw_scores = _deep(record["raw_scores"])
    row.answers = _deep(record["answers"])
    row.flagged = _deep(record["flagged"])
    row.overall_band = record["overall_band"]
    row.xp_awarded = int(record["xp_awarded"] or 0)


async def _persist(db: Optional[AsyncSession], record: dict) -> None:
    """Mirror the record in memory and, when a DB exists, in Postgres."""
    _MEMORY_ATTEMPTS[record["id"]] = record
    if db is None:
        return
    row = await db.get(MockTestAttempt, record["id"])
    if row is None:
        row = MockTestAttempt(id=record["id"])
        db.add(row)
    _apply_record(row, record)
    await db.commit()


async def _load_attempt(db: Optional[AsyncSession], attempt_id: Any) -> dict:
    identifier = _as_uuid(attempt_id)
    record = _MEMORY_ATTEMPTS.get(identifier)
    if record is not None:
        return record
    if db is not None:
        row = await db.get(MockTestAttempt, identifier)
        if row is not None:
            record = _record_from_row(row)
            _MEMORY_ATTEMPTS[identifier] = record
            return record
    raise MockTestNotFound(f"Attempt not found: {attempt_id}")


def _check_access(record: dict, user_id: Optional[UUID]) -> None:
    owner = record.get("user_id")
    if owner is None:
        return
    if user_id is None or _as_uuid(user_id) != _as_uuid(owner):
        raise AttemptAccessDenied("This attempt belongs to another user")


def _planned_skills(record: dict) -> list[str]:
    skills = [str(skill) for skill in (record.get("section_started_at") or {})]
    return [skill for skill in ALL_SKILLS if skill in skills]


def _skill_duration(set_data: dict, skill: str) -> int:
    return _duration_seconds((set_data.get("sections") or {}).get(skill))


def _section_status(record: dict, skill: str) -> str:
    return "completed" if skill in (record.get("section_scores") or {}) else "pending"


def attempt_create_response(record: dict, set_data: dict) -> dict:
    return {
        "attempt_id": str(record["id"]),
        "set_id": record["set_id"],
        "mode": record["mode"],
        "started_at": _iso(record["started_at"]),
        "sections": [
            {
                "skill": skill,
                "duration_seconds": _skill_duration(set_data, skill),
                "status": _section_status(record, skill),
            }
            for skill in _planned_skills(record)
        ],
    }


async def create_attempt(
    db: Optional[AsyncSession],
    set_id: str,
    mode: str = "strict",
    skills: Optional[Iterable[str]] = None,
    user_id: Optional[UUID] = None,
    *,
    root: Path | str | None = None,
) -> dict:
    """Create a new attempt and return the contract create-response payload."""
    set_data = get_set(set_id, root=root)
    normalized_mode = (mode or "strict").lower()
    if normalized_mode not in MODES:
        raise MockTestError(f"Invalid mode: {mode}")

    available = [
        skill
        for skill in (set_data.get("skills") or ALL_SKILLS)
        if skill in (set_data.get("sections") or {})
    ]
    if skills:
        requested = {str(skill).lower() for skill in skills}
        unknown = requested - set(available)
        if unknown:
            raise InvalidSkillError(
                "Skills not available in this set: " + ", ".join(sorted(unknown))
            )
        planned = [skill for skill in ALL_SKILLS if skill in requested]
    else:
        planned = available or list(ALL_SKILLS)
    if not planned:
        raise MockTestError("This set has no usable sections")

    now = _utcnow()
    record = {
        "id": uuid4(),
        "user_id": _as_uuid(user_id) if user_id is not None else None,
        "set_id": set_data["id"],
        "test_type": set_data.get("type") or "academic",
        "mode": normalized_mode,
        "status": "in_progress",
        "started_at": now,
        "completed_at": None,
        "section_started_at": {skill: None for skill in planned},
        "section_scores": {},
        "raw_scores": {},
        "answers": {},
        "flagged": {},
        "overall_band": None,
        "xp_awarded": 0,
    }
    await _persist(db, record)
    return attempt_create_response(record, set_data)


async def save_section(
    db: Optional[AsyncSession],
    attempt_id: Any,
    skill: str,
    answers: Optional[dict[str, str]] = None,
    flagged: Optional[list[str]] = None,
    remaining_seconds: Optional[int] = None,
    user_id: Optional[UUID] = None,
    *,
    root: Path | str | None = None,
) -> None:
    """Upsert in-progress answers/flagged state and the section start time."""
    record = await _load_attempt(db, attempt_id)
    _check_access(record, user_id)
    normalized_skill = (skill or "").lower()
    if normalized_skill not in _planned_skills(record):
        raise InvalidSkillError(f"Skill not part of this attempt: {skill}")

    if answers is not None:
        current = dict((record.get("answers") or {}).get(normalized_skill) or {})
        current.update({str(key): value for key, value in answers.items()})
        record.setdefault("answers", {})[normalized_skill] = current

    if flagged is not None:
        record.setdefault("flagged", {})[normalized_skill] = _dedupe(
            str(item) for item in flagged
        )

    section_started = record.setdefault("section_started_at", {})
    if not section_started.get(normalized_skill):
        started = _utcnow()
        if remaining_seconds is not None:
            try:
                set_data = get_set(record["set_id"], root=root)
                duration = _skill_duration(set_data, normalized_skill)
                remaining = max(0, min(int(remaining_seconds), duration or int(remaining_seconds)))
                started -= timedelta(seconds=max(0, duration - remaining))
            except (MockTestError, TypeError, ValueError):
                pass
        section_started[normalized_skill] = _iso(started)

    await _persist(db, record)


async def submit_section(
    db: Optional[AsyncSession],
    attempt_id: Any,
    skill: str,
    payload: Optional[dict] = None,
    user_id: Optional[UUID] = None,
    *,
    root: Path | str | None = None,
) -> dict:
    """Grade one section, persist its score, and return the SectionScore."""
    record = await _load_attempt(db, attempt_id)
    _check_access(record, user_id)
    normalized_skill = (skill or "").lower()
    if normalized_skill not in ALL_SKILLS:
        raise InvalidSkillError(f"Unknown skill: {skill}")
    if normalized_skill not in _planned_skills(record):
        raise InvalidSkillError(f"Skill not part of this attempt: {skill}")

    existing = (record.get("section_scores") or {}).get(normalized_skill)
    if existing:
        return _deep(existing)  # idempotent re-submit

    payload = payload or {}
    set_data = get_set(record["set_id"], root=root)
    stored_answers = dict((record.get("answers") or {}).get(normalized_skill) or {})

    if normalized_skill in {"listening", "reading"}:
        incoming = payload.get("answers") or {}
        answers = {str(key): value for key, value in incoming.items()}
        merged = {**stored_answers, **answers}
        score = grade_section(
            record["set_id"], normalized_skill, merged, set_data=set_data
        )
        record.setdefault("answers", {})[normalized_skill] = merged
    elif normalized_skill == "writing":
        incoming = payload.get("answers") or {}
        answers = {str(key): value for key, value in incoming.items()}
        merged = {**stored_answers, **answers}
        score = await grade_writing(set_data, merged)
        record.setdefault("answers", {})[normalized_skill] = merged
    else:  # speaking
        speaking_payload = {
            "topic": payload.get("topic"),
            "part1_qa": payload.get("part1_qa") or [],
            "part2_answer": payload.get("part2_answer") or "",
            "part3_qa": payload.get("part3_qa") or [],
            "follow_up_qa": payload.get("follow_up_qa") or [],
        }
        score = await grade_speaking(speaking_payload, set_data)
        record.setdefault("answers", {})[normalized_skill] = speaking_payload

    record.setdefault("section_scores", {})[normalized_skill] = score
    record.setdefault("raw_scores", {})[normalized_skill] = score.get("raw_score", 0)
    record.setdefault("section_started_at", {}).setdefault(
        normalized_skill, _iso(_utcnow())
    )
    await _persist(db, record)
    return _deep(score)


def _attempt_result(record: dict, first_completion: bool) -> dict:
    planned = _planned_skills(record)
    return {
        "attempt_id": str(record["id"]),
        "overall_band": float(record.get("overall_band") or 0.0),
        "skills": {
            skill: _deep(score)
            for skill, score in (record.get("section_scores") or {}).items()
            if skill in planned
        },
        "xp_awarded": int(record.get("xp_awarded") or 0),
        "completed_at": _iso(record.get("completed_at")),
        "_first_completion": first_completion,
    }


async def complete_attempt(
    db: Optional[AsyncSession],
    attempt_id: Any,
    user_id: Optional[UUID] = None,
) -> dict:
    """Finalise an attempt: validate all sections are submitted, compute bands."""
    record = await _load_attempt(db, attempt_id)
    _check_access(record, user_id)
    if record.get("status") == "completed" and record.get("overall_band") is not None:
        return _attempt_result(record, first_completion=False)

    planned = _planned_skills(record)
    submitted = record.get("section_scores") or {}
    missing = [skill for skill in planned if skill not in submitted]
    if missing:
        raise IncompleteAttemptError(missing)

    bands = {skill: float(submitted[skill].get("band") or 0.0) for skill in planned}
    record["overall_band"] = overall_band(bands)
    record["xp_awarded"] = 50 * len(planned) + (
        200 if set(planned) == set(ALL_SKILLS) else 0
    )
    record["status"] = "completed"
    record["completed_at"] = _utcnow()
    await _persist(db, record)
    return _attempt_result(record, first_completion=True)


async def list_attempts(
    db: Optional[AsyncSession],
    user_id: Optional[UUID],
    *,
    root: Path | str | None = None,
) -> list[dict]:
    """Return the current user's attempt history, newest first."""
    if user_id is None:
        return []
    owner = _as_uuid(user_id)

    records: dict[UUID, dict] = {
        identifier: record
        for identifier, record in _MEMORY_ATTEMPTS.items()
        if record.get("user_id") == owner
    }
    if db is not None:
        from sqlalchemy import select

        result = await db.execute(
            select(MockTestAttempt)
            .where(MockTestAttempt.user_id == owner)
            .order_by(MockTestAttempt.started_at.desc())
        )
        for row in result.scalars().all():
            records.setdefault(row.id, _record_from_row(row))

    set_titles: dict[str, tuple[str, str]] = {}
    try:
        for summary in list_sets(root=root):
            set_titles[summary["id"]] = (summary["title"], summary["type"])
    except MockTestError:
        pass

    ordered = sorted(
        records.values(),
        key=lambda item: item.get("started_at") or datetime.min.replace(tzinfo=timezone.utc),
        reverse=True,
    )
    history: list[dict] = []
    for record in ordered:
        title, test_type = set_titles.get(
            record["set_id"], (record["set_id"], record.get("test_type") or "academic")
        )
        submitted = record.get("section_scores") or {}
        planned = _planned_skills(record)
        history.append(
            {
                "attempt_id": str(record["id"]),
                "set_id": record["set_id"],
                "title": title,
                "type": test_type,
                "mode": record["mode"],
                "status": record["status"],
                "overall_band": record.get("overall_band"),
                "completed_at": _iso(record.get("completed_at")),
                "skills": {
                    skill: (submitted.get(skill) or {}).get("band")
                    for skill in planned
                },
            }
        )
    return history


async def get_attempt_detail(
    db: Optional[AsyncSession],
    attempt_id: Any,
    user_id: Optional[UUID] = None,
    *,
    root: Path | str | None = None,
) -> dict:
    """Attempt detail with sanitized content and post-submission review."""
    record = await _load_attempt(db, attempt_id)
    _check_access(record, user_id)

    set_data: dict = {}
    try:
        set_data = get_set(record["set_id"], root=root)
    except MockTestError:
        logger.warning("Mock test content missing for set %s", record["set_id"])

    submitted = record.get("section_scores") or {}
    scores = {skill: _deep(score) for skill, score in submitted.items()}
    review = {
        skill: {
            "details": score.get("details") or [],
            "comment": score.get("comment") or "",
            "strengths": score.get("strengths") or [],
            "improvements": score.get("improvements") or [],
            "corrections": score.get("corrections") or [],
        }
        for skill, score in scores.items()
    }

    return {
        "attempt_id": str(record["id"]),
        "set_id": record["set_id"],
        "title": set_data.get("title") or record["set_id"],
        "type": record.get("test_type") or set_data.get("type") or "academic",
        "mode": record["mode"],
        "status": record["status"],
        "started_at": _iso(record.get("started_at")),
        "completed_at": _iso(record.get("completed_at")),
        "overall_band": record.get("overall_band"),
        "xp_awarded": int(record.get("xp_awarded") or 0),
        "skills": _planned_skills(record),
        "sections": sanitize_set(set_data.get("sections") or {}) if set_data else {},
        "scores": scores,
        "review": review,
        "answers": _deep(record.get("answers") or {}),
        "flagged": _deep(record.get("flagged") or {}),
        "section_started_at": _deep(record.get("section_started_at") or {}),
    }


__all__ = [
    "ALL_SKILLS",
    "AttemptAccessDenied",
    "IncompleteAttemptError",
    "InvalidSkillError",
    "MockTestError",
    "MockTestNotFound",
    "canonical_boolean",
    "complete_attempt",
    "create_attempt",
    "data_root",
    "get_attempt_detail",
    "get_set",
    "grade_boolean",
    "grade_choice",
    "grade_completion",
    "grade_question",
    "grade_section",
    "grade_speaking",
    "grade_writing",
    "list_attempts",
    "list_sets",
    "normalize_answer",
    "overall_band",
    "raw_to_band",
    "reset_memory_attempts",
    "round_to_half",
    "sanitize_set",
    "save_section",
    "submit_section",
]
