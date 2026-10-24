"""Pydantic schemas for the CEFR placement test API (v2)."""

from __future__ import annotations

from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

PlacementMode = Literal["quick", "standard", "full"]
TargetExam = Literal["ielts", "toeic", "toefl", "general"]


class PlacementConfigResponse(BaseModel):
    model_config = ConfigDict(extra="allow")

    version: str
    description: str = ""
    skill_order: list[str] = []
    skill_labels: dict[str, str] = {}
    modes: dict[str, Any] = {}
    cut_scores: dict[str, float] = {}
    level_labels: dict[str, str] = {}
    level_descriptions_vi: dict[str, str] = {}
    exam_mapping: dict[str, Any] = {}
    can_do: dict[str, Any] = {}


class PlacementSessionCreate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    mode: PlacementMode = "quick"
    target_exam: TargetExam = "general"


class PlacementAnswerRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    item_id: str = Field(min_length=1, max_length=64)
    answer: list[str] | str = Field(default_factory=list)
    response_time_ms: int = Field(default=0, ge=0)
    flagged: bool = False


class PlacementStageCompleteRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    answers: Optional[list[PlacementAnswerRequest]] = None
    flagged: Optional[list[str]] = None
    stage_token: Optional[str] = None


class PlacementWritingRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    task_id: str = Field(min_length=1, max_length=64)
    text: str = Field(min_length=0, max_length=20000)
    response_time_ms: int = Field(default=0, ge=0)


class PlacementAnswerResponse(BaseModel):
    saved: bool = True
    answered: int = 0
    total: int = 0
    stage_complete: bool = False
    duplicate: bool = False


class PlacementSkipSpeakingRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    task_id: str = Field(min_length=1, max_length=64)


class PlacementSessionResponse(BaseModel):
    """A session snapshot.  Extra keys depend on the current section."""

    model_config = ConfigDict(extra="allow")

    session_id: str
    mode: str
    status: str
    blueprint_version: str = "2.0.0"
    current: dict[str, Any] = Field(default_factory=dict)
    progress: dict[str, Any] = Field(default_factory=dict)
    completed: bool = False
    result: Optional[dict[str, Any]] = None
    server_time: Optional[str] = None


class PlacementResultResponse(BaseModel):
    model_config = ConfigDict(extra="allow")

    result_id: str
    session_id: str
    mode: str
    target_exam: str = "general"
    completed_at: str
    overall: dict[str, Any]
    skills: dict[str, Any]
    exam_equivalents: dict[str, str] = {}
    recommendation: str = ""


class PlacementHistoryItem(BaseModel):
    result_id: str
    session_id: str
    mode: str
    target_exam: str = "general"
    overall_level: str
    overall_theta: float = 0.0
    overall_se: float = 0.0
    completed_at: str
