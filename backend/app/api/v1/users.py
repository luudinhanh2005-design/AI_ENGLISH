from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from typing import Optional

from ...database import get_db
from ...models.user import User, UserProfile
from ...schemas.auth import OnboardingRequest, UpdateProfileRequest, UserResponse
from ..deps import get_current_user, get_optional_user, save_memory_users

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

    save_memory_users()
    return UserResponse(**current_user.to_dict())


# ──────────────────────────────────────────────
# Update User Profile
# ──────────────────────────────────────────────
@router.put("/me", response_model=UserResponse)
async def update_profile(
    request: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update user profile fields."""
    if request.name is not None and request.name.strip():
        current_user.name = request.name.strip()
    if request.avatar_url is not None:
        current_user.avatar_url = request.avatar_url
    if request.daily_learning_minutes is not None:
        current_user.daily_learning_minutes = request.daily_learning_minutes
    if request.target_level is not None:
        current_user.target_level = request.target_level
    if request.current_level is not None:
        current_user.current_level = request.current_level
    if request.learning_goal is not None:
        current_user.learning_goal = request.learning_goal

    try:
        await db.flush()
    except Exception:
        pass

    save_memory_users()
    return UserResponse(**current_user.to_dict())


# ──────────────────────────────────────────────
# Gamification: Weekly Leaderboard & Badges
# ──────────────────────────────────────────────

_CLAIMED_BADGES: dict[str, set[str]] = {}

@router.get("/leaderboard")
async def get_weekly_leaderboard(
    current_user: Optional[User] = Depends(get_optional_user),
):
    """
    Get weekly leaderboard and league standings.
    Calculates user rank dynamically based on their total XP.
    """
    user_xp = (current_user.total_xp if current_user else 320) or 0

    base_leaderboard = [
        {"id": "bot_1", "name": "Minh Anh", "avatar": "👩‍🎓", "weekly_xp": 1280, "streak": 14, "title": "Bậc Thầy Giao Tiếp"},
        {"id": "bot_2", "name": "Tuấn Kiệt", "avatar": "🚀", "weekly_xp": 960, "streak": 9, "title": "Chiến Binh IELTS"},
        {"id": "bot_3", "name": "Thuỳ Linh", "avatar": "✨", "weekly_xp": 820, "streak": 12, "title": "Thợ Săn Phát Âm"},
        {"id": "bot_4", "name": "Đức Huy", "avatar": "⚡", "weekly_xp": 540, "streak": 6, "title": "Học Viên Chăm Chỉ"},
        {"id": "bot_5", "name": "Bảo Ngọc", "avatar": "🌟", "weekly_xp": 480, "streak": 4, "title": "Tân Binh Tiềm Năng"},
        {"id": "bot_6", "name": "Hoàng Nam", "avatar": "🎯", "weekly_xp": 390, "streak": 5, "title": "Người Kiên Trì"},
        {"id": "bot_7", "name": "Khánh Vy", "avatar": "🌸", "weekly_xp": 310, "streak": 3, "title": "Yêu Thích Tiếng Anh"},
        {"id": "bot_8", "name": "Gia Bách", "avatar": "🦁", "weekly_xp": 240, "streak": 2, "title": "Khám Phá Từ Mới"},
        {"id": "bot_9", "name": "Phương Thảo", "avatar": "🎨", "weekly_xp": 180, "streak": 1, "title": "Mục Tiêu B2"},
    ]

    # Insert current user
    user_entry = {
        "id": str(current_user.id) if current_user else "guest_user",
        "name": (current_user.name if current_user and current_user.name else "Bạn"),
        "avatar": (current_user.avatar_url if current_user and current_user.avatar_url else "👑"),
        "weekly_xp": max(220, user_xp),
        "streak": (current_user.streak if current_user and current_user.streak else 3),
        "title": "Bạn (Học viên)",
        "is_current_user": True,
    }

    all_users = base_leaderboard + [user_entry]
    all_users.sort(key=lambda x: x["weekly_xp"], reverse=True)

    # Assign ranks
    user_rank = 1
    for index, u in enumerate(all_users):
        u["rank"] = index + 1
        if u.get("is_current_user"):
            user_rank = index + 1

    return {
        "league_name": "Giải Đấu Vàng 🥇",
        "league_tier": "gold",
        "time_remaining": "2 ngày 14 giờ",
        "top_users": all_users[:10],
        "current_user_rank": user_rank,
        "current_user_xp": user_entry["weekly_xp"],
        "promotion_zone_cutoff": 3,  # Top 3 promote
    }


@router.get("/badges")
async def get_user_badges(
    current_user: Optional[User] = Depends(get_optional_user),
):
    """
    Get user badges and achievement progress.
    """
    user_id_str = str(current_user.id) if current_user else "guest_user"
    claimed_set = _CLAIMED_BADGES.get(user_id_str, set())
    user_xp = (current_user.total_xp if current_user else 320) or 0
    streak = (current_user.streak if current_user else 3) or 0

    badges_definition = [
        {
            "id": "badge_voice_first",
            "title": "Bước Đầu Tự Tin",
            "description": "Thực hiện cuộc gọi thoại đầu tiên với gia sư AI",
            "category": "Giao tiếp",
            "icon": "phone_in_talk_rounded",
            "reward_xp": 50,
            "current_progress": 1,
            "target_progress": 1,
            "is_unlocked": True,
            "is_claimed": "badge_voice_first" in claimed_set,
        },
        {
            "id": "badge_streak_3",
            "title": "Chiến Binh Kiên Trì",
            "description": "Giữ chuỗi học tập ít nhất 3 ngày liên tiếp",
            "category": "Kỷ luật",
            "icon": "local_fire_department_rounded",
            "reward_xp": 50,
            "current_progress": streak,
            "target_progress": 3,
            "is_unlocked": streak >= 3,
            "is_claimed": "badge_streak_3" in claimed_set,
        },
        {
            "id": "badge_ielts_first",
            "title": "Thử Thách IELTS Speaking",
            "description": "Hoàn thành một bài thi thử IELTS Speaking 3 phần",
            "category": "IELTS",
            "icon": "military_tech_rounded",
            "reward_xp": 100,
            "current_progress": 1 if user_xp >= 50 else 0,
            "target_progress": 1,
            "is_unlocked": user_xp >= 50,
            "is_claimed": "badge_ielts_first" in claimed_set,
        },
        {
            "id": "badge_shadowing_pro",
            "title": "Bậc Thầy Nhại Giọng",
            "description": "Đạt điểm Shadowing trên 80% với một bài luyện nói",
            "category": "Phát âm",
            "icon": "record_voice_over_rounded",
            "reward_xp": 75,
            "current_progress": 1,
            "target_progress": 1,
            "is_unlocked": True,
            "is_claimed": "badge_shadowing_pro" in claimed_set,
        },
        {
            "id": "badge_mistake_collector",
            "title": "Thợ Săn Lỗi Sai",
            "description": "Lưu và ôn tập ít nhất 3 lỗi trong Sổ tay lỗi sai",
            "category": "Học tập",
            "icon": "auto_stories_rounded",
            "reward_xp": 60,
            "current_progress": 3,
            "target_progress": 3,
            "is_unlocked": True,
            "is_claimed": "badge_mistake_collector" in claimed_set,
        },
        {
            "id": "badge_xp_500",
            "title": "Ngôi Sao Tích Lũy",
            "description": "Tích lũy đạt mốc 500 XP rèn luyện",
            "category": "Danh dự",
            "icon": "bolt_rounded",
            "reward_xp": 100,
            "current_progress": user_xp,
            "target_progress": 500,
            "is_unlocked": user_xp >= 500,
            "is_claimed": "badge_xp_500" in claimed_set,
        },
    ]

    return badges_definition


@router.post("/badges/{badge_id}/claim")
async def claim_badge_reward(
    badge_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Claim XP reward for an unlocked badge."""
    user_id_str = str(current_user.id)
    if user_id_str not in _CLAIMED_BADGES:
        _CLAIMED_BADGES[user_id_str] = set()

    if badge_id in _CLAIMED_BADGES[user_id_str]:
        return {"message": "Badge already claimed", "claimed": True, "awarded_xp": 0}

    # Reward amount map
    rewards = {
        "badge_voice_first": 50,
        "badge_streak_3": 50,
        "badge_ielts_first": 100,
        "badge_shadowing_pro": 75,
        "badge_mistake_collector": 60,
        "badge_xp_500": 100,
    }
    reward_xp = rewards.get(badge_id, 50)
    _CLAIMED_BADGES[user_id_str].add(badge_id)

    # Award to user
    try:
        current_user.total_xp = (current_user.total_xp or 0) + reward_xp
        await db.flush()
    except Exception:
        current_user.total_xp = (current_user.total_xp or 0) + reward_xp

    save_memory_users()
    return {
        "message": f"Claimed {reward_xp} XP successfully!",
        "claimed": True,
        "awarded_xp": reward_xp,
        "new_total_xp": current_user.total_xp,
    }
