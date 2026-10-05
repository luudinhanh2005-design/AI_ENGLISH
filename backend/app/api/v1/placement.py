import logging
from collections import defaultdict

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...database import get_db
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


@router.get("/questions", response_model=list[PlacementQuestionResponse])
async def get_placement_questions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve active placement test questions."""
    result = await db.execute(
        select(PlacementQuestion)
        .where(PlacementQuestion.is_active == True)
        .order_index_by_order if hasattr(PlacementQuestion, 'order_index_by_order') else
        select(PlacementQuestion).where(PlacementQuestion.is_active == True).order_by(PlacementQuestion.order_index)
    )
    questions = result.scalars().all()
    return questions


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

    # 1. Fetch questions from DB
    question_ids = [a.question_id for a in submission.answers]
    result = await db.execute(
        select(PlacementQuestion).where(PlacementQuestion.id.in_(question_ids))
    )
    question_map = {q.id: q for q in result.scalars().all()}

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

    # 6. Save test submission
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

    # 7. Update User profile and level
    current_user.current_level = level
    current_user.total_xp += 50  # Reward 50 XP for completing placement

    # Update or create user profile
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

    return PlacementResultResponse(
        total_questions=total_count,
        correct_count=correct_count,
        score_percentage=score_percentage,
        assessed_level=level,
        skill_breakdown=skill_breakdown,
        recommendation=recommendation,
        weaknesses=weaknesses,
    )
