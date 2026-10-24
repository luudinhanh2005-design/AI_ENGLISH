import json
import logging
from pathlib import Path
from typing import Optional
from uuid import UUID, uuid4

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from ..database import get_db
from ..models.user import User
from ..utils.security import decode_token, hash_password

# Bearer token scheme
security = HTTPBearer()
logger = logging.getLogger(__name__)

# In-memory user store for demo/offline fallback.
# Only populated when ENABLE_DEMO_ACCOUNTS=true (must be disabled in production).
_DEFAULT_DEMO_ID = UUID("11111111-1111-1111-1111-111111111111")
_DEMO_ADMIN_ID = UUID("22222222-2222-2222-2222-222222222222")


def _build_memory_users() -> dict[UUID, User]:
    if not settings.enable_demo_accounts:
        return {}

    demo_password = settings.demo_user_password
    return {
        _DEFAULT_DEMO_ID: User(
            id=_DEFAULT_DEMO_ID,
            email="test@gmail.com",
            password_hash=hash_password(demo_password),
            name="Admin Learner",
            current_level="B1",
            target_level="B2",
            learning_goal="General Communication",
            daily_learning_minutes=20,
            streak=5,
            total_xp=450,
            has_completed_onboarding=True,
            is_active=True,
            role="user",
        ),
        _DEMO_ADMIN_ID: User(
            id=_DEMO_ADMIN_ID,
            email="admin@gmail.com",
            password_hash=hash_password(demo_password),
            name="Admin User",
            current_level="B2",
            target_level="C1",
            learning_goal="IELTS Academic",
            daily_learning_minutes=30,
            streak=10,
            total_xp=1200,
            has_completed_onboarding=True,
            is_active=True,
            role="admin",
        ),
    }


MEMORY_USERS: dict[UUID, User] = _build_memory_users()

# ── Persistence for offline accounts ──
# Without a running PostgreSQL, accounts live in MEMORY_USERS. Save them to a
# JSON file so registered users are not lost every time the backend restarts.
_USERS_FILE = Path("storage/users.json")
_PERSIST_FIELDS = (
    "email", "password_hash", "name", "avatar_url", "current_level",
    "target_level", "learning_goal", "daily_learning_minutes", "streak",
    "total_xp", "has_completed_onboarding", "is_active", "role",
)
_DEMO_IDS = {_DEFAULT_DEMO_ID, _DEMO_ADMIN_ID}


def save_memory_users() -> None:
    """Write non-demo in-memory users to disk (best effort)."""
    try:
        data = {
            str(uid): {f: getattr(u, f, None) for f in _PERSIST_FIELDS}
            for uid, u in MEMORY_USERS.items()
            if uid not in _DEMO_IDS
        }
        _USERS_FILE.parent.mkdir(parents=True, exist_ok=True)
        tmp = _USERS_FILE.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(_USERS_FILE)
    except Exception:
        logger.exception("Could not persist offline users")


def _load_memory_users() -> None:
    if not _USERS_FILE.exists():
        return
    try:
        data = json.loads(_USERS_FILE.read_text(encoding="utf-8"))
        for uid, fields in data.items():
            uuid_ = UUID(uid)
            MEMORY_USERS[uuid_] = User(id=uuid_, **fields)
        logger.info("Loaded %d offline users from %s", len(data), _USERS_FILE)
    except Exception:
        logger.exception("Could not load offline users")


_load_memory_users()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Dependency: Extract and validate JWT, return current user."""
    token = credentials.credentials
    payload = decode_token(token)

    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token_type = payload.get("type")
    if token_type != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
        )

    user_id = payload.get("sub")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    # Fetch user from database, with fallback to in-memory store
    user = None
    from ..database import is_db_connected
    if is_db_connected():
        try:
            result = await db.execute(
                select(User).where(User.id == UUID(user_id))
            )
            user = result.scalar_one_or_none()
        except Exception:
            pass

    if user is None:
        try:
            user = MEMORY_USERS.get(UUID(user_id))
        except Exception:
            user = None

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    if user.is_active is False:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    return user


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(
        HTTPBearer(auto_error=False)
    ),
    db: AsyncSession = Depends(get_db),
) -> Optional[User]:
    """Dependency: Optionally extract user if token is provided."""
    if credentials is None:
        return None

    try:
        return await get_current_user(credentials, db)
    except HTTPException:
        return None


async def require_staff(
    current_user: User = Depends(get_current_user),
) -> User:
    """Allow reviewers and admins to access the content workspace."""
    if (current_user.role or "user") not in {"reviewer", "admin"}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Staff access required",
        )
    return current_user


async def require_admin(
    current_user: User = Depends(get_current_user),
) -> User:
    """Restrict publishing and destructive content actions to admins."""
    if (current_user.role or "user") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return current_user
