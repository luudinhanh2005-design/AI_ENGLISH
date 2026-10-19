import logging
from collections import defaultdict

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...database import get_db, is_db_connected
from ...models.learning import PlacementQuestion, UserTestSubmission
from ...models.user import User, UserProfile
from ...schemas.learning import (
    PlacementQuestionResponse,
    PlacementResultResponse,
    PlacementSubmissionRequest,
)
from ..deps import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()


import uuid
from uuid import UUID

from ...utils.seed_learning_data import SAMPLE_QUESTIONS

# Pre-generate fallback placement question models
_FALLBACK_QUESTIONS = []
_FALLBACK_QUESTION_MAP = {}
for q in SAMPLE_QUESTIONS:
    q_id = uuid.uuid5(uuid.NAMESPACE_DNS, f"placement-{q['order_index']}")
    q_obj = PlacementQuestion(
        id=q_id,
        skill=q["skill"],
        difficulty_level=q["difficulty_level"],
        question_text=q["question_text"],
        context_text=q.get("context_text"),
        audio_url=q.get("audio_url"),
        options=q["options"],
        correct_option=q["correct_option"],
        explanation=q.get("explanation"),
        order_index=q["order_index"],
        is_active=True,
    )
    _FALLBACK_QUESTIONS.append(q_obj)
    _FALLBACK_QUESTION_MAP[q_id] = q_obj


@router.get("/questions", response_model=list[PlacementQuestionResponse])
async def get_placement_questions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve active placement test questions."""
    if is_db_connected():
        try:
            result = await db.execute(
                select(PlacementQuestion)
                .where(PlacementQuestion.is_active == True)
                .order_by(PlacementQuestion.order_index)
            )
            questions = result.scalars().all()
            if questions:
                return questions
        except Exception:
            pass

    return _FALLBACK_QUESTIONS


@router.post("/submit", response_model=PlacementResultResponse)
async def submit_placement_test(
    submission: PlacementSubmissionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Evaluate placement test answers, assign CEFR level, 
    and update learner's profile with AI-assessed skills and weaknesses.
    """
    if not submission.answers:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one answer must be submitted",
        )

    # 1. Fetch questions from DB or fallback
    question_map = {}
    try:
        question_ids = [a.question_id for a in submission.answers]
        result = await db.execute(
            select(PlacementQuestion).where(PlacementQuestion.id.in_(question_ids))
        )
        question_map = {q.id: q for q in result.scalars().all()}
    except Exception:
        pass

    if not question_map:
        question_map = _FALLBACK_QUESTION_MAP

    # 2. Score calculations
    total_count = len(submission.answers)
    correct_count = 0
    skill_stats = defaultdict(lambda: {"total": 0, "correct": 0})
    user_answers_log = []

    for item in submission.answers:
        q = question_map.get(item.question_id)
        if not q:
            continue

        is_correct = (item.selected_option == q.correct_option)
        if is_correct:
            correct_count += 1
            skill_stats[q.skill]["correct"] += 1
        skill_stats[q.skill]["total"] += 1

        user_answers_log.append({
            "question_id": str(item.question_id),
            "selected_option": item.selected_option,
            "correct_option": q.correct_option,
            "is_correct": is_correct,
            "skill": q.skill,
        })

    score_percentage = round((correct_count / total_count) * 100, 1) if total_count > 0 else 0.0

    # 3. Determine CEFR Level
    # Standard thresholding:
    # 0-35%: A1, 36-55%: A2, 56-75%: B1, 76-90%: B2, 91-100%: C1
    if score_percentage <= 35:
        level = "A1"
    elif score_percentage <= 55:
        level = "A2"
    elif score_percentage <= 75:
        level = "B1"
    elif score_percentage <= 90:
        level = "B2"
    else:
        level = "C1"

    # 4. Compute skill breakdown percentages & identify weaknesses
    skill_breakdown = {}
    weaknesses = []
    for skill_name, stats in skill_stats.items():
        pct = round((stats["correct"] / stats["total"]) * 100, 1) if stats["total"] > 0 else 0.0
        skill_breakdown[skill_name] = pct
        if pct < 60.0:
            weaknesses.append(f"Kỹ năng {skill_name} cần cải thiện ({pct}%)")

    # 5. Recommendation message
    recommendation = (
        f"Bạn được xếp vào trình độ {level}. "
        f"Lộ trình học đã được AI tối ưu hóa để tập trung củng cố {', '.join(weaknesses) if weaknesses else 'kỹ năng giao tiếp nâng cao'}."
    )

    # 6. Save test submission & update profile
    current_user.current_level = level
    current_user.total_xp = (current_user.total_xp or 0) + 50  # Reward 50 XP for completing placement

    try:
        test_record = UserTestSubmission(
            user_id=current_user.id,
            total_questions=total_count,
            correct_count=correct_count,
            score_percentage=score_percentage,
            assessed_level=level,
            skill_breakdown=skill_breakdown,
            user_answers=user_answers_log,
        )
        db.add(test_record)

        result_profile = await db.execute(
            select(UserProfile).where(UserProfile.user_id == current_user.id)
        )
        profile = result_profile.scalar_one_or_none()
        if not profile:
            profile = UserProfile(user_id=current_user.id)
            db.add(profile)

        profile.skill_scores = skill_breakdown
        profile.weaknesses = weaknesses
        await db.flush()
    except Exception:
        pass

    return PlacementResultResponse(
        total_questions=total_count,
        correct_count=correct_count,
        score_percentage=score_percentage,
        assessed_level=level,
        skill_breakdown=skill_breakdown,
        recommendation=recommendation,
        weaknesses=weaknesses,
    )
