"""
Phase 4 — Speech AI Models
- SpeakingSession: Practice sessions (read-aloud, free speaking)
- PronunciationAssessment: Per-word phoneme-level scoring
- AudioRecording: Stored audio references
"""
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class SpeakingSession(Base):
    """A speaking / pronunciation practice session."""

    __tablename__ = "speaking_sessions"

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
    # "read_aloud", "repeat_after_me", "free_speaking", "pronunciation_drill"
    session_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="read_aloud",
    )
    reference_text: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="The target sentence/passage the user should read.",
    )
    overall_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    fluency_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    accuracy_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    completeness_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    prosody_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Recognised transcript from STT
    recognised_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Detailed per-word analysis stored as JSON
    word_scores: Mapped[Optional[list]] = mapped_column(
        JSONB,
        nullable=True,
        comment="List of {word, accuracy_score, error_type, phonemes: [{phoneme, score}]}",
    )

    # Feedback & tips
    feedback: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    improvement_tips: Mapped[Optional[list]] = mapped_column(
        JSONB,
        nullable=True,
        comment="List of actionable pronunciation tips",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    # Relationships
    recordings: Mapped[list["AudioRecording"]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class AudioRecording(Base):
    """Stored audio file reference for a speaking session."""

    __tablename__ = "audio_recordings"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("speaking_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # "user" or "native" (TTS reference)
    audio_type: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="user",
    )
    # Path or URL to audio file (local storage / Supabase Storage / S3)
    file_url: Mapped[str] = mapped_column(String(500), nullable=False)
    file_format: Mapped[str] = mapped_column(String(10), default="wav")
    duration_seconds: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    # Relationship
    session: Mapped["SpeakingSession"] = relationship(back_populates="recordings")


class PronunciationDrill(Base):
    """Pre-built pronunciation drill content (minimal pairs, tongue twisters, etc.)."""

    __tablename__ = "pronunciation_drills"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    # "minimal_pair", "tongue_twister", "word_stress", "intonation"
    drill_type: Mapped[str] = mapped_column(String(50), nullable=False)
    difficulty: Mapped[str] = mapped_column(
        String(10),
        default="A2",
        comment="CEFR level: A1, A2, B1, B2, C1",
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    # The text content to practice
    content: Mapped[str] = mapped_column(Text, nullable=False)
    # IPA transcription for reference
    ipa_transcription: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    # Audio URL for native speaker reference
    native_audio_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    # Phoneme focus, e.g. ["θ", "ð"] for th-sounds
    target_phonemes: Mapped[Optional[list]] = mapped_column(
        JSONB,
        nullable=True,
        comment="List of IPA phonemes this drill targets",
    )

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
