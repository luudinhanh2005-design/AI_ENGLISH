from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


# ──────────────────────────────────────────────
# AI Tutor Schemas
# ──────────────────────────────────────────────

class AICorrectionItem(BaseModel):
    original: str
    correction: str
    explanation_vi: str


class AIChatRequest(BaseModel):
    session_id: Optional[UUID] = None
    persona: str = Field(default="sarah", description="sarah, harrison, emma")
    message: str = Field(..., min_length=1, max_length=2000)
    topic: Optional[str] = "General Conversation"


class AIChatResponse(BaseModel):
    session_id: UUID
    reply: str
    corrections: list[AICorrectionItem] = []
    suggested_replies: list[str] = []


class AITutorMessageItem(BaseModel):
    id: UUID
    role: str
    content: str
    corrections: Optional[list[dict]] = []
    suggested_replies: Optional[list[str]] = []
    created_at: datetime

    class Config:
        from_attributes = True


class AITutorSessionSummary(BaseModel):
    id: UUID
    persona: str
    topic: str
    created_at: datetime
    updated_at: datetime
    message_count: int = 0

    class Config:
        from_attributes = True


# ──────────────────────────────────────────────
# AI Exercise Generator Schemas
# ──────────────────────────────────────────────

class AIExerciseGenerateRequest(BaseModel):
    skill: Optional[str] = Field(default=None, description="vocabulary, grammar, reading")
    count: int = Field(default=3, ge=1, le=10)


class AIExerciseItem(BaseModel):
    question: str
    skill: str
    options: list[str]
    correct_option: int
    explanation: str


class AIExerciseGenerateResponse(BaseModel):
    target_level: str
    targeted_weaknesses: list[str]
    exercises: list[AIExerciseItem]


# ──────────────────────────────────────────────
# AI Writing Evaluation Schemas
# ──────────────────────────────────────────────

class AIWritingSubmitRequest(BaseModel):
    topic: str = Field(..., min_length=3, max_length=200)
    text: str = Field(..., min_length=20, max_length=5000)


class AIWritingResponse(BaseModel):
    overall_score: float
    cefr_level: str
    ielts_equivalent: float
    grammar_feedback: list[dict]
    vocab_suggestions: list[dict]
    general_comment: str
    revised_text: str
