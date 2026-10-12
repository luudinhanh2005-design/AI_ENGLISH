from datetime import datetime, timezone
from typing import Any, cast, Optional
import uuid
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ...database import get_db, IS_DB_CONNECTED
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
from ...utils.seed_learning_data import SAMPLE_VOCABULARY
from ..deps import get_current_user, get_optional_user, _DEFAULT_DEMO_ID

router = APIRouter()

# Pre-generate fallback vocabulary data
_FALLBACK_TOPICS: list[VocabularyTopic] = []
_FALLBACK_TOPIC_WORDS: dict[UUID, list[VocabularyWord]] = {}
_FALLBACK_ALL_WORDS: list[VocabularyWord] = []
_FALLBACK_WORDS_MAP: dict[UUID, VocabularyWord] = {}

for idx, t_raw in enumerate(SAMPLE_VOCABULARY):
    t_data: dict[str, Any] = cast(dict[str, Any], t_raw)
    t_slug = str(t_data["slug"])
    t_id = uuid.uuid5(uuid.NAMESPACE_DNS, f"vocab-topic-{t_slug}")
    words_list: list[VocabularyWord] = []
    raw_words = cast(list[dict[str, Any]], t_data.get("words", []))
    for w_data in raw_words:
        w_word = str(w_data["word"])
        w_id = uuid.uuid5(uuid.NAMESPACE_DNS, f"vocab-word-{w_word}")
        w_obj = VocabularyWord(
            id=w_id,
            topic_id=t_id,
            word=w_word,
            phonetic=str(w_data["phonetic"]),
            part_of_speech=str(w_data["part_of_speech"]),
            meaning_vi=str(w_data["meaning_vi"]),
            meaning_en=str(w_data["meaning_en"]),
            example_sentence=str(w_data["example_sentence"]),
            example_translation=str(w_data["example_translation"]),
            audio_url=w_data.get("audio_url"),
            image_url=w_data.get("image_url"),
            level=str(w_data.get("level", "A1")),
        )
        words_list.append(w_obj)
        _FALLBACK_ALL_WORDS.append(w_obj)
        _FALLBACK_WORDS_MAP[w_id] = w_obj

    t_obj = VocabularyTopic(
        id=t_id,
        slug=t_slug,
        title=str(t_data["title"]),
        description=t_data.get("description"),
        icon_name=str(t_data.get("icon_name", "book")),
        level=str(t_data.get("level", "A1")),
        total_words=len(words_list),
        order_index=idx,
        is_active=True,
    )
    t_obj.words = words_list
    _FALLBACK_TOPICS.append(t_obj)
    _FALLBACK_TOPIC_WORDS[t_id] = words_list


@router.get("/topics", response_model=list[VocabularyTopicResponse])
async def list_topics(
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Retrieve all active vocabulary topics."""
    if IS_DB_CONNECTED:
        try:
            result = await db.execute(
                select(VocabularyTopic)
                .where(VocabularyTopic.is_active == True)
                .order_by(VocabularyTopic.order_index)
            )
            topics = result.scalars().all()
            if topics:
                return topics
        except Exception:
            pass
    return _FALLBACK_TOPICS


@router.get("/topics/{topic_id}/words", response_model=list[VocabularyWordResponse])
async def get_topic_words(
    topic_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Retrieve all words belonging to a specific topic."""
    if IS_DB_CONNECTED:
        try:
            result = await db.execute(
                select(VocabularyWord).where(VocabularyWord.topic_id == topic_id)
            )
            words = result.scalars().all()
            if words:
                return words
        except Exception:
            pass
    return _FALLBACK_TOPIC_WORDS.get(topic_id, [])


@router.get("/due", response_model=list[DueReviewWordItem])
async def get_due_words(
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """
    Retrieve words that are due for review today according to SM-2 Spaced Repetition.
    If fewer words are due, fetch some unlearned new words as well.
    """
    now = datetime.now(timezone.utc)

    if IS_DB_CONNECTED and current_user:
        try:
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
            for p in progress_list:
                w_res = await db.execute(
                    select(VocabularyWord).where(VocabularyWord.id == p.word_id)
                )
                word = w_res.scalar_one_or_none()
                if word:
                    due_items.append(
                        DueReviewWordItem(
                            word=VocabularyWordResponse.model_validate(word),
                            progress=WordProgressResponse.model_validate(p),
                        )
                    )

            # 2. If below limit, fetch new unreviewed words
            remaining = limit - len(due_items)
            if remaining > 0:
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
                    due_items.append(
                        DueReviewWordItem(
                            word=VocabularyWordResponse.model_validate(w),
                            progress=None,
                        )
                    )

            if due_items:
                return due_items
        except Exception:
            pass

    return [
        DueReviewWordItem(
            word=VocabularyWordResponse.model_validate(w),
            progress=None,
        )
        for w in _FALLBACK_ALL_WORDS[:limit]
    ]


@router.post("/words/{word_id}/review", response_model=WordProgressResponse)
async def submit_word_review(
    word_id: UUID,
    request: WordReviewSubmitRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """
    Submit a review rating (0 to 5) for a vocabulary word.
    Applies the SM-2 algorithm to compute next review interval and updates user progress.
    """
    # Verify word exists
    word = None
    if IS_DB_CONNECTED:
        try:
            w_res = await db.execute(
                select(VocabularyWord).where(VocabularyWord.id == word_id)
            )
            word = w_res.scalar_one_or_none()
        except Exception:
            pass

    if not word:
        word = _FALLBACK_WORDS_MAP.get(word_id)

    if not word:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vocabulary word not found",
        )

    # Find existing progress or initialize new
    progress = None
    user_id = current_user.id if current_user else _DEFAULT_DEMO_ID
    if IS_DB_CONNECTED and current_user:
        try:
            p_res = await db.execute(
                select(UserWordProgress).where(
                    UserWordProgress.user_id == user_id,
                    UserWordProgress.word_id == word_id,
                )
            )
            progress = p_res.scalar_one_or_none()
        except Exception:
            pass

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
            id=uuid.uuid4(),
            user_id=user_id,
            word_id=word_id,
            repetition_count=new_rep,
            ease_factor=new_ef,
            interval_days=new_interval,
            next_review_at=next_review,
            last_reviewed_at=datetime.now(timezone.utc),
            status=status_str,
        )
        if IS_DB_CONNECTED and current_user:
            try:
                db.add(progress)
            except Exception:
                pass
    else:
        progress.repetition_count = new_rep
        progress.ease_factor = new_ef
        progress.interval_days = new_interval
        progress.next_review_at = next_review
        progress.last_reviewed_at = datetime.now(timezone.utc)
        progress.status = status_str

    if current_user:
        current_user.total_xp = (current_user.total_xp or 0) + 10
        if IS_DB_CONNECTED:
            try:
                await db.flush()
            except Exception:
                pass

    return progress
