from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...database import get_db
from ...models.learning import GrammarLesson, UserGrammarProgress
from ...models.user import User
from ...schemas.learning import (
    GrammarLessonDetail,
    GrammarLessonSummary,
    GrammarResultResponse,
    GrammarSubmitRequest,
)
from ..deps import get_current_user

router = APIRouter()


@router.get("/lessons", response_model=list[GrammarLessonSummary])
async def list_grammar_lessons(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve all grammar lessons with current user completion status."""
    result = await db.execute(
        select(GrammarLesson)
        .where(GrammarLesson.is_active == True)
        .order_by(GrammarLesson.order_index)
    )
    lessons = result.scalars().all()

    # User progress map
    prog_res = await db.execute(
        select(UserGrammarProgress).where(UserGrammarProgress.user_id == current_user.id)
    )
    user_prog_map = {p.lesson_id: p for p in prog_res.scalars().all()}

    summary_list = []
    for l in lessons:
        p = user_prog_map.get(l.id)
        summary_list.append(
            GrammarLessonSummary(
                id=l.id,
                slug=l.slug,
                title=l.title,
                level=l.level,
                summary=l.summary,
                order_index=l.order_index,
                is_completed=p.is_completed if p else False,
                score=p.score if p else None,
            )
        )

    return summary_list


@router.get("/lessons/{lesson_id}", response_model=GrammarLessonDetail)
async def get_grammar_lesson_detail(
    lesson_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve full content, formulas, examples, and practice quiz of a grammar lesson."""
    result = await db.execute(
        select(GrammarLesson).where(GrammarLesson.id == lesson_id)
    )
    lesson = result.scalar_one_or_none()
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Grammar lesson not found",
        )
    return lesson


@router.post("/lessons/{lesson_id}/submit", response_model=GrammarResultResponse)
async def submit_grammar_practice(
    lesson_id: UUID,
    request: GrammarSubmitRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Submit answers for the practice quiz in a grammar lesson."""
    result = await db.execute(
        select(GrammarLesson).where(GrammarLesson.id == lesson_id)
    )
    lesson = result.scalar_one_or_none()
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Grammar lesson not found",
        )

    questions = lesson.practice_questions or []
    if not questions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No practice questions available for this lesson",
        )

    total = len(questions)
    correct = 0

    # Map user answers
    user_ans_map = {a.question_index: a.selected_option for a in request.answers}
    for idx, q in enumerate(questions):
        correct_opt = q.get("correct_option")
        if user_ans_map.get(idx) == correct_opt:
            correct += 1

    score_pct = round((correct / total) * 100, 1) if total > 0 else 0.0
    is_passed = score_pct >= 70.0
    xp_earned = 30 if is_passed else 10

    # Save or update progress
    p_res = await db.execute(
        select(UserGrammarProgress).where(
            UserGrammarProgress.user_id == current_user.id,
            UserGrammarProgress.lesson_id == lesson_id,
        )
    )
    prog = p_res.scalar_one_or_none()
    if not prog:
        prog = UserGrammarProgress(
            user_id=current_user.id,
            lesson_id=lesson_id,
            score=score_pct,
            is_completed=is_passed,
            completed_at=datetime.now(timezone.utc) if is_passed else None,
        )
        db.add(prog)
    else:
        prog.score = max(prog.score, score_pct)
        if is_passed and not prog.is_completed:
            prog.is_completed = True
            prog.completed_at = datetime.now(timezone.utc)

    current_user.total_xp += xp_earned
    await db.flush()

    return GrammarResultResponse(
        score=score_pct,
        total=total,
        correct=correct,
        is_passed=is_passed,
        xp_earned=xp_earned,
    )
