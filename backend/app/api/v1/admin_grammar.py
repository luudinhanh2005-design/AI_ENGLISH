"""Staff API for the grammar content workspace.

The HTML workspace lives at ``/admin/grammar`` and talks to these endpoints
with the normal JWT bearer token.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ...database import get_db, is_db_connected
from ...models.learning import (
    GrammarAttempt,
    GrammarLesson,
    GrammarLessonVersion,
    XpTransaction,
)
from ...models.user import User
from ...schemas.grammar import (
    GrammarAdminLessonInput,
    GrammarAdminStats,
    GrammarLessonDetail,
    GrammarLessonSummary,
    GrammarValidationResponse,
    GrammarVersionSummary,
)
from ...services.grammar_service import (
    add_audit,
    content_hash,
    lesson_to_payload,
    normalize_lesson,
    payload_to_detail,
    payload_to_summary,
    validate_payload,
)
from ..deps import require_admin, require_staff

logger = logging.getLogger(__name__)
router = APIRouter()


def _require_db() -> None:
    if not is_db_connected():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database is unavailable",
        )


async def _get_lesson(db: AsyncSession, identifier: str) -> GrammarLesson:
    lesson = None
    try:
        result = await db.execute(
            select(GrammarLesson).where(GrammarLesson.slug == identifier)
        )
        lesson = result.scalar_one_or_none()
        if lesson is None:
            result = await db.execute(
                select(GrammarLesson).where(GrammarLesson.id == UUID(identifier))
            )
            lesson = result.scalar_one_or_none()
    except (ValueError, TypeError):
        lesson = None
    if lesson is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grammar lesson not found")
    return lesson


def _payload_from_input(data: GrammarAdminLessonInput, order_index: int = 0) -> dict:
    raw = data.model_dump()
    raw["order_index"] = order_index
    raw["description"] = data.description or raw.get("summary") or ""
    payload = normalize_lesson(raw, order_index=order_index)
    payload["status"] = data.status
    return payload


def _apply_payload(
    lesson: GrammarLesson,
    payload: dict,
    actor: User,
    *,
    status_value: Optional[str] = None,
) -> bool:
    digest = content_hash(payload)
    changed = lesson.content_hash != digest
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
    lesson.is_beta = payload["is_beta"]
    lesson.tags = payload["tags"]
    lesson.estimated_minutes = payload["estimated_minutes"]
    lesson.order_index = payload["order_index"]
    lesson.updated_by = actor.id
    lesson.is_active = True
    if status_value:
        lesson.status = status_value
        payload["status"] = status_value
    lesson.content = payload
    if lesson.status == "published":
        lesson.published_at = lesson.published_at or datetime.now(timezone.utc)
    return changed


async def _store_version(
    db: AsyncSession,
    lesson: GrammarLesson,
    payload: dict,
    actor: User,
    changelog: str,
) -> GrammarLessonVersion:
    lesson.version = int(lesson.version or 1) + 1
    payload = dict(payload)
    payload["version"] = lesson.version
    payload["updated_at"] = datetime.now(timezone.utc).isoformat()
    digest = content_hash(payload)
    lesson.content = payload
    lesson.content_hash = digest
    version = GrammarLessonVersion(
        id=uuid4(),
        lesson_id=lesson.id,
        version=lesson.version,
        content=payload,
        content_hash=digest,
        changelog=changelog,
        created_by=actor.id,
    )
    db.add(version)
    return version


@router.get("/lessons", response_model=list[GrammarLessonSummary])
async def admin_list_lessons(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_staff),
):
    _require_db()
    result = await db.execute(
        select(GrammarLesson).order_by(
            GrammarLesson.order_index, GrammarLesson.level, GrammarLesson.slug
        )
    )
    return [payload_to_summary(lesson_to_payload(lesson)) for lesson in result.scalars().all()]


@router.get("/lessons/{identifier}", response_model=GrammarLessonDetail)
async def admin_get_lesson(
    identifier: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_staff),
):
    _require_db()
    lesson = await _get_lesson(db, identifier)
    return payload_to_detail(lesson_to_payload(lesson))


@router.post("/lessons", response_model=GrammarLessonDetail, status_code=status.HTTP_201_CREATED)
async def admin_create_lesson(
    request: GrammarAdminLessonInput,
    db: AsyncSession = Depends(get_db),
    actor: User = Depends(require_staff),
):
    _require_db()
    if not request.id.strip():
        raise HTTPException(status_code=400, detail="id is required")
    existing = await db.execute(select(GrammarLesson).where(GrammarLesson.slug == request.id))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="A lesson with this id already exists")

    order_result = await db.execute(select(func.max(GrammarLesson.order_index)))
    order_index = int(order_result.scalar() or 0) + 1
    payload = _payload_from_input(request, order_index=order_index)
    payload["version"] = 1
    payload["updated_at"] = datetime.now(timezone.utc).isoformat()

    validation = validate_payload(payload)
    if not validation.valid:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"message": "Invalid grammar content", "errors": validation.errors},
        )

    lesson = GrammarLesson(
        id=uuid4(),
        slug=request.id,
        version=1,
        status=request.status,
        content_hash=content_hash(payload),
        created_by=actor.id,
        updated_by=actor.id,
    )
    _apply_payload(lesson, payload, actor, status_value=request.status)
    db.add(lesson)
    await db.flush()
    db.add(
        GrammarLessonVersion(
            id=uuid4(),
            lesson_id=lesson.id,
            version=1,
            content=payload,
            content_hash=content_hash(payload),
            changelog=request.changelog or "Created in admin workspace",
            created_by=actor.id,
        )
    )
    add_audit(db, actor, "create", lesson.id, {"slug": lesson.slug})
    await db.flush()
    return payload_to_detail(lesson_to_payload(lesson))


@router.put("/lessons/{identifier}", response_model=GrammarLessonDetail)
async def admin_update_lesson(
    identifier: str,
    request: GrammarAdminLessonInput,
    db: AsyncSession = Depends(get_db),
    actor: User = Depends(require_staff),
):
    _require_db()
    lesson = await _get_lesson(db, identifier)
    if request.id != lesson.slug:
        raise HTTPException(status_code=400, detail="Lesson id cannot be changed")
    payload = _payload_from_input(request, order_index=lesson.order_index)
    validation = validate_payload(payload)
    if not validation.valid:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"message": "Invalid grammar content", "errors": validation.errors},
        )

    changed = _apply_payload(lesson, payload, actor, status_value=request.status)
    if changed:
        payload["version"] = int(lesson.version or 1) + 1
        payload["updated_at"] = datetime.now(timezone.utc).isoformat()
        lesson.version = payload["version"]
        lesson.content = payload
        db.add(
            GrammarLessonVersion(
                id=uuid4(),
                lesson_id=lesson.id,
                version=lesson.version,
                content=payload,
                content_hash=content_hash(payload),
                changelog=request.changelog or "Updated in admin workspace",
                created_by=actor.id,
            )
        )
    add_audit(db, actor, "update", lesson.id, {"slug": lesson.slug, "changed": changed})
    await db.flush()
    return payload_to_detail(lesson_to_payload(lesson))


@router.post("/lessons/{identifier}/validate", response_model=GrammarValidationResponse)
async def admin_validate_lesson(
    identifier: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_staff),
):
    _require_db()
    lesson = await _get_lesson(db, identifier)
    return validate_payload(lesson_to_payload(lesson))


@router.post("/lessons/{identifier}/submit-review", response_model=GrammarLessonDetail)
async def admin_submit_review(
    identifier: str,
    db: AsyncSession = Depends(get_db),
    actor: User = Depends(require_staff),
):
    _require_db()
    lesson = await _get_lesson(db, identifier)
    validation = validate_payload(lesson_to_payload(lesson))
    if not validation.valid:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"message": "Fix validation errors before review", "errors": validation.errors},
        )
    lesson.status = "in_review"
    add_audit(db, actor, "submit_review", lesson.id, {"slug": lesson.slug})
    await db.flush()
    return payload_to_detail(lesson_to_payload(lesson))


@router.post("/lessons/{identifier}/publish", response_model=GrammarLessonDetail)
async def admin_publish_lesson(
    identifier: str,
    db: AsyncSession = Depends(get_db),
    actor: User = Depends(require_admin),
):
    _require_db()
    lesson = await _get_lesson(db, identifier)
    payload = lesson_to_payload(lesson)
    validation = validate_payload(payload)
    if not validation.valid:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"message": "Cannot publish invalid content", "errors": validation.errors},
        )

    now = datetime.now(timezone.utc)
    payload["status"] = "published"
    payload["updated_at"] = now.isoformat()
    lesson.status = "published"
    lesson.reviewed_at = now
    lesson.published_at = now
    lesson.updated_by = actor.id
    lesson.content = payload

    # Publishing always produces an immutable snapshot.
    version_result = await db.execute(
        select(GrammarLessonVersion).where(
            GrammarLessonVersion.lesson_id == lesson.id,
            GrammarLessonVersion.version == int(lesson.version or 1),
            GrammarLessonVersion.content_hash == content_hash(payload),
        )
    )
    if version_result.scalar_one_or_none() is None:
        await _store_version(db, lesson, payload, actor, "Published from admin workspace")
    add_audit(db, actor, "publish", lesson.id, {"slug": lesson.slug, "version": lesson.version})
    await db.flush()
    return payload_to_detail(lesson_to_payload(lesson))


@router.get("/lessons/{identifier}/versions", response_model=list[GrammarVersionSummary])
async def admin_list_versions(
    identifier: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_staff),
):
    _require_db()
    lesson = await _get_lesson(db, identifier)
    result = await db.execute(
        select(GrammarLessonVersion)
        .where(GrammarLessonVersion.lesson_id == lesson.id)
        .order_by(GrammarLessonVersion.version.desc())
    )
    return [
        GrammarVersionSummary(
            version=version.version,
            content_hash=version.content_hash,
            changelog=version.changelog or "",
            created_at=version.created_at,
        )
        for version in result.scalars().all()
    ]


@router.post("/lessons/{identifier}/rollback/{version_number}", response_model=GrammarLessonDetail)
async def admin_rollback_lesson(
    identifier: str,
    version_number: int,
    db: AsyncSession = Depends(get_db),
    actor: User = Depends(require_admin),
):
    _require_db()
    lesson = await _get_lesson(db, identifier)
    result = await db.execute(
        select(GrammarLessonVersion).where(
            GrammarLessonVersion.lesson_id == lesson.id,
            GrammarLessonVersion.version == version_number,
        )
    )
    snapshot = result.scalar_one_or_none()
    if snapshot is None:
        raise HTTPException(status_code=404, detail="Version not found")

    payload = dict(snapshot.content)
    payload["status"] = "published"
    payload["updated_at"] = datetime.now(timezone.utc).isoformat()
    _apply_payload(lesson, payload, actor, status_value="published")
    lesson.reviewed_at = datetime.now(timezone.utc)
    lesson.published_at = datetime.now(timezone.utc)
    await _store_version(
        db,
        lesson,
        payload,
        actor,
        f"Rolled back from version {version_number}",
    )
    add_audit(
        db,
        actor,
        "rollback",
        lesson.id,
        {"slug": lesson.slug, "from_version": version_number, "to_version": lesson.version},
    )
    await db.flush()
    return payload_to_detail(lesson_to_payload(lesson))


@router.get("/export", response_model=list[GrammarLessonDetail])
async def admin_export(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    _require_db()
    result = await db.execute(select(GrammarLesson).order_by(GrammarLesson.order_index))
    return [payload_to_detail(lesson_to_payload(lesson)) for lesson in result.scalars().all()]


@router.post("/import")
async def admin_import(
    _: User = Depends(require_admin),
):
    _require_db()
    from ...utils.import_grammar import import_grammar

    code = await import_grammar(dry_run=False)
    if code != 0:
        raise HTTPException(status_code=500, detail="Import failed")
    return {"ok": True, "message": "Imported bundled curriculum"}


@router.get("/stats", response_model=GrammarAdminStats)
async def admin_stats(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_staff),
):
    _require_db()
    total = int((await db.execute(select(func.count(GrammarLesson.id)))).scalar() or 0)
    published = int(
        (
            await db.execute(
                select(func.count(GrammarLesson.id)).where(GrammarLesson.status == "published")
            )
        ).scalar()
        or 0
    )
    drafts = int(
        (
            await db.execute(
                select(func.count(GrammarLesson.id)).where(GrammarLesson.status.in_(["draft", "in_review"]))
            )
        ).scalar()
        or 0
    )
    beta = int(
        (
            await db.execute(
                select(func.count(GrammarLesson.id)).where(GrammarLesson.is_beta == True)  # noqa: E712
            )
        ).scalar()
        or 0
    )
    attempts = int((await db.execute(select(func.count(GrammarAttempt.id)))).scalar() or 0)
    xp = int((await db.execute(select(func.sum(XpTransaction.amount)))).scalar() or 0)
    by_level_result = await db.execute(
        select(GrammarLesson.level, func.count(GrammarLesson.id)).group_by(GrammarLesson.level)
    )
    by_level = {level: int(count) for level, count in by_level_result.all()}
    return GrammarAdminStats(
        total_lessons=total,
        published_lessons=published,
        draft_lessons=drafts,
        beta_lessons=beta,
        total_attempts=attempts,
        total_xp_awarded=xp,
        by_level=by_level,
    )


@router.get("/audit")
async def admin_audit(
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_staff),
):
    _require_db()
    from ...models.learning import GrammarAdminAudit

    result = await db.execute(
        select(GrammarAdminAudit)
        .order_by(GrammarAdminAudit.created_at.desc())
        .limit(max(1, min(limit, 200)))
    )
    return [
        {
            "id": str(row.id),
            "actor_id": str(row.actor_id) if row.actor_id else None,
            "action": row.action,
            "lesson_id": str(row.lesson_id) if row.lesson_id else None,
            "details": row.details,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        }
        for row in result.scalars().all()
    ]
