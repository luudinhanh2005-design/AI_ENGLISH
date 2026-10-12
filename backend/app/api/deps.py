from typing import Optional
from uuid import UUID, uuid4

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.user import User
from ..utils.security import decode_token, hash_password

# Bearer token scheme
security = HTTPBearer()

# In-memory user store for demo/offline fallback
_DEFAULT_DEMO_ID = UUID("11111111-1111-1111-1111-111111111111")
_DEMO_ADMIN_ID = UUID("22222222-2222-2222-2222-222222222222")
MEMORY_USERS: dict[UUID, User] = {
    _DEFAULT_DEMO_ID: User(
        id=_DEFAULT_DEMO_ID,
        email="test@gmail.com",
        password_hash=hash_password("Password123"),
        name="Admin Learner",
        current_level="B1",
        target_level="B2",
        learning_goal="General Communication",
        daily_learning_minutes=20,
        streak=5,
        total_xp=450,
        has_completed_onboarding=True,
        is_active=True,
    ),
    _DEMO_ADMIN_ID: User(
        id=_DEMO_ADMIN_ID,
        email="admin@gmail.com",
        password_hash=hash_password("Password123"),
        name="Admin User",
        current_level="B2",
        target_level="C1",
        learning_goal="IELTS Academic",
        daily_learning_minutes=30,
        streak=10,
        total_xp=1200,
        has_completed_onboarding=True,
        is_active=True,
    ),
}


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
    from ..database import IS_DB_CONNECTED
    if IS_DB_CONNECTED:
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
