from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...database import get_db, is_db_connected
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


import uuid
from ...utils.seed_learning_data import SAMPLE_GRAMMAR

# Pre-generate fallback grammar data
_FALLBACK_GRAMMAR_LESSONS = []
_FALLBACK_GRAMMAR_MAP = {}

for idx, g_data in enumerate(SAMPLE_GRAMMAR):
    g_id = uuid.uuid5(uuid.NAMESPACE_DNS, f"grammar-lesson-{g_data['slug']}")
    g_obj = GrammarLesson(
        id=g_id,
        slug=g_data["slug"],
        title=g_data["title"],
        level=g_data["level"],
        summary=g_data["summary"],
        formula=g_data["formula"],
        content_markdown=g_data["content_markdown"],
        examples=g_data["examples"],
        practice_questions=g_data["practice_questions"],
        order_index=g_data["order_index"],
        is_active=True,
    )
    _FALLBACK_GRAMMAR_LESSONS.append(g_obj)
    _FALLBACK_GRAMMAR_MAP[g_id] = g_obj


@router.get("/lessons", response_model=list[GrammarLessonSummary])
async def list_grammar_lessons(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve all grammar lessons with current user completion status."""
    if is_db_connected():
        try:
            result = await db.execute(
                select(GrammarLesson)
                .where(GrammarLesson.is_active == True)
                .order_by(GrammarLesson.order_index)
            )
            lessons = result.scalars().all()

            if lessons:
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
        except Exception:
            pass

    return [
        GrammarLessonSummary(
            id=l.id,
            slug=l.slug,
            title=l.title,
            level=l.level,
            summary=l.summary,
            order_index=l.order_index,
            is_completed=False,
            score=None,
        )
        for l in _FALLBACK_GRAMMAR_LESSONS
    ]


@router.get("/lessons/{lesson_id}", response_model=GrammarLessonDetail)
async def get_grammar_lesson_detail(
    lesson_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve full content, formulas, examples, and practice quiz of a grammar lesson."""
    lesson = None
    if is_db_connected():
        try:
            result = await db.execute(
                select(GrammarLesson).where(GrammarLesson.id == lesson_id)
            )
            lesson = result.scalar_one_or_none()
        except Exception:
            pass

    if not lesson:
        lesson = _FALLBACK_GRAMMAR_MAP.get(lesson_id)

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
    lesson = None
    try:
        result = await db.execute(
            select(GrammarLesson).where(GrammarLesson.id == lesson_id)
        )
        lesson = result.scalar_one_or_none()
    except Exception:
        pass

    if not lesson:
        lesson = _FALLBACK_GRAMMAR_MAP.get(lesson_id)

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

    # Save or update progress safely
    try:
        p_res = await db.execute(
            select(UserGrammarProgress).where(
                UserGrammarProgress.user_id == current_user.id,
                UserGrammarProgress.lesson_id == lesson_id,
            )
        )
        prog = p_res.scalar_one_or_none()
        if not prog:
            prog = UserGrammarProgress(
                id=uuid.uuid4(),
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
        await db.flush()
    except Exception:
        pass

    current_user.total_xp = (current_user.total_xp or 0) + xp_earned

    return GrammarResultResponse(
        score=score_pct,
        total=total,
        correct=correct,
        is_passed=is_passed,
        xp_earned=xp_earned,
    )
