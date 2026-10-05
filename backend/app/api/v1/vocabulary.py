from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ...database import get_db
from ...models.learning import UserWordProgress, VocabularyTopic, VocabularyWord
from ...models.user import User
from ...schemas.learning import (
    DueReviewWordItem,
    VocabularyTopicResponse,
    VocabularyWordResponse,
    WordProgressResponse,
    WordReviewSubmitRequest,
)
from ...services.sm2 import SM2Calculator
from ..deps import get_current_user

router = APIRouter()


@router.get("/topics", response_model=list[VocabularyTopicResponse])
async def list_topics(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve all active vocabulary topics."""
    result = await db.execute(
        select(VocabularyTopic)
        .where(VocabularyTopic.is_active == True)
        .order_by(VocabularyTopic.order_index)
    )
    topics = result.scalars().all()
    return topics


@router.get("/topics/{topic_id}/words", response_model=list[VocabularyWordResponse])
async def get_topic_words(
    topic_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve all words belonging to a specific topic."""
    result = await db.execute(
        select(VocabularyWord).where(VocabularyWord.topic_id == topic_id)
    )
    words = result.scalars().all()
    return words


@router.get("/due", response_model=list[DueReviewWordItem])
async def get_due_words(
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieve words that are due for review today according to SM-2 Spaced Repetition.
    If fewer words are due, fetch some unlearned new words as well.
    """
    now = datetime.now(timezone.utc)

    # 1. Fetch due reviews for this user
    result = await db.execute(
        select(UserWordProgress)
        .where(
            UserWordProgress.user_id == current_user.id,
            UserWordProgress.next_review_at <= now,
        )
        .order_by(UserWordProgress.next_review_at)
        .limit(limit)
    )
    progress_list = result.scalars().all()

    due_items = []
    reviewed_word_ids = set()

    for p in progress_list:
        reviewed_word_ids.add(p.word_id)
        w_res = await db.execute(
            select(VocabularyWord).where(VocabularyWord.id == p.word_id)
        )
        word = w_res.scalar_one_or_none()
        if word:
            due_items.append(DueReviewWordItem(word=word, progress=p))

    # 2. If below limit, fetch new unreviewed words
    remaining = limit - len(due_items)
    if remaining > 0:
        # Subquery of all words user has interacted with
        user_words_subquery = (
            select(UserWordProgress.word_id)
            .where(UserWordProgress.user_id == current_user.id)
        )
        new_words_res = await db.execute(
            select(VocabularyWord)
            .where(VocabularyWord.id.not_in(user_words_subquery))
            .limit(remaining)
        )
        for w in new_words_res.scalars().all():
            due_items.append(DueReviewWordItem(word=w, progress=None))

    return due_items


@router.post("/words/{word_id}/review", response_model=WordProgressResponse)
async def submit_word_review(
    word_id: UUID,
    request: WordReviewSubmitRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Submit a review rating (0 to 5) for a vocabulary word.
    Applies the SM-2 algorithm to compute next review interval and updates user progress.
    """
    # Verify word exists
    w_res = await db.execute(
        select(VocabularyWord).where(VocabularyWord.id == word_id)
    )
    word = w_res.scalar_one_or_none()
    if not word:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vocabulary word not found",
        )

    # Find existing progress or initialize new
    p_res = await db.execute(
        select(UserWordProgress).where(
            UserWordProgress.user_id == current_user.id,
            UserWordProgress.word_id == word_id,
        )
    )
    progress = p_res.scalar_one_or_none()

    if not progress:
        rep_count = 0
        interval = 0
        ef = SM2Calculator.DEFAULT_EASE_FACTOR
    else:
        rep_count = progress.repetition_count
        interval = progress.interval_days
        ef = progress.ease_factor

    # Apply SM-2 calculation
    new_rep, new_ef, new_interval, next_review, status_str = (
        SM2Calculator.calculate_next_review(
            repetition_count=rep_count,
            ease_factor=ef,
            interval_days=interval,
            quality=request.quality,
        )
    )

    if not progress:
        progress = UserWordProgress(
            user_id=current_user.id,
            word_id=word_id,
            repetition_count=new_rep,
            ease_factor=new_ef,
            interval_days=new_interval,
            next_review_at=next_review,
            last_reviewed_at=datetime.now(timezone.utc),
            status=status_str,
        )
        db.add(progress)
    else:
        progress.repetition_count = new_rep
        progress.ease_factor = new_ef
        progress.interval_days = new_interval
        progress.next_review_at = next_review
        progress.last_reviewed_at = datetime.now(timezone.utc)
        progress.status = status_str

    # Reward XP: 10 XP for review
    current_user.total_xp += 10
    await db.flush()

    return progress
