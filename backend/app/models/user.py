import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class User(Base):
    """User account table."""

    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        index=True,
    )
    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    avatar_url: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
    )
    current_level: Mapped[str | None] = mapped_column(
        String(10),
        nullable=True,
    )
    target_level: Mapped[str | None] = mapped_column(
        String(10),
        nullable=True,
    )
    learning_goal: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )
    daily_learning_minutes: Mapped[int] = mapped_column(
        Integer,
        default=20,
    )
    streak: Mapped[int] = mapped_column(
        Integer,
        default=0,
    )
    total_xp: Mapped[int] = mapped_column(
        Integer,
        default=0,
    )
    has_completed_onboarding: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
    )
    role: Mapped[str] = mapped_column(
        String(20),
        default="user",
        server_default="user",
        index=True,
        comment="user, reviewer, admin",
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

    # Relationship to profile
    profile: Mapped["UserProfile"] = relationship(
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )

    def to_dict(self) -> dict:
        """Convert to dictionary for API response."""
        return {
            "id": str(self.id),
            "email": self.email,
            "name": self.name,
            "avatar_url": self.avatar_url,
            "current_level": self.current_level,
            "target_level": self.target_level,
            "learning_goal": self.learning_goal,
            "daily_learning_minutes": self.daily_learning_minutes if self.daily_learning_minutes is not None else 20,
            "streak": self.streak if self.streak is not None else 0,
            "total_xp": self.total_xp if self.total_xp is not None else 0,
            "has_completed_onboarding": bool(self.has_completed_onboarding),
            "role": self.role or "user",
            "created_at": self.created_at.isoformat() if self.created_at else datetime.utcnow().isoformat(),
        }


class UserProfile(Base):
    """Extended user profile with learning preferences and AI data."""

    __tablename__ = "user_profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    learning_goals: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
    )
    interested_topics: Mapped[list | None] = mapped_column(
        JSONB,
        nullable=True,
    )
    skill_scores: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Per-skill scores: vocabulary, grammar, listening, etc.",
    )
    weaknesses: Mapped[list | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Detected weak areas from AI analysis",
    )
    last_placement_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
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

    # Relationship
    user: Mapped["User"] = relationship(back_populates="profile")
