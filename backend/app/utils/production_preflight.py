"""Read-only production readiness checks for the grammar backend.

Run from ``backend/`` with production environment variables:

    python -m app.utils.production_preflight

The command exits non-zero if any check fails. It never writes data.
"""
from __future__ import annotations

import asyncio
import sys

from sqlalchemy import text

from app.config import settings
from app.database import engine


def _check(results: list[tuple[str, bool, str]], name: str, ok: bool, detail: str) -> None:
    results.append((name, bool(ok), detail))


async def _database_checks(results: list[tuple[str, bool, str]]) -> None:
    try:
        async with engine.connect() as conn:
            revision = (
                await conn.execute(text("select version_num from alembic_version"))
            ).scalar_one_or_none()
            published = int(
                (
                    await conn.execute(
                        text(
                            "select count(*) from grammar_lessons "
                            "where status = 'published' and is_active = true"
                        )
                    )
                ).scalar()
                or 0
            )
            beta = int(
                (
                    await conn.execute(
                        text(
                            "select count(*) from grammar_lessons "
                            "where is_beta = true and status = 'published'"
                        )
                    )
                ).scalar()
                or 0
            )
            admins = int(
                (
                    await conn.execute(
                        text(
                            "select count(*) from users "
                            "where role = 'admin' and is_active = true"
                        )
                    )
                ).scalar()
                or 0
            )
    except Exception as exc:  # pragma: no cover - depends on deployment DB
        _check(results, "database", False, f"{type(exc).__name__}: {exc}")
        return

    _check(
        results,
        "alembic",
        revision == "0002_grammar_backend",
        f"revision={revision!r} (expected '0002_grammar_backend')",
    )
    _check(
        results,
        "published lessons",
        published == 96,
        f"published={published} (expected 96)",
    )
    _check(
        results,
        "beta lessons",
        beta == 20,
        f"beta={beta} (expected 20 until human review clears C1/C2)",
    )
    _check(
        results,
        "active admin account",
        admins >= 1,
        f"admins={admins} (create a dedicated production admin)",
    )


async def main() -> int:
    results: list[tuple[str, bool, str]] = []

    _check(
        results,
        "environment",
        settings.environment.lower() == "production",
        f"ENVIRONMENT={settings.environment!r}",
    )
    _check(results, "debug", not settings.debug, f"DEBUG={settings.debug}")
    _check(
        results,
        "demo accounts",
        not settings.enable_demo_accounts,
        f"ENABLE_DEMO_ACCOUNTS={settings.enable_demo_accounts}",
    )
    secret = settings.jwt_secret_key
    secret_is_placeholder = "REPLACE" in secret.upper() or "CHANGE" in secret.upper()
    _check(
        results,
        "JWT secret",
        len(secret) >= 32 and not secret_is_placeholder,
        "JWT_SECRET_KEY must be at least 32 random characters, not a placeholder",
    )
    origins = [origin.strip() for origin in settings.cors_origins if origin.strip()]
    unsafe_origins = [
        origin
        for origin in origins
        if origin == "*"
        or "localhost" in origin
        or "127.0.0.1" in origin
        or "YOUR_" in origin
    ]
    _check(
        results,
        "CORS origins",
        bool(origins) and not unsafe_origins,
        f"origins={origins!r}; remove wildcard/localhost entries",
    )

    await _database_checks(results)
    await engine.dispose()

    failed = False
    for name, ok, detail in results:
        status = "PASS" if ok else "FAIL"
        print(f"[{status}] {name}: {detail}")
        failed = failed or not ok
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
