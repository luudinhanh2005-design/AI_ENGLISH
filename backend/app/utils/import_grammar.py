"""Import the bundled 96-lesson grammar curriculum into PostgreSQL.

Usage (from ``backend/``):
    python -m app.utils.import_grammar
    python -m app.utils.import_grammar --dry-run

The import is idempotent by slug + content hash. A changed lesson creates a new
``grammar_lesson_versions`` row and increments ``grammar_lessons.version``.
"""
from __future__ import annotations

import argparse
import asyncio
import sys
from datetime import datetime, timezone

from sqlalchemy import select

from app.database import async_session_factory, init_db
from app.models.learning import GrammarLesson, GrammarLessonVersion
from app.services.grammar_service import (
    content_hash,
    deterministic_lesson_id,
    load_seed_lessons,
)


async def import_grammar(dry_run: bool = False) -> int:
    payloads = load_seed_lessons()
    if len(payloads) != 96:
        print(
            f"Refusing to import: expected 96 lessons, found {len(payloads)}",
            file=sys.stderr,
        )
        return 2

    if dry_run:
        levels: dict[str, int] = {}
        for payload in payloads:
            levels[payload["level"]] = levels.get(payload["level"], 0) + 1
        print(f"Dry run OK: {len(payloads)} lessons")
        for level, count in sorted(levels.items()):
            print(f"  {level}: {count}")
        print(f"  quiz questions: {sum(len(p['quiz']) for p in payloads)}")
        return 0

    await init_db(create_tables=False)

    created = 0
    updated = 0
    unchanged = 0
    now = datetime.now(timezone.utc)

    async with async_session_factory() as session:
        for payload in payloads:
            slug = payload["id"]
            digest = content_hash(payload)
            result = await session.execute(
                select(GrammarLesson).where(GrammarLesson.slug == slug)
            )
            lesson = result.scalar_one_or_none()

            if lesson is None:
                payload = dict(payload)
                payload["version"] = 1
                payload["updated_at"] = now.isoformat()
                lesson = GrammarLesson(
                    id=deterministic_lesson_id(slug),
                    slug=slug,
                    title=payload["title"],
                    title_vi=payload["title_vi"],
                    level=payload["level"],
                    category=payload["category"],
                    summary=payload["description"],
                    content_markdown=payload["content_markdown"],
                    formula=payload["formula_affirmative"] or None,
                    examples=payload["examples"],
                    practice_questions=payload["quiz"],
                    content=payload,
                    content_hash=digest,
                    status="published",
                    version=1,
                    is_beta=payload["is_beta"],
                    tags=payload["tags"],
                    estimated_minutes=payload["estimated_minutes"],
                    order_index=payload["order_index"],
                    is_active=True,
                    published_at=now,
                )
                session.add(lesson)
                created += 1
                version = 1
            else:
                if lesson.content_hash != digest:
                    lesson.version = int(lesson.version or 1) + 1
                    updated += 1
                else:
                    lesson.version = int(lesson.version or 1)
                    unchanged += 1
                version = lesson.version
                payload = dict(payload)
                payload["version"] = version
                payload["updated_at"] = now.isoformat()
                lesson.title = payload["title"]
                lesson.title_vi = payload["title_vi"]
                lesson.level = payload["level"]
                lesson.category = payload["category"]
                lesson.summary = payload["description"]
                lesson.content_markdown = payload["content_markdown"]
                lesson.formula = payload["formula_affirmative"] or None
                lesson.examples = payload["examples"]
                lesson.practice_questions = payload["quiz"]
                lesson.content = payload
                lesson.content_hash = digest
                lesson.status = "published"
                lesson.is_beta = payload["is_beta"]
                lesson.tags = payload["tags"]
                lesson.estimated_minutes = payload["estimated_minutes"]
                lesson.order_index = payload["order_index"]
                lesson.is_active = True
                lesson.published_at = lesson.published_at or now

            await session.flush()

            version_result = await session.execute(
                select(GrammarLessonVersion).where(
                    GrammarLessonVersion.lesson_id == lesson.id,
                    GrammarLessonVersion.version == version,
                )
            )
            if version_result.scalar_one_or_none() is None:
                session.add(
                    GrammarLessonVersion(
                        lesson_id=lesson.id,
                        version=version,
                        content=payload,
                        content_hash=digest,
                        changelog="Imported from bundled curriculum",
                    )
                )

        # Older dev databases were seeded by ``create_all` + SAMPLE_GRAMMAR``.
        # Keep those rows for audit/history but remove them from the public
        # curriculum now that the 96 canonical lessons are present.
        legacy_result = await session.execute(
            select(GrammarLesson).where(GrammarLesson.content.is_(None))
        )
        for legacy in legacy_result.scalars().all():
            legacy.status = "archived"
            legacy.is_active = False

        await session.commit()

    print(
        f"Grammar import complete: {created} created, {updated} updated, "
        f"{unchanged} unchanged"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Import bilingual grammar curriculum")
    parser.add_argument("--dry-run", action="store_true", help="Validate without writing")
    args = parser.parse_args()
    try:
        return asyncio.run(import_grammar(dry_run=args.dry_run))
    except Exception as exc:
        print(f"Grammar import failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
