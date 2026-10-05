import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


# ──────────────────────────────────────────────
# 1. Placement Test Models
# ──────────────────────────────────────────────

class PlacementQuestion(Base):
    """Question bank for Placement Test and general evaluations."""

    __tablename__ = "placement_questions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    skill: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
        comment="vocabulary, grammar, reading, listening",
    )
    difficulty_level: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        index=True,
        comment="A1, A2, B1, B2, C1",
    )
    question_text: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    context_text: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="Reading passage or context if applicable",
    )
    audio_url: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
        comment="Audio URL for listening questions",
    )
    options: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        comment="List of options: ['A', 'B', 'C', 'D']",
    )
    correct_option: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="Index of correct option (0-indexed)",
    )
    explanation: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="Detailed explanation of the correct answer",
    )
    order_index: Mapped[int] = mapped_column(
        Integer,
        default=0,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


class UserTestSubmission(Base):
    """User placement test submissions and results."""

    __tablename__ = "user_test_submissions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    total_questions: Mapped[int] = mapped_column(Integer, nullable=False)
    correct_count: Mapped[int] = mapped_column(Integer, nullable=False)
    score_percentage: Mapped[float] = mapped_column(Float, nullable=False)
    assessed_level: Mapped[str] = mapped_column(String(10), nullable=False)
    skill_breakdown: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        comment="Breakdown by skill: {vocabulary: 80, grammar: 60, ...}",
    )
    user_answers: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        comment="List of {question_id, selected_option, is_correct}",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


# ──────────────────────────────────────────────
# 2. Vocabulary & Spaced Repetition (SM-2) Models
# ──────────────────────────────────────────────

class VocabularyTopic(Base):
    """Vocabulary category or topic."""

    __tablename__ = "vocabulary_topics"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    slug: Mapped[str] = mapped_column(
        String(100),
        unique=True,
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    icon_name: Mapped[str] = mapped_column(String(50), default="book")
    level: Mapped[str] = mapped_column(String(10), default="A1")
    total_words: Mapped[int] = mapped_column(Integer, default=0)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Relationships
    words: Mapped[list["VocabularyWord"]] = relationship(
        back_populates="topic",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class VocabularyWord(Base):
    """Individual vocabulary item."""

    __tablename__ = "vocabulary_words"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    topic_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("vocabulary_topics.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    word: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    phonetic: Mapped[str] = mapped_column(String(100), nullable=False)
    part_of_speech: Mapped[str] = mapped_column(String(30), default="noun")
    meaning_vi: Mapped[str] = mapped_column(Text, nullable=False)
    meaning_en: Mapped[str] = mapped_column(Text, nullable=False)
    example_sentence: Mapped[str] = mapped_column(Text, nullable=False)
    example_translation: Mapped[str] = mapped_column(Text, nullable=False)
    audio_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    level: Mapped[str] = mapped_column(String(10), default="A1")

    # Relationships
    topic: Mapped["VocabularyTopic"] = relationship(back_populates="words")


class UserWordProgress(Base):
    """Spaced Repetition (SM-2) tracking for each user & word."""

    __tablename__ = "user_word_progress"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    word_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("vocabulary_words.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # SM-2 Algorithm variables
    repetition_count: Mapped[int] = mapped_column(Integer, default=0)
    interval_days: Mapped[int] = mapped_column(Integer, default=0)
    ease_factor: Mapped[float] = mapped_column(Float, default=2.5)
    last_reviewed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    next_review_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=func.now(),
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(20),
        default="new",
        comment="new, learning, reviewing, mastered",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


# ──────────────────────────────────────────────
# 3. Grammar Lesson Models
# ──────────────────────────────────────────────

class GrammarLesson(Base):
    """Grammar lesson content and rules."""

    __tablename__ = "grammar_lessons"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    slug: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    level: Mapped[str] = mapped_column(String(10), default="A1")
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    content_markdown: Mapped[str] = mapped_column(Text, nullable=False)
    formula: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    examples: Mapped[list] = mapped_column(JSONB, default=list)
    practice_questions: Mapped[list] = mapped_column(
        JSONB,
        default=list,
        comment="List of quiz questions for immediate practice",
    )
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


class UserGrammarProgress(Base):
    """User completion status for grammar lessons."""

    __tablename__ = "user_grammar_progress"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    lesson_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("grammar_lessons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    score: Mapped[float] = mapped_column(Float, default=0.0)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
