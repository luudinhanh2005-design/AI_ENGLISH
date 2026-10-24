"""IELTS Writing (Task 1 / Task 2) evaluation service.

The service asks the configured LLM for a strict IELTS band breakdown, then
normalises the answer itself:

* every band is clamped to 0.0-9.0 and snapped to the nearest 0.5;
* the overall task band is always recomputed as the mean of the four criteria
  (the model's own average is never trusted);
* when the model is unavailable or returns unusable JSON, a transparent
  heuristic based on measurable text statistics is returned instead, so the
  mock-test flow never blocks on the LLM.

Public API
----------
``await evaluate_ielts_writing(task_number, prompt, essay, min_words=150)``
    Full evaluation (LLM first, heuristic fallback).

``heuristic_writing_band(essay, min_words)``
    Synchronous, LLM-free estimate that reuses the same dict shape.
"""

from __future__ import annotations

import asyncio
import logging
import math
import re
from typing import Any

from .ai_service import AIService

logger = logging.getLogger(__name__)

# An essay shorter than this is considered "not attempted / too short" and is
# never sent to the LLM.
MIN_ESSAY_WORDS = 40

# Heuristic estimates stay inside this window: below 3.5 the statistics cannot
# distinguish real levels, above 7.5 they cannot justify a higher band.
CRITERIA_LOW = 3.5
CRITERIA_HIGH = 7.5

COHESIVE_DEVICES: tuple[str, ...] = (
    "however",
    "furthermore",
    "moreover",
    "whereas",
    "consequently",
    "in addition",
    "on the other hand",
    "nevertheless",
    "therefore",
    "for instance",
)

COMPLEX_MARKERS: tuple[str, ...] = (
    "although",
    "though",
    "despite",
    "in spite of",
    "which",
    "who",
    "whose",
    "whereas",
    "even though",
    "while",
    "not only",
    "whether",
    "unless",
    "provided that",
)

# Words/phrases that usually signal a limited lexical range when repeated.
_SIMPLE_WORD_RE = re.compile(
    r"\b(very|really|good|bad|nice|big|small|thing|things|a lot|lots of)\b",
    re.IGNORECASE,
)
_WORD_RE = re.compile(r"[A-Za-z]+(?:['\u2019-][A-Za-z]+)*|\d+(?:[.,]\d+)*")
_LETTER_RE = re.compile(r"[A-Za-z]")

_CRITERIA_ORDER = ("coherence", "lexical", "grammar")

_CRITERIA_ALIASES: dict[str, tuple[str, ...]] = {
    "task_achievement": (
        "task_achievement",
        "task1",
        "task_1",
        "task_achievement_and_response",
        "ta",
    ),
    "task_response": (
        "task_response",
        "task2",
        "task_2",
        "tr",
    ),
    "coherence": (
        "coherence",
        "coherence_and_cohesion",
        "coherence_cohesion",
        "cc",
    ),
    "lexical": (
        "lexical",
        "lexical_resource",
        "vocabulary",
        "lr",
    ),
    "grammar": (
        "grammar",
        "grammatical_range_and_accuracy",
        "grammatical_range",
        "grammatical_accuracy",
        "gra",
    ),
}

_SYSTEM_PROMPT = (
    "You are a certified IELTS Writing examiner with at least 15 years of experience. "
    "You grade strictly and honestly against the official IELTS Writing band descriptors "
    "(Task 1 and Task 2, public version) and you never inflate scores. "
    "You return exactly ONE valid JSON object and nothing else: no markdown fences, "
    "no comments, and no text before or after the object."
)


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------


def _clean_text(value: Any, max_length: int = 2000) -> str:
    """Collapse whitespace, strip control characters and cap the length."""
    if value is None:
        return ""
    text = str(value).replace("\x00", " ").strip()
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text[:max_length].strip()


def _as_str_list(value: Any, limit: int = 4) -> list[str]:
    """Normalise a model-provided list of strings (dedupe, strip, cap)."""
    if isinstance(value, str):
        value = [value]
    if not isinstance(value, list):
        return []
    result: list[str] = []
    seen: set[str] = set()
    for item in value:
        text = _clean_text(item, 500)
        key = text.casefold()
        if text and key not in seen:
            seen.add(key)
            result.append(text)
        if len(result) >= limit:
            break
    return result


def _count_words(text: str) -> int:
    """IELTS-style word count (hyphenated words and numbers count once)."""
    return len(_WORD_RE.findall(text or ""))


def _snap_band(
    value: Any,
    default: float = 5.0,
    low: float = 0.0,
    high: float = 9.0,
) -> float:
    """Clamp to ``low..high`` and snap to the nearest 0.5 (round half up)."""
    try:
        number = float(value)
    except (TypeError, ValueError):
        number = float(default)
    if not math.isfinite(number):
        number = float(default)
    number = min(float(high), max(float(low), number))
    return math.floor(number * 2.0 + 0.5) / 2.0


def _optional_band(value: Any) -> float | None:
    """Snap a value to a band, or return ``None`` when it is not a number."""
    if value is None or isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(number):
        return None
    return _snap_band(number)


def _criterion_key(task_number: int) -> str:
    """Task 1 uses ``task_achievement``; Task 2 uses ``task_response``."""
    try:
        task = int(task_number)
    except (TypeError, ValueError):
        task = 1
    return "task_response" if task >= 2 else "task_achievement"


def _task_label(task_number: int) -> str:
    return "Task 2" if _criterion_key(task_number) == "task_response" else "Task 1"


def _paragraphs(text: str) -> list[str]:
    blocks = [block.strip() for block in re.split(r"\n\s*\n", text) if block.strip()]
    return blocks or ([text.strip()] if text.strip() else [])


def _sentences(text: str) -> list[str]:
    parts = re.split(r"(?<=[.!?])\s+|\n+", text)
    return [part.strip() for part in parts if _LETTER_RE.search(part or "")]


def _normalise_corrections(raw: Any, essay: str) -> list[dict[str, str]]:
    """Keep only corrections whose ``original`` really appears in the essay."""
    if isinstance(raw, dict):
        raw = [raw]
    if not isinstance(raw, list):
        return []

    flat_essay = re.sub(r"\s+", " ", essay).casefold()
    corrections: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()

    for item in raw:
        if not isinstance(item, dict):
            continue
        original = _clean_text(
            item.get("original") or item.get("error") or item.get("incorrect"), 400
        )
        corrected = _clean_text(
            item.get("corrected") or item.get("correction") or item.get("correct"), 800
        )
        explanation = _clean_text(
            item.get("explanation")
            or item.get("explanation_vi")
            or item.get("note"),
            600,
        )
        if not original or not corrected:
            continue
        flat_original = re.sub(r"\s+", " ", original).casefold()
        if flat_original == re.sub(r"\s+", " ", corrected).casefold():
            continue
        # Guard against hallucinated quotes that are not in the candidate text.
        if flat_original not in flat_essay:
            continue
        key = (flat_original, corrected.casefold())
        if key in seen:
            continue
        seen.add(key)
        corrections.append(
            {
                "original": original,
                "corrected": corrected,
                "explanation": explanation
                or "Cách diễn đạt này tự nhiên và chính xác hơn trong văn viết học thuật.",
            }
        )
        if len(corrections) >= 8:
            break

    return corrections


# ---------------------------------------------------------------------------
# LLM result normalisation
# ---------------------------------------------------------------------------


def _extract_criteria(raw: Any, criterion_key: str) -> dict[str, float] | None:
    """Read the four criteria from a model response, tolerating key aliases."""
    if not isinstance(raw, dict):
        return None

    found: dict[str, float] = {}
    for canonical, aliases in _CRITERIA_ALIASES.items():
        for alias in aliases:
            band = _optional_band(raw.get(alias))
            if band is not None:
                found[canonical] = band
                break

    # The model sometimes labels the task criterion with the other task's key.
    if criterion_key not in found:
        for other in ("task_achievement", "task_response"):
            if other in found:
                found[criterion_key] = found.pop(other)
                break
    found.pop(
        "task_response" if criterion_key == "task_achievement" else "task_achievement",
        None,
    )

    if len(found) < 2:
        return None

    if len(found) < 4:
        average = _snap_band(sum(found.values()) / len(found))
        for canonical in (criterion_key, *_CRITERIA_ORDER):
            found.setdefault(canonical, average)

    return {
        criterion_key: _snap_band(found[criterion_key]),
        **{
            canonical: _snap_band(found[canonical])
            for canonical in _CRITERIA_ORDER
        },
    }


def _normalise_llm_result(
    data: Any,
    *,
    essay: str,
    word_count: int,
    criterion_key: str,
    min_words: int,
) -> dict[str, Any] | None:
    """Validate an LLM evaluation; return ``None`` when it cannot be trusted."""
    if not isinstance(data, dict):
        return None

    criteria = _extract_criteria(data.get("criteria"), criterion_key)
    if criteria is None:
        return None

    band = _snap_band(sum(criteria.values()) / len(criteria))

    comment = _clean_text(
        data.get("comment")
        or data.get("general_comment")
        or data.get("examiner_comment"),
        1600,
    )
    if not comment:
        comment = (
            f"Bài viết đạt Band {band:.1f} theo bốn tiêu chí chấm. "
            "Hãy đọc kỹ phần sửa lỗi và các gợi ý cải thiện để nâng band ở lần viết sau."
        )

    strengths = _as_str_list(data.get("strengths"), 4)
    if not strengths and word_count >= min_words:
        strengths = [
            "Bài viết đạt độ dài tối thiểu và truyền đạt được ý chính của đề bài."
        ]

    improvements = _as_str_list(data.get("improvements"), 5)
    if not improvements:
        improvements = [
            "Rà soát lại lỗi ngữ pháp, chia thì và liên kết giữa các đoạn để nâng band."
        ]

    revised = _clean_text(data.get("revised_text"), 12000)
    if len(revised) < 20:
        revised = essay

    return {
        "band": band,
        "criteria": criteria,
        "word_count": word_count,
        "comment": comment,
        "corrections": _normalise_corrections(data.get("corrections"), essay),
        "strengths": strengths,
        "improvements": improvements,
        "revised_text": revised,
    }


# ---------------------------------------------------------------------------
# Heuristic fallback
# ---------------------------------------------------------------------------


def _short_essay_result(
    essay: str,
    *,
    min_words: int,
    criterion_key: str,
    word_count: int,
) -> dict[str, Any]:
    """Empty / very short essays: Band 1.0-2.0 with a clear explanation."""
    if word_count == 0:
        band = 1.0
    elif word_count < 20:
        band = 1.5
    else:
        band = 2.0

    criteria = {
        criterion_key: band,
        **{canonical: band for canonical in _CRITERIA_ORDER},
    }

    if word_count == 0:
        comment = (
            "Bài viết trống: thí sinh không thực hiện bài viết (did not attempt), "
            "nên cả bốn tiêu chí chỉ có thể ở Band 1.0. "
            f"Hãy viết tối thiểu {min_words} từ, chia thành 4-5 đoạn, "
            "trả lời trực tiếp yêu cầu của đề và đưa ra ví dụ/lý do cụ thể."
        )
        strengths: list[str] = []
        improvements = [
            f"Viết tối thiểu {min_words} từ cho đúng yêu cầu của đề.",
            "Lập dàn ý trước khi viết: mở bài, 2 đoạn thân bài, kết luận.",
            "Trả lời đúng trọng tâm câu hỏi của đề bài.",
        ]
    else:
        comment = (
            f"Bài viết quá ngắn ({word_count} từ trong khi yêu cầu tối thiểu "
            f"{min_words} từ), chưa đủ dữ liệu để chấm bốn tiêu chí. "
            f"Đây là Band ước tính {band:.1f} (did not attempt / quá ngắn), "
            "không phải kết quả chấm của giám khảo. Cần viết đủ độ dài và triển khai "
            "ý rõ ràng trước khi có thể đánh giá Task Achievement, Coherence, "
            "Lexical Resource và Grammatical Range."
        )
        strengths = ["Đã có nội dung tiếng Anh ban đầu để bắt đầu chỉnh sửa."]
        improvements = [
            f"Tăng độ dài lên tối thiểu {min_words} từ (hiện có {word_count} từ).",
            "Phát triển mỗi ý thành 2-3 câu có giải thích và ví dụ.",
            "Chia bài thành các đoạn rõ ràng và dùng từ nối giữa các ý.",
        ]

    return {
        "band": band,
        "criteria": criteria,
        "word_count": word_count,
        "comment": comment,
        "corrections": [],
        "strengths": strengths,
        "improvements": improvements,
        "revised_text": essay,
    }


def _heuristic_impl(
    essay: str,
    min_words: int,
    criterion_key: str,
) -> dict[str, Any]:
    text = (essay or "").strip()
    word_count = _count_words(text)
    effective_min = max(1, int(min_words or 150))

    if word_count < MIN_ESSAY_WORDS:
        return _short_essay_result(
            text,
            min_words=effective_min,
            criterion_key=criterion_key,
            word_count=word_count,
        )

    flat = re.sub(r"\s+", " ", text)
    lowered = flat.lower()
    paragraphs = _paragraphs(text) or [text]
    sentences = _sentences(text)
    sentence_count = max(1, len(sentences))
    avg_sentence = word_count / sentence_count

    tokens = [token.lower() for token in _WORD_RE.findall(text)]
    content_tokens = [token for token in tokens if len(token) > 2]
    ttr = (
        len(set(content_tokens)) / len(content_tokens) if content_tokens else 0.0
    )
    long_word_ratio = (
        sum(1 for token in tokens if len(token) >= 8) / len(tokens)
        if tokens
        else 0.0
    )

    cohesive = [device for device in COHESIVE_DEVICES if device in lowered]
    complex_hits = [
        marker
        for marker in COMPLEX_MARKERS
        if re.search(rf"\b{re.escape(marker)}\b", lowered)
    ]
    comma_count = flat.count(",")
    semicolon_count = flat.count(";") + flat.count(":")
    simple_repeats = len(_SIMPLE_WORD_RE.findall(lowered))

    # Task Achievement / Task Response: length vs. requirement + paragraphing.
    ratio = word_count / effective_min
    if ratio >= 1.0:
        task_band = 5.0 + min(1.5, (ratio - 1.0) * 1.5)
    else:
        task_band = 3.5 + max(0.0, ratio - 0.4) * 2.5
    if len(paragraphs) >= 3:
        task_band += 0.5
    elif len(paragraphs) <= 1:
        task_band -= 0.5

    # Coherence & Cohesion: cohesive devices + paragraph structure.
    coherence_band = 4.5 + 0.5 * min(3, len(cohesive))
    if len(paragraphs) >= 3:
        coherence_band += 0.5
    if len(paragraphs) >= 4:
        coherence_band += 0.5
    if len(paragraphs) <= 1:
        coherence_band -= 0.5

    # Lexical Resource: type-token ratio, long words, simple-word repetition.
    lexical_band = 4.5 + max(-0.5, min(1.5, (ttr - 0.40) * 6.0))
    if long_word_ratio >= 0.12:
        lexical_band += 0.5
    if simple_repeats >= 4:
        lexical_band -= 0.5

    # Grammatical Range & Accuracy: complex markers, sentence length, punctuation.
    grammar_band = 4.5 + 0.5 * min(2, len(complex_hits))
    if 12.0 <= avg_sentence <= 26.0:
        grammar_band += 0.5
    elif avg_sentence < 8.0 or avg_sentence > 38.0:
        grammar_band -= 0.5
    if comma_count >= max(1, sentence_count // 2):
        grammar_band += 0.5
    if semicolon_count:
        grammar_band += 0.25

    criteria = {
        criterion_key: _snap_band(
            task_band, low=CRITERIA_LOW, high=CRITERIA_HIGH
        ),
        "coherence": _snap_band(
            coherence_band, low=CRITERIA_LOW, high=CRITERIA_HIGH
        ),
        "lexical": _snap_band(
            lexical_band, low=CRITERIA_LOW, high=CRITERIA_HIGH
        ),
        "grammar": _snap_band(
            grammar_band, low=CRITERIA_LOW, high=CRITERIA_HIGH
        ),
    }
    band = _snap_band(sum(criteria.values()) / len(criteria))

    comment_parts = [
        "Điểm ước lượng bằng phương pháp heuristic (mô hình AI chưa khả dụng), "
        "không phải kết quả chấm của giám khảo.",
        (
            f"Bài viết có {word_count} từ (yêu cầu tối thiểu {effective_min} từ), "
            f"{len(paragraphs)} đoạn, {sentence_count} câu, độ dài câu trung bình "
            f"{avg_sentence:.1f} từ, tỉ lệ từ vựng đa dạng (TTR) {ttr:.2f}."
        ),
        (
            "Có dùng từ nối học thuật: " + ", ".join(cohesive[:5]) + "."
            if cohesive
            else "Chưa thấy từ nối học thuật rõ ràng (however, furthermore, "
            "moreover, whereas, consequently, in addition, on the other hand)."
        ),
        (
            "Có cấu trúc phức: " + ", ".join(complex_hits[:4]) + "."
            if complex_hits
            else "Chưa thấy nhiều cấu trúc phức (although, despite, "
            "mệnh đề quan hệ which/who)."
        ),
        f"Dấu câu: {comma_count} dấu phẩy, {semicolon_count} dấu chấm phẩy/hai chấm.",
    ]
    comment = _clean_text(" ".join(comment_parts), 1600)

    strengths: list[str] = []
    if word_count >= effective_min:
        strengths.append(
            f"Đạt yêu cầu độ dài tối thiểu ({word_count}/{effective_min} từ)."
        )
    if len(paragraphs) >= 3:
        strengths.append(f"Bài viết được chia thành {len(paragraphs)} đoạn rõ ràng.")
    if cohesive:
        strengths.append(
            "Dùng được một số từ nối học thuật: " + ", ".join(cohesive[:4]) + "."
        )
    if complex_hits:
        strengths.append(
            "Có cố gắng dùng cấu trúc phức: " + ", ".join(complex_hits[:3]) + "."
        )
    if ttr >= 0.45:
        strengths.append(f"Vốn từ tương đối đa dạng (TTR {ttr:.2f}).")
    if 12.0 <= avg_sentence <= 26.0:
        strengths.append("Độ dài câu trung bình phù hợp với văn viết học thuật.")

    improvements: list[str] = []
    if word_count < effective_min:
        improvements.append(
            f"Tăng độ dài lên tối thiểu {effective_min} từ (hiện có {word_count} từ)."
        )
    if len(paragraphs) < 3:
        improvements.append(
            "Chia bài thành 4 đoạn rõ ràng: mở bài, hai đoạn thân bài và kết luận."
        )
    if not cohesive:
        improvements.append(
            "Dùng từ nối để liên kết ý: however, furthermore, moreover, whereas, "
            "consequently, in addition, on the other hand."
        )
    if not complex_hits:
        improvements.append(
            "Thêm cấu trúc phức: mệnh đề quan hệ (which/who), although/despite, "
            "câu điều kiện hoặc bị động."
        )
    if ttr < 0.40:
        improvements.append(
            "Đa dạng hoá từ vựng: tránh lặp từ và thay các từ đơn giản bằng từ "
            "học thuật chính xác hơn."
        )
    if avg_sentence > 30.0:
        improvements.append(
            f"Câu quá dài (trung bình {avg_sentence:.1f} từ): tách thành 2 câu ngắn "
            "hơn để tránh lỗi cấu trúc."
        )
    elif avg_sentence < 10.0:
        improvements.append(
            f"Câu khá ngắn (trung bình {avg_sentence:.1f} từ): ghép câu bằng "
            "liên từ để thể hiện quan hệ ý nghĩa."
        )
    if comma_count < max(1, sentence_count // 2):
        improvements.append(
            "Dùng dấu phẩy sau trạng ngữ/mệnh đề phụ và trước liên từ để câu rõ ràng hơn."
        )
    if simple_repeats >= 4:
        improvements.append(
            "Hạn chế lặp các từ đơn giản (very, good, bad, thing...); dùng từ "
            "cụ thể và chính xác hơn."
        )

    if not strengths:
        strengths = [
            "Bài viết có nội dung liên tục và đủ dài để bắt đầu đánh giá."
        ]
    if not improvements:
        improvements = [
            "Tiếp tục rà soát lỗi ngữ pháp và mở rộng ý bằng ví dụ cụ thể."
        ]

    return {
        "band": band,
        "criteria": criteria,
        "word_count": word_count,
        "comment": comment,
        "corrections": [],
        "strengths": strengths[:4],
        "improvements": improvements[:5],
        "revised_text": text,
    }


def heuristic_writing_band(essay: str, min_words: int) -> dict[str, Any]:
    """Estimate an IELTS writing band without calling the LLM.

    The task criterion is named ``task_response`` when ``min_words >= 200``
    (Task 2) and ``task_achievement`` otherwise (Task 1).  The returned dict
    has the same shape as :func:`evaluate_ielts_writing`.
    """
    criterion_key = "task_response" if int(min_words or 0) >= 200 else "task_achievement"
    return _heuristic_impl(essay, int(min_words or 0), criterion_key)


# ---------------------------------------------------------------------------
# Public evaluation entry point
# ---------------------------------------------------------------------------


def _build_user_prompt(
    *,
    task_number: int,
    prompt_text: str,
    essay: str,
    word_count: int,
    min_words: int,
    criterion_key: str,
) -> str:
    task_label = _task_label(task_number)
    return (
        f"You are marking {task_label} of the IELTS Writing test.\n"
        f"MINIMUM WORD REQUIREMENT: {min_words} words\n"
        f"CANDIDATE WORD COUNT (counted from the essay): {word_count}\n\n"
        "TASK PROMPT:\n"
        f'"""{prompt_text}"""\n\n'
        "CANDIDATE ESSAY:\n"
        f'"""{essay}"""\n\n'
        "Mark the essay against the official band descriptors and return exactly "
        "one JSON object with these keys:\n"
        "{\n"
        '  "band": 6.0,\n'
        f'  "criteria": {{"{criterion_key}": 6.0, "coherence": 6.0, '
        '"lexical": 6.0, "grammar": 6.0},\n'
        f'  "word_count": {word_count},\n'
        '  "comment": "<nhan xet cu the bang tieng Viet, 2-4 cau>",\n'
        '  "corrections": [{"original": "<exact words from the essay>", '
        '"corrected": "<corrected version>", '
        '"explanation": "<giai thich bang tieng Viet>"}],\n'
        '  "strengths": ["<diem manh, tieng Viet>"],\n'
        '  "improvements": ["<goi y cai thien, tieng Viet>"],\n'
        '  "revised_text": "<improved version of the whole essay>"\n'
        "}\n\n"
        "Rules:\n"
        f'- The task criterion key MUST be "{criterion_key}" for {task_label}.\n'
        "- Use only the four criteria above. Each criterion is a number from 0 to 9 "
        "in steps of 0.5, justified by the official descriptors for that band.\n"
        "- Do not reward memorised templates, off-topic content, or an essay that "
        "ignores part of the task.\n"
        f"- If the essay is under {min_words} words, penalise the task criterion "
        "and explain the penalty in the comment.\n"
        "- Your overall band must be the mean of the four criteria, rounded to the "
        "nearest 0.5; the application recomputes it anyway.\n"
        "- Give 3 to 8 corrections maximum. Every \"original\" MUST be copied "
        "exactly from the essay (same words and spelling).\n"
        "- Write comment, strengths, improvements and every explanation in "
        "Vietnamese with full diacritics. Be specific to THIS essay, not generic.\n"
        "- revised_text keeps the candidate's ideas and data but improves grammar, "
        "vocabulary and cohesion. Do not invent facts, figures or examples.\n"
        "- Return JSON only. No markdown fences, no extra commentary."
    )


async def evaluate_ielts_writing(
    task_number: int,
    prompt: str,
    essay: str,
    min_words: int = 150,
) -> dict[str, Any]:
    """Evaluate one IELTS writing task and return a JSON-serialisable result.

    The returned dict always contains: ``band``, ``criteria`` (four keys),
    ``word_count``, ``comment``, ``corrections``, ``strengths``,
    ``improvements`` and ``revised_text``.
    """
    essay_text = _clean_text(essay, 20000)
    prompt_text = _clean_text(prompt, 4000)
    word_count = _count_words(essay_text)
    criterion_key = _criterion_key(task_number)

    try:
        requested_min = int(min_words)
    except (TypeError, ValueError):
        requested_min = 0
    if requested_min <= 0:
        requested_min = 250 if criterion_key == "task_response" else 150

    # Empty or very short essays are never sent to the model.
    if word_count < MIN_ESSAY_WORDS:
        return _short_essay_result(
            essay_text,
            min_words=requested_min,
            criterion_key=criterion_key,
            word_count=word_count,
        )

    data: Any = None
    try:
        data = await asyncio.wait_for(
            AIService._llm_json(
                _SYSTEM_PROMPT,
                _build_user_prompt(
                    task_number=task_number,
                    prompt_text=prompt_text,
                    essay=essay_text,
                    word_count=word_count,
                    min_words=requested_min,
                    criterion_key=criterion_key,
                ),
                max_tokens=1200,
                temperature=0.2,
            ),
            timeout=45.0,
        )
    except Exception as exc:  # noqa: BLE001 - never break the exam flow
        logger.warning("IELTS writing LLM call failed, using heuristic: %s", exc)
        data = None

    result = _normalise_llm_result(
        data,
        essay=essay_text,
        word_count=word_count,
        criterion_key=criterion_key,
        min_words=requested_min,
    )
    if result is not None:
        logger.info(
            "IELTS writing evaluated by LLM: task=%s words=%s band=%s",
            _task_label(task_number),
            word_count,
            result["band"],
        )
        return result

    logger.warning(
        "No usable LLM evaluation for IELTS writing (task=%s); using heuristic",
        _task_label(task_number),
    )
    return _heuristic_impl(essay_text, requested_min, criterion_key)


__all__ = ["evaluate_ielts_writing", "heuristic_writing_band"]
