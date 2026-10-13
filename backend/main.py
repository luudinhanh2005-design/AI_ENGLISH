from contextlib import asynccontextmanager
import logging

import uvicorn
from fastapi import FastAPI

from app.api.middleware import (
    ErrorHandlingMiddleware,
    RequestLoggingMiddleware,
    setup_cors,
)
from app.api.v1.router import router as api_router
from app.config import settings
from app.database import init_db

# Configure logging
logging.basicConfig(
    level=logging.INFO if settings.debug else logging.WARNING,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle manager for startup and shutdown events."""
    logger.info(f"ðŸš€ Starting {settings.app_name} v{settings.app_version}")
    try:
        # Create tables (use Alembic migrations in production)
        await init_db()
        logger.info("Database initialized")
        # Local LLM will be lazy-loaded on demand if requested
        logger.info("Server startup complete")
    except Exception as e:
        logger.warning(
            f"âš ï¸ Could not connect to database on startup: {e}. "
            "The server will continue running, but DB-dependent endpoints require a running PostgreSQL instance."
        )
    yield
    logger.info("ðŸ‘‹ Shutting down...")


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        description="EnglishAI â€” Personalized AI English Learning Assistant API",
        docs_url="/docs" if settings.debug else None,
        redoc_url="/redoc" if settings.debug else None,
        lifespan=lifespan,
    )

    # â”€â”€ Middleware â”€â”€
    setup_cors(app, settings.cors_origins)
    app.add_middleware(RequestLoggingMiddleware)
    app.add_middleware(ErrorHandlingMiddleware)

    # â”€â”€ Routes â”€â”€
    app.include_router(api_router)

    # Also support direct paths without /api/v1 prefix for client compatibility
    from app.api.v1.auth import router as auth_router
    from app.api.v1.users import router as users_router
    from app.api.v1.placement import router as placement_router
    from app.api.v1.vocabulary import router as vocabulary_router
    from app.api.v1.grammar import router as grammar_router
    from app.api.v1.ai import router as ai_router
    from app.api.v1.speech import router as speech_router

    app.include_router(auth_router, prefix="/auth", tags=["Authentication"])
    app.include_router(users_router, prefix="/users", tags=["Users"])
    app.include_router(placement_router, prefix="/placement", tags=["Placement Test"])
    app.include_router(vocabulary_router, prefix="/vocabulary", tags=["Vocabulary & SM-2"])
    app.include_router(grammar_router, prefix="/grammar", tags=["Grammar"])
    app.include_router(ai_router, prefix="/ai", tags=["AI Tutor & Intelligent Engine"])
    app.include_router(speech_router, prefix="/speech", tags=["Speech AI & Pronunciation"])

    # â”€â”€ Health Check â”€â”€
    @app.get("/health", tags=["Health"])
    async def health_check():
        return {
            "status": "healthy",
            "app": settings.app_name,
            "version": settings.app_version,
        }

    return app


app = create_app()

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
        log_level="info",
    )
