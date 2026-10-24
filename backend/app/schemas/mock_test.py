"""Pydantic schemas for the IELTS Mock Test API (contract v1)."""

from __future__ import annotations

from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Skill = Literal["listening", "reading", "writing", "speaking"]
Mode = Literal["strict", "practice"]


class MockTestSetSummary(BaseModel):
    id: str
    type: str
    title: str
    description: str = ""
    duration_minutes: int
    skills: list[str]


class AttemptCreateRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    set_id: str = Field(min_length=1, max_length=64)
    mode: Mode = "strict"
    skills: Optional[list[Skill]] = None


class SectionInfo(BaseModel):
    skill: str
    duration_seconds: int
    status: str


class AttemptCreateResponse(BaseModel):
    attempt_id: str
    set_id: str
    mode: str
    started_at: str
    sections: list[SectionInfo]


class SectionSaveRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    skill: Skill
    answers: Optional[dict[str, str]] = None
    flagged: Optional[list[str]] = None
    remaining_seconds: Optional[int] = None


class QAItem(BaseModel):
    model_config = ConfigDict(extra="ignore")

    question: str = ""
    answer: str = ""


class SectionSubmitRequest(BaseModel):
    """Payload accepted by the section submit endpoint.

    Listening/Reading/Writing only use ``answers``; Speaking uses the
    ``part*_qa`` fields. Everything is optional so either shape validates.
    """

    model_config = ConfigDict(extra="ignore")

    answers: Optional[dict[str, str]] = None
    topic: Optional[str] = None
    part1_qa: Optional[list[QAItem]] = None
    part2_answer: Optional[str] = None
    part3_qa: Optional[list[QAItem]] = None
    follow_up_qa: Optional[list[QAItem]] = None


class SectionScoreDetail(BaseModel):
    question_id: str
    number: int
    user_answer: str
    correct_answer: str
    is_correct: bool
    explanation: str = ""


class SectionScore(BaseModel):
    skill: str
    band: float
    raw_score: int
    total: int
    criteria: dict[str, Any] = Field(default_factory=dict)
    comment: str = ""
    details: list[SectionScoreDetail] = Field(default_factory=list)
    strengths: list[str] = Field(default_factory=list)
    improvements: list[str] = Field(default_factory=list)
    corrections: list[Any] = Field(default_factory=list)
    extra: dict[str, Any] = Field(default_factory=dict)


class AttemptCompleteResponse(BaseModel):
    attempt_id: str
    overall_band: float
    skills: dict[str, SectionScore]
    xp_awarded: int
    completed_at: Optional[str] = None


class AttemptSummary(BaseModel):
    attempt_id: str
    set_id: str
    title: str = ""
    type: str = "academic"
    mode: str = "strict"
    status: str = "in_progress"
    overall_band: Optional[float] = None
    completed_at: Optional[str] = None
    skills: dict[str, Optional[float]] = Field(default_factory=dict)


class AttemptSectionDetail(BaseModel):
    """Attempt + sanitized content + submitted scores (review after submit)."""

    attempt_id: str
    set_id: str
    title: str = ""
    type: str = "academic"
    mode: str = "strict"
    status: str = "in_progress"
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    overall_band: Optional[float] = None
    xp_awarded: int = 0
    sections: dict[str, Any] = Field(default_factory=dict)
    scores: dict[str, SectionScore] = Field(default_factory=dict)
    review: dict[str, Any] = Field(default_factory=dict)
    answers: dict[str, Any] = Field(default_factory=dict)
    flagged: dict[str, Any] = Field(default_factory=dict)
    section_started_at: dict[str, Any] = Field(default_factory=dict)


__all__ = [
    "AttemptCompleteResponse",
    "AttemptCreateRequest",
    "AttemptCreateResponse",
    "AttemptSectionDetail",
    "AttemptSummary",
    "MockTestSetSummary",
    "QAItem",
    "SectionInfo",
    "SectionSaveRequest",
    "SectionScore",
    "SectionScoreDetail",
    "SectionSubmitRequest",
    "Skill",
]
