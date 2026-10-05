from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


# ──────────────────────────────────────────────
# Placement Test Schemas
# ──────────────────────────────────────────────

class PlacementQuestionResponse(BaseModel):
    id: UUID
    skill: str
    difficulty_level: str
    question_text: str
    context_text: Optional[str] = None
    audio_url: Optional[str] = None
    options: list[str]
    order_index: int

    class Config:
        from_attributes = True


class PlacementAnswerItem(BaseModel):
    question_id: UUID
    selected_option: int = Field(..., ge=0, le=3)


class PlacementSubmissionRequest(BaseModel):
    answers: list[PlacementAnswerItem]


class PlacementResultResponse(BaseModel):
    total_questions: int
    correct_count: int
    score_percentage: float
    assessed_level: str
    skill_breakdown: dict[str, float]
    recommendation: str
    weaknesses: list[str]


# ──────────────────────────────────────────────
# Vocabulary Schemas
# ──────────────────────────────────────────────

class VocabularyWordResponse(BaseModel):
    id: UUID
    topic_id: UUID
    word: str
    phonetic: str
    part_of_speech: str
    meaning_vi: str
    meaning_en: str
    example_sentence: str
    example_translation: str
    audio_url: Optional[str] = None
    image_url: Optional[str] = None
    level: str

    class Config:
        from_attributes = True


class VocabularyTopicResponse(BaseModel):
    id: UUID
    slug: str
    title: str
    description: Optional[str] = None
    icon_name: str
    level: str
    total_words: int
    words: Optional[list[VocabularyWordResponse]] = None

    class Config:
        from_attributes = True


class WordReviewSubmitRequest(BaseModel):
    """
    Quality rating for SM-2:
    - 5: Perfect recall
    - 4: Good
    - 3: Hard (Correct with difficulty)
    - 2: Almost (Incorrect)
    - 1: Wrong
    """
    quality: int = Field(..., ge=0, le=5)


class WordProgressResponse(BaseModel):
    id: UUID
    word_id: UUID
    repetition_count: int
    interval_days: int
    ease_factor: float
    next_review_at: datetime
    status: str

    class Config:
        from_attributes = True


class DueReviewWordItem(BaseModel):
    word: VocabularyWordResponse
    progress: Optional[WordProgressResponse] = None


# ──────────────────────────────────────────────
# Grammar Schemas
# ──────────────────────────────────────────────

class GrammarLessonSummary(BaseModel):
    id: UUID
    slug: str
    title: str
    level: str
    summary: str
    order_index: int
    is_completed: bool = False
    score: Optional[float] = None

    class Config:
        from_attributes = True


class GrammarLessonDetail(BaseModel):
    id: UUID
    slug: str
    title: str
    level: str
    summary: str
    content_markdown: str
    formula: Optional[str] = None
    examples: list[dict]
    practice_questions: list[dict]

    class Config:
        from_attributes = True


class GrammarSubmitAnswer(BaseModel):
    question_index: int
    selected_option: int


class GrammarSubmitRequest(BaseModel):
    answers: list[GrammarSubmitAnswer]


class GrammarResultResponse(BaseModel):
    score: float
    total: int
    correct: int
    is_passed: bool
    xp_earned: int
