"""Honest pronunciation scoring.

Uses only the Python standard library so it can be imported and tested
without FastAPI / SQLAlchemy / app configuration.

Design rules:
  * ordered word alignment (difflib opcodes), never "word appears somewhere"
  * no score floor, no fake bonus points
  * tempo / fluency only from real STT timestamps
  * hard cap: 96 with timing, 95 without timing
"""

from __future__ import annotations

import difflib
import re
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

DEFAULT_WEIGHTS = {
    "accuracy": 0.50,
    "completeness": 0.25,
    "tempo": 0.15,
    "fluency": 0.10,
}

MAX_SCORE_WITH_TIMING = 96.0
MAX_SCORE_WITHOUT_TIMING = 95.0

_CONTRACTIONS = {
    "i'm": "i am",
    "i've": "i have",
    "i'll": "i will",
    "i'd": "i would",
    "you're": "you are",
    "you've": "you have",
    "you'll": "you will",
    "he's": "he is",
    "she's": "she is",
    "it's": "it is",
    "that's": "that is",
    "there's": "there is",
    "what's": "what is",
    "let's": "let us",
    "we're": "we are",
    "they're": "they are",
    "don't": "do not",
    "doesn't": "does not",
    "didn't": "did not",
    "can't": "can not",
    "cannot": "can not",
    "won't": "will not",
    "isn't": "is not",
    "aren't": "are not",
    "wasn't": "was not",
    "weren't": "were not",
    "haven't": "have not",
    "hasn't": "has not",
    "hadn't": "had not",
    "wouldn't": "would not",
    "shouldn't": "should not",
    "couldn't": "could not",
}

# A token may contain one internal apostrophe (contraction / possessive).
_TOKEN_RE = re.compile(r"[a-z0-9]+(?:'[a-z]+)?")
_WORD_RE = re.compile(r"[a-z0-9]+")

MATCH_DISPLAY_SCORE = 92.0
NEAR_THRESHOLD = 0.75
MATCH_THRESHOLD = 0.999
NEAR_CREDIT = 0.5

LONG_PAUSE_SECONDS = 0.8

# Nếu chưa khớp đủ % từ thì điểm tốc độ/nhịp không có ý nghĩa
# (nói một câu khác đúng nhịp không phải là nhại giỏi).
MIN_ACCURACY_FOR_TIMING = 40.0

NOTE_TIMING_SOURCE = "Đo từ timestamp thật của STT."
NOTE_NO_TIMING = "STT không trả timestamp — không chấm tốc độ/nhịp."
NOTE_CAP = "Điểm tối đa 96 vì chỉ chấm qua STT, không phân tích âm học."


@dataclass
class WordOp:
    kind: str  # "match" | "near" | "replace" | "omit" | "insert"
    ref_word: Optional[str]
    hyp_word: Optional[str]
    similarity: float  # 0..1
    credit: float
    display_score: float  # 0..100


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def _clamp(value: float, low: float = 0.0, high: float = 100.0) -> float:
    return max(low, min(high, value))


def _to_float(value: Any, default: Optional[float] = None) -> Optional[float]:
    if value is None:
        return default
    try:
        result = float(value)
    except (TypeError, ValueError):
        return default
    if result != result:  # NaN
        return default
    return result


def _similarity(a: Optional[str], b: Optional[str]) -> float:
    if not a or not b:
        return 0.0
    return difflib.SequenceMatcher(None, a, b).ratio()


def _classify(ref_word: str, hyp_word: str) -> Tuple[str, float, float, float]:
    """Return (kind, similarity, credit, display_score)."""
    sim = _similarity(ref_word, hyp_word)
    if sim >= MATCH_THRESHOLD:
        return "match", sim, 1.0, MATCH_DISPLAY_SCORE
    if sim >= NEAR_THRESHOLD:
        display = 60.0 + (sim - NEAR_THRESHOLD) / (MATCH_THRESHOLD - NEAR_THRESHOLD) * 25.0
        return "near", sim, NEAR_CREDIT, round(_clamp(display), 1)
    return "replace", sim, sim * 0.5, round(_clamp(sim * 60.0), 1)


def _omit(ref_word: str) -> WordOp:
    return WordOp(
        kind="omit",
        ref_word=ref_word,
        hyp_word=None,
        similarity=0.0,
        credit=0.0,
        display_score=0.0,
    )


def _insert(hyp_word: str) -> WordOp:
    return WordOp(
        kind="insert",
        ref_word=None,
        hyp_word=hyp_word,
        similarity=0.0,
        credit=0.0,
        display_score=0.0,
    )


# ---------------------------------------------------------------------------
# normalisation / alignment
# ---------------------------------------------------------------------------
def normalize_words(text: str) -> List[str]:
    """Lowercase, unify apostrophes, expand contractions, keep [a-z0-9]+."""
    if not text:
        return []
    lowered = str(text).lower()
    for apostrophe in ("\u2019", "\u2018", "\u02bc", "`", "\u00b4"):
        lowered = lowered.replace(apostrophe, "'")

    words: List[str] = []
    for token in _TOKEN_RE.findall(lowered):
        expanded = _CONTRACTIONS.get(token, token)
        words.extend(_WORD_RE.findall(expanded))
    return words


def align_words(reference_text: str, recognised_text: str) -> List[WordOp]:
    """Ordered word alignment between reference and recognised text."""
    ref_words = normalize_words(reference_text)
    hyp_words = normalize_words(recognised_text)

    matcher = difflib.SequenceMatcher(None, ref_words, hyp_words, autojunk=False)
    ops: List[WordOp] = []

    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            for offset in range(i2 - i1):
                ref_word = ref_words[i1 + offset]
                kind, sim, credit, display = _classify(ref_word, hyp_words[j1 + offset])
                ops.append(WordOp(kind, ref_word, hyp_words[j1 + offset], sim, credit, display))
        elif tag == "replace":
            ref_span = ref_words[i1:i2]
            hyp_span = hyp_words[j1:j2]
            paired = min(len(ref_span), len(hyp_span))
            for offset in range(paired):
                kind, sim, credit, display = _classify(ref_span[offset], hyp_span[offset])
                ops.append(WordOp(kind, ref_span[offset], hyp_span[offset], sim, credit, display))
            for ref_word in ref_span[paired:]:
                ops.append(_omit(ref_word))
            for hyp_word in hyp_span[paired:]:
                ops.append(_insert(hyp_word))
        elif tag == "delete":
            for ref_word in ref_words[i1:i2]:
                ops.append(_omit(ref_word))
        elif tag == "insert":
            for hyp_word in hyp_words[j1:j2]:
                ops.append(_insert(hyp_word))

    return ops


def _word_score_entry(word: str, display_score: float, error_type: str) -> Dict[str, Any]:
    return {
        "word": word,
        "accuracy_score": round(_clamp(display_score), 1),
        "error_type": error_type,
        "phonemes": [],
    }


_ERROR_TYPES = {
    "match": "None",
    "near": "Mispronunciation",
    "replace": "Mispronunciation",
    "omit": "Omission",
    "insert": "Insertion",
}


def score_alignment(reference_text: str, recognised_text: str) -> Dict[str, Any]:
    ref_words = normalize_words(reference_text)
    hyp_words = normalize_words(recognised_text)
    ops = align_words(reference_text, recognised_text)

    total_ref = len(ref_words)
    total_hyp = len(hyp_words)

    matched = near = wrong = omitted = inserted = 0
    credit_sum = 0.0
    word_scores: List[Dict[str, Any]] = []

    for op in ops:
        if op.kind == "match":
            matched += 1
        elif op.kind == "near":
            near += 1
        elif op.kind == "replace":
            wrong += 1
        elif op.kind == "omit":
            omitted += 1
        elif op.kind == "insert":
            inserted += 1

        if op.ref_word is not None:
            credit_sum += op.credit

        if op.kind == "insert":
            display_word = f"[{op.hyp_word}]"
            display_score = 0.0
        else:
            display_word = op.ref_word or ""
            display_score = op.display_score

        word_scores.append(
            _word_score_entry(display_word, display_score, _ERROR_TYPES.get(op.kind, "None"))
        )

    if total_ref > 0:
        accuracy = credit_sum / total_ref * 100.0
        completeness = (matched + near) / total_ref * 100.0
    else:
        accuracy = 0.0
        completeness = 0.0

    return {
        "accuracy_score": round(_clamp(accuracy), 1),
        "completeness_score": round(_clamp(completeness), 1),
        "word_scores": word_scores,
        "matched_words": matched,
        "near_words": near,
        "wrong_words": wrong,
        "omitted_words": omitted,
        "inserted_words": inserted,
        "total_ref_words": total_ref,
        "total_hyp_words": total_hyp,
        "has_speech": total_hyp > 0,
    }


# ---------------------------------------------------------------------------
# timing
# ---------------------------------------------------------------------------
def _times_from_stt_word(raw: dict) -> Tuple[Optional[float], Optional[float]]:
    start = _to_float(raw.get("start_time", raw.get("start")))
    end = _to_float(raw.get("end_time", raw.get("end")))
    return start, end


def score_timing(
    stt_words: List[dict],
    reference_text: str,
    target_wpm: Optional[float] = None,
) -> Dict[str, Any]:
    stt_words = stt_words or []
    target = _to_float(target_wpm)

    timed: List[Tuple[float, float]] = []
    has_timing = False
    for raw in stt_words:
        if not isinstance(raw, dict):
            continue
        start, end = _times_from_stt_word(raw)
        if start is None and end is None:
            continue
        if start is None:
            start = 0.0
        if end is None:
            end = start
        if end > start and end > 0:
            has_timing = True
            timed.append((float(start), float(end)))

    if not has_timing:
        return {
            "has_timing": False,
            "speech_duration": None,
            "actual_wpm": None,
            "target_wpm": target,
            "tempo_score": None,
            "fluency_score": None,
            "long_pause_count": 0,
            "pause_ratio": None,
            "notes": [NOTE_NO_TIMING],
        }

    timed.sort(key=lambda pair: (pair[0], pair[1]))
    word_count = len(timed)

    speech_duration = timed[-1][1] - timed[0][0]
    if speech_duration <= 0:
        speech_duration = sum(end - start for start, end in timed)
    if speech_duration <= 0:
        speech_duration = 0.0

    actual_wpm = (word_count / (speech_duration / 60.0)) if speech_duration > 0 else 0.0
    ratio = (actual_wpm / target) if target and target > 0 else None

    tempo_score: Optional[float] = None
    if ratio is not None:
        if 0.8 <= ratio <= 1.25:
            tempo_score = 100.0
        elif ratio < 0.8:
            tempo_score = max(0.0, 100.0 - (0.8 - ratio) * 125.0)
        else:
            tempo_score = max(0.0, 100.0 - (ratio - 1.25) * 100.0)
        tempo_score = round(_clamp(tempo_score), 1)

    long_pause_count = 0
    long_pause_total = 0.0
    for index in range(1, word_count):
        gap = timed[index][0] - timed[index - 1][1]
        if gap > LONG_PAUSE_SECONDS:
            long_pause_count += 1
            long_pause_total += gap

    pause_ratio = (long_pause_total / speech_duration) if speech_duration > 0 else 0.0
    pause_ratio = _clamp(pause_ratio, 0.0, 1.0)

    if ratio is not None:
        fluency = 100.0 - pause_ratio * 80.0
        fluency -= max(0.0, 0.8 - ratio) * 40.0
        # Too-fast speech hurts rhythm too (assumption: real STT timing is noisy
        # when the learner rushes, so it must not be rewarded).
        fluency -= max(0.0, ratio - 1.25) * 40.0
    else:
        fluency = 100.0 - pause_ratio * 100.0
    fluency = round(_clamp(fluency), 1)

    notes: List[str] = [NOTE_TIMING_SOURCE]
    if ratio is not None:
        notes.append(
            f"Nhịp nói {actual_wpm:.0f} từ/phút, mục tiêu {target:.0f} từ/phút."
        )
    if long_pause_count > 0:
        notes.append(f"Phát hiện {long_pause_count} khoảng ngừng dài.")

    return {
        "has_timing": True,
        "speech_duration": round(speech_duration, 2),
        "actual_wpm": round(actual_wpm, 1),
        "target_wpm": target,
        "tempo_score": tempo_score,
        "fluency_score": fluency,
        "long_pause_count": long_pause_count,
        "pause_ratio": round(pause_ratio, 3),
        "notes": notes,
    }


# ---------------------------------------------------------------------------
# combining
# ---------------------------------------------------------------------------
def combine_overall(
    accuracy: float,
    completeness: float,
    tempo: Optional[float],
    fluency: Optional[float],
    weights: Optional[dict] = None,
) -> Tuple[float, Dict[str, float]]:
    base = dict(DEFAULT_WEIGHTS)
    if weights:
        for key in base:
            value = weights.get(key)
            numeric = _to_float(value)
            if numeric is not None and numeric >= 0:
                base[key] = numeric

    values: Dict[str, Optional[float]] = {
        "accuracy": accuracy,
        "completeness": completeness,
        "tempo": tempo,
        "fluency": fluency,
    }

    used = {
        key: base[key]
        for key, value in values.items()
        if value is not None and base[key] > 0
    }
    total_weight = sum(used.values())

    if total_weight <= 0:
        return 0.0, {}

    overall = sum(
        values[key] * weight  # type: ignore[operator]
        for key, weight in used.items()
    ) / total_weight

    normalized = {key: round(weight / total_weight, 3) for key, weight in used.items()}
    return round(_clamp(overall), 1), normalized


# ---------------------------------------------------------------------------
# public entry point
# ---------------------------------------------------------------------------
def build_assessment(
    reference_text: str,
    recognised_text: str,
    stt_words: Optional[List[dict]] = None,
    target_wpm: Optional[float] = None,
) -> Dict[str, Any]:
    reference_text = reference_text or ""
    recognised_text = recognised_text or ""

    ref_words = normalize_words(reference_text)
    hyp_words = normalize_words(recognised_text)

    empty_metrics = {
        "matched_words": 0,
        "near_words": 0,
        "wrong_words": 0,
        "omitted_words": 0,
        "inserted_words": 0,
        "total_ref_words": len(ref_words),
        "total_hyp_words": 0,
        "speech_duration": None,
        "actual_wpm": None,
        "target_wpm": _to_float(target_wpm),
        "long_pause_count": 0,
        "pause_ratio": None,
    }

    if not hyp_words:
        word_scores = [
            _word_score_entry(word, 0.0, "Omission") for word in ref_words
        ]
        return {
            "scored": False,
            "reason": "no_speech",
            "reference_text": reference_text,
            "recognised_text": recognised_text,
            "accuracy_score": 0.0,
            "completeness_score": 0.0,
            "tempo_score": None,
            "fluency_score": None,
            "overall_score": 0.0,
            "has_timing": False,
            "weights_used": {},
            "word_scores": word_scores,
            "notes": [NOTE_NO_TIMING, NOTE_CAP],
            "metrics": empty_metrics,
        }

    alignment = score_alignment(reference_text, recognised_text)
    timing = score_timing(stt_words or [], reference_text, target_wpm)

    accuracy = alignment["accuracy_score"]
    completeness = alignment["completeness_score"]
    tempo = timing["tempo_score"]
    fluency = timing["fluency_score"]
    has_timing = bool(timing["has_timing"])

    # Chưa khớp đủ từ thì tốc độ/nhịp không có ý nghĩa:
    # loại hai thành phần này khỏi điểm tổng thay vì cộng 25 điểm ảo.
    timing_meaningful = accuracy >= MIN_ACCURACY_FOR_TIMING
    if has_timing and not timing_meaningful:
        tempo = None
        fluency = None

    overall, weights_used = combine_overall(accuracy, completeness, tempo, fluency)
    cap = MAX_SCORE_WITH_TIMING if has_timing else MAX_SCORE_WITHOUT_TIMING
    overall = round(min(overall, cap), 1)

    notes: List[str] = list(timing["notes"])
    if has_timing and not timing_meaningful:
        notes.append("Chưa khớp đủ từ nên không đánh giá tốc độ/nhịp.")
    notes.append(NOTE_CAP)

    metrics = {
        "matched_words": alignment["matched_words"],
        "near_words": alignment["near_words"],
        "wrong_words": alignment["wrong_words"],
        "omitted_words": alignment["omitted_words"],
        "inserted_words": alignment["inserted_words"],
        "total_ref_words": alignment["total_ref_words"],
        "total_hyp_words": alignment["total_hyp_words"],
        "speech_duration": timing["speech_duration"],
        "actual_wpm": timing["actual_wpm"],
        "target_wpm": timing["target_wpm"],
        "long_pause_count": timing["long_pause_count"],
        "pause_ratio": timing["pause_ratio"],
    }

    return {
        "scored": True,
        "reason": None,
        "reference_text": reference_text,
        "recognised_text": recognised_text,
        "accuracy_score": accuracy,
        "completeness_score": completeness,
        "tempo_score": tempo,
        "fluency_score": fluency,
        "overall_score": overall,
        "has_timing": has_timing,
        "weights_used": weights_used,
        "word_scores": alignment["word_scores"],
        "notes": notes,
        "metrics": metrics,
    }
