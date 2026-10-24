"""IELTS Mock Test API (contract v1).

Routes are mounted under ``/api/v1/mock-tests`` by ``api/v1/router.py``.
Static ``/attempts`` routes are declared before ``/{set_id}`` so that
"attempts" is never interpreted as a set id.
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import inspect as sa_inspect
from sqlalchemy.ext.asyncio import AsyncSession

from ...database import get_db
from ...models.user import User
from ...schemas.mock_test import (
    AttemptCompleteResponse,
    AttemptCreateRequest,
    AttemptCreateResponse,
    AttemptSectionDetail,
    AttemptSummary,
    MockTestSetSummary,
    SectionSaveRequest,
    SectionScore,
    SectionSubmitRequest,
)
from ...services import mock_test_service as service
from ..deps import get_optional_user

logger = logging.getLogger(__name__)

router = APIRouter()


def _raise_http(exc: service.MockTestError) -> None:
    """Translate service errors into clean HTTP responses."""
    if isinstance(exc, service.MockTestNotFound):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))
    if isinstance(exc, service.AttemptAccessDenied):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc))
    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


def _award_xp(user: User, xp: int) -> None:
    """Credit XP to a DB-backed user, or to the in-memory user store."""
    if xp <= 0:
        return
    user.total_xp = int(user.total_xp or 0) + xp
    try:
        state = sa_inspect(user)
    except Exception:
        state = None
    if state is not None and state.session is not None:
        return  # the request session commits the change
    try:
        from ..deps import save_memory_users

        save_memory_users()
    except Exception:
        logger.warning("Could not persist offline user XP", exc_info=True)


# ──────────────────────────────────────────────
# Sets
# ──────────────────────────────────────────────


@router.get("", response_model=list[MockTestSetSummary])
async def list_mock_tests():
    """List every available mock-test set."""
    return service.list_sets()


# ──────────────────────────────────────────────
# Attempts (declared before /{set_id})
# ──────────────────────────────────────────────


@router.get("/attempts", response_model=list[AttemptSummary])
async def list_attempts(
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Attempt history for the current user (guests have no history)."""
    if current_user is None:
        return []
    try:
        return await service.list_attempts(db, current_user.id)
    except service.MockTestError as exc:
        _raise_http(exc)
    return []


@router.post("/attempts", response_model=AttemptCreateResponse)
async def create_attempt(
    body: AttemptCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Start a strict/practice attempt for a set."""
    try:
        return await service.create_attempt(
            db,
            set_id=body.set_id,
            mode=body.mode,
            skills=body.skills,
            user_id=current_user.id if current_user else None,
        )
    except service.MockTestError as exc:
        _raise_http(exc)
    raise HTTPException(status_code=400, detail="Could not create attempt")


@router.get("/attempts/{attempt_id}", response_model=AttemptSectionDetail)
async def get_attempt(
    attempt_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Full attempt detail: sanitized content, scores and review."""
    try:
        return await service.get_attempt_detail(
            db, attempt_id, current_user.id if current_user else None
        )
    except service.MockTestError as exc:
        _raise_http(exc)
    raise HTTPException(status_code=404, detail="Attempt not found")


@router.patch("/attempts/{attempt_id}")
async def save_attempt_section(
    attempt_id: str,
    body: SectionSaveRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Persist in-progress answers/flagged state for one section."""
    try:
        await service.save_section(
            db,
            attempt_id,
            skill=body.skill,
            answers=body.answers,
            flagged=body.flagged,
            remaining_seconds=body.remaining_seconds,
            user_id=current_user.id if current_user else None,
        )
    except service.MockTestError as exc:
        _raise_http(exc)
    return {"ok": True}


@router.post(
    "/attempts/{attempt_id}/sections/{skill}/submit",
    response_model=SectionScore,
)
async def submit_attempt_section(
    attempt_id: str,
    skill: str,
    body: Optional[SectionSubmitRequest] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Grade one section. Re-submitting returns the stored score."""
    payload = body.model_dump() if body is not None else {}
    try:
        return await service.submit_section(
            db,
            attempt_id,
            skill=skill,
            payload=payload,
            user_id=current_user.id if current_user else None,
        )
    except service.MockTestError as exc:
        _raise_http(exc)
    raise HTTPException(status_code=400, detail="Could not grade section")


@router.post(
    "/attempts/{attempt_id}/complete",
    response_model=AttemptCompleteResponse,
)
async def complete_attempt(
    attempt_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Finalise the attempt, compute the overall band and award XP."""
    try:
        result = await service.complete_attempt(
            db, attempt_id, current_user.id if current_user else None
        )
    except service.IncompleteAttemptError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Missing section scores: {', '.join(exc.missing)}",
        )
    except service.MockTestError as exc:
        _raise_http(exc)

    first_completion = bool(result.pop("_first_completion", False))
    if first_completion and current_user is not None:
        _award_xp(current_user, int(result.get("xp_awarded") or 0))
    return result


# ──────────────────────────────────────────────
# Set detail (must stay last: /{set_id} would swallow /attempts)
# ──────────────────────────────────────────────


@router.get("/{set_id}")
async def get_mock_test(set_id: str):
    """Sanitized set content (no answer keys, transcripts or sample answers)."""
    try:
        return service.sanitize_set(service.get_set(set_id))
    except service.MockTestError as exc:
        _raise_http(exc)
    raise HTTPException(status_code=404, detail=f"Mock test set not found: {set_id}")
