from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, EmailStr, Field


# ──────────────────────────────────────────────
# Request Schemas
# ──────────────────────────────────────────────

class RegisterRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    email: str = Field(..., max_length=255)
    password: str = Field(..., min_length=8, max_length=128)


class LoginRequest(BaseModel):
    email: str
    password: str


class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str = Field(..., min_length=8, max_length=128)


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class OnboardingRequest(BaseModel):
    learning_goal: str
    daily_learning_minutes: int = Field(..., ge=5, le=120)
    interested_topics: List[str]


# ──────────────────────────────────────────────
# Response Schemas
# ──────────────────────────────────────────────

class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    avatar_url: Optional[str] = None
    current_level: Optional[str] = None
    target_level: Optional[str] = None
    learning_goal: Optional[str] = None
    daily_learning_minutes: int = 20
    streak: int = 0
    total_xp: int = 0
    has_completed_onboarding: bool = False
    created_at: str

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    user: UserResponse


class MessageResponse(BaseModel):
    message: str
