"""Grammar content, progress, and idempotent attempt logic.

The public payload intentionally matches ``english_ai/assets/data/grammar`` so
the Flutter app can parse seed, cache, and server data with the same model.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any, Optional
from uuid import NAMESPACE_URL, UUID, uuid4, uuid5

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.learning import (
    GrammarAdminAudit,
    GrammarAttempt,
    GrammarLesson,
    GrammarLessonVersion,
    UserGrammarProgress,
    XpTransaction,
)
from ..models.user import User
from ..schemas.grammar import (
    GrammarAttemptResponse,
    GrammarLessonDetail,
    GrammarLessonSummary,
    GrammarProgressItem,
    GrammarProgressResponse,
    GrammarSubmitAnswer,
    GrammarValidationResponse,
)

logger = logging.getLogger(__name__)

LEVELS = ("A1", "A2", "B1", "B2", "C1", "C2")
_BETA_LEVELS = {"C1", "C2"}
_PROJECT_ROOT = Path(__file__).resolve().parents[3]
_DEFAULT_SEED_DIR = _PROJECT_ROOT / "english_ai" / "assets" / "data" / "grammar"
_PASS_SCORE = 70.0


# ──────────────────────────────────────────────
# Content normalization / seed loading
# ──────────────────────────────────────────────

def seed_dir() -> Path:
    configured = os.getenv("GRAMMAR_SEED_DIR")
    return Path(configured) if configured else _DEFAULT_SEED_DIR


def _as_str(value: Any, default: str = "") -> str:
    if value is None:
        return default
    return str(value)


def _as_list(value: Any) -> list:
    return value if isinstance(value, list) else []


def _normalise_examples(raw_examples: Any) -> list[dict]:
    examples: list[dict] = []
    for raw in _as_list(raw_examples):
        if not isinstance(raw, dict):
            continue
        english = _as_str(raw.get("english") or raw.get("en"))
        vietnamese = _as_str(raw.get("vietnamese") or raw.get("vi"))
        note = _as_str(raw.get("note"))
        examples.append(
            {
                "english": english,
                "vietnamese": vietnamese,
                "note": note,
                # Legacy / old Flutter grammar provider aliases.
                "en": english,
                "vi": vietnamese,
            }
        )
    return examples


def _normalise_quiz(raw_quiz: Any) -> list[dict]:
    quiz: list[dict] = []
    for raw in _as_list(raw_quiz):
        if not isinstance(raw, dict):
            continue
        raw_correct = raw.get("correct_index", raw.get("correct_option", 0))
        try:
            correct = int(raw_correct)
        except (TypeError, ValueError):
            correct = 0
        explanation = _as_str(raw.get("explanation") or raw.get("explanation_vi"))
        quiz.append(
            {
                "question": _as_str(raw.get("question")),
                "options": [_as_str(option) for option in _as_list(raw.get("options"))],
                "correct_index": correct,
                # Legacy alias used by the old backend submit endpoint.
                "correct_option": correct,
                "explanation": explanation,
                "explanation_vi": explanation,
            }
        )
    return quiz


def normalize_lesson(raw: dict, order_index: int = 0) -> dict:
    """Return the canonical local-compatible lesson payload."""
    lesson_id = _as_str(raw.get("id") or raw.get("slug"))
    level = _as_str(raw.get("level") or "A1").upper()
    description = _as_str(raw.get("description") or raw.get("summary"))
    usage_rules = [_as_str(item) for item in _as_list(raw.get("usage_rules"))]
    formula_affirmative = _as_str(raw.get("formula_affirmative"))
    formula_negative = _as_str(raw.get("formula_negative"))
    formula_question = _as_str(raw.get("formula_question"))
    quiz = _normalise_quiz(raw.get("quiz") or raw.get("practice_questions"))
    examples = _normalise_examples(raw.get("examples"))

    content_markdown = _as_str(raw.get("content_markdown"))
    if not content_markdown:
        lines = []
        if description:
            lines.append(description)
        if usage_rules:
            lines.append("")
            lines.extend(f"- {rule}" for rule in usage_rules)
        content_markdown = "\n".join(lines)

    payload = {
        "id": lesson_id,
        "slug": lesson_id,
        "title": _as_str(raw.get("title")),
        "title_vi": _as_str(raw.get("title_vi")),
        "level": level,
        "category": _as_str(raw.get("category")),
        "description": description,
        "summary": _as_str(raw.get("summary") or description),
        "content_markdown": content_markdown,
        "formula": _as_str(raw.get("formula") or formula_affirmative),
        "formula_affirmative": formula_affirmative,
        "formula_negative": formula_negative,
        "formula_question": formula_question,
        "time_markers": [_as_str(item) for item in _as_list(raw.get("time_markers"))],
        "usage_rules": usage_rules,
        "examples": examples,
        "common_mistakes": [_as_str(item) for item in _as_list(raw.get("common_mistakes"))],
        "quiz": quiz,
        "practice_questions": quiz,
        "is_beta": bool(raw.get("is_beta", level in _BETA_LEVELS)),
        "status": _as_str(raw.get("status") or "published"),
        "version": int(raw.get("version") or 1),
        "tags": [_as_str(item) for item in _as_list(raw.get("tags"))],
        "estimated_minutes": int(raw.get("estimated_minutes") or 10),
        "order_index": int(raw.get("order_index", order_index) or order_index),
    }
    return payload


def content_hash(payload: dict) -> str:
    """Stable hash used for import idempotency and cache validation."""
    stable = {
        key: value
        for key, value in payload.items()
        if key not in {"content_hash", "updated_at", "order_index", "version"}
    }
    blob = json.dumps(stable, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def _parse_datetime(value: Any) -> Optional[datetime]:
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        return value
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


@lru_cache(maxsize=1)
def load_seed_lessons() -> tuple[dict, ...]:
    """Load the 96 bundled lessons as canonical payloads.

    The cache is intentionally process-local; in development restart the
    backend after changing asset JSON (same rule as Flutter assets).
    """
    data_dir = seed_dir()
    curriculum_path = data_dir / "curriculum.json"
    curriculum: dict[str, dict] = {}
    if curriculum_path.exists():
        try:
            raw_curriculum = json.loads(curriculum_path.read_text(encoding="utf-8"))
            if isinstance(raw_curriculum, list):
                curriculum = {
                    str(item.get("id")): item
                    for item in raw_curriculum
                    if isinstance(item, dict) and item.get("id")
                }
        except Exception:
            logger.exception("Could not read grammar curriculum at %s", curriculum_path)

    lessons: list[dict] = []
    for level in LEVELS:
        path = data_dir / f"{level.lower()}.json"
        if not path.exists():
            continue
        try:
            raw_lessons = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            logger.exception("Could not read grammar seed file %s", path)
            continue
        if not isinstance(raw_lessons, list):
            continue
        for index, raw in enumerate(raw_lessons):
            if not isinstance(raw, dict):
                continue
            lesson_id = _as_str(raw.get("id"))
            expected = curriculum.get(lesson_id, {})
            raw = {**expected, **raw}
            order_index = int(expected.get("order_index", index))
            lessons.append(normalize_lesson(raw, order_index=order_index))
    lessons.sort(key=lambda item: (LEVELS.index(item["level"]) if item["level"] in LEVELS else 99, item["order_index"]))
    return tuple(lessons)


@lru_cache(maxsize=1)
def seed_lesson_map() -> dict[str, dict]:
    return {lesson["id"]: lesson for lesson in load_seed_lessons()}


# ──────────────────────────────────────────────
# DB -> public payload
# ──────────────────────────────────────────────

def lesson_to_payload(lesson: GrammarLesson) -> dict:
    base = dict(lesson.content or {})
    if not base:
        base = {
            "id": lesson.slug,
            "title": lesson.title,
            "title_vi": lesson.title_vi,
            "level": lesson.level,
            "category": lesson.category,
            "description": lesson.summary,
            "summary": lesson.summary,
            "content_markdown": lesson.content_markdown,
            "formula": lesson.formula,
            "formula_affirmative": lesson.formula or "",
            "examples": lesson.examples or [],
            "quiz": lesson.practice_questions or [],
        }

    payload = normalize_lesson(base, order_index=lesson.order_index)
    payload.update(
        {
            "id": lesson.slug,
            "slug": lesson.slug,
            "title": lesson.title or payload["title"],
            "title_vi": lesson.title_vi or payload["title_vi"],
            "level": lesson.level or payload["level"],
            "category": lesson.category or payload["category"],
            "description": payload["description"] or lesson.summary,
            "summary": lesson.summary or payload["summary"],
            "content_markdown": payload["content_markdown"] or lesson.content_markdown,
            "formula": lesson.formula or payload["formula"],
            "examples": payload["examples"] or _normalise_examples(lesson.examples),
            "quiz": payload["quiz"] or _normalise_quiz(lesson.practice_questions),
            "is_beta": bool(lesson.is_beta),
            "status": lesson.status or "published",
            "version": int(lesson.version or 1),
            "tags": list(lesson.tags or []),
            "estimated_minutes": int(lesson.estimated_minutes or 10),
            "order_index": int(lesson.order_index or 0),
            # ``updated_at`` is server-generated and may be expired after a
            # flush. Use __dict__ so response serialization never triggers
            # lazy IO outside SQLAlchemy's greenlet.
            "updated_at": (
                lesson.__dict__.get("updated_at").isoformat()
                if lesson.__dict__.get("updated_at")
                else None
            ),
        }
    )
    payload["practice_questions"] = payload["quiz"]
    return payload


def payload_to_summary(
    payload: dict,
    progress: Optional[UserGrammarProgress] = None,
) -> GrammarLessonSummary:
    return GrammarLessonSummary(
        id=str(payload["id"]),
        slug=str(payload.get("slug") or payload["id"]),
        title=str(payload.get("title") or ""),
        title_vi=str(payload.get("title_vi") or ""),
        level=str(payload.get("level") or "A1"),
        category=str(payload.get("category") or ""),
        summary=str(payload.get("summary") or payload.get("description") or ""),
        description=str(payload.get("description") or payload.get("summary") or ""),
        order_index=int(payload.get("order_index") or 0),
        is_completed=bool(progress.is_completed) if progress else False,
        score=(progress.best_score or progress.score) if progress else None,
        is_beta=bool(payload.get("is_beta")),
        version=int(payload.get("version") or 1),
        status=str(payload.get("status") or "published"),
        updated_at=_parse_datetime(payload.get("updated_at")),
    )


def payload_to_detail(payload: dict) -> GrammarLessonDetail:
    quiz = _normalise_quiz(payload.get("quiz") or payload.get("practice_questions"))
    examples = _normalise_examples(payload.get("examples"))
    return GrammarLessonDetail(
        id=str(payload["id"]),
        slug=str(payload.get("slug") or payload["id"]),
        title=str(payload.get("title") or ""),
        title_vi=str(payload.get("title_vi") or ""),
        level=str(payload.get("level") or "A1"),
        category=str(payload.get("category") or ""),
        summary=str(payload.get("summary") or payload.get("description") or ""),
        description=str(payload.get("description") or payload.get("summary") or ""),
        content_markdown=str(payload.get("content_markdown") or ""),
        formula=str(payload.get("formula") or payload.get("formula_affirmative") or "") or None,
        formula_affirmative=str(payload.get("formula_affirmative") or ""),
        formula_negative=str(payload.get("formula_negative") or ""),
        formula_question=str(payload.get("formula_question") or ""),
        time_markers=[str(item) for item in _as_list(payload.get("time_markers"))],
        usage_rules=[str(item) for item in _as_list(payload.get("usage_rules"))],
        examples=examples,
        common_mistakes=[str(item) for item in _as_list(payload.get("common_mistakes"))],
        quiz=quiz,
        practice_questions=quiz,
        is_beta=bool(payload.get("is_beta")),
        version=int(payload.get("version") or 1),
        status=str(payload.get("status") or "published"),
        tags=[str(item) for item in _as_list(payload.get("tags"))],
        estimated_minutes=int(payload.get("estimated_minutes") or 10),
        updated_at=_parse_datetime(payload.get("updated_at")),
    )


def build_manifest(lessons: list[dict]) -> tuple[str, list[dict]]:
    entries = [
        {
            "slug": lesson["id"],
            "title": lesson.get("title", ""),
            "level": lesson.get("level", "A1"),
            "version": int(lesson.get("version") or 1),
            "content_hash": content_hash(lesson),
            "updated_at": lesson.get("updated_at"),
            "is_beta": bool(lesson.get("is_beta")),
        }
        for lesson in lessons
    ]
    version_blob = json.dumps(
        [
            [entry["slug"], entry["version"], entry["content_hash"]]
            for entry in entries
        ],
        ensure_ascii=False,
        sort_keys=True,
    )
    version = hashlib.sha256(version_blob.encode("utf-8")).hexdigest()[:16]
    return version, entries


# ──────────────────────────────────────────────
# Queries
# ──────────────────────────────────────────────

async def find_lesson(db: AsyncSession, identifier: str) -> Optional[GrammarLesson]:
    """Find by slug first, then by UUID for backwards-compatible links."""
    try:
        result = await db.execute(select(GrammarLesson).where(GrammarLesson.slug == identifier))
        lesson = result.scalar_one_or_none()
        if lesson:
            return lesson
    except Exception:
        logger.exception("Could not query grammar lesson by slug")
        return None

    try:
        lesson_id = UUID(identifier)
    except (TypeError, ValueError):
        return None
    try:
        result = await db.execute(select(GrammarLesson).where(GrammarLesson.id == lesson_id))
        return result.scalar_one_or_none()
    except Exception:
        logger.exception("Could not query grammar lesson by id")
        return None


async def load_published_lessons(db: AsyncSession) -> list[GrammarLesson]:
    result = await db.execute(
        select(GrammarLesson)
        .where(GrammarLesson.is_active == True)  # noqa: E712
        .where(GrammarLesson.status == "published")
        .order_by(GrammarLesson.order_index, GrammarLesson.level, GrammarLesson.slug)
    )
    return list(result.scalars().all())


async def load_progress_map(db: AsyncSession, user_id: UUID) -> dict[UUID, UserGrammarProgress]:
    result = await db.execute(
        select(UserGrammarProgress).where(UserGrammarProgress.user_id == user_id)
    )
    return {progress.lesson_id: progress for progress in result.scalars().all()}


async def load_progress_response(db: AsyncSession, user: User) -> GrammarProgressResponse:
    progress_rows = await db.execute(
        select(UserGrammarProgress, GrammarLesson.slug)
        .join(GrammarLesson, GrammarLesson.id == UserGrammarProgress.lesson_id)
        .where(UserGrammarProgress.user_id == user.id)
    )
    items: list[GrammarProgressItem] = []
    for progress, slug in progress_rows.all():
        items.append(
            GrammarProgressItem(
                lesson_slug=slug,
                best_score=float(progress.best_score or progress.score or 0),
                is_completed=bool(progress.is_completed),
                attempts_count=int(progress.attempts_count or 0),
                last_attempt_at=progress.last_attempt_at,
                completed_at=progress.completed_at,
            )
        )
    items.sort(key=lambda item: item.lesson_slug)
    return GrammarProgressResponse(items=items, total_xp=int(user.total_xp or 0))


# ──────────────────────────────────────────────
# Attempts / XP
# ──────────────────────────────────────────────

def _grade_attempt(payload: dict, answers: list[GrammarSubmitAnswer]) -> tuple[int, int, float]:
    quiz = _normalise_quiz(payload.get("quiz") or payload.get("practice_questions"))
    answer_map = {answer.question_index: answer.selected_option for answer in answers}
    correct = 0
    for index, question in enumerate(quiz):
        if answer_map.get(index) == int(question.get("correct_index", -1)):
            correct += 1
    total = len(quiz)
    score = round((correct / total) * 100, 1) if total else 0.0
    return correct, total, score


def _attempt_response(
    attempt: GrammarAttempt,
    lesson_slug: str,
    best_score: float,
    is_completed: bool,
    duplicate: bool = False,
) -> GrammarAttemptResponse:
    return GrammarAttemptResponse(
        attempt_id=attempt.attempt_id,
        lesson_slug=lesson_slug,
        lesson_version=int(attempt.lesson_version or 1),
        score=float(attempt.score or 0),
        total=int(attempt.total or 0),
        correct=int(attempt.correct or 0),
        is_passed=float(attempt.score or 0) >= _PASS_SCORE,
        xp_earned=int(attempt.xp_awarded or 0),
        best_score=float(best_score or 0),
        is_completed=bool(is_completed),
        duplicate=duplicate,
        created_at=attempt.created_at,
    )


async def submit_attempt(
    db: AsyncSession,
    user: User,
    lesson_slug: str,
    attempt_id: UUID,
    answers: list[GrammarSubmitAnswer],
    lesson_version: Optional[int] = None,
) -> GrammarAttemptResponse:
    """Grade and persist an attempt exactly once per ``(user, attempt_id)``."""
    lesson = await find_lesson(db, lesson_slug)
    if lesson is None or lesson.status != "published" or not lesson.is_active:
        raise LookupError("Grammar lesson not found")

    existing_result = await db.execute(
        select(GrammarAttempt).where(
            GrammarAttempt.user_id == user.id,
            GrammarAttempt.attempt_id == attempt_id,
        )
    )
    existing = existing_result.scalar_one_or_none()
    if existing:
        progress_result = await db.execute(
            select(UserGrammarProgress).where(
                UserGrammarProgress.user_id == user.id,
                UserGrammarProgress.lesson_id == existing.lesson_id,
            )
        )
        progress = progress_result.scalars().first()
        return _attempt_response(
            existing,
            lesson_slug,
            float(progress.best_score if progress else existing.score),
            bool(progress.is_completed) if progress else float(existing.score) >= _PASS_SCORE,
            duplicate=True,
        )

    payload = lesson_to_payload(lesson)
    correct, total, score = _grade_attempt(payload, answers)
    if total == 0:
        raise ValueError("Lesson has no quiz questions")
    is_passed = score >= _PASS_SCORE

    progress_result = await db.execute(
        select(UserGrammarProgress).where(
            UserGrammarProgress.user_id == user.id,
            UserGrammarProgress.lesson_id == lesson.id,
        )
    )
    progress = progress_result.scalars().first()
    previous_best = float((progress.best_score or progress.score) if progress else 0)
    has_previous_attempt = bool(progress and (progress.attempts_count or 0) > 0)

    # First attempt: participation XP. Later attempts only reward a new best.
    if not has_previous_attempt:
        xp_earned = 30 if is_passed else 10
    elif score > previous_best:
        xp_earned = 5
    else:
        xp_earned = 0

    attempt = GrammarAttempt(
        id=uuid4(),
        attempt_id=attempt_id,
        user_id=user.id,
        lesson_id=lesson.id,
        lesson_version=int(lesson.version or lesson_version or 1),
        answers=[answer.model_dump() for answer in answers],
        score=score,
        correct=correct,
        total=total,
        xp_awarded=xp_earned,
    )
    db.add(attempt)
    try:
        await db.flush()
    except IntegrityError:
        # Concurrent retry won the race. Return the winner's result.
        await db.rollback()
        winner_result = await db.execute(
            select(GrammarAttempt).where(
                GrammarAttempt.user_id == user.id,
                GrammarAttempt.attempt_id == attempt_id,
            )
        )
        winner = winner_result.scalar_one()
        progress_result = await db.execute(
            select(UserGrammarProgress).where(
                UserGrammarProgress.user_id == user.id,
                UserGrammarProgress.lesson_id == winner.lesson_id,
            )
        )
        progress = progress_result.scalars().first()
        return _attempt_response(
            winner,
            lesson_slug,
            float(progress.best_score if progress else winner.score),
            bool(progress.is_completed) if progress else float(winner.score) >= _PASS_SCORE,
            duplicate=True,
        )

    now = datetime.now(timezone.utc)
    if progress is None:
        progress = UserGrammarProgress(
            id=uuid4(),
            user_id=user.id,
            lesson_id=lesson.id,
            score=score,
            best_score=score,
            attempts_count=1,
            is_completed=is_passed,
            completed_at=now if is_passed else None,
            last_attempt_at=now,
        )
        db.add(progress)
    else:
        progress.attempts_count = int(progress.attempts_count or 0) + 1
        progress.best_score = max(previous_best, score)
        progress.score = max(float(progress.score or 0), score)
        progress.last_attempt_at = now
        if is_passed and not progress.is_completed:
            progress.is_completed = True
            progress.completed_at = now

    if xp_earned:
        db.add(
            XpTransaction(
                id=uuid4(),
                user_id=user.id,
                source_type="grammar_attempt",
                source_id=attempt.id,
                amount=xp_earned,
            )
        )
        user.total_xp = int(user.total_xp or 0) + xp_earned

    await db.flush()
    return _attempt_response(
        attempt,
        lesson_slug,
        float(progress.best_score or score),
        bool(progress.is_completed),
    )


# ──────────────────────────────────────────────
# Validation / audit helpers
# ──────────────────────────────────────────────

def validate_payload(payload: dict) -> GrammarValidationResponse:
    errors: list[str] = []
    warnings: list[str] = []

    required_strings = (
        "id",
        "title",
        "level",
        "description",
        "formula_affirmative",
        "formula_negative",
        "formula_question",
    )
    for key in required_strings:
        value = payload.get(key)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"Missing/empty field '{key}'")

    if payload.get("level") not in LEVELS:
        errors.append("level must be one of A1, A2, B1, B2, C1, C2")

    for key, minimum, maximum in (
        ("time_markers", 3, 6),
        ("usage_rules", 3, 5),
        ("common_mistakes", 3, 5),
    ):
        values = payload.get(key)
        if not isinstance(values, list) or not (minimum <= len(values) <= maximum):
            errors.append(f"{key} must contain {minimum}-{maximum} items")

    examples = payload.get("examples")
    if not isinstance(examples, list) or not (3 <= len(examples) <= 5):
        errors.append("examples must contain 3-5 items")
    else:
        for index, example in enumerate(examples):
            if not isinstance(example, dict):
                errors.append(f"examples[{index}] must be an object")
            elif not str(example.get("english") or "").strip():
                errors.append(f"examples[{index}] is missing english")
            elif not str(example.get("vietnamese") or "").strip():
                errors.append(f"examples[{index}] is missing vietnamese")

    quiz = payload.get("quiz")
    if not isinstance(quiz, list) or len(quiz) != 5:
        errors.append("quiz must contain exactly 5 questions")
    else:
        seen: set[str] = set()
        for index, question in enumerate(quiz):
            if not isinstance(question, dict):
                errors.append(f"quiz[{index}] must be an object")
                continue
            text = str(question.get("question") or "").strip()
            if not text:
                errors.append(f"quiz[{index}] is missing question")
            elif text.lower() in seen:
                errors.append(f"quiz[{index}] duplicates another question")
            else:
                seen.add(text.lower())
            options = question.get("options")
            if not isinstance(options, list) or len(options) != 4:
                errors.append(f"quiz[{index}] must have exactly 4 options")
            elif len({str(option) for option in options}) != 4:
                errors.append(f"quiz[{index}] options must be unique")
            correct = question.get("correct_index")
            if not isinstance(correct, int) or not (0 <= correct <= 3):
                errors.append(f"quiz[{index}] correct_index must be 0-3")
            if not str(question.get("explanation") or "").strip():
                errors.append(f"quiz[{index}] is missing explanation")

    if payload.get("is_beta") and payload.get("level") not in _BETA_LEVELS:
        warnings.append("is_beta is only expected for C1/C2")

    return GrammarValidationResponse(valid=not errors, errors=errors, warnings=warnings)


def add_audit(
    db: AsyncSession,
    actor: Optional[User],
    action: str,
    lesson_id: Optional[UUID] = None,
    details: Optional[dict] = None,
) -> None:
    db.add(
        GrammarAdminAudit(
            id=uuid4(),
            actor_id=actor.id if actor else None,
            action=action,
            lesson_id=lesson_id,
            details=details or {},
        )
    )


def deterministic_lesson_id(slug: str) -> UUID:
    return uuid5(NAMESPACE_URL, f"englishai:grammar:{slug}")
