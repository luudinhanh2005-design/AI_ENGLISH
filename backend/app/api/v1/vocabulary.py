from datetime import datetime, timezone
from typing import Any, Optional
import uuid
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import noload

from ...database import get_db, is_db_connected
from ...models.learning import UserWordProgress, VocabularyTopic, VocabularyWord
from ...models.user import User
from ...schemas.learning import (
    DueReviewWordItem,
    VocabularyStatsResponse,
    VocabularyTopicResponse,
    VocabularyWordPage,
    VocabularyWordResponse,
    WordProgressResponse,
    WordReviewSubmitRequest,
)
from ...services.sm2 import SM2Calculator
from ...utils.vocabulary_catalog import catalog_topics
from ..deps import get_optional_user, _DEFAULT_DEMO_ID

router = APIRouter()

# Pre-generate the offline fallback deck from the canonical catalog.  IDs are
# deterministic and shared with the database seed and the Flutter asset, so
# progress follows a word even when the app switches between online/offline.
_FALLBACK_TOPICS: list[VocabularyTopic] = []
_FALLBACK_TOPIC_BY_ID: dict[UUID, VocabularyTopic] = {}
_FALLBACK_TOPIC_WORDS: dict[UUID, list[VocabularyWord]] = {}
_FALLBACK_ALL_WORDS: list[VocabularyWord] = []
_FALLBACK_WORDS_MAP: dict[UUID, VocabularyWord] = {}
_FALLBACK_TOPIC_ORDER: dict[UUID, int] = {}


def _catalog_word_obj(topic_uuid: UUID, data: dict[str, Any]) -> VocabularyWord:
    return VocabularyWord(
        id=UUID(str(data["id"])),
        topic_id=topic_uuid,
        word=str(data["word"]),
        phonetic=str(data["phonetic"]),
        part_of_speech=str(data["part_of_speech"]),
        meaning_vi=str(data["meaning_vi"]),
        meaning_en=str(data["meaning_en"]),
        example_sentence=str(data["example_sentence"]),
        example_translation=str(data["example_translation"]),
        audio_url=data.get("audio_url"),
        image_url=data.get("image_url"),
        level=str(data.get("level", "A1")),
        collocations=list(data.get("collocations") or []),
        synonyms=list(data.get("synonyms") or []),
        antonyms=list(data.get("antonyms") or []),
        tags=list(data.get("tags") or []),
        order_index=int(data.get("order_index", 0)),
    )


for _idx, _topic_data in enumerate(catalog_topics()):
    _topic_uuid = UUID(str(_topic_data["id"]))
    _words_list: list[VocabularyWord] = []
    for _word_data in _topic_data.get("words", []):
        _word_obj = _catalog_word_obj(_topic_uuid, _word_data)
        _words_list.append(_word_obj)
        _FALLBACK_ALL_WORDS.append(_word_obj)
        _FALLBACK_WORDS_MAP[_word_obj.id] = _word_obj

    _topic_obj = VocabularyTopic(
        id=_topic_uuid,
        slug=str(_topic_data["slug"]),
        title=str(_topic_data["title"]),
        description=_topic_data.get("description"),
        icon_name=str(_topic_data.get("icon_name", "book")),
        level=str(_topic_data.get("level", "A1")),
        total_words=len(_words_list),
        order_index=int(_topic_data.get("order_index", _idx)),
        is_active=True,
    )
    _topic_obj.words = _words_list
    _FALLBACK_TOPICS.append(_topic_obj)
    _FALLBACK_TOPIC_BY_ID[_topic_uuid] = _topic_obj
    _FALLBACK_TOPIC_WORDS[_topic_uuid] = _words_list
    _FALLBACK_TOPIC_ORDER[_topic_uuid] = int(_topic_data.get("order_index", _idx))


def _topic_response(topic: VocabularyTopic, total_words: int | None = None) -> VocabularyTopicResponse:
    """Serialize a topic without loading its nested words."""
    return VocabularyTopicResponse(
        id=topic.id,
        slug=topic.slug,
        title=topic.title,
        description=topic.description,
        icon_name=topic.icon_name,
        level=topic.level,
        total_words=total_words
        if total_words is not None
        else int(getattr(topic, "total_words", 0) or 0),
        words=None,
    )


def _fallback_due_items(limit: int) -> list[DueReviewWordItem]:
    return [
        DueReviewWordItem(
            word=VocabularyWordResponse.model_validate(word),
            progress=None,
        )
        for word in _FALLBACK_ALL_WORDS[:limit]
    ]


def _fallback_word_page(
    *,
    q: Optional[str],
    topic_id: Optional[UUID],
    topic_slug: Optional[str],
    level: Optional[str],
    page: int,
    limit: int,
) -> VocabularyWordPage:
    query = (q or "").strip().lower()
    level_filter = (level or "").strip().upper()
    slug_filter = (topic_slug or "").strip().lower()

    topic_ids = set(_FALLBACK_TOPIC_BY_ID)
    if topic_id is not None:
        topic_ids &= {topic_id}
    elif slug_filter:
        topic_ids &= {
            topic.id for topic in _FALLBACK_TOPICS if topic.slug == slug_filter
        }

    filtered = []
    for word in _FALLBACK_ALL_WORDS:
        if word.topic_id not in topic_ids:
            continue
        if level_filter and word.level.upper() != level_filter:
            continue
        if query and (
            query not in word.word.lower()
            and query not in word.meaning_vi.lower()
            and query not in word.meaning_en.lower()
        ):
            continue
        filtered.append(word)

    filtered.sort(
        key=lambda word: (
            _FALLBACK_TOPIC_ORDER.get(word.topic_id, 0),
            word.order_index,
            word.word.lower(),
        )
    )
    total = len(filtered)
    start = (page - 1) * limit
    items = [
        VocabularyWordResponse.model_validate(word)
        for word in filtered[start : start + limit]
    ]
    return VocabularyWordPage(
        items=items,
        total=total,
        page=page,
        limit=limit,
        has_more=start + limit < total,
    )


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
            collocations=list(word.collocations or []),
            synonyms=list(word.synonyms or []),
            antonyms=list(word.antonyms or []),
            tags=list(word.tags or []),
            order_index=word.order_index,
        )
    )
    await db.flush()


@router.get("/topics", response_model=list[VocabularyTopicResponse])
async def list_topics(
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Retrieve all active vocabulary topics with live word counts."""
    if is_db_connected():
        try:
            counts = (
                select(
                    VocabularyWord.topic_id,
                    func.count(VocabularyWord.id).label("word_count"),
                )
                .group_by(VocabularyWord.topic_id)
                .subquery()
            )
            result = await db.execute(
                select(VocabularyTopic, func.coalesce(counts.c.word_count, 0))
                .options(noload(VocabularyTopic.words))
                .outerjoin(counts, counts.c.topic_id == VocabularyTopic.id)
                .where(VocabularyTopic.is_active == True)
                .order_by(VocabularyTopic.order_index, VocabularyTopic.title)
            )
            rows = result.all()
            if rows:
                return [
                    _topic_response(topic, int(total))
                    for topic, total in rows
                ]
        except Exception:
            await db.rollback()
    return [_topic_response(topic) for topic in _FALLBACK_TOPICS]


@router.get("/words", response_model=VocabularyWordPage)
async def list_words(
    q: Optional[str] = Query(None, description="Search headword or meaning"),
    topic_id: Optional[UUID] = None,
    topic_slug: Optional[str] = None,
    level: Optional[str] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Paginated, searchable vocabulary list for the full dictionary screen."""
    query_text = (q or "").strip()
    level_filter = (level or "").strip().upper()
    slug_filter = (topic_slug or "").strip().lower()

    if is_db_connected():
        try:
            conditions = [VocabularyTopic.is_active == True]
            if topic_id is not None:
                conditions.append(VocabularyWord.topic_id == topic_id)
            if slug_filter:
                conditions.append(VocabularyTopic.slug == slug_filter)
            if level_filter:
                conditions.append(VocabularyWord.level == level_filter)
            if query_text:
                pattern = f"%{query_text}%"
                conditions.append(
                    or_(
                        VocabularyWord.word.ilike(pattern),
                        VocabularyWord.meaning_vi.ilike(pattern),
                        VocabularyWord.meaning_en.ilike(pattern),
                    )
                )

            count_result = await db.execute(
                select(func.count(VocabularyWord.id))
                .join(VocabularyTopic, VocabularyWord.topic_id == VocabularyTopic.id)
                .where(*conditions)
            )
            total = int(count_result.scalar_one() or 0)

            result = await db.execute(
                select(VocabularyWord)
                .join(VocabularyTopic, VocabularyWord.topic_id == VocabularyTopic.id)
                .where(*conditions)
                .order_by(
                    VocabularyTopic.order_index,
                    VocabularyWord.order_index,
                    VocabularyWord.word,
                )
                .offset((page - 1) * limit)
                .limit(limit)
            )
            items = [
                VocabularyWordResponse.model_validate(word)
                for word in result.scalars().all()
            ]
            return VocabularyWordPage(
                items=items,
                total=total,
                page=page,
                limit=limit,
                has_more=(page - 1) * limit + len(items) < total,
            )
        except Exception:
            await db.rollback()

    return _fallback_word_page(
        q=q,
        topic_id=topic_id,
        topic_slug=topic_slug,
        level=level,
        page=page,
        limit=limit,
    )


@router.get("/stats", response_model=VocabularyStatsResponse)
async def get_vocabulary_stats(
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Return a small dashboard summary for the vocabulary bank."""
    total_words = len(_FALLBACK_ALL_WORDS)
    learned_words = 0
    due_words = 0
    mastered_words = 0

    if is_db_connected():
        try:
            total_result = await db.execute(
                select(func.count(VocabularyWord.id))
                .join(VocabularyTopic, VocabularyWord.topic_id == VocabularyTopic.id)
                .where(VocabularyTopic.is_active == True)
            )
            total_words = int(total_result.scalar_one() or 0)
            if total_words == 0:
                # Fresh database that has not been seeded yet; expose the
                # offline catalog size instead of a misleading zero.
                total_words = len(_FALLBACK_ALL_WORDS)

            if current_user is not None:
                now = datetime.now(timezone.utc)
                learned_result = await db.execute(
                    select(func.count(UserWordProgress.id))
                    .join(VocabularyWord, UserWordProgress.word_id == VocabularyWord.id)
                    .join(
                        VocabularyTopic,
                        VocabularyWord.topic_id == VocabularyTopic.id,
                    )
                    .where(
                        UserWordProgress.user_id == current_user.id,
                        VocabularyTopic.is_active == True,
                    )
                )
                learned_words = int(learned_result.scalar_one() or 0)

                due_result = await db.execute(
                    select(func.count(UserWordProgress.id))
                    .join(VocabularyWord, UserWordProgress.word_id == VocabularyWord.id)
                    .join(
                        VocabularyTopic,
                        VocabularyWord.topic_id == VocabularyTopic.id,
                    )
                    .where(
                        UserWordProgress.user_id == current_user.id,
                        UserWordProgress.next_review_at <= now,
                        VocabularyTopic.is_active == True,
                    )
                )
                due_words = int(due_result.scalar_one() or 0)

                mastered_result = await db.execute(
                    select(func.count(UserWordProgress.id))
                    .join(VocabularyWord, UserWordProgress.word_id == VocabularyWord.id)
                    .join(
                        VocabularyTopic,
                        VocabularyWord.topic_id == VocabularyTopic.id,
                    )
                    .where(
                        UserWordProgress.user_id == current_user.id,
                        UserWordProgress.status == "mastered",
                        VocabularyTopic.is_active == True,
                    )
                )
                mastered_words = int(mastered_result.scalar_one() or 0)
        except Exception:
            await db.rollback()

    return VocabularyStatsResponse(
        total_words=total_words,
        learned_words=learned_words,
        due_words=due_words,
        mastered_words=mastered_words,
        new_words=max(total_words - learned_words, 0),
    )


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
                select(VocabularyWord)
                .where(VocabularyWord.topic_id == topic_id)
                .order_by(VocabularyWord.order_index, VocabularyWord.word)
            )
            words = result.scalars().all()
            if words:
                return words
        except Exception:
            await db.rollback()
    return _FALLBACK_TOPIC_WORDS.get(topic_id, [])


@router.get("/due", response_model=list[DueReviewWordItem])
async def get_due_words(
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """
    Retrieve words that are due for review today according to SM-2.
    If fewer words are due, fetch some unlearned new words as well.
    """
    now = datetime.now(timezone.utc)

    if is_db_connected() and current_user:
        try:
            # If migrations ran but the catalog was not seeded, use the
            # in-memory deck instead of showing an empty "all done" screen.
            has_words = await db.execute(select(VocabularyWord.id).limit(1))
            if has_words.scalar_one_or_none() is None:
                return _fallback_due_items(limit)
        except Exception:
            await db.rollback()

        try:
            # 1. Due reviews, joined in one query instead of N+1 lookups.
            due_result = await db.execute(
                select(UserWordProgress, VocabularyWord)
                .join(VocabularyWord, UserWordProgress.word_id == VocabularyWord.id)
                .join(VocabularyTopic, VocabularyWord.topic_id == VocabularyTopic.id)
                .where(
                    UserWordProgress.user_id == current_user.id,
                    UserWordProgress.next_review_at <= now,
                    VocabularyTopic.is_active == True,
                )
                .order_by(UserWordProgress.next_review_at)
                .limit(limit)
            )
            due_items = [
                DueReviewWordItem(
                    word=VocabularyWordResponse.model_validate(word),
                    progress=WordProgressResponse.model_validate(progress),
                )
                for progress, word in due_result.all()
            ]

            # 2. Fill the remainder with new words the user has not reviewed.
            remaining = limit - len(due_items)
            if remaining > 0:
                user_words_subquery = select(UserWordProgress.word_id).where(
                    UserWordProgress.user_id == current_user.id
                )
                new_words_result = await db.execute(
                    select(VocabularyWord)
                    .join(VocabularyTopic, VocabularyWord.topic_id == VocabularyTopic.id)
                    .where(
                        VocabularyTopic.is_active == True,
                        VocabularyWord.id.not_in(user_words_subquery),
                    )
                    .order_by(func.random())
                    .limit(remaining)
                )
                for word in new_words_result.scalars().all():
                    due_items.append(
                        DueReviewWordItem(
                            word=VocabularyWordResponse.model_validate(word),
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
    Applies the SM-2 algorithm to compute the next review interval.
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
            progress_result = await db.execute(
                select(UserWordProgress).where(
                    UserWordProgress.user_id == user_id,
                    UserWordProgress.word_id == word_id,
                )
            )
            progress = progress_result.scalar_one_or_none()
        except Exception:
            await db.rollback()
            use_db = False

    if not progress:
        repetition_count = 0
        interval = 0
        ease_factor = SM2Calculator.DEFAULT_EASE_FACTOR
    else:
        repetition_count = progress.repetition_count
        interval = progress.interval_days
        ease_factor = progress.ease_factor

    new_rep, new_ef, new_interval, next_review, status_str = (
        SM2Calculator.calculate_next_review(
            repetition_count=repetition_count,
            ease_factor=ease_factor,
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
