"""Pure scoring and routing engine for the EnglishAI placement test.

The engine is deliberately framework-free so it can be unit-tested without a
database or a running FastAPI app.  It implements a compact multi-stage
adaptive test (MST) with a 3-parameter logistic item response model and EAP
ability estimation.
"""

from __future__ import annotations

import json
import math
import random
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Optional

CEFR_LEVELS: list[str] = ["A1", "A2", "B1", "B2", "C1", "C2"]
SKILLS: list[str] = [
    "listening",
    "reading",
    "use_of_english",
    "writing",
    "speaking",
]
RECEPTIVE_SKILLS: list[str] = ["listening", "reading", "use_of_english"]

LEVEL_CENTERS: dict[str, float] = {
    "A1": -2.0,
    "A2": -1.2,
    "B1": -0.4,
    "B2": 0.4,
    "C1": 1.2,
    "C2": 2.0,
}

DEFAULT_CUT_SCORES: dict[str, float] = {
    "A2": -1.5,
    "B1": -0.75,
    "B2": 0.0,
    "C1": 0.75,
    "C2": 1.5,
}

DEFAULT_WEIGHTS: dict[str, float] = {
    "listening": 0.25,
    "reading": 0.25,
    "use_of_english": 0.20,
    "writing": 0.15,
    "speaking": 0.15,
}

# Stage 1 is deliberately broad.  Later stages are routed by ability.
_STAGE1_LEVELS = ["A1", "A2", "B1", "B2"]

_ROUTE_LEVELS: dict[int, list[tuple[float, list[str]]]] = {
    2: [
        (-0.60, ["A1", "A2", "A2", "B1"]),
        (0.40, ["A2", "B1", "B1", "B2"]),
        (1.20, ["B1", "B2", "B2", "C1"]),
        (math.inf, ["B2", "C1", "C1", "C2"]),
    ],
    3: [
        (-0.80, ["A1", "A2", "A2", "B1"]),
        (-0.20, ["A2", "B1", "B1", "B2"]),
        (0.60, ["B1", "B2", "B2", "C1"]),
        (1.30, ["B2", "C1", "C1", "C2"]),
        (math.inf, ["C1", "C1", "C2", "C2"]),
    ],
}

_PUNCT_RE = re.compile(r"[^\w\s']", re.UNICODE)
_SPACE_RE = re.compile(r"\s+")


# ──────────────────────────────────────────────
# Small helpers
# ──────────────────────────────────────────────


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def normalize_text(value: Any) -> str:
    """Normalise a constructed-response answer for comparison."""
    text = str(value or "").strip().lower()
    text = _PUNCT_RE.sub(" ", text)
    text = _SPACE_RE.sub(" ", text).strip()
    # Ignore leading articles, which are rarely part of the tested meaning.
    text = re.sub(r"^(a|an|the)\s+", "", text)
    return text


def _as_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, (list, tuple, set)):
        return [str(v) for v in value if str(v).strip()]
    return [str(value)] if str(value).strip() else []


def _option_keys(item: dict[str, Any]) -> set[str]:
    return {
        str(option.get("key", "")).upper()
        for option in item.get("options", [])
        if isinstance(option, dict)
    }


def grade_item(item: dict[str, Any], answer: Any) -> bool:
    """Grade one item.  Supports option keys and short constructed answers."""
    expected = _as_list(item.get("answer"))
    if not expected:
        return False

    given = _as_list(answer)
    if not given:
        return False

    option_keys = _option_keys(item)
    expected_keys = {value.upper() for value in expected}
    item_type = str(item.get("type", "mcq_single"))

    # Multi-select is all-or-nothing: every correct key and no incorrect key.
    if item_type == "multi_select":
        if option_keys and expected_keys.issubset(option_keys):
            return {value.upper() for value in given} == expected_keys
        return {normalize_text(value) for value in given} == {
            normalize_text(value) for value in expected
        }

    # Key-based items (MCQ, true/false/not given, gap-fill with a word bank).
    if option_keys and expected_keys.issubset(option_keys):
        return any(value.upper() in expected_keys for value in given)

    # Constructed response: accept any listed alternative.
    expected_text = {normalize_text(value) for value in expected}
    return any(normalize_text(value) in expected_text for value in given)


def probability(theta: float, b: float, a: float = 1.0, c: float = 0.0) -> float:
    """3PL item response function."""
    try:
        exponent = -a * (theta - b)
        if exponent > 50:
            logistic = 0.0
        elif exponent < -50:
            logistic = 1.0
        else:
            logistic = 1.0 / (1.0 + math.exp(exponent))
    except OverflowError:
        logistic = 0.0 if exponent > 0 else 1.0
    return clamp(c + (1.0 - c) * logistic, 0.000001, 0.999999)


@dataclass
class AbilityEstimate:
    theta: float
    se: float
    posterior: list[tuple[float, float]]


def estimate_theta(
    responses: Iterable[dict[str, Any]],
    prior_mean: float = 0.0,
    prior_sd: float = 1.2,
    grid_min: float = -3.5,
    grid_max: float = 3.5,
    grid_step: float = 0.05,
) -> AbilityEstimate:
    """EAP ability estimate over a fixed grid.

    Each response needs ``b``, optional ``a``/``c`` and ``correct``.
    """
    responses = list(responses)
    points: list[float] = []
    log_posterior: list[float] = []
    grid_size = int(round((grid_max - grid_min) / grid_step)) + 1

    for index in range(grid_size):
        theta = grid_min + index * grid_step
        # Gaussian prior (up to a constant).
        log_prior = -0.5 * ((theta - prior_mean) / prior_sd) ** 2
        log_likelihood = 0.0
        for response in responses:
            p = probability(
                theta,
                float(response.get("b", 0.0)),
                float(response.get("a", 1.0)),
                float(response.get("c", 0.0)),
            )
            if response.get("correct"):
                log_likelihood += math.log(p)
            else:
                log_likelihood += math.log(1.0 - p)
        points.append(theta)
        log_posterior.append(log_prior + log_likelihood)

    if not points:
        return AbilityEstimate(theta=prior_mean, se=prior_sd, posterior=[])

    peak = max(log_posterior)
    weights = [math.exp(value - peak) for value in log_posterior]
    total = sum(weights)
    if total <= 0:
        return AbilityEstimate(theta=prior_mean, se=prior_sd, posterior=[])

    posterior = [(point, weight / total) for point, weight in zip(points, weights)]
    mean = sum(point * weight for point, weight in posterior)
    variance = sum(((point - mean) ** 2) * weight for point, weight in posterior)
    return AbilityEstimate(theta=mean, se=math.sqrt(max(variance, 0.0001)), posterior=posterior)


def level_from_theta(
    theta: float, cut_scores: Optional[dict[str, float]] = None
) -> str:
    cuts = cut_scores or DEFAULT_CUT_SCORES
    if theta < cuts["A2"]:
        return "A1"
    if theta < cuts["B1"]:
        return "A2"
    if theta < cuts["B2"]:
        return "B1"
    if theta < cuts["C1"]:
        return "B2"
    if theta < cuts["C2"]:
        return "C1"
    return "C2"


def level_index(level: str) -> int:
    try:
        return CEFR_LEVELS.index(str(level).upper())
    except ValueError:
        return 0


def level_range(
    theta: float,
    se: float,
    cut_scores: Optional[dict[str, float]] = None,
    z: float = 1.645,
) -> tuple[str, str]:
    """Approximate 90% confidence interval expressed as a CEFR range."""
    low = level_from_theta(theta - z * se, cut_scores)
    high = level_from_theta(theta + z * se, cut_scores)
    if level_index(low) > level_index(high):
        low, high = high, low
    return low, high


def theta_from_cefr(level: str, score_0_100: Optional[float] = None) -> float:
    """Map an AI-assigned CEFR level (plus optional 0-100 score) to theta."""
    center = LEVEL_CENTERS.get(str(level).upper(), 0.0)
    if score_0_100 is None:
        return center
    # Shift within roughly +/-0.35 theta around the level centre.
    score = clamp(float(score_0_100), 0.0, 100.0)
    return center + (score - 60.0) / 100.0 * 0.7


def rubric_to_theta(scores: dict[str, float], max_score: float = 5.0) -> tuple[float, float]:
    """Map a 0-5 rubric average to theta and an approximate standard error."""
    if not scores:
        return 0.0, 0.55
    average = sum(float(v) for v in scores.values()) / len(scores)
    average = clamp(average, 0.0, max_score)
    # Piecewise anchors keep 3/5 roughly at B1 and 4/5 at B2.
    anchors = [(0.0, -2.6), (1.0, -1.8), (2.0, -1.0), (3.0, -0.2), (4.0, 0.7), (5.0, 1.6)]
    theta = anchors[-1][1]
    for (x0, y0), (x1, y1) in zip(anchors, anchors[1:]):
        if x0 <= average <= x1:
            ratio = 0.0 if x1 == x0 else (average - x0) / (x1 - x0)
            theta = y0 + ratio * (y1 - y0)
            break
    return theta, 0.42


def weighted_overall(
    skill_estimates: dict[str, dict[str, Any]],
    weights: Optional[dict[str, float]] = None,
) -> tuple[float, float]:
    """Weighted mean theta across available skills, renormalising weights."""
    weights = weights or DEFAULT_WEIGHTS
    available: list[tuple[float, float, float]] = []
    for skill, estimate in skill_estimates.items():
        if estimate is None or "theta" not in estimate:
            continue
        weight = float(weights.get(skill, 0.0))
        if weight > 0:
            available.append(
                (
                    float(estimate["theta"]),
                    float(estimate.get("se", 0.5)),
                    weight,
                )
            )
    if not available:
        return 0.0, 0.55

    total_weight = sum(item[2] for item in available)
    theta = sum(item[0] * item[2] for item in available) / total_weight
    # Approximate SE for a weighted mean of independent estimates.
    variance = sum((item[1] ** 2) * (item[2] ** 2) for item in available) / (total_weight ** 2)
    return theta, math.sqrt(max(variance, 0.0001))


def exam_equivalents(level: str, mapping: dict[str, Any]) -> dict[str, str]:
    """Return the reference exam ranges for a CEFR level."""
    key = str(level).upper()
    result: dict[str, str] = {}
    for exam in ("ielts", "toeic", "toefl", "cambridge"):
        table = mapping.get(exam) or {}
        if key in table:
            result[exam] = str(table[key])
    return result


# ──────────────────────────────────────────────
# Content bank
# ──────────────────────────────────────────────


class PlacementBank:
    """Loads the static placement content and exposes selection helpers."""

    def __init__(self, data_dir: Optional[Path | str] = None) -> None:
        self.data_dir = Path(data_dir) if data_dir else Path(__file__).resolve().parent.parent / "data" / "placement"
        self.manifest: dict[str, Any] = self._read_json(self.data_dir / "manifest.json")
        self.can_do: dict[str, Any] = self._read_json(self.data_dir / "can_do.json")
        self.items: dict[str, dict[str, Any]] = {}
        self.tasks: dict[str, dict[str, Any]] = {}
        self.by_skill_level: dict[str, dict[str, list[dict[str, Any]]]] = {}
        self.writing_tasks: list[dict[str, Any]] = []
        self.speaking_tasks: list[dict[str, Any]] = []
        self.writing_rubric: dict[str, Any] = {}
        self.speaking_rubric: dict[str, Any] = {}

        for filename in ("listening.json", "reading.json", "use_of_english.json"):
            payload = self._read_json(self.data_dir / filename)
            for item in payload.get("items", []):
                if str(item.get("status", "active")) != "active":
                    continue
                item_id = str(item.get("id", "")).strip()
                if not item_id:
                    continue
                if item_id in self.items:
                    raise ValueError(f"Duplicate placement item id: {item_id}")
                self.items[item_id] = item
                skill = str(item.get("skill", "")).strip()
                level = str(item.get("level", "")).strip().upper()
                self.by_skill_level.setdefault(skill, {}).setdefault(level, []).append(item)

        writing_payload = self._read_json(self.data_dir / "writing.json")
        self.writing_tasks = [t for t in writing_payload.get("tasks", []) if t.get("status", "active") == "active"]
        self.writing_rubric = writing_payload.get("rubric", {})
        for task in self.writing_tasks:
            self.tasks[str(task["id"])] = task

        speaking_payload = self._read_json(self.data_dir / "speaking.json")
        self.speaking_tasks = [t for t in speaking_payload.get("tasks", []) if t.get("status", "active") == "active"]
        self.speaking_rubric = speaking_payload.get("rubric", {})
        for task in self.speaking_tasks:
            self.tasks[str(task["id"])] = task

        self.cut_scores = {
            **DEFAULT_CUT_SCORES,
            **{str(k): float(v) for k, v in (self.manifest.get("cut_scores") or {}).items()},
        }
        self.weights = {
            **DEFAULT_WEIGHTS,
            **{str(k): float(v) for k, v in (self.manifest.get("weights") or {}).items()},
        }

    @staticmethod
    def _read_json(path: Path) -> dict[str, Any]:
        return json.loads(path.read_text(encoding="utf-8"))

    # ── config ────────────────────────────────

    def public_config(self) -> dict[str, Any]:
        return {
            "version": self.manifest.get("version", "2.0.0"),
            "description": self.manifest.get("description", ""),
            "skill_order": self.manifest.get("skill_order", RECEPTIVE_SKILLS),
            "skill_labels": self.manifest.get("skill_labels", {}),
            "modes": self.manifest.get("modes", {}),
            "cut_scores": self.cut_scores,
            "level_labels": self.manifest.get("level_labels", {}),
            "level_descriptions_vi": self.manifest.get("level_descriptions_vi", {}),
            "exam_mapping": self.manifest.get("exam_mapping", {}),
            "can_do": self.can_do.get("descriptors", {}),
        }

    def mode(self, mode: str) -> dict[str, Any]:
        modes = self.manifest.get("modes", {})
        if mode not in modes:
            raise ValueError(f"Unknown placement mode: {mode}")
        return modes[mode]

    def stage_time(self, skill: str) -> int:
        return int(self.manifest.get("stage_time_seconds", {}).get(skill, 300))

    def get_item(self, item_id: str) -> Optional[dict[str, Any]]:
        return self.items.get(str(item_id))

    def get_task(self, task_id: str) -> Optional[dict[str, Any]]:
        return self.tasks.get(str(task_id))

    # ── item selection ────────────────────────

    @staticmethod
    def stage_levels(stage: int, theta: float) -> list[str]:
        if stage <= 1:
            return list(_STAGE1_LEVELS)
        routes = _ROUTE_LEVELS.get(stage, _ROUTE_LEVELS[3])
        for threshold, levels in routes:
            if theta < threshold:
                return list(levels)
        return list(routes[-1][1])

    def _pick_from_level(
        self,
        skill: str,
        level: str,
        exclude: set[str],
        rng: random.Random,
    ) -> Optional[dict[str, Any]]:
        pool = [
            item
            for item in self.by_skill_level.get(skill, {}).get(level, [])
            if str(item.get("id")) not in exclude
        ]
        if not pool:
            return None
        return rng.choice(pool)

    def _nearest_available(
        self,
        skill: str,
        target_level: str,
        exclude: set[str],
        rng: random.Random,
    ) -> Optional[dict[str, Any]]:
        target_index = level_index(target_level)
        for distance in range(1, len(CEFR_LEVELS)):
            for index in (target_index - distance, target_index + distance):
                if 0 <= index < len(CEFR_LEVELS):
                    item = self._pick_from_level(skill, CEFR_LEVELS[index], exclude, rng)
                    if item is not None:
                        return item
        return None

    def select_stage(
        self,
        skill: str,
        stage: int,
        theta: float,
        exclude_ids: Iterable[str] = (),
        count: Optional[int] = None,
        rng: Optional[random.Random] = None,
    ) -> list[dict[str, Any]]:
        rng = rng or random.Random()
        exclude = {str(item) for item in exclude_ids}
        levels = self.stage_levels(stage, theta)
        if count is not None:
            while len(levels) < count:
                levels.append(levels[-1])
            levels = levels[:count]
        else:
            count = len(levels)

        selected: list[dict[str, Any]] = []
        for level in levels:
            item = self._pick_from_level(skill, level, exclude, rng)
            if item is None:
                item = self._nearest_available(skill, level, exclude, rng)
            if item is not None:
                selected.append(item)
                exclude.add(str(item["id"]))
        rng.shuffle(selected)
        return selected

    def select_writing_tasks(
        self,
        theta: float,
        count: int,
        exclude_ids: Iterable[str] = (),
        rng: Optional[random.Random] = None,
    ) -> list[dict[str, Any]]:
        return self._select_tasks(self.writing_tasks, theta, count, exclude_ids, rng)

    def select_speaking_tasks(
        self,
        theta: float,
        count: int,
        exclude_ids: Iterable[str] = (),
        rng: Optional[random.Random] = None,
    ) -> list[dict[str, Any]]:
        return self._select_tasks(self.speaking_tasks, theta, count, exclude_ids, rng)

    def _select_tasks(
        self,
        tasks: list[dict[str, Any]],
        theta: float,
        count: int,
        exclude_ids: Iterable[str],
        rng: Optional[random.Random],
    ) -> list[dict[str, Any]]:
        rng = rng or random.Random()
        exclude = {str(item) for item in exclude_ids}
        target_level = level_from_theta(theta, self.cut_scores)
        target_index = level_index(target_level)
        ranked: list[tuple[int, float, dict[str, Any]]] = []
        for task in tasks:
            task_id = str(task.get("id"))
            if task_id in exclude:
                continue
            distance = abs(level_index(str(task.get("level", "B1"))) - target_index)
            ranked.append((distance, rng.random(), task))
        ranked.sort(key=lambda item: (item[0], item[1]))
        return [task for _, _, task in ranked[:count]]

    # ── payload sanitising ────────────────────

    def sanitize_item(self, item: dict[str, Any]) -> dict[str, Any]:
        """Return a client-safe item payload (no answer key or explanation)."""
        payload = {
            "id": item.get("id"),
            "skill": item.get("skill"),
            "level": item.get("level"),
            "type": item.get("type"),
            "stem": item.get("stem", ""),
            "options": item.get("options", []),
            "time_seconds": item.get("time_seconds"),
        }
        if item.get("passage"):
            payload["passage"] = item["passage"]
        if item.get("audio_url"):
            payload["audio_url"] = item["audio_url"]
            payload["play_limit"] = item.get("play_limit", 2)
        return payload

    def sanitize_writing_task(self, task: dict[str, Any]) -> dict[str, Any]:
        return {
            "id": task.get("id"),
            "skill": "writing",
            "level": task.get("level"),
            "type": task.get("type"),
            "title": task.get("title", ""),
            "prompt": task.get("prompt", ""),
            "instructions_vi": task.get("instructions_vi", ""),
            "min_words": task.get("min_words", 80),
            "max_words": task.get("max_words", 300),
            "time_minutes": task.get("time_minutes", 30),
        }

    def sanitize_speaking_task(self, task: dict[str, Any]) -> dict[str, Any]:
        return {
            "id": task.get("id"),
            "skill": "speaking",
            "level": task.get("level"),
            "type": task.get("type"),
            "title": task.get("title", ""),
            "prompt": task.get("prompt", ""),
            "bullets": task.get("bullets", []),
            "reference_text": task.get("reference_text", ""),
            "prep_seconds": task.get("prep_seconds", 20),
            "response_seconds": task.get("response_seconds", 60),
        }

    def can_do_for(self, level: str, skill: str) -> list[str]:
        return list(
            (self.can_do.get("descriptors", {}).get(str(level).upper(), {}) or {}).get(
                str(skill), []
            )
        )
