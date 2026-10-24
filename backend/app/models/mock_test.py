import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from ..database import Base


class MockTestAttempt(Base):
    """A full IELTS mock-test attempt (listening/reading/writing/speaking)."""

    __tablename__ = "mock_test_attempts"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    set_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    test_type: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="academic",
        comment="academic | general",
    )
    mode: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="strict",
        comment="strict | practice",
    )
    status: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="in_progress",
        comment="in_progress | completed",
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    section_started_at: Mapped[dict] = mapped_column(
        JSONB,
        default=dict,
        comment="skill -> ISO timestamp when the section was started",
    )
    section_scores: Mapped[dict] = mapped_column(
        JSONB,
        default=dict,
        comment="skill -> SectionScore payload",
    )
    raw_scores: Mapped[dict] = mapped_column(
        JSONB,
        default=dict,
        comment="skill -> raw score",
    )
    answers: Mapped[dict] = mapped_column(
        JSONB,
        default=dict,
        comment="skill -> {question_id: answer}",
    )
    flagged: Mapped[dict] = mapped_column(
        JSONB,
        default=dict,
        comment="skill -> [question_id]",
    )
    overall_band: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    xp_awarded: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
