"""Grammar API schemas.

The public shapes intentionally mirror the bundled Flutter JSON so the mobile
client can use one parser for local seed data, cache data, and server data.
"""
from __future__ import annotations

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class GrammarLessonSummary(BaseModel):
    id: str
    slug: str
    title: str
    title_vi: str = ""
    level: str
    category: str = ""
    summary: str = ""
    description: str = ""
    order_index: int = 0
    is_completed: bool = False
    score: Optional[float] = None
    is_beta: bool = False
    version: int = 1
    status: str = "published"
    updated_at: Optional[datetime] = None


class GrammarLessonDetail(BaseModel):
    id: str
    slug: str
    title: str
    title_vi: str = ""
    level: str
    category: str = ""
    summary: str = ""
    description: str = ""
    content_markdown: str = ""
    formula: Optional[str] = None
    formula_affirmative: str = ""
    formula_negative: str = ""
    formula_question: str = ""
    time_markers: list[str] = Field(default_factory=list)
    usage_rules: list[str] = Field(default_factory=list)
    examples: list[dict] = Field(default_factory=list)
    common_mistakes: list[str] = Field(default_factory=list)
    quiz: list[dict] = Field(default_factory=list)
    practice_questions: list[dict] = Field(default_factory=list)
    is_beta: bool = False
    version: int = 1
    status: str = "published"
    tags: list[str] = Field(default_factory=list)
    estimated_minutes: int = 10
    updated_at: Optional[datetime] = None


class GrammarManifestLesson(BaseModel):
    slug: str
    title: str
    level: str
    version: int
    content_hash: Optional[str] = None
    updated_at: Optional[datetime] = None
    is_beta: bool = False


class GrammarManifestResponse(BaseModel):
    version: str
    generated_at: datetime
    lessons: list[GrammarManifestLesson]


class GrammarBundleResponse(BaseModel):
    version: str
    generated_at: datetime
    lessons: list[GrammarLessonDetail]


class GrammarSubmitAnswer(BaseModel):
    question_index: int = Field(..., ge=0)
    selected_option: int = Field(..., ge=0, le=3)


class GrammarSubmitRequest(BaseModel):
    answers: list[GrammarSubmitAnswer]


class GrammarAttemptRequest(BaseModel):
    attempt_id: UUID
    lesson_slug: str
    lesson_version: Optional[int] = None
    answers: list[GrammarSubmitAnswer]


class GrammarAttemptResponse(BaseModel):
    attempt_id: UUID
    lesson_slug: str
    lesson_version: int
    score: float
    total: int
    correct: int
    is_passed: bool
    xp_earned: int
    best_score: float
    is_completed: bool
    duplicate: bool = False
    created_at: Optional[datetime] = None


class GrammarResultResponse(BaseModel):
    score: float
    total: int
    correct: int
    is_passed: bool
    xp_earned: int


class GrammarProgressItem(BaseModel):
    lesson_slug: str
    best_score: float = 0.0
    is_completed: bool = False
    attempts_count: int = 0
    last_attempt_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None


class GrammarProgressResponse(BaseModel):
    items: list[GrammarProgressItem]
    total_xp: int = 0


# ──────────────────────────────────────────────
# Admin schemas
# ──────────────────────────────────────────────

class GrammarAdminLessonInput(BaseModel):
    id: str = Field(..., min_length=2, max_length=100)
    title: str = Field(..., min_length=2, max_length=200)
    title_vi: str = ""
    level: str = "A1"
    category: str = ""
    description: str = ""
    formula_affirmative: str = ""
    formula_negative: str = ""
    formula_question: str = ""
    time_markers: list[str] = Field(default_factory=list)
    usage_rules: list[str] = Field(default_factory=list)
    examples: list[dict] = Field(default_factory=list)
    common_mistakes: list[str] = Field(default_factory=list)
    quiz: list[dict] = Field(default_factory=list)
    is_beta: bool = False
    status: str = "draft"
    tags: list[str] = Field(default_factory=list)
    estimated_minutes: int = 10
    changelog: str = ""


class GrammarValidationResponse(BaseModel):
    valid: bool
    errors: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)


class GrammarVersionSummary(BaseModel):
    version: int
    content_hash: str
    changelog: str = ""
    created_at: Optional[datetime] = None


class GrammarAdminStats(BaseModel):
    total_lessons: int
    published_lessons: int
    draft_lessons: int
    beta_lessons: int
    total_attempts: int
    total_xp_awarded: int
    by_level: dict[str, int] = Field(default_factory=dict)
