import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
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


class UserMistake(Base):
    """A mistake saved to the user's notebook for SM-2 review."""

    __tablename__ = "user_mistakes"

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
    original_text: Mapped[str] = mapped_column(Text, nullable=False)
    corrected_text: Mapped[str] = mapped_column(Text, nullable=False, default="")
    explanation: Mapped[str] = mapped_column(Text, nullable=False, default="")
    type: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="grammar",
        comment="grammar, vocabulary, pronunciation",
    )
    source: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="practice",
        comment="voice_call, writing, ielts, practice, custom",
    )

    # SM-2 scheduling state
    repetition_count: Mapped[int] = mapped_column(Integer, default=0)
    interval_days: Mapped[int] = mapped_column(Integer, default=1)
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
    """Grammar lesson content and rules.

    ``content`` is the canonical local-compatible payload. The legacy columns
    remain populated so older clients and admin queries keep working.
    """

    __tablename__ = "grammar_lessons"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    slug: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    title_vi: Mapped[str] = mapped_column(String(200), default="", server_default="")
    level: Mapped[str] = mapped_column(String(10), default="A1")
    category: Mapped[str] = mapped_column(String(120), default="", server_default="")
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    content_markdown: Mapped[str] = mapped_column(Text, nullable=False)
    formula: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    examples: Mapped[list] = mapped_column(JSONB, default=list)
    practice_questions: Mapped[list] = mapped_column(
        JSONB,
        default=list,
        comment="List of quiz questions for immediate practice",
    )
    content: Mapped[Optional[dict]] = mapped_column(
        JSONB,
        nullable=True,
        comment="Canonical A1-C2 JSON payload used by the Flutter client",
    )
    content_hash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    status: Mapped[str] = mapped_column(
        String(20),
        default="published",
        server_default="published",
        index=True,
        comment="draft, in_review, published, archived",
    )
    version: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    is_beta: Mapped[bool] = mapped_column(Boolean, default=False)
    tags: Mapped[list] = mapped_column(JSONB, default=list)
    estimated_minutes: Mapped[int] = mapped_column(Integer, default=10, server_default="10")
    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), nullable=True)
    updated_by: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), nullable=True)
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    published_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


class GrammarLessonVersion(Base):
    """Immutable published/draft snapshots for rollback and audit."""

    __tablename__ = "grammar_lesson_versions"
    __table_args__ = (
        UniqueConstraint("lesson_id", "version", name="uq_grammar_lesson_version"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    lesson_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("grammar_lessons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    content: Mapped[dict] = mapped_column(JSONB, nullable=False)
    content_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    changelog: Mapped[str] = mapped_column(Text, default="", server_default="")
    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


class UserGrammarProgress(Base):
    """Best score and completion state for a user and lesson."""

    __tablename__ = "user_grammar_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "lesson_id", name="uq_user_grammar_progress_user_lesson"),
    )

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
    best_score: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    attempts_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    last_attempt_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


class GrammarAttempt(Base):
    """An idempotent grammar quiz attempt."""

    __tablename__ = "grammar_attempts"
    __table_args__ = (
        UniqueConstraint("user_id", "attempt_id", name="uq_grammar_attempt_user_attempt"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    attempt_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
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
    lesson_version: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    answers: Mapped[list] = mapped_column(JSONB, default=list)
    score: Mapped[float] = mapped_column(Float, default=0.0)
    correct: Mapped[int] = mapped_column(Integer, default=0)
    total: Mapped[int] = mapped_column(Integer, default=0)
    xp_awarded: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


class XpTransaction(Base):
    """Append-only XP ledger used to prevent duplicate rewards."""

    __tablename__ = "xp_transactions"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "source_type",
            "source_id",
            name="uq_xp_transaction_source",
        ),
    )

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
    source_type: Mapped[str] = mapped_column(String(40), nullable=False)
    source_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


class GrammarAdminAudit(Base):
    """Audit trail for staff changes to grammar content."""

    __tablename__ = "grammar_admin_audit"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    actor_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    action: Mapped[str] = mapped_column(String(50), nullable=False)
    lesson_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("grammar_lessons.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    details: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
