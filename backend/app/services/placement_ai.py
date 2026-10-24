"""AI-assisted rubric scoring for the productive placement skills.

Writing and speaking are not scored with the IRT bank.  They use a CEFR-aligned
5-point rubric, with a deterministic local fallback so the product still works
when the LLM or STT providers are unavailable.
"""

from __future__ import annotations

import logging
import re
from typing import Any, Optional

from .ai_service import AIService
from .placement_engine import clamp, level_from_theta, rubric_to_theta
from .speech_service import SpeechAIService

logger = logging.getLogger(__name__)

_WRITING_CRITERIA = (
    "task_achievement",
    "coherence_cohesion",
    "lexical_resource",
    "grammar_accuracy",
)
_SPEAKING_CRITERIA = (
    "pronunciation",
    "fluency_coherence",
    "lexical_resource",
    "grammar_range",
    "task_response",
)


def _valid_level(value: Any) -> str:
    level = str(value or "").strip().upper()
    return level if level in {"A1", "A2", "B1", "B2", "C1", "C2"} else "B1"


def _round_half(value: Any) -> float:
    try:
        return round(clamp(float(value), 0.0, 5.0) * 2) / 2
    except Exception:
        return 0.0


def _normalise_criteria(raw: Any, keys: tuple[str, ...]) -> dict[str, float]:
    raw = raw if isinstance(raw, dict) else {}
    return {key: _round_half(raw.get(key, 0)) for key in keys}


def _word_count(text: str) -> int:
    return len(re.findall(r"\b[\w'-]+\b", text or ""))


class PlacementAIService:
    """Rubric evaluators with graceful degradation."""

    # ── Writing ────────────────────────────────────────────────

    @classmethod
    async def evaluate_writing(
        cls,
        task: dict[str, Any],
        text: str,
        user_level: str = "B1",
    ) -> dict[str, Any]:
        word_count = _word_count(text)
        min_words = int(task.get("min_words") or 0)
        prompt = str(task.get("prompt") or task.get("title") or "Writing task")

        if word_count < 15:
            return cls._low_writing_result(
                "Bài viết quá ngắn để đánh giá. Hãy viết tối thiểu "
                f"{max(15, min_words)} từ và nêu rõ ý chính.",
                word_count,
                task,
                engine="guard",
            )

        system_prompt = (
            "You are a certified CEFR writing examiner. Assess the response "
            "against the CEFR Companion Volume. Reply with ONE valid JSON "
            "object only, without markdown."
        )
        user_prompt = (
            f"Task: {prompt}\n"
            f"Target CEFR level: {task.get('level', user_level)}\n"
            f"Word limit: {task.get('min_words', 80)}-{task.get('max_words', 300)} words\n"
            f"Learner response ({word_count} words):\n\"\"\"{text}\"\"\"\n\n"
            "Return JSON with exactly these keys:\n"
            "cefr_level: one of A1,A2,B1,B2,C1,C2;\n"
            "criteria: an object with task_achievement, coherence_cohesion, "
            "lexical_resource, grammar_accuracy, each a number from 0 to 5 "
            "(0.5 increments allowed);\n"
            "strengths: a list of 2-3 short Vietnamese sentences;\n"
            "improvements: a list of 2-3 short Vietnamese sentences, each "
            "actionable and specific to this response;\n"
            "feedback: 2-4 Vietnamese sentences summarising the performance;\n"
            "corrected_excerpts: a list of at most 3 objects with original, "
            "correction, explanation_vi. Only include real errors copied exactly "
            "from the response; use an empty list if there are none."
        )

        data: Optional[dict[str, Any]] = None
        try:
            data = await AIService._llm_json(
                system_prompt, user_prompt, max_tokens=900, temperature=0.2
            )
        except Exception as exc:
            logger.warning("Placement writing AI evaluation failed: %s", exc)

        if data and isinstance(data.get("criteria"), dict):
            criteria = _normalise_criteria(data.get("criteria"), _WRITING_CRITERIA)
            average = sum(criteria.values()) / len(criteria)
            theta, se = rubric_to_theta(criteria)
            cefr = _valid_level(data.get("cefr_level") or level_from_theta(theta))
            return {
                "criteria": criteria,
                "average": round(average, 2),
                "cefr": cefr,
                "theta": theta,
                "se": se,
                "feedback": str(data.get("feedback") or "").strip(),
                "strengths": [str(v) for v in (data.get("strengths") or [])][:4],
                "improvements": [str(v) for v in (data.get("improvements") or [])][:4],
                "corrected_excerpts": list(data.get("corrected_excerpts") or [])[:3],
                "word_count": word_count,
                "within_word_limit": (
                    not min_words or word_count >= min_words
                ) and word_count <= int(task.get("max_words") or 10000),
                "engine": "ai",
            }

        return await cls._fallback_writing(task, text, user_level, word_count)

    @classmethod
    async def _fallback_writing(
        cls,
        task: dict[str, Any],
        text: str,
        user_level: str,
        word_count: int,
    ) -> dict[str, Any]:
        try:
            legacy = await AIService.evaluate_writing(
                user_text=text,
                topic=str(task.get("prompt") or task.get("title") or ""),
                user_level=user_level,
            )
        except Exception:
            legacy = {}

        score = float(legacy.get("overall_score") or 55.0)
        base = clamp(score / 20.0, 0.0, 5.0)
        grammar_errors = list(legacy.get("grammar_feedback") or [])
        vocab_suggestions = list(legacy.get("vocab_suggestions") or [])
        criteria = {
            "task_achievement": _round_half(base),
            "coherence_cohesion": _round_half(base - 0.2),
            "lexical_resource": _round_half(base - 0.1),
            "grammar_accuracy": _round_half(
                base - 0.15 - min(len(grammar_errors) * 0.25, 1.0)
            ),
        }
        theta, se = rubric_to_theta(criteria)
        cefr = _valid_level(legacy.get("cefr_level") or level_from_theta(theta))
        improvements = []
        for error in grammar_errors[:2]:
            improvements.append(
                f"Sửa lỗi “{error.get('error', '')}” thành “{error.get('correction', '')}”: "
                f"{error.get('rule', '')}"
            )
        for suggestion in vocab_suggestions[:2]:
            alternatives = ", ".join(suggestion.get("advanced_alternatives") or [])
            improvements.append(
                f"Thay “{suggestion.get('original', '')}” bằng {alternatives}."
            )
        if not improvements:
            improvements = [
                "Bổ sung ví dụ cụ thể để làm rõ luận điểm.",
                "Dùng thêm từ nối để liên kết đoạn văn mạch lạc hơn.",
            ]

        return {
            "criteria": criteria,
            "average": round(sum(criteria.values()) / len(criteria), 2),
            "cefr": cefr,
            "theta": theta,
            "se": se,
            "feedback": str(
                legacy.get("general_comment")
                or "Bài viết đã được chấm bằng bộ tiêu chí ước lượng. "
                "Hãy bật mô hình AI để nhận phản hồi chi tiết hơn."
            ),
            "strengths": [
                f"Hoàn thành bài viết với {word_count} từ.",
                "Có ý tưởng chính rõ ràng để người đọc theo dõi.",
            ],
            "improvements": improvements[:3],
            "corrected_excerpts": [],
            "word_count": word_count,
            "within_word_limit": (
                not int(task.get("min_words") or 0)
                or word_count >= int(task.get("min_words") or 0)
            ) and word_count <= int(task.get("max_words") or 10000),
            "engine": "fallback",
        }

    @classmethod
    def _low_writing_result(
        cls,
        feedback: str,
        word_count: int,
        task: dict[str, Any],
        engine: str,
    ) -> dict[str, Any]:
        criteria = {key: 0.0 for key in _WRITING_CRITERIA}
        theta, se = rubric_to_theta(criteria)
        return {
            "criteria": criteria,
            "average": 0.0,
            "cefr": "A1",
            "theta": theta,
            "se": se,
            "feedback": feedback,
            "strengths": [],
            "improvements": [
                f"Viết tối thiểu {task.get('min_words', 80)} từ.",
                "Trả lời trực tiếp từng phần của đề bài.",
            ],
            "corrected_excerpts": [],
            "word_count": word_count,
            "within_word_limit": False,
            "engine": engine,
        }

    # ── Speaking ───────────────────────────────────────────────

    @classmethod
    async def evaluate_speaking(
        cls,
        task: dict[str, Any],
        audio_data: bytes,
        filename: str = "answer.webm",
        content_type: str = "audio/webm",
        user_level: str = "B1",
    ) -> dict[str, Any]:
        file_format = "wav"
        if filename and "." in filename:
            extension = filename.rsplit(".", 1)[-1].lower()
            if extension in {"mp3", "webm", "ogg", "m4a", "wav"}:
                file_format = extension

        reference_text = str(task.get("reference_text") or "").strip()
        transcript = ""
        pronunciation_score: Optional[float] = None
        pronunciation_feedback = ""
        pronunciation_tips: list[str] = []

        try:
            if reference_text:
                assessment = await SpeechAIService.assess_pronunciation(
                    audio_data=audio_data,
                    reference_text=reference_text,
                    user_level=user_level,
                    file_format=file_format,
                )
                transcript = str(assessment.get("recognised_text") or "").strip()
                pronunciation_score = float(assessment.get("overall_score") or 0.0)
                pronunciation_feedback = str(assessment.get("feedback") or "")
                pronunciation_tips = list(assessment.get("improvement_tips") or [])
                if not assessment.get("scored", True):
                    return cls._empty_speaking_result(
                        "Chưa nghe rõ giọng nói. Hãy thu âm lại trong môi trường yên tĩnh, "
                        "nói to và rõ hơn.",
                        task,
                        pronunciation_score=pronunciation_score,
                    )
            else:
                stt = await SpeechAIService.transcribe_audio(
                    audio_data=audio_data,
                    language="en-US",
                    file_format=file_format,
                    assessment_mode=True,
                )
                transcript = str(stt.get("transcript") or "").strip()
        except Exception as exc:
            logger.warning("Placement speaking transcription failed: %s", exc)

        if not transcript:
            return cls._empty_speaking_result(
                "Không nhận diện được nội dung bài nói. Hãy kiểm tra micro và thu âm lại.",
                task,
                pronunciation_score=pronunciation_score,
            )

        system_prompt = (
            "You are a certified CEFR speaking examiner. Assess the transcript "
            "against the CEFR Companion Volume. Reply with ONE valid JSON object "
            "only, without markdown."
        )
        user_prompt = (
            f"Task: {task.get('prompt', '')}\n"
            f"Task type: {task.get('type', 'monologue')}\n"
            f"Target CEFR level: {task.get('level', user_level)}\n"
            f"Response time: {task.get('response_seconds', 60)} seconds\n"
            f"Candidate transcript:\n\"\"\"{transcript}\"\"\"\n\n"
            "Return JSON with exactly these keys:\n"
            "cefr_level: one of A1,A2,B1,B2,C1,C2;\n"
            "criteria: an object with pronunciation, fluency_coherence, "
            "lexical_resource, grammar_range, task_response, each 0-5 "
            "(0.5 increments allowed);\n"
            "strengths: a list of 2-3 short Vietnamese sentences;\n"
            "improvements: a list of 2-3 actionable Vietnamese sentences;\n"
            "feedback: 2-4 Vietnamese sentences summarising the performance."
        )

        data: Optional[dict[str, Any]] = None
        try:
            data = await AIService._llm_json(
                system_prompt, user_prompt, max_tokens=800, temperature=0.2
            )
        except Exception as exc:
            logger.warning("Placement speaking AI evaluation failed: %s", exc)

        if data and isinstance(data.get("criteria"), dict):
            criteria = _normalise_criteria(data.get("criteria"), _SPEAKING_CRITERIA)
            engine = "ai"
            cefr = _valid_level(data.get("cefr_level"))
            feedback = str(data.get("feedback") or "").strip()
            strengths = [str(v) for v in (data.get("strengths") or [])][:4]
            improvements = [str(v) for v in (data.get("improvements") or [])][:4]
        else:
            criteria, cefr, feedback, strengths, improvements = cls._heuristic_speaking(
                task, transcript, pronunciation_score
            )
            engine = "fallback"

        if pronunciation_score is not None:
            criteria["pronunciation"] = _round_half(pronunciation_score / 20.0)
            if pronunciation_feedback:
                feedback = (feedback + " " + pronunciation_feedback).strip()
            if pronunciation_tips:
                improvements = (improvements + pronunciation_tips)[:4]

        theta, se = rubric_to_theta(criteria)
        if engine == "fallback":
            cefr = level_from_theta(theta)

        return {
            "criteria": criteria,
            "average": round(sum(criteria.values()) / len(criteria), 2),
            "cefr": cefr,
            "theta": theta,
            "se": se,
            "feedback": feedback,
            "strengths": strengths,
            "improvements": improvements,
            "transcript": transcript,
            "pronunciation_score": pronunciation_score,
            "word_count": _word_count(transcript),
            "engine": engine,
        }

    @classmethod
    def _heuristic_speaking(
        cls,
        task: dict[str, Any],
        transcript: str,
        pronunciation_score: Optional[float],
    ) -> tuple[dict[str, float], str, str, list[str], list[str]]:
        words = re.findall(r"\b[\w'-]+\b", transcript.lower())
        count = len(words)
        unique_ratio = len(set(words)) / max(count, 1)
        response_seconds = max(int(task.get("response_seconds") or 60), 20)
        expected_words = max(response_seconds * 1.6, 60)

        fluency = clamp((count / expected_words) * 4.2, 0.5, 5.0)
        lexical = clamp(unique_ratio * 7.0, 0.5, 5.0)
        grammar = 2.5
        task_response = clamp((count / max(expected_words * 0.55, 30)) * 4.0, 0.5, 5.0)
        pronunciation = (
            clamp(pronunciation_score / 20.0, 0.0, 5.0)
            if pronunciation_score is not None
            else 2.5
        )
        criteria = {
            "pronunciation": _round_half(pronunciation),
            "fluency_coherence": _round_half(fluency),
            "lexical_resource": _round_half(lexical),
            "grammar_range": _round_half(grammar),
            "task_response": _round_half(task_response),
        }
        theta, _ = rubric_to_theta(criteria)
        cefr = level_from_theta(theta)
        feedback = (
            f" Bài nói có {count} từ. Hệ thống đang chấm bằng tiêu chí ước lượng; "
            "hãy bật mô hình AI để nhận đánh giá ngữ pháp và từ vựng chi tiết hơn."
        )
        strengths = []
        if count >= 40:
            strengths.append("Duy trì được bài nói đủ dài để truyền đạt ý chính.")
        if unique_ratio >= 0.5:
            strengths.append("Sử dụng từ vựng đa dạng, ít lặp lại.")
        improvements = []
        if count < expected_words * 0.5:
            improvements.append("Phát triển thêm ý và ví dụ để bài nói dài hơn.")
        if pronunciation_score is not None and pronunciation_score < 70:
            improvements.append("Luyện phát âm trọng âm và âm cuối của từ.")
        improvements.append("Dùng từ nối để liên kết các ý mạch lạc hơn.")
        return criteria, cefr, feedback.strip(), strengths, improvements

    @classmethod
    def skipped_speaking_result(cls, task: dict[str, Any]) -> dict[str, Any]:
        """Deterministic zero-score payload used when a candidate skips."""
        result = cls._empty_speaking_result(
            "Bạn đã bỏ qua nhiệm vụ nói này. Hãy luyện lại và làm bài kiểm tra sau.",
            task,
        )
        result["engine"] = "skipped"
        return result

    @classmethod
    def _empty_speaking_result(
        cls,
        feedback: str,
        task: dict[str, Any],
        pronunciation_score: Optional[float] = None,
    ) -> dict[str, Any]:
        criteria = {key: 0.0 for key in _SPEAKING_CRITERIA}
        theta, se = rubric_to_theta(criteria)
        return {
            "criteria": criteria,
            "average": 0.0,
            "cefr": "A1",
            "theta": theta,
            "se": se,
            "feedback": feedback,
            "strengths": [],
            "improvements": [
                "Thu âm lại trong không gian yên tĩnh.",
                "Nói to, rõ và hướng micro về phía miệng.",
            ],
            "transcript": "",
            "pronunciation_score": pronunciation_score,
            "word_count": 0,
            "engine": "guard",
        }
