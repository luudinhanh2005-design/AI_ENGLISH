"""Orchestration for the CEFR multi-stage adaptive placement test."""

from __future__ import annotations

import asyncio
import json
import logging
import random
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional
from uuid import UUID

from sqlalchemy import inspect as sa_inspect, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.user import User, UserProfile
from .placement_ai import PlacementAIService
from .placement_engine import (
    CEFR_LEVELS,
    PlacementBank,
    estimate_theta,
    exam_equivalents,
    grade_item,
    level_from_theta,
    level_index,
    level_range,
    rubric_to_theta,
    weighted_overall,
)
from .placement_store import PlacementRepository

logger = logging.getLogger(__name__)


class PlacementError(Exception):
    """Base class for placement business errors."""


class PlacementNotFound(PlacementError):
    pass


class PlacementAccessDenied(PlacementError):
    pass


class PlacementStateError(PlacementError):
    pass


_bank: Optional[PlacementBank] = None


def get_bank() -> PlacementBank:
    global _bank
    if _bank is None:
        _bank = PlacementBank()
    return _bank


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat()


def _parse_dt(value: Any) -> Optional[datetime]:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed
    except Exception:
        return None


def _new_id() -> str:
    return str(uuid.uuid4())


def _answer_list(answer: Any) -> list[str]:
    if answer is None:
        return []
    if isinstance(answer, (list, tuple, set)):
        return [str(item) for item in answer if str(item).strip()]
    return [str(answer)] if str(answer).strip() else []


def _mode_config(mode: str) -> dict[str, Any]:
    try:
        return get_bank().mode(mode)
    except ValueError as exc:
        raise PlacementStateError(str(exc)) from exc


def _result_summary(result: dict[str, Any]) -> dict[str, Any]:
    overall = result.get("overall") or {}
    return {
        "result_id": result.get("result_id"),
        "session_id": result.get("session_id"),
        "mode": result.get("mode", "quick"),
        "target_exam": result.get("target_exam", "general"),
        "overall_level": overall.get("level", "A1"),
        "overall_theta": overall.get("theta", 0.0),
        "overall_se": overall.get("se", 0.5),
        "completed_at": result.get("completed_at", ""),
    }


# ──────────────────────────────────────────────
# Session creation / stage management
# ──────────────────────────────────────────────


async def _ensure_audio(item: dict[str, Any]) -> None:
    """Generate a stable placement audio file on demand (best effort)."""
    if item.get("skill") != "listening" or not item.get("transcript"):
        return
    target_name = f"placement_{item['id']}.mp3"
    try:
        from .speech_service import AUDIO_DIR, SpeechAIService

        target = AUDIO_DIR / target_name
        if target.exists() and target.stat().st_size > 800:
            item["audio_url"] = f"/api/v1/speech/audio/{target_name}"
            return
        generated = await SpeechAIService.text_to_speech(
            str(item["transcript"]), voice="en-US-Standard-C", speed=0.98
        )
        filename = generated.get("filename")
        if filename:
            source = AUDIO_DIR / filename
            if source.exists():
                source.replace(target)
                item["audio_url"] = f"/api/v1/speech/audio/{target_name}"
    except Exception:
        logger.warning("Could not prepare audio for %s", item.get("id"), exc_info=True)


async def _prepare_listening_audio(items: list[dict[str, Any]]) -> None:
    listening = [item for item in items if item.get("skill") == "listening"]
    if listening:
        await asyncio.gather(*(_ensure_audio(item) for item in listening))


async def _start_receptive_stage(
    state: dict[str, Any],
    skill: str,
    stage: int,
    theta: float,
) -> None:
    bank = get_bank()
    config = _mode_config(state["mode"])
    count = int(config.get("items_per_stage", 4))
    items = bank.select_stage(
        skill,
        stage,
        theta,
        exclude_ids=state.get("served_item_ids", []),
        count=count,
        rng=random.Random(),
    )
    if not items:
        raise PlacementStateError(f"Ngân hàng câu hỏi cho kỹ năng {skill} chưa đủ.")

    await _prepare_listening_audio(items)

    now = _now()
    item_ids = [str(item["id"]) for item in items]
    for item_id in item_ids:
        if item_id not in state.setdefault("served_item_ids", []):
            state["served_item_ids"].append(item_id)

    total_item_seconds = sum(int(item.get("time_seconds") or 60) for item in items)
    limit = max(int(bank.stage_time(skill)), total_item_seconds + 90)
    state["current"] = {
        "section": "receptive",
        "skill": skill,
        "stage": stage,
        "stage_count": int(config.get("stages", 3)),
        "item_ids": item_ids,
        "task_ids": [],
        "stage_token": _new_id(),
        "stage_started_at": _iso(now),
        "stage_expires_at": _iso(now + timedelta(seconds=limit)),
        "time_limit_seconds": limit,
    }


def _start_writing(state: dict[str, Any], theta: float) -> None:
    bank = get_bank()
    config = _mode_config(state["mode"])
    count = int(config.get("writing_tasks", 0))
    if count <= 0:
        return
    tasks = bank.select_writing_tasks(
        theta,
        count,
        exclude_ids=state.get("served_writing_ids", []),
        rng=random.Random(),
    )
    if not tasks:
        return
    now = _now()
    task_ids = [str(task["id"]) for task in tasks]
    state.setdefault("served_writing_ids", []).extend(task_ids)
    total_seconds = sum(int(task.get("time_minutes") or 30) * 60 for task in tasks)
    state["current"] = {
        "section": "writing",
        "skill": "writing",
        "stage": 1,
        "stage_count": 1,
        "item_ids": [],
        "task_ids": task_ids,
        "stage_token": _new_id(),
        "stage_started_at": _iso(now),
        "stage_expires_at": _iso(now + timedelta(seconds=total_seconds + 120)),
        "time_limit_seconds": total_seconds + 120,
    }


def _start_speaking(state: dict[str, Any], theta: float) -> None:
    bank = get_bank()
    config = _mode_config(state["mode"])
    count = int(config.get("speaking_tasks", 0))
    if count <= 0:
        return
    tasks = bank.select_speaking_tasks(
        theta,
        count,
        exclude_ids=state.get("served_speaking_ids", []),
        rng=random.Random(),
    )
    if not tasks:
        return
    now = _now()
    task_ids = [str(task["id"]) for task in tasks]
    state.setdefault("served_speaking_ids", []).extend(task_ids)
    total_seconds = sum(
        int(task.get("prep_seconds") or 20) + int(task.get("response_seconds") or 60)
        for task in tasks
    )
    state["current"] = {
        "section": "speaking",
        "skill": "speaking",
        "stage": 1,
        "stage_count": 1,
        "item_ids": [],
        "task_ids": task_ids,
        "stage_token": _new_id(),
        "stage_started_at": _iso(now),
        "stage_expires_at": _iso(now + timedelta(seconds=total_seconds + 180)),
        "time_limit_seconds": total_seconds + 180,
    }


def _receptive_overall(state: dict[str, Any]) -> tuple[float, float]:
    abilities = state.get("skill_abilities") or {}
    return weighted_overall(abilities, get_bank().weights)


def _enter_after_receptive(state: dict[str, Any]) -> None:
    config = _mode_config(state["mode"])
    theta, _ = _receptive_overall(state)
    if int(config.get("writing_tasks", 0)) > 0:
        _start_writing(state, theta)
        return
    if int(config.get("speaking_tasks", 0)) > 0:
        _start_speaking(state, theta)
        return
    state["current"] = {
        "section": "done",
        "skill": "",
        "stage": 0,
        "stage_count": 0,
        "item_ids": [],
        "task_ids": [],
        "stage_token": "",
        "stage_started_at": None,
        "stage_expires_at": None,
        "time_limit_seconds": 0,
    }


def _record_answer(
    state: dict[str, Any],
    item_id: str,
    answer: Any,
    response_time_ms: int = 0,
) -> dict[str, Any]:
    bank = get_bank()
    current = state.get("current") or {}
    if current.get("section") != "receptive":
        raise PlacementStateError("Phiên đang không ở phần câu hỏi trắc nghiệm.")
    item_ids = list(current.get("item_ids") or [])
    if str(item_id) not in item_ids:
        raise PlacementStateError("Câu hỏi không thuộc chặng hiện tại.")
    item = bank.get_item(str(item_id))
    if item is None:
        raise PlacementStateError("Không tìm thấy câu hỏi.")

    responses = state.setdefault("responses", {})
    previous = responses.get(str(item_id))
    answer_values = _answer_list(answer)
    response = {
        "item_id": str(item_id),
        "skill": str(item.get("skill")),
        "stage": int(current.get("stage", 1)),
        "level": str(item.get("level")),
        "answer": answer_values,
        "is_correct": grade_item(item, answer_values),
        "response_time_ms": max(0, int(response_time_ms or 0)),
        "b": float(item.get("difficulty_b", 0.0)),
        "a": float(item.get("discrimination_a", 1.0)),
        "c": float(item.get("guessing_c", 0.0)),
        "answered_at": _iso(_now()),
        "skipped": not bool(answer_values),
    }
    if previous and previous.get("answered_at"):
        response["answered_at"] = previous["answered_at"]
    responses[str(item_id)] = response
    return response


def _skill_estimate(state: dict[str, Any], skill: str) -> dict[str, Any]:
    responses = [
        response
        for response in (state.get("responses") or {}).values()
        if response.get("skill") == skill
    ]
    estimation_input = [
        {
            "b": float(response.get("b", 0.0)),
            "a": float(response.get("a", 1.0)),
            "c": float(response.get("c", 0.0)),
            "correct": bool(response.get("is_correct")),
        }
        for response in responses
    ]
    estimate = estimate_theta(estimation_input)
    correct = sum(1 for response in responses if response.get("is_correct"))
    return {
        "theta": estimate.theta,
        "se": estimate.se,
        "answered": len(responses),
        "correct": correct,
        "percent": round(correct / len(responses) * 100, 1) if responses else 0.0,
    }


def _productive_estimate(
    state: dict[str, Any],
    skill: str,
) -> Optional[dict[str, Any]]:
    key = "writing_scores" if skill == "writing" else "speaking_scores"
    scores = state.get(key) or {}
    if not scores:
        return None
    criteria_keys = (
        ("task_achievement", "coherence_cohesion", "lexical_resource", "grammar_accuracy")
        if skill == "writing"
        else (
            "pronunciation",
            "fluency_coherence",
            "lexical_resource",
            "grammar_range",
            "task_response",
        )
    )
    aggregate: dict[str, list[float]] = {key: [] for key in criteria_keys}
    for score in scores.values():
        criteria = score.get("criteria") or {}
        for criterion in criteria_keys:
            try:
                aggregate[criterion].append(float(criteria.get(criterion, 0.0)))
            except Exception:
                aggregate[criterion].append(0.0)
    averaged = {
        criterion: round(sum(values) / max(len(values), 1), 2)
        for criterion, values in aggregate.items()
    }
    theta, se = rubric_to_theta(averaged)
    return {
        "theta": theta,
        "se": se,
        "criteria": averaged,
        "average": round(sum(averaged.values()) / len(averaged), 2),
        "answered": len(scores),
    }


# ──────────────────────────────────────────────
# Public payloads
# ──────────────────────────────────────────────


def _public_session(state: dict[str, Any]) -> dict[str, Any]:
    bank = get_bank()
    current = state.get("current") or {}
    section = current.get("section", "done")
    config = _mode_config(state.get("mode", "quick"))
    now = _now()
    expires = _parse_dt(current.get("stage_expires_at"))
    remaining = max(0, int((expires - now).total_seconds())) if expires else 0

    current_payload: dict[str, Any] = {
        "section": section,
        "skill": current.get("skill", ""),
        "stage": current.get("stage", 0),
        "stage_count": current.get("stage_count", 0),
        "stage_token": current.get("stage_token", ""),
        "started_at": current.get("stage_started_at"),
        "expires_at": current.get("stage_expires_at"),
        "time_limit_seconds": current.get("time_limit_seconds", 0),
        "time_remaining_seconds": remaining,
        "items": [],
        "tasks": [],
        "answers": {},
        "submitted_task_ids": [],
    }

    responses = state.get("responses") or {}
    if section == "receptive":
        item_ids = current.get("item_ids") or []
        current_payload["items"] = [
            bank.sanitize_item(item)
            for item in (bank.get_item(item_id) for item_id in item_ids)
            if item is not None
        ]
        current_payload["answers"] = {
            item_id: responses[item_id].get("answer", [])
            for item_id in item_ids
            if item_id in responses
        }
    elif section == "writing":
        task_ids = current.get("task_ids") or []
        current_payload["tasks"] = [
            bank.sanitize_writing_task(task)
            for task in (bank.get_task(task_id) for task_id in task_ids)
            if task is not None
        ]
        current_payload["submitted_task_ids"] = list(
            (state.get("writing_scores") or {}).keys()
        )
        current_payload["drafts"] = {
            task_id: submission.get("text", "")
            for task_id, submission in (state.get("writing_submissions") or {}).items()
        }
    elif section == "speaking":
        task_ids = current.get("task_ids") or []
        current_payload["tasks"] = [
            bank.sanitize_speaking_task(task)
            for task in (bank.get_task(task_id) for task_id in task_ids)
            if task is not None
        ]
        current_payload["submitted_task_ids"] = list(
            (state.get("speaking_scores") or {}).keys()
        )

    expected_items = len(config.get("skills", [])) * int(config.get("stages", 0)) * int(
        config.get("items_per_stage", 0)
    )
    answered = len(responses)
    skill_progress = {}
    for skill in config.get("skills", []):
        ability = (state.get("skill_abilities") or {}).get(skill)
        skill_progress[skill] = {
            "completed": skill in (state.get("completed_skills") or []),
            "theta": round(float(ability["theta"]), 3) if ability else None,
            "se": round(float(ability["se"]), 3) if ability else None,
        }
    if int(config.get("writing_tasks", 0)) > 0:
        skill_progress["writing"] = {
            "completed": len((state.get("writing_scores") or {}))
            >= int(config.get("writing_tasks", 0)),
        }
    if int(config.get("speaking_tasks", 0)) > 0:
        skill_progress["speaking"] = {
            "completed": len((state.get("speaking_scores") or {}))
            >= int(config.get("speaking_tasks", 0)),
        }

    result = None
    if str(state.get("status")) == "completed":
        result = state.get("result_payload")

    return {
        "session_id": str(state.get("id")),
        "mode": str(state.get("mode", "quick")),
        "target_exam": str(state.get("target_exam", "general")),
        "status": str(state.get("status", "in_progress")),
        "blueprint_version": str(state.get("blueprint_version", "2.0.0")),
        "current": current_payload,
        "progress": {
            "answered": answered,
            "expected_items": expected_items,
            "percent": round(answered / expected_items * 100, 1)
            if expected_items
            else 0.0,
            "completed_skills": list(state.get("completed_skills") or []),
            "skills": skill_progress,
        },
        "completed": result is not None,
        "result": result,
        "server_time": _iso(now),
    }


def _progress_consistency(skill_levels: dict[str, str]) -> str:
    indices = [level_index(level) for level in skill_levels.values()]
    if not indices:
        return "unknown"
    return "consistent" if max(indices) - min(indices) <= 1 else "uneven"


def _build_result_payload(
    state: dict[str, Any],
    result_id: str,
) -> dict[str, Any]:
    bank = get_bank()
    config = _mode_config(state.get("mode", "quick"))
    now = _now()
    weights = bank.weights
    skill_order = list(config.get("skills", []))
    if int(config.get("writing_tasks", 0)) > 0:
        skill_order.append("writing")
    if int(config.get("speaking_tasks", 0)) > 0:
        skill_order.append("speaking")

    estimates: dict[str, dict[str, Any]] = {}
    for skill in ("listening", "reading", "use_of_english"):
        if skill in config.get("skills", []):
            estimates[skill] = _skill_estimate(state, skill)
    for skill in ("writing", "speaking"):
        if skill in skill_order:
            productive = _productive_estimate(state, skill)
            if productive is not None:
                estimates[skill] = productive

    overall_theta, overall_se = weighted_overall(estimates, weights)
    overall_level = level_from_theta(overall_theta, bank.cut_scores)
    low, high = level_range(overall_theta, overall_se, bank.cut_scores)

    skills_payload: dict[str, Any] = {}
    for skill in skill_order:
        estimate = estimates.get(skill)
        if estimate is None:
            continue
        skill_level = level_from_theta(float(estimate["theta"]), bank.cut_scores)
        skill_low, skill_high = level_range(
            float(estimate["theta"]), float(estimate.get("se", 0.5)), bank.cut_scores
        )
        base = {
            "label": bank.manifest.get("skill_labels", {}).get(skill, skill),
            "level": skill_level,
            "theta": round(float(estimate["theta"]), 3),
            "se": round(float(estimate.get("se", 0.5)), 3),
            "level_range": [skill_low, skill_high],
            "weight": float(weights.get(skill, 0.0)),
            "can_do": bank.can_do_for(skill_level, skill),
        }
        if skill in ("writing", "speaking"):
            scores = state.get(
                "writing_scores" if skill == "writing" else "speaking_scores", {}
            )
            base.update(
                {
                    "type": "productive",
                    "rubric_average": estimate.get("average", 0.0),
                    "criteria": estimate.get("criteria", {}),
                    "tasks": [
                        {
                            "task_id": task_id,
                            "level": score.get("cefr") or score.get("level"),
                            "criteria": score.get("criteria", {}),
                            "average": score.get("average", 0.0),
                            "feedback": score.get("feedback", ""),
                            "strengths": score.get("strengths", []),
                            "improvements": score.get("improvements", []),
                            "word_count": score.get("word_count", 0),
                            "transcript": score.get("transcript"),
                            "pronunciation_score": score.get("pronunciation_score"),
                            "engine": score.get("engine", "ai"),
                        }
                        for task_id, score in scores.items()
                    ],
                }
            )
        else:
            base.update(
                {
                    "type": "receptive",
                    "correct": estimate.get("correct", 0),
                    "total": estimate.get("answered", 0),
                    "percent": estimate.get("percent", 0.0),
                }
            )
        skills_payload[skill] = base

    ranked = sorted(
        (
            (skill, float(estimate["theta"]))
            for skill, estimate in estimates.items()
        ),
        key=lambda item: item[1],
        reverse=True,
    )
    strengths = [
        {
            "skill": skill,
            "label": bank.manifest.get("skill_labels", {}).get(skill, skill),
            "level": level_from_theta(theta, bank.cut_scores),
            "note": "Điểm mạnh nổi bật của bạn.",
        }
        for skill, theta in ranked[:2]
        if theta >= overall_theta - 0.15 or len(ranked) <= 2
    ]
    weaknesses = [
        {
            "skill": skill,
            "label": bank.manifest.get("skill_labels", {}).get(skill, skill),
            "level": level_from_theta(theta, bank.cut_scores),
            "note": "Cần ưu tiên luyện tập trong 4 tuần tới.",
        }
        for skill, theta in reversed(ranked[-2:])
        if theta < overall_theta + 0.15
    ]
    if not strengths:
        strengths = [
            {
                "skill": skill,
                "label": bank.manifest.get("skill_labels", {}).get(skill, skill),
                "level": level_from_theta(theta, bank.cut_scores),
                "note": "Kỹ năng tương đối ổn định.",
            }
            for skill, theta in ranked[:1]
        ]
    if not weaknesses:
        weakest = ranked[-1] if ranked else None
        if weakest:
            weaknesses = [
                {
                    "skill": weakest[0],
                    "label": bank.manifest.get("skill_labels", {}).get(
                        weakest[0], weakest[0]
                    ),
                    "level": level_from_theta(weakest[1], bank.cut_scores),
                    "note": "Kỹ năng thấp nhất; nên duy trì luyện tập đều.",
                }
            ]

    confidence = (
        "high" if overall_se < 0.45 else "medium" if overall_se < 0.7 else "low"
    )
    confidence_vi = {
        "high": "Cao",
        "medium": "Trung bình",
        "low": "Cần thêm dữ liệu",
    }[confidence]
    exam_map = bank.manifest.get("exam_mapping", {})
    equivalents = exam_equivalents(overall_level, exam_map)
    target_exam = str(state.get("target_exam") or "general").lower()
    target_reference = ""
    if target_exam in equivalents:
        target_reference = f" Quy đổi tham khảo cho {target_exam.upper()}: {equivalents[target_exam]}."

    recommendation = (
        f"Bạn đang ở trình độ {overall_level} (khoảng {low}–{high} trên thang CEFR). "
        f"Điểm mạnh: {', '.join(item['label'] for item in strengths)}. "
        f"Cần cải thiện: {', '.join(item['label'] for item in weaknesses)}. "
        f"Độ tin cậy của kết quả: {confidence_vi}.{target_reference}"
    )

    roadmap = []
    routes = {
        "listening": "/listening",
        "reading": "/reading",
        "use_of_english": "/grammar",
        "writing": "/writing-practice",
        "speaking": "/pronunciation",
    }
    weak_skills = {item["skill"] for item in weaknesses}
    for skill in skill_order:
        if skill not in skills_payload:
            continue
        skill_data = skills_payload[skill]
        roadmap.append(
            {
                "skill": skill,
                "label": skill_data["label"],
                "level": skill_data["level"],
                "priority": "high" if skill in weak_skills else "maintain",
                "action": (
                    "Luyện tập trọng tâm 20–30 phút/ngày với phản hồi tức thì."
                    if skill in weak_skills
                    else "Duy trì 2–3 buổi/tuần để giữ tiến độ."
                ),
                "route": routes.get(skill, "/learn"),
            }
        )

    review: list[dict[str, Any]] = []
    for item_id in state.get("served_item_ids", []):
        response = (state.get("responses") or {}).get(item_id)
        if not response:
            continue
        item = bank.get_item(item_id)
        if not item:
            continue
        review.append(
            {
                "item_id": item_id,
                "skill": response.get("skill"),
                "level": response.get("level"),
                "stem": item.get("stem", ""),
                "selected": response.get("answer", []),
                "correct": item.get("answer", []),
                "is_correct": bool(response.get("is_correct")),
                "explanation_vi": item.get("explanation_vi", ""),
            }
        )

    xp_map = {"quick": 80, "standard": 120, "full": 180}
    xp_awarded = xp_map.get(str(state.get("mode")), 80)

    return {
        "result_id": result_id,
        "session_id": str(state.get("id")),
        "user_id": str(state.get("user_id")),
        "mode": str(state.get("mode", "quick")),
        "target_exam": target_exam,
        "blueprint_version": str(state.get("blueprint_version", "2.0.0")),
        "completed_at": _iso(now),
        "overall": {
            "level": overall_level,
            "theta": round(overall_theta, 3),
            "se": round(overall_se, 3),
            "level_range": [low, high],
            "confidence": confidence,
            "confidence_vi": confidence_vi,
            "level_label": bank.manifest.get("level_labels", {}).get(overall_level, ""),
            "description_vi": bank.manifest.get("level_descriptions_vi", {}).get(
                overall_level, ""
            ),
        },
        "skills": skills_payload,
        "strengths": strengths,
        "weaknesses": weaknesses,
        "profile_consistency": _progress_consistency(
            {skill: data["level"] for skill, data in skills_payload.items()}
        ),
        "recommendation": recommendation,
        "roadmap": roadmap,
        "exam_equivalents": equivalents,
        "can_do": {
            skill: bank.can_do_for(overall_level, skill)
            for skill in (
                "listening",
                "reading",
                "use_of_english",
                "writing",
                "speaking",
            )
        },
        "review": review,
        "xp_awarded": xp_awarded,
    }


async def _persist_profile(
    db: Optional[AsyncSession],
    user: Optional[User],
    result: dict[str, Any],
) -> None:
    if user is None:
        return
    overall = result.get("overall") or {}
    level = str(overall.get("level", "A1"))
    user.current_level = level
    user.has_completed_onboarding = True

    try:
        inspected = sa_inspect(user)
    except Exception:
        inspected = None
    attached_to_db = inspected is not None and inspected.session is not None

    if db is not None and attached_to_db:
        try:
            profile_result = await db.execute(
                select(UserProfile).where(UserProfile.user_id == user.id)
            )
            profile = profile_result.scalar_one_or_none()
            if profile is None:
                profile = UserProfile(user_id=user.id)
                db.add(profile)
            profile.skill_scores = {
                skill: {
                    "level": data.get("level"),
                    "theta": data.get("theta"),
                    "se": data.get("se"),
                    "percent": data.get("percent", data.get("rubric_average", 0) * 20),
                }
                for skill, data in (result.get("skills") or {}).items()
            }
            profile.weaknesses = [
                f"Cần cải thiện {item.get('label')} (trình độ {item.get('level')})"
                for item in (result.get("weaknesses") or [])
            ]
            profile.last_placement_at = _now()
            await db.flush()
        except Exception:
            logger.warning("Could not persist placement profile", exc_info=True)

    try:
        state = sa_inspect(user)
    except Exception:
        state = None
    if state is None or state.session is None:
        try:
            from ..api.deps import save_memory_users

            save_memory_users()
        except Exception:
            logger.warning("Could not persist offline placement profile", exc_info=True)


# ──────────────────────────────────────────────
# Public service API
# ──────────────────────────────────────────────


async def create_session(
    db: Optional[AsyncSession],
    user: User,
    mode: str = "quick",
    target_exam: str = "general",
) -> dict[str, Any]:
    config = _mode_config(mode)
    skill_order = list(config.get("skills") or ["listening", "reading", "use_of_english"])
    if not skill_order:
        raise PlacementStateError("Mode này chưa có kỹ năng nào.")

    state: dict[str, Any] = {
        "id": _new_id(),
        "user_id": str(user.id),
        "mode": mode,
        "target_exam": target_exam,
        "status": "in_progress",
        "blueprint_version": get_bank().manifest.get("version", "2.0.0"),
        "created_at": _iso(_now()),
        "updated_at": _iso(_now()),
        "expires_at": _iso(_now() + timedelta(minutes=120)),
        "served_item_ids": [],
        "served_writing_ids": [],
        "served_speaking_ids": [],
        "responses": {},
        "skill_abilities": {},
        "completed_skills": [],
        "writing_scores": {},
        "writing_submissions": {},
        "speaking_scores": {},
        "current": {},
        "integrity": {"flags": []},
    }
    await _start_receptive_stage(state, skill_order[0], 1, theta=0.0)
    state["updated_at"] = _iso(_now())
    await PlacementRepository(db).save_session(state)
    return _public_session(state)


async def get_session(
    db: Optional[AsyncSession],
    session_id: str,
    user_id: str,
) -> dict[str, Any]:
    state = await PlacementRepository(db).get_session(session_id)
    if state is None:
        raise PlacementNotFound("Không tìm thấy phiên kiểm tra.")
    if str(state.get("user_id")) != str(user_id):
        raise PlacementAccessDenied("Bạn không có quyền xem phiên này.")
    if state.get("status") == "completed" and not state.get("result_payload"):
        stored = await PlacementRepository(db).get_result_by_session(session_id)
        if stored:
            state["result_payload"] = stored
    return _public_session(state)


async def save_answer(
    db: Optional[AsyncSession],
    session_id: str,
    user_id: str,
    item_id: str,
    answer: Any,
    response_time_ms: int = 0,
    flagged: bool = False,
) -> dict[str, Any]:
    repo = PlacementRepository(db)
    state = await repo.get_session(session_id)
    if state is None:
        raise PlacementNotFound("Không tìm thấy phiên kiểm tra.")
    if str(state.get("user_id")) != str(user_id):
        raise PlacementAccessDenied("Bạn không có quyền sửa phiên này.")
    if state.get("status") != "in_progress":
        raise PlacementStateError("Phiên kiểm tra đã kết thúc.")

    duplicate = str(item_id) in (state.get("responses") or {})
    _record_answer(state, item_id, answer, response_time_ms)
    if flagged:
        flags = state.setdefault("integrity", {}).setdefault("flags", [])
        if item_id not in flags:
            flags.append(str(item_id))
    state["updated_at"] = _iso(_now())
    await repo.save_response(state, item_id)
    await repo.save_session(state)

    current = state.get("current") or {}
    item_ids = list(current.get("item_ids") or [])
    answered = sum(1 for value in item_ids if value in (state.get("responses") or {}))
    return {
        "saved": True,
        "answered": answered,
        "total": len(item_ids),
        "stage_complete": answered >= len(item_ids),
        "duplicate": duplicate,
    }


async def complete_stage(
    db: Optional[AsyncSession],
    session_id: str,
    user_id: str,
    answers: Optional[list[dict[str, Any]]] = None,
    stage_token: Optional[str] = None,
) -> dict[str, Any]:
    repo = PlacementRepository(db)
    state = await repo.get_session(session_id)
    if state is None:
        raise PlacementNotFound("Không tìm thấy phiên kiểm tra.")
    if str(state.get("user_id")) != str(user_id):
        raise PlacementAccessDenied("Bạn không có quyền sửa phiên này.")
    if state.get("status") != "in_progress":
        raise PlacementStateError("Phiên kiểm tra đã kết thúc.")

    current = state.get("current") or {}
    if current.get("section") != "receptive":
        return _public_session(state)
    if stage_token and stage_token != current.get("stage_token"):
        raise PlacementStateError(
            "Chặng đã chuyển. Hãy tải lại phiên để tiếp tục đúng chặng."
        )

    for item in answers or []:
        if not isinstance(item, dict):
            continue
        item_id = str(item.get("item_id") or "")
        if item_id and item_id in (current.get("item_ids") or []):
            _record_answer(
                state,
                item_id,
                item.get("answer", []),
                int(item.get("response_time_ms") or 0),
            )

    # Unanswered items count as incorrect, but are still recorded for review.
    for item_id in current.get("item_ids") or []:
        if item_id not in (state.get("responses") or {}):
            _record_answer(state, item_id, [], 0)

    skill = str(current.get("skill") or "")
    estimate = _skill_estimate(state, skill)
    state.setdefault("skill_abilities", {})[skill] = estimate
    stage = int(current.get("stage", 1))
    stage_count = int(current.get("stage_count", 1))

    if stage < stage_count:
        await _start_receptive_stage(state, skill, stage + 1, estimate["theta"])
    else:
        if skill not in (state.setdefault("completed_skills", [])):
            state["completed_skills"].append(skill)
        config = _mode_config(state["mode"])
        skill_order = list(config.get("skills") or [])
        next_skill = next(
            (candidate for candidate in skill_order if candidate not in state["completed_skills"]),
            None,
        )
        if next_skill:
            await _start_receptive_stage(state, next_skill, 1, theta=0.0)
        else:
            _enter_after_receptive(state)
            if (state.get("current") or {}).get("section") == "done":
                return await _finalize(db, state, user_id)

    state["updated_at"] = _iso(_now())
    await repo.save_session(state)
    return _public_session(state)


async def submit_writing(
    db: Optional[AsyncSession],
    session_id: str,
    user_id: str,
    task_id: str,
    text: str,
    response_time_ms: int = 0,
) -> dict[str, Any]:
    repo = PlacementRepository(db)
    state = await repo.get_session(session_id)
    if state is None:
        raise PlacementNotFound("Không tìm thấy phiên kiểm tra.")
    if str(state.get("user_id")) != str(user_id):
        raise PlacementAccessDenied("Bạn không có quyền sửa phiên này.")
    current = state.get("current") or {}
    if current.get("section") != "writing":
        raise PlacementStateError("Phiên đang không ở phần viết.")
    task_ids = list(current.get("task_ids") or [])
    if str(task_id) not in task_ids:
        raise PlacementStateError("Đề bài không thuộc phần viết hiện tại.")

    task = get_bank().get_task(str(task_id))
    if task is None:
        raise PlacementStateError("Không tìm thấy đề viết.")

    user_level = level_from_theta(
        float((state.get("skill_abilities") or {}).get("reading", {}).get("theta", 0.0)),
        get_bank().cut_scores,
    )
    score = await PlacementAIService.evaluate_writing(task, text, user_level)
    state.setdefault("writing_scores", {})[str(task_id)] = score
    state.setdefault("writing_submissions", {})[str(task_id)] = {
        "text": text,
        "word_count": score.get("word_count", 0),
        "response_time_ms": max(0, int(response_time_ms or 0)),
        "submitted_at": _iso(_now()),
    }

    if len(state["writing_scores"]) >= len(task_ids):
        speaking_count = int(_mode_config(state["mode"]).get("speaking_tasks", 0))
        if speaking_count > 0:
            writing_estimate = _productive_estimate(state, "writing")
            theta = (
                float(writing_estimate["theta"])
                if writing_estimate
                else float((state.get("skill_abilities") or {}).get("reading", {}).get("theta", 0.0))
            )
            _start_speaking(state, theta)
        else:
            return await _finalize(db, state, user_id)

    state["updated_at"] = _iso(_now())
    await repo.save_session(state)
    return _public_session(state)


async def submit_speaking(
    db: Optional[AsyncSession],
    session_id: str,
    user_id: str,
    task_id: str,
    audio_data: bytes,
    filename: str = "answer.webm",
    content_type: str = "audio/webm",
) -> dict[str, Any]:
    repo = PlacementRepository(db)
    state = await repo.get_session(session_id)
    if state is None:
        raise PlacementNotFound("Không tìm thấy phiên kiểm tra.")
    if str(state.get("user_id")) != str(user_id):
        raise PlacementAccessDenied("Bạn không có quyền sửa phiên này.")
    current = state.get("current") or {}
    if current.get("section") != "speaking":
        raise PlacementStateError("Phiên đang không ở phần nói.")
    task_ids = list(current.get("task_ids") or [])
    if str(task_id) not in task_ids:
        raise PlacementStateError("Nhiệm vụ không thuộc phần nói hiện tại.")

    task = get_bank().get_task(str(task_id))
    if task is None:
        raise PlacementStateError("Không tìm thấy nhiệm vụ nói.")

    user_level = level_from_theta(
        float((state.get("skill_abilities") or {}).get("reading", {}).get("theta", 0.0)),
        get_bank().cut_scores,
    )
    score = await PlacementAIService.evaluate_speaking(
        task,
        audio_data,
        filename=filename,
        content_type=content_type,
        user_level=user_level,
    )
    state.setdefault("speaking_scores", {})[str(task_id)] = score

    if len(state["speaking_scores"]) >= len(task_ids):
        return await _finalize(db, state, user_id)

    state["updated_at"] = _iso(_now())
    await repo.save_session(state)
    return _public_session(state)


async def skip_speaking(
    db: Optional[AsyncSession],
    session_id: str,
    user_id: str,
    task_id: str,
) -> dict[str, Any]:
    repo = PlacementRepository(db)
    state = await repo.get_session(session_id)
    if state is None:
        raise PlacementNotFound("Không tìm thấy phiên kiểm tra.")
    if str(state.get("user_id")) != str(user_id):
        raise PlacementAccessDenied("Bạn không có quyền sửa phiên này.")
    current = state.get("current") or {}
    if current.get("section") != "speaking":
        raise PlacementStateError("Phiên đang không ở phần nói.")
    task_ids = list(current.get("task_ids") or [])
    if str(task_id) not in task_ids:
        raise PlacementStateError("Nhiệm vụ không thuộc phần nói hiện tại.")

    task = get_bank().get_task(str(task_id))
    if task is None:
        raise PlacementStateError("Không tìm thấy nhiệm vụ nói.")

    state.setdefault("speaking_scores", {})[str(task_id)] = (
        PlacementAIService.skipped_speaking_result(task)
    )
    if len(state["speaking_scores"]) >= len(task_ids):
        return await _finalize(db, state, user_id)

    state["updated_at"] = _iso(_now())
    await repo.save_session(state)
    return _public_session(state)


async def _finalize(
    db: Optional[AsyncSession],
    state: dict[str, Any],
    user_id: str,
) -> dict[str, Any]:
    repo = PlacementRepository(db)
    existing = await repo.get_result_by_session(str(state.get("id")))
    if existing:
        state["status"] = "completed"
        state["result_payload"] = existing
        state["current"] = {
            "section": "done",
            "skill": "",
            "stage": 0,
            "stage_count": 0,
            "item_ids": [],
            "task_ids": [],
            "stage_token": "",
            "stage_started_at": None,
            "stage_expires_at": None,
            "time_limit_seconds": 0,
        }
        await repo.save_session(state)
        snapshot = _public_session(state)
        snapshot["_first_completion"] = False
        return snapshot

    result = _build_result_payload(state, _new_id())
    user = None
    if db is not None:
        try:
            result_user = await db.execute(select(User).where(User.id == UUID(str(user_id))))
            user = result_user.scalar_one_or_none()
        except Exception:
            user = None
    if user is None:
        try:
            from ..api.deps import MEMORY_USERS

            user = MEMORY_USERS.get(UUID(str(user_id)))
        except Exception:
            user = None

    await _persist_profile(db, user, result)

    state["status"] = "completed"
    state["completed_at"] = _iso(_now())
    state["result_id"] = result["result_id"]
    state["result_payload"] = result
    state["current"] = {
        "section": "done",
        "skill": "",
        "stage": 0,
        "stage_count": 0,
        "item_ids": [],
        "task_ids": [],
        "stage_token": "",
        "stage_started_at": None,
        "stage_expires_at": None,
        "time_limit_seconds": 0,
    }
    await repo.save_result(result)
    await repo.save_session(state)
    snapshot = _public_session(state)
    snapshot["_first_completion"] = True
    return snapshot


async def get_result(
    db: Optional[AsyncSession],
    result_id: str,
    user_id: str,
) -> dict[str, Any]:
    result = await PlacementRepository(db).get_result(result_id)
    if result is None:
        raise PlacementNotFound("Không tìm thấy kết quả.")
    if str(result.get("user_id")) != str(user_id):
        raise PlacementAccessDenied("Bạn không có quyền xem kết quả này.")
    return result


async def get_latest_result(
    db: Optional[AsyncSession],
    user_id: str,
) -> Optional[dict[str, Any]]:
    return await PlacementRepository(db).latest_result(user_id)


async def list_history(
    db: Optional[AsyncSession],
    user_id: str,
    limit: int = 20,
) -> list[dict[str, Any]]:
    results = await PlacementRepository(db).list_results(user_id, limit)
    return [_result_summary(result) for result in results]


async def abandon_session(
    db: Optional[AsyncSession],
    session_id: str,
    user_id: str,
) -> None:
    repo = PlacementRepository(db)
    state = await repo.get_session(session_id)
    if state is None:
        raise PlacementNotFound("Không tìm thấy phiên kiểm tra.")
    if str(state.get("user_id")) != str(user_id):
        raise PlacementAccessDenied("Bạn không có quyền sửa phiên này.")
    if state.get("status") == "in_progress":
        state["status"] = "abandoned"
        state["updated_at"] = _iso(_now())
        await repo.save_session(state)


def get_config() -> dict[str, Any]:
    return get_bank().public_config()
