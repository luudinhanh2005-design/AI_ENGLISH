from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from .config import settings


# Create async engine
engine = create_async_engine(
    settings.database_url,
    echo=settings.debug,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
    connect_args={"statement_cache_size": 0},
)

# Session factory
async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy models."""
    pass


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency that provides a database session."""
    if not IS_DB_CONNECTED:
        yield None  # type: ignore
        return

    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


IS_DB_CONNECTED: bool = False


async def init_db():
    """Create all tables. Use Alembic in production instead."""
    global IS_DB_CONNECTED
    import asyncio
    async def _connect():
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    try:
        await asyncio.wait_for(_connect(), timeout=1.5)
        IS_DB_CONNECTED = True
    except Exception as e:
        IS_DB_CONNECTED = False
        raise e
