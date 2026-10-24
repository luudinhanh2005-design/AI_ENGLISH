"""CEFR placement test API (v2).

The legacy ``/questions`` + ``/submit`` endpoints are kept only as explicit
deprecation responses; the app now uses adaptive stages, writing and speaking.
"""

from __future__ import annotations

import logging
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import inspect as sa_inspect
from sqlalchemy.ext.asyncio import AsyncSession

from ...database import get_db
from ...models.learning import XpTransaction
from ...models.user import User
from ...schemas.placement import (
    PlacementAnswerRequest,
    PlacementAnswerResponse,
    PlacementConfigResponse,
    PlacementHistoryItem,
    PlacementSessionCreate,
    PlacementSessionResponse,
    PlacementSkipSpeakingRequest,
    PlacementStageCompleteRequest,
    PlacementWritingRequest,
)
from ...services import placement_service as service
from ..deps import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()


def _raise_http(exc: service.PlacementError) -> None:
    if isinstance(exc, service.PlacementNotFound):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))
    if isinstance(exc, service.PlacementAccessDenied):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc))
    if isinstance(exc, service.PlacementStateError):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc))
    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


def _award_xp(
    db: Optional[AsyncSession],
    user: User,
    xp: int,
    session_id: str,
) -> None:
    if xp <= 0:
        return
    user.total_xp = int(user.total_xp or 0) + xp
    try:
        state = sa_inspect(user)
    except Exception:
        state = None
    if state is None or state.session is None:
        try:
            from ..deps import save_memory_users

            save_memory_users()
        except Exception:
            logger.warning("Could not persist offline placement XP", exc_info=True)
        return
    if db is not None:
        try:
            db.add(
                XpTransaction(
                    user_id=user.id,
                    source_type="placement",
                    source_id=UUID(session_id),
                    amount=xp,
                )
            )
        except Exception:
            logger.warning("Could not add placement XP ledger entry", exc_info=True)


# ──────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────


@router.get("/config", response_model=PlacementConfigResponse)
async def get_placement_config():
    """Public blueprint: modes, CEFR cut scores, exam mapping and can-do data."""
    return service.get_config()


# ──────────────────────────────────────────────
# Sessions
# ──────────────────────────────────────────────


@router.post("/sessions", response_model=PlacementSessionResponse)
async def create_placement_session(
    body: PlacementSessionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        return await service.create_session(
            db,
            current_user,
            mode=body.mode,
            target_exam=body.target_exam,
        )
    except service.PlacementError as exc:
        _raise_http(exc)
    raise HTTPException(status_code=400, detail="Could not create placement session")


@router.get("/sessions/{session_id}", response_model=PlacementSessionResponse)
async def get_placement_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        return await service.get_session(db, session_id, str(current_user.id))
    except service.PlacementError as exc:
        _raise_http(exc)
    raise HTTPException(status_code=404, detail="Placement session not found")


@router.post("/sessions/{session_id}/answers", response_model=PlacementAnswerResponse)
async def save_placement_answer(
    session_id: str,
    body: PlacementAnswerRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        return await service.save_answer(
            db,
            session_id,
            str(current_user.id),
            item_id=body.item_id,
            answer=body.answer,
            response_time_ms=body.response_time_ms,
            flagged=body.flagged,
        )
    except service.PlacementError as exc:
        _raise_http(exc)
    raise HTTPException(status_code=400, detail="Could not save answer")


@router.post(
    "/sessions/{session_id}/stages/complete",
    response_model=PlacementSessionResponse,
)
async def complete_placement_stage(
    session_id: str,
    body: Optional[PlacementStageCompleteRequest] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    payload = body.model_dump() if body is not None else {}
    answers = payload.get("answers")
    try:
        result = await service.complete_stage(
            db,
            session_id,
            str(current_user.id),
            answers=answers,
            stage_token=payload.get("stage_token"),
        )
    except service.PlacementError as exc:
        _raise_http(exc)
    first_completion = bool(result.pop("_first_completion", False))
    if first_completion:
        _award_xp(
            db,
            current_user,
            int(result.get("xp_awarded") or 0),
            session_id,
        )
    return result


@router.post("/sessions/{session_id}/writing", response_model=PlacementSessionResponse)
async def submit_placement_writing(
    session_id: str,
    body: PlacementWritingRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        result = await service.submit_writing(
            db,
            session_id,
            str(current_user.id),
            task_id=body.task_id,
            text=body.text,
            response_time_ms=body.response_time_ms,
        )
    except service.PlacementError as exc:
        _raise_http(exc)
    first_completion = bool(result.pop("_first_completion", False))
    if first_completion:
        _award_xp(
            db,
            current_user,
            int(result.get("xp_awarded") or 0),
            session_id,
        )
    return result


@router.post("/sessions/{session_id}/speaking", response_model=PlacementSessionResponse)
async def submit_placement_speaking(
    session_id: str,
    task_id: str = Form(...),
    audio: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    audio_data = await audio.read()
    if len(audio_data) > 12 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio file quá lớn. Tối đa 12MB.",
        )
    if len(audio_data) < 500:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio quá ngắn hoặc không hợp lệ.",
        )
    try:
        result = await service.submit_speaking(
            db,
            session_id,
            str(current_user.id),
            task_id=task_id,
            audio_data=audio_data,
            filename=audio.filename or "answer.webm",
            content_type=audio.content_type or "audio/webm",
        )
    except service.PlacementError as exc:
        _raise_http(exc)
    first_completion = bool(result.pop("_first_completion", False))
    if first_completion:
        _award_xp(
            db,
            current_user,
            int(result.get("xp_awarded") or 0),
            session_id,
        )
    return result


@router.post("/sessions/{session_id}/speaking/skip", response_model=PlacementSessionResponse)
async def skip_placement_speaking(
    session_id: str,
    body: PlacementSkipSpeakingRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        result = await service.skip_speaking(
            db,
            session_id,
            str(current_user.id),
            task_id=body.task_id,
        )
    except service.PlacementError as exc:
        _raise_http(exc)
    first_completion = bool(result.pop("_first_completion", False))
    if first_completion:
        _award_xp(
            db,
            current_user,
            int(result.get("xp_awarded") or 0),
            session_id,
        )
    return result


@router.delete("/sessions/{session_id}")
async def abandon_placement_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        await service.abandon_session(db, session_id, str(current_user.id))
    except service.PlacementError as exc:
        _raise_http(exc)
    return {"ok": True}


# ──────────────────────────────────────────────
# Results / history
# ──────────────────────────────────────────────


@router.get("/results/latest")
async def get_latest_placement_result(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await service.get_latest_result(db, str(current_user.id))
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chưa có kết quả kiểm tra trình độ.",
        )
    return result


@router.get("/results/{result_id}")
async def get_placement_result(
    result_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        return await service.get_result(db, result_id, str(current_user.id))
    except service.PlacementError as exc:
        _raise_http(exc)
    raise HTTPException(status_code=404, detail="Placement result not found")


@router.get("/history", response_model=list[PlacementHistoryItem])
async def get_placement_history(
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await service.list_history(
        db, str(current_user.id), limit=max(1, min(limit, 50))
    )


# ──────────────────────────────────────────────
# Legacy (explicitly retired)
# ──────────────────────────────────────────────


@router.get("/questions", deprecated=True)
async def legacy_placement_questions():
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="API cũ đã ngừng. Hãy dùng /placement/config và /placement/sessions.",
    )


@router.post("/submit", deprecated=True)
async def legacy_placement_submit():
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="API cũ đã ngừng. Hãy dùng /placement/sessions.",
    )
