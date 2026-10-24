from datetime import datetime, timezone
from typing import Any, cast, Optional
import uuid
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ...database import get_db, is_db_connected
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
_FALLBACK_TOPIC_BY_ID: dict[UUID, VocabularyTopic] = {}
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
    _FALLBACK_TOPIC_BY_ID[t_id] = t_obj
    _FALLBACK_TOPIC_WORDS[t_id] = words_list


async def _ensure_word_persisted(db: AsyncSession, word: VocabularyWord) -> None:
    """Insert a fallback word (and its topic) before tracking progress for it."""
    topic = _FALLBACK_TOPIC_BY_ID.get(word.topic_id)
    topic_id = word.topic_id

    if topic is not None:
        existing_topic = await db.get(VocabularyTopic, topic.id)
        if existing_topic is None:
            # A manual/legacy seed may have created the same slug with a
            # different generated id. Re-use it instead of violating the
            # unique slug constraint.
            by_slug = await db.execute(
                select(VocabularyTopic).where(VocabularyTopic.slug == topic.slug)
            )
            existing_topic = by_slug.scalar_one_or_none()

        if existing_topic is None:
            db.add(
                VocabularyTopic(
                    id=topic.id,
                    slug=topic.slug,
                    title=topic.title,
                    description=topic.description,
                    icon_name=topic.icon_name,
                    level=topic.level,
                    total_words=topic.total_words,
                    order_index=topic.order_index,
                    is_active=True,
                )
            )
            await db.flush()
        else:
            topic_id = existing_topic.id

    db.add(
        VocabularyWord(
            id=word.id,
            topic_id=topic_id,
            word=word.word,
            phonetic=word.phonetic,
            part_of_speech=word.part_of_speech,
            meaning_vi=word.meaning_vi,
            meaning_en=word.meaning_en,
            example_sentence=word.example_sentence,
            example_translation=word.example_translation,
            audio_url=word.audio_url,
            image_url=word.image_url,
            level=word.level,
        )
    )
    await db.flush()


@router.get("/topics", response_model=list[VocabularyTopicResponse])
async def list_topics(
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Retrieve all active vocabulary topics."""
    if is_db_connected():
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
    if is_db_connected():
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


def _fallback_due_items(limit: int) -> list[DueReviewWordItem]:
    return [
        DueReviewWordItem(
            word=VocabularyWordResponse.model_validate(w),
            progress=None,
        )
        for w in _FALLBACK_ALL_WORDS[:limit]
    ]


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

    if is_db_connected() and current_user:
        try:
            # If migrations ran but the vocabulary seed did not, use the
            # in-memory deck instead of showing an empty "all done" screen.
            has_words = await db.execute(select(VocabularyWord.id).limit(1))
            if has_words.scalar_one_or_none() is None:
                return _fallback_due_items(limit)
        except Exception:
            await db.rollback()

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
                    .join(VocabularyTopic, VocabularyWord.topic_id == VocabularyTopic.id)
                    .where(
                        VocabularyTopic.is_active == True,
                        VocabularyWord.id.not_in(user_words_subquery),
                    )
                    .order_by(func.random())
                    .limit(remaining)
                )
                for w in new_words_res.scalars().all():
                    due_items.append(
                        DueReviewWordItem(
                            word=VocabularyWordResponse.model_validate(w),
                            progress=None,
                        )
                    )

            # A successful DB query with an empty list means the user is done
            # for today. Do not fall back to the same static words, otherwise
            # every session would repeat them forever.
            return due_items
        except Exception:
            await db.rollback()

    return _fallback_due_items(limit)


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
    use_db = bool(is_db_connected() and current_user is not None and db is not None)

    # Verify word exists
    word = None
    if use_db:
        try:
            word = await db.get(VocabularyWord, word_id)
        except Exception:
            await db.rollback()
            use_db = False

    if not word:
        word = _FALLBACK_WORDS_MAP.get(word_id)

    if not word:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vocabulary word not found",
        )

    # Fallback vocabulary lives in memory; persist it before writing progress so
    # the `user_word_progress.word_id` foreign key is always satisfied.
    if use_db and not await db.get(VocabularyWord, word.id):
        try:
            await _ensure_word_persisted(db, word)
        except Exception:
            await db.rollback()
            use_db = False

    # Find existing progress or initialize new
    progress = None
    user_id = current_user.id if current_user else _DEFAULT_DEMO_ID
    if use_db:
        try:
            p_res = await db.execute(
                select(UserWordProgress).where(
                    UserWordProgress.user_id == user_id,
                    UserWordProgress.word_id == word_id,
                )
            )
            progress = p_res.scalar_one_or_none()
        except Exception:
            await db.rollback()
            use_db = False

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
        if use_db:
            db.add(progress)
    else:
        progress.repetition_count = new_rep
        progress.ease_factor = new_ef
        progress.interval_days = new_interval
        progress.next_review_at = next_review
        progress.last_reviewed_at = datetime.now(timezone.utc)
        progress.status = status_str

    if current_user:
        current_user.total_xp = (current_user.total_xp or 0) + 10
        if use_db:
            try:
                await db.flush()
            except Exception:
                await db.rollback()

    return progress
