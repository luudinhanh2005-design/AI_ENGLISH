"""
Phase 4 — Speech AI Schemas
Pydantic models for Speech-to-Text, pronunciation assessment, and TTS.
"""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


# ──────────────────────────────────────────────
# Pronunciation Assessment Schemas
# ──────────────────────────────────────────────

class PhonemeScore(BaseModel):
    phoneme: str
    score: float = Field(ge=0, le=100)


class WordScore(BaseModel):
    word: str
    accuracy_score: float = Field(ge=0, le=100)
    error_type: str = Field(
        default="None",
        description="None, Mispronunciation, Omission, Insertion",
    )
    phonemes: list[PhonemeScore] = []


class PronunciationAssessRequest(BaseModel):
    """Submit an audio recording for pronunciation assessment."""
    reference_text: str = Field(
        ...,
        min_length=1,
        max_length=1000,
        description="The target sentence/passage the user attempted to read.",
    )
    session_type: str = Field(
        default="read_aloud",
        description="read_aloud, repeat_after_me, free_speaking, pronunciation_drill",
    )


class PronunciationAssessResponse(BaseModel):
    """Pronunciation assessment results."""
    session_id: UUID
    reference_text: str
    recognised_text: str
    overall_score: float
    fluency_score: float
    accuracy_score: float
    completeness_score: float
    prosody_score: float
    word_scores: list[WordScore]
    feedback: str
    improvement_tips: list[str]
    native_audio_url: Optional[str] = None


# ──────────────────────────────────────────────
# Speech-to-Text Schemas
# ──────────────────────────────────────────────

class STTRequest(BaseModel):
    """Speech-to-Text transcription request metadata."""
    language: str = Field(default="en-US", description="BCP-47 language code")


class STTResponse(BaseModel):
    """Speech-to-Text transcription result."""
    transcript: str
    confidence: float = Field(ge=0.0, le=1.0)
    language: str
    duration_seconds: Optional[float] = None
    words: list[dict] = Field(
        default_factory=list,
        description="Word-level timing: [{word, start_time, end_time, confidence}]",
    )


# ──────────────────────────────────────────────
# Text-to-Speech Schemas
# ──────────────────────────────────────────────

class TTSRequest(BaseModel):
    """Text-to-Speech synthesis request."""
    text: str = Field(
        ...,
        min_length=1,
        max_length=2000,
        description="Text to convert to speech",
    )
    voice: str = Field(
        default="en-US-Standard-C",
        description="Voice ID for TTS engine",
    )
    speed: float = Field(
        default=1.0,
        ge=0.5,
        le=2.0,
        description="Playback speed multiplier",
    )


class TTSResponse(BaseModel):
    """Text-to-Speech result."""
    audio_url: str
    text: str
    voice: str
    duration_seconds: Optional[float] = None


# ──────────────────────────────────────────────
# Pronunciation Drill Schemas
# ──────────────────────────────────────────────

class PronunciationDrillItem(BaseModel):
    id: UUID
    drill_type: str
    difficulty: str
    title: str
    description: Optional[str] = None
    content: str
    ipa_transcription: Optional[str] = None
    native_audio_url: Optional[str] = None
    target_phonemes: Optional[list[str]] = None

    class Config:
        from_attributes = True


class PronunciationDrillListResponse(BaseModel):
    drills: list[PronunciationDrillItem]
    total: int


# ──────────────────────────────────────────────
# Speaking Session History Schemas
# ──────────────────────────────────────────────

class SpeakingSessionSummary(BaseModel):
    id: UUID
    session_type: str
    reference_text: str
    overall_score: Optional[float] = None
    accuracy_score: Optional[float] = None
    fluency_score: Optional[float] = None
    created_at: datetime

    class Config:
        from_attributes = True


class SpeakingSessionListResponse(BaseModel):
    sessions: list[SpeakingSessionSummary]
    total: int
    average_score: Optional[float] = None


class SpeakingStatsResponse(BaseModel):
    """User's speaking practice statistics."""
    total_sessions: int
    total_practice_time_minutes: float
    average_overall_score: Optional[float] = None
    average_fluency: Optional[float] = None
    average_accuracy: Optional[float] = None
    weakest_phonemes: list[dict] = Field(
        default_factory=list,
        description="List of {phoneme, average_score, practice_count}",
    )
    score_trend: list[dict] = Field(
        default_factory=list,
        description="List of {date, score} for chart rendering",
    )
    level_label: str = Field(
        default="Beginner",
        description="Beginner, Elementary, Intermediate, Advanced, Near-Native",
    )
