from uuid import UUID

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...config import settings
from ...database import get_db, is_db_connected
from ...models.user import User, UserProfile
from ...schemas.auth import (
    AuthResponse,
    ForgotPasswordRequest,
    GoogleAuthRequest,
    LoginRequest,
    MessageResponse,
    OnboardingRequest,
    RefreshTokenRequest,
    RegisterRequest,
    ResetPasswordRequest,
    UserResponse,
)
from ...utils.security import (
    create_access_token,
    create_refresh_token,
    create_reset_token,
    decode_token,
    hash_password,
    verify_password,
)
from ..deps import get_current_user, MEMORY_USERS

router = APIRouter()

logger = logging.getLogger(__name__)


def _decode_jwt_claims_unverified(token: str) -> dict:
    """Best-effort decode of a JWT payload WITHOUT verifying the signature.

    Used only for diagnostics when Google token verification fails.
    """
    import base64
    import json

    try:
        parts = token.split(".")
        if len(parts) < 2:
            return {}
        payload = parts[1]
        padding = "=" * (-len(payload) % 4)
        data = base64.urlsafe_b64decode(payload + padding)
        decoded = json.loads(data.decode("utf-8"))
        return decoded if isinstance(decoded, dict) else {}
    except Exception:
        return {}


# ──────────────────────────────────────────────
# Register
# ──────────────────────────────────────────────
@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(
    request: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    """Register a new user account."""
    user = None
    email_clean = request.email.lower().strip()

    if is_db_connected():
        try:
            # Check if email already exists in DB
            result = await db.execute(
                select(User).where(User.email == email_clean)
            )
            existing_user = result.scalar_one_or_none()

            if existing_user:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="An account with this email already exists",
                )

            # Create user
            user = User(
                email=email_clean,
                password_hash=hash_password(request.password),
                name=request.name.strip(),
                total_xp=0,
                streak=0,
                daily_learning_minutes=20,
            )
            db.add(user)
            await db.flush()  # Get the user ID

            # Create empty profile
            profile = UserProfile(user_id=user.id)
            db.add(profile)
            await db.flush()
        except HTTPException:
            raise
        except Exception:
            await db.rollback()
            user = None
            logger.exception("DB registration failed; falling back to in-memory store")

    if user is None:
        # DB offline fallback: store in memory
        existing_mem = next((u for u in MEMORY_USERS.values() if u.email == email_clean), None)
        if existing_mem:
            existing_mem.password_hash = hash_password(request.password)
            existing_mem.name = request.name.strip()
            user = existing_mem
        else:
            import uuid
            new_id = uuid.uuid4()
            user = User(
                id=new_id,
                email=email_clean,
                password_hash=hash_password(request.password),
                name=request.name.strip(),
                total_xp=0,
                streak=0,
                daily_learning_minutes=20,
                has_completed_onboarding=True,
                is_active=True,
            )
            MEMORY_USERS[new_id] = user

    # Generate tokens
    access_token = create_access_token(str(user.id))
    refresh_token = create_refresh_token(str(user.id))

    return AuthResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse(**user.to_dict()),
    )


# ──────────────────────────────────────────────
# Login
# ──────────────────────────────────────────────
@router.post("/login", response_model=AuthResponse)
async def login(
    request: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """Authenticate user and return tokens."""
    user = None
    email_clean = request.email.lower().strip()

    if is_db_connected() and db is not None:
        try:
            result = await db.execute(
                select(User).where(User.email == email_clean)
            )
            user = result.scalar_one_or_none()
        except Exception:
            user = None

        if user is None or not verify_password(request.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Tài khoản hoặc mật khẩu không chính xác",
            )
    else:
        # Offline memory fallback: verify user and password
        user = next((u for u in MEMORY_USERS.values() if u.email == email_clean), None)
        if user is None or not verify_password(request.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Tài khoản hoặc mật khẩu không chính xác",
            )

    if user.is_active is False:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    access_token = create_access_token(str(user.id))
    refresh_token = create_refresh_token(str(user.id))

    return AuthResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse(**user.to_dict()),
    )


# ──────────────────────────────────────────────
# Google Sign-In
# ──────────────────────────────────────────────
@router.post("/google", response_model=AuthResponse)
async def google_sign_in(
    request: GoogleAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    """Authenticate with a Google ID token (from the client SDK).

    Verifies the token against GOOGLE_OAUTH_CLIENT_ID, then finds or
    creates the matching local account.
    """
    if not settings.google_oauth_client_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Sign-In is not configured on the server",
        )

    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token as google_id_token
    except ImportError as exc:
        logger.error("google-auth is not installed on the server: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Google Sign-In backend dependency missing (google-auth)",
        ) from exc

    try:
        idinfo = google_id_token.verify_oauth2_token(
            request.id_token,
            google_requests.Request(),
            settings.google_oauth_client_id,
        )
    except Exception as exc:
        claims = _decode_jwt_claims_unverified(request.id_token)
        logger.warning(
            "Google ID token verification failed: %s (token aud=%s, iss=%s, "
            "expected aud=%s)",
            exc,
            claims.get("aud"),
            claims.get("iss"),
            settings.google_oauth_client_id,
        )
        detail = "Invalid Google ID token"
        if settings.environment.lower() != "production":
            detail = f"Invalid Google ID token: {exc}"
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
        ) from exc

    email_clean = (idinfo.get("email") or "").lower().strip()
    if not email_clean:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google account has no email address",
        )

    name = (idinfo.get("name") or email_clean.split("@")[0]).strip()
    avatar_url = idinfo.get("picture")

    user = None
    if is_db_connected():
        try:
            result = await db.execute(
                select(User).where(User.email == email_clean)
            )
            user = result.scalar_one_or_none()

            if user is None:
                import uuid

                user = User(
                    email=email_clean,
                    password_hash=hash_password(uuid.uuid4().hex),
                    name=name,
                    avatar_url=avatar_url,
                    daily_learning_minutes=20,
                    has_completed_onboarding=True,
                    is_active=True,
                )
                db.add(user)
                await db.flush()
                db.add(UserProfile(user_id=user.id))
                await db.flush()
            elif avatar_url and not user.avatar_url:
                user.avatar_url = avatar_url
        except Exception:
            user = None

    if user is None:
        # DB offline fallback: find or create in memory
        user = next(
            (u for u in MEMORY_USERS.values() if u.email == email_clean),
            None,
        )
        if user is None:
            import uuid

            new_id = uuid.uuid4()
            user = User(
                id=new_id,
                email=email_clean,
                password_hash=hash_password(uuid.uuid4().hex),
                name=name,
                avatar_url=avatar_url,
                daily_learning_minutes=20,
                has_completed_onboarding=True,
                is_active=True,
            )
            MEMORY_USERS[new_id] = user

    if user.is_active is False:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    access_token = create_access_token(str(user.id))
    refresh_token = create_refresh_token(str(user.id))

    return AuthResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse(**user.to_dict()),
    )


# ──────────────────────────────────────────────
# Refresh Token
# ──────────────────────────────────────────────
@router.post("/refresh", response_model=AuthResponse)
async def refresh_token(
    request: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """Refresh access token using a valid refresh token."""
    payload = decode_token(request.refresh_token)

    if payload is None or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    user_id = payload.get("sub")
    user = None
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

    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or deactivated",
        )

    new_access_token = create_access_token(str(user.id))
    new_refresh_token = create_refresh_token(str(user.id))

    return AuthResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        user=UserResponse(**user.to_dict()),
    )


# ──────────────────────────────────────────────
# Logout
# ──────────────────────────────────────────────
@router.post("/logout", response_model=MessageResponse)
async def logout(
    current_user: User = Depends(get_current_user),
):
    """Logout current user. Client should discard tokens."""
    # In a more advanced setup, we'd blacklist the token in Redis
    return MessageResponse(message="Successfully logged out")


# ──────────────────────────────────────────────
# Forgot Password
# ──────────────────────────────────────────────
@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(
    request: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """Send password reset email."""
    import logging

    logger = logging.getLogger(__name__)
    email_clean = request.email.lower().strip()

    # Always return success to prevent email enumeration
    reset_token = None
    try:
        result = await db.execute(select(User).where(User.email == email_clean))
        user = result.scalar_one_or_none()
        if user:
            reset_token = create_reset_token(str(user.id))
    except Exception:
        user = next((u for u in MEMORY_USERS.values() if u.email == email_clean), None)
        if user:
            reset_token = create_reset_token(str(user.id))

    if reset_token:
        # In production: email the reset link instead of logging it.
        logger.info("Password reset token for %s: %s", email_clean, reset_token)

    return MessageResponse(
        message="If an account with that email exists, a reset link has been sent"
    )


# ──────────────────────────────────────────────
# Reset Password
# ──────────────────────────────────────────────
@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(
    request: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """Reset a user's password using a valid reset token."""
    payload = decode_token(request.token)
    if payload is None or payload.get("type") != "reset":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token",
        )

    user_id = payload.get("sub")
    updated = False

    if is_db_connected() and db is not None:
        try:
            result = await db.execute(
                select(User).where(User.id == UUID(user_id))
            )
            user = result.scalar_one_or_none()
            if user:
                user.password_hash = hash_password(request.new_password)
                await db.flush()
                updated = True
        except Exception:
            updated = False

    if not updated:
        try:
            mem_user = MEMORY_USERS.get(UUID(user_id))
            if mem_user:
                mem_user.password_hash = hash_password(request.new_password)
                updated = True
        except Exception:
            updated = False

    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return MessageResponse(message="Password has been reset successfully")
