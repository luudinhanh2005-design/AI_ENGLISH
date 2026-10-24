"""Storage adapter for placement sessions and reports.

PostgreSQL is used when it is connected.  A small JSON store mirrors the same
operations for demo/offline environments, which is how the rest of the app
already behaves.
"""

from __future__ import annotations

import asyncio
import json
import logging
from pathlib import Path
from typing import Any, Optional
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import is_db_connected
from ..models.placement import (
    PlacementResponseRecord,
    PlacementResultRecord,
    PlacementSessionRecord,
)

logger = logging.getLogger(__name__)


class _JsonStore:
    def __init__(self, root: Optional[Path] = None) -> None:
        base = Path(root) if root else Path("storage")
        self.sessions_path = base / "placement_sessions.json"
        self.results_path = base / "placement_results.json"
        self._lock = asyncio.Lock()
        self._sessions: dict[str, dict[str, Any]] = self._load(self.sessions_path)
        self._results: dict[str, dict[str, Any]] = self._load(self.results_path)

    @staticmethod
    def _load(path: Path) -> dict[str, Any]:
        if not path.exists():
            return {}
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            return data if isinstance(data, dict) else {}
        except Exception:
            logger.warning("Could not read %s", path, exc_info=True)
            return {}

    @staticmethod
    def _write(path: Path, data: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        tmp.replace(path)

    async def save_session(self, state: dict[str, Any]) -> None:
        async with self._lock:
            self._sessions[str(state["id"])] = state
            self._write(self.sessions_path, self._sessions)

    async def get_session(self, session_id: str) -> Optional[dict[str, Any]]:
        async with self._lock:
            state = self._sessions.get(str(session_id))
            return json.loads(json.dumps(state)) if state is not None else None

    async def save_result(self, result: dict[str, Any]) -> None:
        async with self._lock:
            self._results[str(result["result_id"])] = result
            self._write(self.results_path, self._results)

    async def get_result(self, result_id: str) -> Optional[dict[str, Any]]:
        async with self._lock:
            result = self._results.get(str(result_id))
            return json.loads(json.dumps(result)) if result is not None else None

    async def get_result_by_session(self, session_id: str) -> Optional[dict[str, Any]]:
        async with self._lock:
            for result in self._results.values():
                if str(result.get("session_id")) == str(session_id):
                    return json.loads(json.dumps(result))
            return None

    async def latest_result(self, user_id: str) -> Optional[dict[str, Any]]:
        async with self._lock:
            matches = [
                result
                for result in self._results.values()
                if str(result.get("user_id")) == str(user_id)
            ]
            if not matches:
                return None
            matches.sort(key=lambda item: str(item.get("completed_at", "")), reverse=True)
            return json.loads(json.dumps(matches[0]))

    async def list_results(self, user_id: str, limit: int = 20) -> list[dict[str, Any]]:
        async with self._lock:
            matches = [
                result
                for result in self._results.values()
                if str(result.get("user_id")) == str(user_id)
            ]
            matches.sort(key=lambda item: str(item.get("completed_at", "")), reverse=True)
            return json.loads(json.dumps(matches[:limit]))


_json_store: Optional[_JsonStore] = None


def json_store() -> _JsonStore:
    global _json_store
    if _json_store is None:
        _json_store = _JsonStore()
    return _json_store


class PlacementRepository:
    """DB-first, JSON-fallback repository."""

    def __init__(self, db: Optional[AsyncSession] = None) -> None:
        self.db = db

    @property
    def use_db(self) -> bool:
        return self.db is not None and is_db_connected()

    # ── sessions ──────────────────────────────────────────────

    async def save_session(self, state: dict[str, Any]) -> None:
        if self.use_db:
            try:
                session_id = UUID(str(state["id"]))
                result = await self.db.execute(
                    select(PlacementSessionRecord).where(
                        PlacementSessionRecord.id == session_id
                    )
                )
                record = result.scalar_one_or_none()
                if record is None:
                    record = PlacementSessionRecord(
                        id=session_id,
                        user_id=UUID(str(state["user_id"])),
                        mode=str(state.get("mode", "quick")),
                        status=str(state.get("status", "in_progress")),
                        blueprint_version=str(state.get("blueprint_version", "2.0.0")),
                        target_exam=state.get("target_exam"),
                        state=state,
                    )
                    self.db.add(record)
                else:
                    record.status = str(state.get("status", record.status))
                    record.state = state
                await self.db.flush()
                return
            except Exception:
                logger.warning("DB save_session failed; using JSON store", exc_info=True)

        await json_store().save_session(state)

    async def get_session(self, session_id: str) -> Optional[dict[str, Any]]:
        if self.use_db:
            try:
                result = await self.db.execute(
                    select(PlacementSessionRecord).where(
                        PlacementSessionRecord.id == UUID(str(session_id))
                    )
                )
                record = result.scalar_one_or_none()
                if record is not None:
                    return dict(record.state or {})
            except Exception:
                logger.warning("DB get_session failed; using JSON store", exc_info=True)
        return await json_store().get_session(session_id)

    async def save_response(self, state: dict[str, Any], item_id: str) -> None:
        """Mirror one graded answer into the analytics table (DB only)."""
        if not self.use_db:
            return
        response = (state.get("responses") or {}).get(str(item_id))
        if not response:
            return
        try:
            session_id = UUID(str(state["id"]))
            result = await self.db.execute(
                select(PlacementResponseRecord).where(
                    PlacementResponseRecord.session_id == session_id,
                    PlacementResponseRecord.item_id == str(item_id),
                )
            )
            record = result.scalar_one_or_none()
            if record is None:
                record = PlacementResponseRecord(
                    session_id=session_id,
                    user_id=UUID(str(state["user_id"])),
                    item_id=str(item_id),
                    skill=str(response.get("skill", "")),
                    stage=int(response.get("stage", 1)),
                )
                self.db.add(record)
            record.answer = {"value": response.get("answer", [])}
            record.is_correct = bool(response.get("is_correct"))
            record.response_time_ms = int(response.get("response_time_ms", 0))
            await self.db.flush()
        except Exception:
            logger.warning("DB save_response failed", exc_info=True)

    # ── results ───────────────────────────────────────────────

    async def save_result(self, result: dict[str, Any]) -> None:
        if self.use_db:
            try:
                session_id = UUID(str(result["session_id"]))
                existing = await self.db.execute(
                    select(PlacementResultRecord).where(
                        PlacementResultRecord.session_id == session_id
                    )
                )
                record = existing.scalar_one_or_none()
                if record is None:
                    record = PlacementResultRecord(
                        id=UUID(str(result["result_id"])),
                        session_id=session_id,
                        user_id=UUID(str(result["user_id"])),
                        mode=str(result.get("mode", "quick")),
                        target_exam=result.get("target_exam"),
                        overall_level=str((result.get("overall") or {}).get("level", "A1")),
                        overall_theta=float((result.get("overall") or {}).get("theta", 0.0)),
                        overall_se=float((result.get("overall") or {}).get("se", 0.5)),
                        payload=result,
                        blueprint_version=str(result.get("blueprint_version", "2.0.0")),
                    )
                    self.db.add(record)
                else:
                    record.payload = result
                    record.overall_level = str((result.get("overall") or {}).get("level", "A1"))
                    record.overall_theta = float((result.get("overall") or {}).get("theta", 0.0))
                    record.overall_se = float((result.get("overall") or {}).get("se", 0.5))
                await self.db.flush()
                return
            except Exception:
                logger.warning("DB save_result failed; using JSON store", exc_info=True)
        await json_store().save_result(result)

    async def get_result(self, result_id: str) -> Optional[dict[str, Any]]:
        if self.use_db:
            try:
                result = await self.db.execute(
                    select(PlacementResultRecord).where(
                        PlacementResultRecord.id == UUID(str(result_id))
                    )
                )
                record = result.scalar_one_or_none()
                if record is not None:
                    return dict(record.payload or {})
            except Exception:
                logger.warning("DB get_result failed; using JSON store", exc_info=True)
        return await json_store().get_result(result_id)

    async def get_result_by_session(self, session_id: str) -> Optional[dict[str, Any]]:
        if self.use_db:
            try:
                result = await self.db.execute(
                    select(PlacementResultRecord).where(
                        PlacementResultRecord.session_id == UUID(str(session_id))
                    )
                )
                record = result.scalar_one_or_none()
                if record is not None:
                    return dict(record.payload or {})
            except Exception:
                logger.warning("DB get_result_by_session failed", exc_info=True)
        return await json_store().get_result_by_session(session_id)

    async def latest_result(self, user_id: str) -> Optional[dict[str, Any]]:
        if self.use_db:
            try:
                result = await self.db.execute(
                    select(PlacementResultRecord)
                    .where(PlacementResultRecord.user_id == UUID(str(user_id)))
                    .order_by(PlacementResultRecord.created_at.desc())
                    .limit(1)
                )
                record = result.scalar_one_or_none()
                if record is not None:
                    return dict(record.payload or {})
            except Exception:
                logger.warning("DB latest_result failed; using JSON store", exc_info=True)
        return await json_store().latest_result(user_id)

    async def list_results(self, user_id: str, limit: int = 20) -> list[dict[str, Any]]:
        if self.use_db:
            try:
                result = await self.db.execute(
                    select(PlacementResultRecord)
                    .where(PlacementResultRecord.user_id == UUID(str(user_id)))
                    .order_by(PlacementResultRecord.created_at.desc())
                    .limit(limit)
                )
                records = result.scalars().all()
                return [dict(record.payload or {}) for record in records]
            except Exception:
                logger.warning("DB list_results failed; using JSON store", exc_info=True)
        return await json_store().list_results(user_id, limit)
