import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class AITutorSession(Base):
    """Chat session with AI Tutor."""

    __tablename__ = "ai_tutor_sessions"

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
    persona: Mapped[str] = mapped_column(
        String(50),
        default="sarah",
        comment="sarah (friendly), harrison (business), emma (ielts)",
    )
    topic: Mapped[str] = mapped_column(
        String(100),
        default="General Conversation",
    )
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

    # Relationships
    messages: Mapped[list["AITutorMessage"]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="AITutorMessage.created_at",
        lazy="selectin",
    )


class AITutorMessage(Base):
    """Individual message in an AI conversation."""

    __tablename__ = "ai_tutor_messages"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("ai_tutor_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        comment="user or assistant",
    )
    content: Mapped[str] = mapped_column(Text, nullable=False)
    corrections: Mapped[list] = mapped_column(
        JSONB,
        default=list,
        comment="List of {original, correction, explanation_vi}",
    )
    suggested_replies: Mapped[list] = mapped_column(
        JSONB,
        default=list,
        comment="Follow-up quick reply suggestions for learner",
    )
    audio_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    # Relationship
    session: Mapped["AITutorSession"] = relationship(back_populates="messages")


class AIWritingSubmission(Base):
    """Writing evaluation record."""

    __tablename__ = "ai_writing_submissions"

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
    topic: Mapped[str] = mapped_column(String(200), nullable=False)
    user_text: Mapped[str] = mapped_column(Text, nullable=False)
    overall_score: Mapped[float] = mapped_column(Float, nullable=False)
    cefr_level: Mapped[str] = mapped_column(String(10), default="B1")
    ielts_equivalent: Mapped[float] = mapped_column(Float, default=6.0)
    grammar_feedback: Mapped[list] = mapped_column(
        JSONB,
        default=list,
        comment="List of grammar errors and corrections",
    )
    vocab_suggestions: Mapped[list] = mapped_column(
        JSONB,
        default=list,
        comment="Lexical improvements and advanced phrasing",
    )
    general_comment: Mapped[str] = mapped_column(Text, nullable=False)
    revised_text: Mapped[str] = mapped_column(Text, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
