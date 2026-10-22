import logging
import secrets
from typing import List

from pydantic import model_validator
from pydantic_settings import BaseSettings

logger = logging.getLogger(__name__)

_INSECURE_JWT_DEFAULT = "your-super-secret-key-change-this-in-production"


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Application
    app_name: str = "EnglishAI"
    app_version: str = "1.0.0"
    environment: str = "development"  # "development" | "production"
    debug: bool = True

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # Database
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/english_ai"
    # None = auto-detect from the URL (SSL for managed hosts like Supabase).
    database_ssl: bool | None = None

    # JWT
    jwt_secret_key: str = ""
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60
    jwt_refresh_token_expire_days: int = 30

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # Google Sign-In (OAuth client ID used to verify ID tokens)
    google_oauth_client_id: str | None = (
        "116869668249-h8j2sit4nft1mrt08rdi993m2rcntapn.apps.googleusercontent.com"
    )

    # CORS
    cors_origins: List[str] = ["http://localhost:3000", "http://localhost:8080"]

    # AI Services (Phase 3)
    openai_api_key: str | None = None
    google_ai_api_key: str | None = None
    ai_provider: str = "gemini"  # "local", "gemini", "openai", or "hybrid"
    ai_model_name: str = "gemini-2.5-flash"
    ai_cloud_fallback: bool = True
    local_llm_enabled: bool = True
    local_llm_preload: bool = True
    local_llm_load_timeout_seconds: float = 120.0
    local_llm_timeout_seconds: float = 60.0

    # Demo/offline fallback accounts (NEVER enable in production)
    enable_demo_accounts: bool = True
    demo_user_password: str = "Password123"

    @model_validator(mode="after")
    def _validate_security(self) -> "Settings":
        is_prod = self.environment.lower() == "production"

        # JWT secret must be strong. Auto-generate a random one in dev,
        # but refuse to start in production with a weak/missing secret.
        if not self.jwt_secret_key or self.jwt_secret_key == _INSECURE_JWT_DEFAULT:
            if is_prod:
                raise ValueError(
                    "JWT_SECRET_KEY must be set to a strong, unique value in production."
                )
            self.jwt_secret_key = secrets.token_urlsafe(48)
            logger.warning(
                "JWT_SECRET_KEY was not configured; generated a random one for this "
                "run. Tokens will be invalidated on restart. Set JWT_SECRET_KEY in .env."
            )

        if is_prod:
            if self.debug:
                logger.warning("DEBUG is enabled while ENVIRONMENT=production.")
            if self.enable_demo_accounts:
                raise ValueError(
                    "ENABLE_DEMO_ACCOUNTS must be false in production."
                )

        return self

    @property
    def docs_enabled(self) -> bool:
        """Expose interactive API docs only outside production."""
        return self.environment.lower() != "production"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False
        extra = "ignore"


settings = Settings()
