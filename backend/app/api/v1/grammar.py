"""Public grammar content, progress, and idempotent quiz attempts."""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from ...database import get_db, is_db_connected
from ...models.learning import GrammarLesson
from ...models.user import User
from ...schemas.grammar import (
    GrammarAttemptRequest,
    GrammarAttemptResponse,
    GrammarBundleResponse,
    GrammarLessonDetail,
    GrammarLessonSummary,
    GrammarManifestResponse,
    GrammarProgressResponse,
    GrammarResultResponse,
    GrammarSubmitRequest,
)
from ...services.grammar_service import (
    build_manifest,
    deterministic_lesson_id,
    find_lesson,
    lesson_to_payload,
    load_progress_map,
    load_progress_response,
    load_published_lessons,
    load_seed_lessons,
    payload_to_detail,
    payload_to_summary,
    seed_lesson_map,
    submit_attempt,
)
from ..deps import get_current_user, get_optional_user

logger = logging.getLogger(__name__)
router = APIRouter()


async def _load_rows(db: Optional[AsyncSession]) -> list[GrammarLesson]:
    if not is_db_connected() or db is None:
        return []
    try:
        return await load_published_lessons(db)
    except Exception:
        logger.exception("Grammar DB query failed; using bundled seed content")
        return []


def _seed_by_identifier(identifier: str) -> Optional[dict]:
    direct = seed_lesson_map().get(identifier)
    if direct:
        return direct
    try:
        wanted = UUID(identifier)
    except (TypeError, ValueError):
        return None
    for payload in load_seed_lessons():
        if deterministic_lesson_id(payload["id"]) == wanted:
            return payload
    return None


async def _public_payloads(db: Optional[AsyncSession]) -> list[dict]:
    rows = await _load_rows(db)
    if rows:
        return [lesson_to_payload(row) for row in rows]
    return list(load_seed_lessons())


async def _resolve_slug(db: AsyncSession, identifier: str) -> Optional[str]:
    lesson = await find_lesson(db, identifier)
    return lesson.slug if lesson else None


@router.get("/manifest", response_model=GrammarManifestResponse)
async def grammar_manifest(db: AsyncSession = Depends(get_db)):
    """Return lightweight version metadata for incremental client sync."""
    payloads = await _public_payloads(db)
    version, entries = build_manifest(payloads)
    return GrammarManifestResponse(
        version=version,
        generated_at=datetime.now(timezone.utc),
        lessons=entries,
    )


@router.get("/bundle", response_model=GrammarBundleResponse)
async def grammar_bundle(db: AsyncSession = Depends(get_db)):
    """Return all published lessons for offline cache bootstrapping."""
    payloads = await _public_payloads(db)
    version, _ = build_manifest(payloads)
    return GrammarBundleResponse(
        version=version,
        generated_at=datetime.now(timezone.utc),
        lessons=[payload_to_detail(payload) for payload in payloads],
    )


@router.get("/lessons", response_model=list[GrammarLessonSummary])
async def list_grammar_lessons(
    level: Optional[str] = Query(default=None),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """List published lessons with optional authenticated progress."""
    rows = await _load_rows(db)
    if rows:
        progress_map = {}
        if current_user is not None:
            try:
                progress_map = await load_progress_map(db, current_user.id)
            except Exception:
                logger.exception("Could not load grammar progress")
        result = []
        for row in rows:
            payload = lesson_to_payload(row)
            if level and payload["level"].upper() != level.upper():
                continue
            result.append(payload_to_summary(payload, progress_map.get(row.id)))
        return result

    # DB unavailable: serve honest seed content, without fake completion scores.
    result = []
    for payload in load_seed_lessons():
        if level and payload["level"].upper() != level.upper():
            continue
        result.append(payload_to_summary(payload))
    return result


@router.get("/lessons/{lesson_id}", response_model=GrammarLessonDetail)
async def get_grammar_lesson_detail(
    lesson_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Get a published lesson by slug (or legacy UUID)."""
    if is_db_connected() and db is not None:
        lesson = await find_lesson(db, lesson_id)
        if lesson is not None and lesson.is_active and lesson.status == "published":
            return payload_to_detail(lesson_to_payload(lesson))

    payload = _seed_by_identifier(lesson_id)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Grammar lesson not found",
        )
    return payload_to_detail(payload)


@router.post("/attempts", response_model=GrammarAttemptResponse)
async def create_grammar_attempt(
    request: GrammarAttemptRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Submit an idempotent quiz attempt and award XP at most once."""
    if not is_db_connected() or db is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Grammar sync is temporarily unavailable",
        )
    try:
        return await submit_attempt(
            db=db,
            user=current_user,
            lesson_slug=request.lesson_slug,
            attempt_id=request.attempt_id,
            answers=request.answers,
            lesson_version=request.lesson_version,
        )
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/progress", response_model=GrammarProgressResponse)
async def get_grammar_progress(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not is_db_connected() or db is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Grammar sync is temporarily unavailable",
        )
    return await load_progress_response(db, current_user)


@router.post("/lessons/{lesson_id}/submit", response_model=GrammarResultResponse)
async def submit_grammar_practice_legacy(
    lesson_id: str,
    request: GrammarSubmitRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Backwards-compatible alias for older clients.

    New clients should use ``POST /grammar/attempts`` with their own
    ``attempt_id`` so retries after a network failure do not double-award XP.
    """
    if not is_db_connected() or db is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Grammar sync is temporarily unavailable",
        )
    slug = await _resolve_slug(db, lesson_id)
    if slug is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Grammar lesson not found",
        )
    try:
        result = await submit_attempt(
            db=db,
            user=current_user,
            lesson_slug=slug,
            attempt_id=uuid4(),
            answers=request.answers,
        )
    except (LookupError, ValueError) as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return GrammarResultResponse(
        score=result.score,
        total=result.total,
        correct=result.correct,
        is_passed=result.is_passed,
        xp_earned=result.xp_earned,
    )
