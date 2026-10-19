from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from .config import settings

_MANAGED_DB_HINTS = ("supabase", "pooler", "neon.tech", "sslmode=require")


def _resolve_ssl() -> bool:
    """SSL is required for managed Postgres hosts, but not for local/Docker."""
    if settings.database_ssl is not None:
        return settings.database_ssl
    url = settings.database_url.lower()
    return any(hint in url for hint in _MANAGED_DB_HINTS)


_connect_args: dict = {"statement_cache_size": 0}
if _resolve_ssl():
    _connect_args["ssl"] = "require"

# Create async engine
engine = create_async_engine(
    settings.database_url,
    echo=settings.debug,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
    connect_args=_connect_args,
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


def is_db_connected() -> bool:
    """Return the live DB status.

    Import this function instead of the ``IS_DB_CONNECTED`` boolean: importing
    the boolean binds a snapshot of its value at import time, before startup
    runs ``init_db``.
    """
    return IS_DB_CONNECTED


async def init_db(create_tables: bool = True):
    """Verify DB connectivity.

    In development `create_tables=True` mirrors the models with `create_all`
    for convenience. In production, tables are managed by Alembic
    (`alembic upgrade head`) and this only checks connectivity.
    """
    global IS_DB_CONNECTED
    import asyncio

    from sqlalchemy import text

    async def _connect():
        async with engine.begin() as conn:
            if create_tables:
                await conn.run_sync(Base.metadata.create_all)
            else:
                await conn.execute(text("SELECT 1"))

    try:
        await asyncio.wait_for(_connect(), timeout=10.0)
        IS_DB_CONNECTED = True
    except Exception as e:
        IS_DB_CONNECTED = False
        raise e
