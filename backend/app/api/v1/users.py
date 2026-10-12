from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ...database import get_db
from ...models.user import User, UserProfile
from ...schemas.auth import OnboardingRequest, UserResponse
from ..deps import get_current_user

router = APIRouter()


# ──────────────────────────────────────────────
# Get Current User
# ──────────────────────────────────────────────
@router.get("/me", response_model=UserResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
):
    """Get current user profile."""
    return UserResponse(**current_user.to_dict())


# ──────────────────────────────────────────────
# Save Onboarding Data
# ──────────────────────────────────────────────
@router.put("/me/onboarding", response_model=UserResponse)
async def save_onboarding(
    request: OnboardingRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Save user onboarding preferences."""
    # Update user
    current_user.learning_goal = request.learning_goal
    current_user.daily_learning_minutes = request.daily_learning_minutes
    current_user.has_completed_onboarding = True

    try:
        # Update or create profile
        result = await db.execute(
            select(UserProfile).where(UserProfile.user_id == current_user.id)
        )
        profile = result.scalar_one_or_none()

        if profile is None:
            profile = UserProfile(user_id=current_user.id)
            db.add(profile)

        profile.learning_goals = {"primary": request.learning_goal}
        profile.interested_topics = request.interested_topics

        await db.flush()
    except Exception:
        pass

    return UserResponse(**current_user.to_dict())


# ──────────────────────────────────────────────
# Update User Profile
# ──────────────────────────────────────────────
@router.put("/me", response_model=UserResponse)
async def update_profile(
    name: str | None = None,
    avatar_url: str | None = None,
    daily_learning_minutes: int | None = None,
    target_level: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update user profile fields."""
    if name is not None:
        current_user.name = name.strip()
    if avatar_url is not None:
        current_user.avatar_url = avatar_url
    if daily_learning_minutes is not None:
        current_user.daily_learning_minutes = daily_learning_minutes
    if target_level is not None:
        current_user.target_level = target_level

    await db.flush()

    return UserResponse(**current_user.to_dict())
