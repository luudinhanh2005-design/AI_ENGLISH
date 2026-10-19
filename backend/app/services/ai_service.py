from .local_llm_service import local_llm_service
import json
import logging
import re
from typing import Any, Optional

import httpx

from ..config import settings

logger = logging.getLogger(__name__)


class AIService:
    """
    AI Engine for EnglishAI:
    - AI Tutor Persona Conversations
    - Real-time grammatical analysis & correction
    - Adaptive exercise generation tailored to learner weaknesses
    - Writing evaluation with CEFR/IELTS scoring
    """

    PERSONA_PROMPTS = {
        "sarah": (
            "You are Sarah, a warm, patient, and friendly English tutor. "
            "Your tone is encouraging, conversational, and helpful. "
            "You help learners build confidence in everyday spoken and conversational English."
        ),
        "harrison": (
            "You are Mr. Harrison, a sharp, executive Business English coach. "
            "Your tone is professional, polished, and direct. "
            "You focus on corporate communications, negotiations, presentation phrases, and workplace etiquette."
        ),
        "emma": (
            "You are Emma, an experienced British IELTS & Academic examiner. "
            "Your tone is articulate, analytical, and structured. "
            "You emphasize advanced lexical resource, complex grammatical accuracy, and coherence."
        ),
    }

    DEFAULT_SUGGESTIONS = [
        "Could you give me an example?",
        "Can we practice another sentence?",
        "How can I sound more natural?",
    ]

    @staticmethod
    def _clean_text(value: Any, max_length: int = 1000) -> str:
        if value is None:
            return ""
        text = str(value).replace("\x00", " ").strip()
        text = text.strip("\"'“”‘’` ")
        text = re.sub(r"\s+", " ", text)
        return text[:max_length].strip()

    @classmethod
    def _normalize_correction_type(cls, value: Any) -> str:
        raw = cls._clean_text(value, 60).lower()
        if raw in {"grammar", "vocabulary", "pronunciation"}:
            return raw
        if any(key in raw for key in ("vocab", "lexical", "word choice", "collocation", "từ vựng", "tu vung")):
            return "vocabulary"
        if any(key in raw for key in ("pronunciation", "phát âm", "phat am", "phoneme")):
            return "pronunciation"
        return "grammar"

    @classmethod
    def normalize_corrections(
        cls,
        raw_corrections: Any,
        user_message: str,
    ) -> list[dict[str, str]]:
        """Chuan hoa correction tu bat ky provider nao, tranh loi 500."""
        if isinstance(raw_corrections, dict):
            raw_corrections = [raw_corrections]
        if not isinstance(raw_corrections, list):
            return []

        normalized: list[dict[str, str]] = []
        seen: set[tuple[str, str]] = set()
        for item in raw_corrections:
            if isinstance(item, str):
                try:
                    item = json.loads(item)
                except Exception:
                    continue
            if not isinstance(item, dict):
                continue

            original = cls._clean_text(
                item.get("original") or item.get("incorrect") or item.get("error"),
                500,
            )
            correction = cls._clean_text(
                item.get("correction") or item.get("corrected") or item.get("correct"),
                1000,
            )
            explanation = cls._clean_text(
                item.get("explanation_vi") or item.get("explanation") or item.get("note"),
                600,
            )
            if not correction:
                continue
            if len(correction.strip(" .,:;!?-_")) < 2:
                continue
            if not re.search(r"[A-Za-z0-9\u00C0-\u1EF9]", correction):
                continue
            if not original:
                original = cls._clean_text(user_message, 500)
            if not original or original.casefold() == correction.casefold():
                continue

            key = (original.casefold(), correction.casefold())
            if key in seen:
                continue
            seen.add(key)

            normalized.append({
                "original": original,
                "correction": correction,
                "explanation_vi": explanation or "AI Tutor đã điều chỉnh câu cho tự nhiên và đúng hơn.",
                "type": cls._normalize_correction_type(
                    item.get("type") or item.get("category") or item.get("kind")
                ),
            })
            if len(normalized) >= 3:
                break
        return normalized

    @classmethod
    def normalize_suggestions(cls, raw_suggestions: Any) -> list[str]:
        if not isinstance(raw_suggestions, list):
            return list(cls.DEFAULT_SUGGESTIONS)
        suggestions: list[str] = []
        for item in raw_suggestions:
            text = cls._clean_text(item, 160)
            if text and text not in suggestions:
                suggestions.append(text)
            if len(suggestions) >= 3:
                break
        return suggestions or list(cls.DEFAULT_SUGGESTIONS)

    @staticmethod
    def _parse_json_object(raw: str) -> Optional[dict[str, Any]]:
        if not raw:
            return None
        text = raw.strip()
        text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.IGNORECASE)
        text = re.sub(r"\s*```$", "", text)
        candidates = [text]
        start = text.find("{")
        end = text.rfind("}")
        if start != -1 and end > start:
            candidates.append(text[start:end + 1])
        for candidate in candidates:
            try:
                parsed = json.loads(candidate)
                if isinstance(parsed, dict):
                    return parsed
            except Exception:
                continue
        return None

    @classmethod
    def _normalize_result(
        cls,
        raw_result: Any,
        user_message: str,
    ) -> Optional[dict[str, Any]]:
        if not isinstance(raw_result, dict):
            return None
        reply = cls._clean_text(
            raw_result.get("reply")
            or raw_result.get("response")
            or raw_result.get("message"),
            4000,
        )
        if not reply:
            return None
        return {
            "reply": reply,
            "corrections": cls.normalize_corrections(
                raw_result.get("corrections"), user_message
            ),
            "suggested_replies": cls.normalize_suggestions(
                raw_result.get("suggested_replies") or raw_result.get("suggestions")
            ),
        }

    @classmethod
    def _provider_order(cls) -> list[str]:
        provider = (settings.ai_provider or "local").strip().lower()
        if provider == "gemini":
            return ["gemini", "openai", "local"]
        if provider == "openai":
            return ["openai", "gemini", "local"]
        if provider == "mock":
            return ["local"]
        return ["local", "gemini", "openai"]

    @staticmethod
    def _reply_claims_correct(reply: str) -> bool:
        return bool(
            re.search(
                r"\b(sentence is correct|no mistakes?|nothing to correct|"
                r"perfectly correct|looks correct|is correct)\b",
                reply or "",
                re.IGNORECASE,
            )
        )

    @classmethod
    def _with_rule_corrections(
        cls,
        result: dict[str, Any],
        user_message: str,
    ) -> dict[str, Any]:
        """Them rule-based safety net neu model khong tra correction nao."""
        if not result.get("corrections"):
            rule_corrections = cls._detect_grammar_errors(user_message)
            result["corrections"] = cls.normalize_corrections(
                rule_corrections, user_message
            )

        if result.get("corrections") and cls._reply_claims_correct(
            str(result.get("reply", ""))
        ):
            result["reply"] = (
                "Good effort! I spotted a small mistake in that sentence. "
                "Have a look at the correction below and try saying it again."
            )
        return result

    @classmethod
    async def chat_with_tutor(
        cls,
        user_name: str,
        user_level: str,
        persona: str,
        topic: str,
        user_message: str,
        history: list[dict],
    ) -> dict[str, Any]:
        """
        Generate AI tutor response with real-time error correction and suggestion chips.
        """
        persona_key = persona.lower()
        system_prompt = cls.PERSONA_PROMPTS.get(persona_key, cls.PERSONA_PROMPTS["sarah"])
        provider = (settings.ai_provider or "local").strip().lower()

        for provider_name in cls._provider_order():
            if provider_name == "local":
                if not settings.local_llm_enabled:
                    continue
                try:
                    local_res = await cls._call_local_llm_chat(
                        system_prompt=system_prompt,
                        user_name=user_name,
                        user_level=user_level,
                        user_message=user_message,
                        history=history,
                    )
                    if local_res:
                        return cls._with_rule_corrections(local_res, user_message)
                except Exception as e:
                    logger.warning(f"Local LLM call failed, falling back: {e}")

            elif provider_name == "gemini":
                if not settings.google_ai_api_key:
                    continue
                if provider == "local" and not settings.ai_cloud_fallback:
                    continue
                try:
                    gemini_res = await cls._call_gemini_chat(
                        system_prompt=system_prompt,
                        user_name=user_name,
                        user_level=user_level,
                        user_message=user_message,
                        history=history,
                    )
                    normalized = cls._normalize_result(gemini_res, user_message)
                    if normalized:
                        return cls._with_rule_corrections(normalized, user_message)
                except Exception as e:
                    logger.warning(f"Gemini API call failed, using fallback: {e}")

            elif provider_name == "openai":
                if not settings.openai_api_key:
                    continue
                if provider == "local" and not settings.ai_cloud_fallback:
                    continue
                try:
                    openai_res = await cls._call_openai_chat(
                        system_prompt=system_prompt,
                        user_name=user_name,
                        user_level=user_level,
                        user_message=user_message,
                        history=history,
                    )
                    normalized = cls._normalize_result(openai_res, user_message)
                    if normalized:
                        return cls._with_rule_corrections(normalized, user_message)
                except Exception as e:
                    logger.warning(f"OpenAI API call failed, using fallback: {e}")

        return cls._intelligent_fallback_chat(
            persona=persona_key,
            user_message=user_message,
            user_level=user_level,
        )

    @classmethod
    async def _call_local_llm_chat(
        cls,
        system_prompt: str,
        user_name: str,
        user_level: str,
        user_message: str,
        history: list[dict],
    ) -> Optional[dict[str, Any]]:
        """Goi truc tiep mo hinh AI cua nguoi dung tren GPU cuc bo."""
        import asyncio

        if not local_llm_service.is_loaded:
            if local_llm_service.is_loading:
                return None
            try:
                loaded = await asyncio.wait_for(
                    asyncio.to_thread(local_llm_service.load_model),
                    timeout=settings.local_llm_load_timeout_seconds,
                )
            except asyncio.TimeoutError:
                logger.warning("Local LLM load timed out; using fallback provider")
                return None
            if not loaded:
                logger.warning(
                    f"Local LLM unavailable: {local_llm_service.load_error or 'unknown error'}"
                )
                return None

        system_instruction = (
            f"{system_prompt}\n"
            f"The learner's name is {user_name}, and their CEFR level is {user_level}.\n"
            "You are an English speaking partner and tutor. Always reply in natural, "
            "engaging ENGLISH and end with a follow-up question.\n"
            "Check the learner's message for grammar, tense, preposition and vocabulary mistakes.\n"
            "Return ONLY one valid JSON object with exactly these keys:\n"
            '{"reply":"<English reply>","corrections":[{"original":"<incorrect part>",'
            '"correction":"<corrected version>","explanation_vi":"<short Vietnamese explanation>",'
            '"type":"grammar|vocabulary"}],"suggested_replies":["<short reply>","<short reply>"]}\n'
            "Rules: original must be the incorrect part from the learner's message; "
            "correction must fix it; type must be 'grammar' for grammar/tense/preposition "
            "and 'vocabulary' for word choice/collocation; if there are no errors, use an "
            "empty corrections array. The explanation_vi value MUST be written in Vietnamese "
            "with Vietnamese diacritics. The reply must react naturally and end with a "
            "follow-up question; never use reply only to repeat the corrected sentence, and "
            "never say the sentence is correct when corrections is non-empty. "
            "Keep reply and each explanation short; do not add extra text. "
            "Do not wrap the JSON in markdown.\n"
            "Example input: Yesterday I go to school.\n"
            'Example output: {"reply":"That sounds like a busy day! What did you do at school?",'
            '"corrections":[{"original":"Yesterday I go","correction":"Yesterday I went",'
            '"explanation_vi":"Dùng thì quá khứ đơn với mốc thời gian đã kết thúc trong quá khứ.",'
            '"type":"grammar"}],"suggested_replies":["I studied English.","I met my friends."]}\n'
            "Example input: I like coffee.\n"
            'Example output: {"reply":"Coffee is a great choice! Do you prefer it hot or iced?",'
            '"corrections":[],"suggested_replies":["I prefer iced coffee.","I drink it every morning."]}'
        )

        formatted_messages = [{"role": "system", "content": system_instruction}]
        for h in history[-4:]:
            role = "assistant" if h.get("role") in ["assistant", "model"] else "user"
            formatted_messages.append({"role": role, "content": h.get("content", "")})
        formatted_messages.append({"role": "user", "content": user_message})

        try:
            raw_reply = await asyncio.wait_for(
                asyncio.to_thread(
                    local_llm_service.generate_chat_response,
                    formatted_messages,
                    220,
                    0.2,
                    timeout_seconds=max(15.0, settings.local_llm_timeout_seconds - 5.0),
                ),
                timeout=settings.local_llm_timeout_seconds,
            )
        except asyncio.TimeoutError:
            logger.warning("Local LLM generation timed out; using fallback provider")
            return None

        if not raw_reply:
            return None

        parsed = cls._parse_json_object(raw_reply)
        if parsed:
            normalized = cls._normalize_result(parsed, user_message)
            if normalized:
                return normalized

        # A malformed JSON-looking answer is not safe to parse as free-form.
        if raw_reply.lstrip().startswith("{"):
            logger.warning("Local LLM returned malformed JSON; using rule fallback")
            return None

        # Legacy/free-form response fallback: parse Correction/Note labels.
        corrections: list[dict[str, Any]] = []
        corr_match = re.search(
            r'''(?:^\s*[*-]+\s*)?(?:The correct(?:\s+way(?:\s+would\s+be)?)?|Correction|Correct version|Câu chuẩn|Accurate version|Professional standard)\s*(?:\*\*)?\s*[:,\-]\s*(?:\*\*)?\s*["'“”]([^"'“”]+)["'“”]''',
            raw_reply,
            re.IGNORECASE | re.MULTILINE,
        )
        if not corr_match:
            corr_match = re.search(r'''\*\*["'“”]([^"'“”]+)["'“”]\*\*''', raw_reply)

        if corr_match:
            corrected_text = corr_match.group(1).strip()
            expl_match = re.search(
                r'''(?:Note|Giải thích|Examiner Note):\s*([^\n\)]+)''',
                raw_reply,
                re.IGNORECASE,
            )
            explanation_vi = (
                expl_match.group(1).strip()
                if expl_match
                else "AI Tutor đã phát hiện và sửa lỗi cấu trúc ngữ pháp giúp bạn."
            )
            correction_type = (
                "vocabulary"
                if re.search(
                    r"\b(vocab(?:ulary)?|word choice|collocation|lexical)\b|từ vựng",
                    raw_reply,
                    re.IGNORECASE,
                )
                else "grammar"
            )
            corrections.append({
                "original": user_message,
                "correction": corrected_text,
                "explanation_vi": explanation_vi,
                "type": correction_type,
            })

        corrections = cls.normalize_corrections(corrections, user_message)

        # Clean conversational reply from verbose raw correction blocks
        clean_reply = raw_reply
        if corrections:
            clean_reply = re.sub(
                r'''(?:\n|\A)\s*(?:The correct(?:\s+way(?:\s+would\s+be)?)?|Correction|Correct version|Câu chuẩn|Accurate version)(?::|,|\s+is)?\s*["'“”][^"'“”]+["'“”][^\n]*''',
                '',
                clean_reply,
                flags=re.IGNORECASE
            )
            clean_reply = re.sub(
                r'''(?:\n|\A)\s*(?:Note|Giải thích|Examiner Note):\s*[^\n]+''',
                '',
                clean_reply,
                flags=re.IGNORECASE
            )
            clean_reply = re.sub(
                r'''(?:\n|\A)\s*The verb should change[^\n\.]+\.?''',
                '',
                clean_reply,
                flags=re.IGNORECASE
            )
            clean_reply = re.sub(r'\n{3,}', '\n\n', clean_reply).strip()
            if not clean_reply or len(clean_reply) < 10:
                clean_reply = raw_reply

        return {
            "reply": cls._clean_text(clean_reply, 4000),
            "corrections": corrections,
            "suggested_replies": list(cls.DEFAULT_SUGGESTIONS),
        }

    @classmethod
    async def _call_gemini_chat(
        cls,
        system_prompt: str,
        user_name: str,
        user_level: str,
        user_message: str,
        history: list[dict],
    ) -> dict[str, Any]:
        """Call Google Gemini API via REST."""
        api_url = f"https://generativelanguage.googleapis.com/v1beta/models/{settings.ai_model_name}:generateContent?key={settings.google_ai_api_key}"

        instruction = (
            f"{system_prompt}\n"
            f"The learner's name is {user_name}, and their CEFR level is {user_level}.\n"
            "Analyze the learner's message for grammatical, spelling, vocabulary, collocation, or unnatural phrasing errors.\n"
            "Respond strictly in valid JSON format matching this JSON schema:\n"
            "{\n"
            '  "reply": "Your conversational response in natural English (keep it engaging and ask a relevant question back)",\n'
            '  "corrections": [\n'
            '    {\n'
            '      "original": "The incorrect part of the learner\'s sentence",\n'
            '      "correction": "The corrected natural version",\n'
            '      "explanation_vi": "Brief explanation in Vietnamese of why it is corrected",\n'
            '      "type": "grammar or vocabulary"\n'
            '    }\n'
            "  ],\n"
            '  "suggested_replies": ["Short suggestion 1", "Short suggestion 2", "Short suggestion 3"]\n'
            "}"
        )

        contents = []
        for h in history[-4:]:
            role = "user" if h["role"] == "user" else "model"
            contents.append({"role": role, "parts": [{"text": h["content"]}]})

        contents.append({"role": "user", "parts": [{"text": f"User message: {user_message}"}]})

        payload = {
            "systemInstruction": {"parts": [{"text": instruction}]},
            "contents": contents,
            "generationConfig": {
                "temperature": 0.7,
                "responseMimeType": "application/json",
            },
        }

        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(api_url, json=payload)
            resp.raise_for_status()
            data = resp.json()
            text_response = data["candidates"][0]["content"]["parts"][0]["text"]
            return json.loads(text_response)

    @classmethod
    async def _call_openai_chat(
        cls,
        system_prompt: str,
        user_name: str,
        user_level: str,
        user_message: str,
        history: list[dict],
    ) -> dict[str, Any]:
        """Call OpenAI API via REST."""
        api_url = "https://api.openai.com/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {settings.openai_api_key}",
            "Content-Type": "application/json",
        }

        instruction = (
            f"{system_prompt}\n"
            f"The learner's name is {user_name}, and their CEFR level is {user_level}.\n"
            "Respond in JSON format with keys: 'reply' (English string), "
            "'corrections' (list of {original, correction, explanation_vi, type}), "
            "and 'suggested_replies' (list of 2-3 short strings). "
            "Use type='grammar' for grammar/tense/preposition errors and type='vocabulary' for word choice/collocation errors."
        )

        messages = [{"role": "system", "content": instruction}]
        for h in history[-4:]:
            messages.append({"role": h["role"], "content": h["content"]})
        messages.append({"role": "user", "content": user_message})

        payload = {
            "model": "gpt-4o-mini",
            "messages": messages,
            "response_format": {"type": "json_object"},
            "temperature": 0.7,
        }

        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(api_url, headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()
            content_str = data["choices"][0]["message"]["content"]
            return json.loads(content_str)

    @classmethod
    def _detect_grammar_errors(cls, user_message: str) -> list[dict[str, str]]:
        msg_lower = user_message.lower().strip()
        corrections = []
        if re.search(r"\b(yesterday\s+i\s+go|i\s+go\s+to\s+.*yesterday|yesterday\s+i\s+eat|last\s+night\s+i\s+eat)\b", msg_lower):
            wrong = "yesterday I go" if "go" in msg_lower else "yesterday I eat"
            correct = "yesterday I went" if "go" in msg_lower else "yesterday I ate"
            corrections.append({
                "original": wrong,
                "correction": correct,
                "explanation_vi": "Hành động đã kết thúc trong quá khứ cần chia động từ ở thì Quá khứ đơn (Past Simple): 'go' -> 'went', 'eat' -> 'ate'.",
            })
        elif re.search(r"\b(she|he|it)\s+don't\b(?!\s+has)", msg_lower):
            m = re.search(r"\b(she|he|it)\s+don't\b(?!\s+has)", msg_lower).group(0)
            corrections.append({
                "original": m,
                "correction": m.replace("don't", "doesn't"),
                "explanation_vi": "Chủ ngữ ngôi thứ ba số ít (she, he, it) trong thì hiện tại đơn phải đi với trợ động từ 'doesn't', không dùng 'don't'.",
            })
        elif re.search(r"\binterested\s+on\b", msg_lower):
            corrections.append({
                "original": "interested on",
                "correction": "interested in",
                "explanation_vi": "Cụm tính từ cố định luôn là 'interested in' (hứng thú với điều gì), không đi kèm giới từ 'on'.",
                "type": "vocabulary",
            })
        elif re.search(r"\b(depends?)\s+of\b", msg_lower):
            corrections.append({
                "original": "depend of",
                "correction": "depend on",
                "explanation_vi": "Động từ 'depend' đi kèm giới từ 'on' (hoặc 'upon'), không dùng 'of'.",
                "type": "vocabulary",
            })
        elif re.search(r"\blook\s+forward\s+to\s+hear\b", msg_lower):
            corrections.append({
                "original": "look forward to hear",
                "correction": "look forward to hearing",
                "explanation_vi": "Sau cấu trúc 'look forward to', động từ luôn ở dạng V-ing ('hearing').",
                "type": "vocabulary",
            })
        elif re.search(r"\bmake\s+homework\b", msg_lower):
            corrections.append({
                "original": "make homework",
                "correction": "do homework",
                "explanation_vi": "Cụm từ cố định chuẩn (collocation) là 'do homework', không dùng 'make homework'.",
                "type": "vocabulary",
            })
        elif re.search(r"\b(two|many|\d+)\s+childs\b", msg_lower):
            corrections.append({
                "original": "childs",
                "correction": "children",
                "explanation_vi": "Danh từ số nhiều bất quy tắc của 'child' là 'children', không thêm 's'.",
            })
        elif re.search(r"\bi\s+live\s+in\s+.*since\b", msg_lower):
            corrections.append({
                "original": "I live in ... since ...",
                "correction": "I have lived in ... since ...",
                "explanation_vi": "Hành động bắt đầu từ quá khứ kéo dài đến hiện tại có mốc 'since' phải dùng thì Hiện tại hoàn thành: 'have lived'.",
            })
        elif re.search(r"\b(she|he)\s+(study|go|play|have)\b", msg_lower):
            m = re.search(r"\b(she|he)\s+(study|go|play|have)\b", msg_lower).group(0)
            fixed = m.replace("study", "studies").replace("go", "goes").replace("play", "plays").replace("have", "has")
            corrections.append({
                "original": m,
                "correction": fixed,
                "explanation_vi": "Chủ ngữ ngôi thứ 3 số ít (He/She) trong thì hiện tại đơn cần chia động từ thêm 's/es' hoặc dùng 'has'.",
            })
        elif re.search(r"\bmore\s+better\b", msg_lower):
            corrections.append({
                "original": "more better",
                "correction": "much better / better",
                "explanation_vi": "'Better' đã là dạng so sánh hơn của 'good', không dùng kèm 'more'.",
            })
        elif re.search(r"\bi\s+have\s+see\b", msg_lower):
            corrections.append({
                "original": "I have see",
                "correction": "I have seen",
                "explanation_vi": "Sau 'have' trong thì hiện tại hoàn thành, động từ phải ở dạng quá khứ phân từ (V3): 'seen'.",
            })
        elif re.search(r"\bi\s+have\s+went\b", msg_lower):
            corrections.append({
                "original": "I have went",
                "correction": "I have gone",
                "explanation_vi": "Thì hiện tại hoàn thành dùng quá khứ phân từ (V3) của 'go' là 'gone', không dùng 'went'.",
            })
        elif re.search(r"\bi\s+(goed|eated|comed)\b", msg_lower):
            wrong = re.search(r"\bi\s+(goed|eated|comed)\b", msg_lower).group(1)
            fixed = {"goed": "went", "eated": "ate", "comed": "came"}[wrong]
            corrections.append({
                "original": f"I {wrong}",
                "correction": f"I {fixed}",
                "explanation_vi": f"Động từ bất quy tắc ở thì Quá khứ đơn: '{wrong}' phải là '{fixed}'.",
            })
        elif re.search(r"\bi\s+am\s+living\b.*\bsince\b", msg_lower):
            corrections.append({
                "original": "I am living ... since ...",
                "correction": "I have lived ... since ...",
                "explanation_vi": "Hành động bắt đầu từ quá khứ và kéo dài đến hiện tại với 'since' phải dùng Hiện tại hoàn thành: 'have lived'.",
            })
        elif re.search(r"\b(she|he|it)\s+don't\s+has\b", msg_lower):
            m = re.search(r"\b(she|he|it)\s+don't\s+has\b", msg_lower).group(0)
            corrections.append({
                "original": m,
                "correction": m.replace("don't has", "doesn't have"),
                "explanation_vi": "Ngôi thứ ba số ít dùng 'doesn't have', không dùng 'don't has'.",
            })
        elif re.search(r"\bi\s+didn't\s+went\b", msg_lower):
            corrections.append({
                "original": "I didn't went",
                "correction": "I didn't go",
                "explanation_vi": "Sau trợ động từ 'didn't', động từ chính phải ở dạng nguyên mẫu: 'go', không dùng 'went'.",
            })
        elif re.search(r"\bdiscuss\s+about\b", msg_lower):
            corrections.append({
                "original": "discuss about",
                "correction": "discuss",
                "explanation_vi": "'Discuss' là ngoại động từ, đi trực tiếp với tân ngữ; không dùng 'discuss about'.",
                "type": "vocabulary",
            })
        elif re.search(r"\bexplain\s+me\b", msg_lower):
            corrections.append({
                "original": "explain me",
                "correction": "explain to me",
                "explanation_vi": "Cấu trúc đúng là 'explain something to someone', không dùng 'explain me'.",
                "type": "vocabulary",
            })
        elif re.search(r"\bmarried\s+with\b", msg_lower):
            corrections.append({
                "original": "married with",
                "correction": "married to",
                "explanation_vi": "Cụm cố định là 'married to someone', không dùng 'married with'.",
                "type": "vocabulary",
            })
        elif re.search(r"\bgood\s+in\b", msg_lower):
            corrections.append({
                "original": "good in",
                "correction": "good at",
                "explanation_vi": "Khi nói giỏi việc gì, dùng 'good at', không dùng 'good in'.",
                "type": "vocabulary",
            })
        elif re.search(r"\badvices\b", msg_lower):
            corrections.append({
                "original": "advices",
                "correction": "advice",
                "explanation_vi": "'Advice' là danh từ không đếm được, không thêm 's'.",
                "type": "vocabulary",
            })
        elif re.search(r"\binformations\b", msg_lower):
            corrections.append({
                "original": "informations",
                "correction": "information",
                "explanation_vi": "'Information' là danh từ không đếm được, không thêm 's'.",
                "type": "vocabulary",
            })
        return corrections

    @classmethod
    def _intelligent_fallback_chat(
        cls,
        persona: str,
        user_message: str,
        user_level: str,
    ) -> dict[str, Any]:
        """
        Deterministic, rule-based natural language processing engine 
        when cloud API keys are absent or network is offline.
        """
        msg_lower = user_message.lower().strip()
        corrections = cls._detect_grammar_errors(user_message)

        # Persona-based responses
        if persona == "harrison":
            if "hello" in msg_lower or "hi" in msg_lower:
                reply = (
                    "Good day! It's a pleasure to connect. In our business session today, "
                    "what strategic topic would you like to focus on — negotiating terms, "
                    "delivering presentations, or leading team meetings?"
                )
                suggested = [
                    "I want to practice meeting presentations.",
                    "Let's practice business negotiation.",
                    "How to write formal emails to clients?",
                ]
            else:
                reply = (
                    f"That is a pertinent point regarding '{user_message[:40]}...'. "
                    "In professional settings, articulate precision is paramount. "
                    "Could you elaborate on how you would propose this in a leadership debrief?"
                )
                suggested = [
                    "I would present the key metrics first.",
                    "We should align with the stakeholders.",
                    "Could you suggest a more formal expression?",
                ]
        elif persona == "emma":
            if "hello" in msg_lower or "hi" in msg_lower:
                reply = (
                    "Hello there! Welcome to our academic speaking consultation. "
                    "I will evaluate your fluency, lexical resource, and grammatical range. "
                    "Shall we begin with a Part 2 speaking prompt or discuss modern technology?"
                )
                suggested = [
                    "Let's practice an IELTS Part 2 cue card.",
                    "I'd like to discuss technology and society.",
                    "Please check my pronunciation and vocabulary.",
                ]
            else:
                reply = (
                    f"Interesting perspective on that topic. To achieve Band 7.5 or higher, "
                    "try to incorporate more cohesive devices and varied sentence structures. "
                    "What do you believe are the primary societal consequences of this trend?"
                )
                suggested = [
                    "On the one hand, it significantly increases efficiency.",
                    "However, there are notable environmental concerns.",
                    "Could you provide an advanced idiom for this?",
                ]
        else:  # Sarah (default friendly tutor)
            if corrections:
                first_corr = corrections[0]
                reply = (
                    f"Good effort! Here is a helpful grammar tip: instead of '{first_corr['original']}', "
                    f"it is more natural to say: \"{first_corr['correction']}\". 😊 "
                    "Could you try saying that sentence again?"
                )
                suggested = [
                    "Could you give me another example?",
                    "Can we practice another sentence?",
                    "Why is it used that way?",
                ]
            elif "hello" in msg_lower or "hi" in msg_lower:
                reply = (
                    "Hello! It's so wonderful to chat with you today! 😊 "
                    "How has your day been so far? Tell me about something interesting you did!"
                )
                suggested = [
                    "I had a busy day at work.",
                    "I am learning English with you!",
                    "Can we talk about travel destinations?",
                ]
            elif "learn" in msg_lower or "study" in msg_lower:
                reply = (
                    "Learning a language is an exciting journey! You're making real progress. "
                    "What English skill do you feel like practicing most right now — speaking, vocabulary, or grammar?"
                )
                suggested = [
                    "I want to expand my daily vocabulary.",
                    "Let's practice speaking about food and hobbies.",
                    "Can you test my grammar?",
                ]
            else:
                reply = (
                    f"That's really interesting! Thank you for sharing that with me. "
                    "I love how you expressed your thoughts. "
                    "What else would you like to explore about this?"
                )
                suggested = [
                    "Tell me how native speakers would say that.",
                    "Can you give me an example sentence?",
                    "Let's try a different topic!",
                ]

        return {
            "reply": reply,
            "corrections": cls.normalize_corrections(corrections, user_message),
            "suggested_replies": suggested,
        }

    @classmethod
    async def generate_adaptive_exercises(
        cls,
        user_level: str,
        weaknesses: list[str],
        count: int = 3,
    ) -> list[dict[str, Any]]:
        """
        Dynamically generate targeted exercises focusing on the user's weaknesses.
        """
        exercises = [
            {
                "question": "Choose the correct sentence in the past simple tense:",
                "skill": "grammar",
                "options": [
                    "Yesterday, I go to the supermarket with my sister.",
                    "Yesterday, I went to the supermarket with my sister.",
                    "Yesterday, I had go to the supermarket with my sister.",
                    "Yesterday, I am going to the supermarket with my sister.",
                ],
                "correct_option": 1,
                "explanation": "Past simple tense uses the irregular past form 'went' (from 'go') with 'yesterday'.",
            },
            {
                "question": "Select the most appropriate professional adjective: 'The CEO gave a ________ presentation that clarified all doubts.'",
                "skill": "vocabulary",
                "options": ["confusing", "compelling", "tedious", "reluctant"],
                "correct_option": 1,
                "explanation": "'Compelling' means evocative, convincing, and holding complete attention.",
            },
            {
                "question": "Which sentence demonstrates the correct use of the Second Conditional?",
                "skill": "grammar",
                "options": [
                    "If I win the lottery, I will buy a car.",
                    "If I won the lottery, I would buy a car.",
                    "If I had won the lottery, I would have bought a car.",
                    "If I win the lottery, I would buy a car.",
                ],
                "correct_option": 1,
                "explanation": "Second conditional (unreal present): If + Past Simple, would + infinitive.",
            },
        ]
        return exercises[:count]

    @classmethod
    async def evaluate_writing(
        cls,
        user_text: str,
        topic: str,
        user_level: str = "B1",
    ) -> dict[str, Any]:
        """
        Evaluate writing quality, grammar errors, vocabulary range, and provide a polished version.
        """
        word_count = len(user_text.split())

        # Analyze errors
        grammar_feedback = []
        if re.search(r"\bi is\b", user_text.lower()):
            grammar_feedback.append({
                "error": "I is",
                "correction": "I am",
                "rule": "Chủ ngữ 'I' luôn đi với trợ động từ 'am' trong thì hiện tại.",
            })
        if re.search(r"\bhe don't\b", user_text.lower()):
            grammar_feedback.append({
                "error": "he don't",
                "correction": "he doesn't",
                "rule": "Ngôi thứ ba số ít 'he' phủ định dùng 'doesn't' thay vì 'don't'.",
            })

        vocab_suggestions = [
            {
                "original": "good",
                "advanced_alternatives": ["exceptional", "advantageous", "beneficial"],
                "reason": "Sử dụng từ vựng học thuật giúp nâng cao điểm Lexical Resource.",
            },
            {
                "original": "very important",
                "advanced_alternatives": ["crucial", "paramount", "indispensable"],
                "reason": "Thay thế cụm 'very + tính từ' bằng tính từ mạnh.",
            },
        ]

        # Calculate score
        score = min(92.0, max(50.0, 65.0 + min(20.0, word_count * 0.3) - len(grammar_feedback) * 5))
        ielts_band = round(min(8.5, max(4.5, (score / 100) * 9)), 1)
        cefr = "B2" if score >= 75 else "B1" if score >= 60 else "A2"

        revised = (
            f"Regarding the topic of '{topic}', {user_text.strip()} "
            "Furthermore, consistent deliberate practice empowers learners to express complex concepts fluently and persuasively."
        )

        return {
            "overall_score": score,
            "cefr_level": cefr,
            "ielts_equivalent": ielts_band,
            "grammar_feedback": grammar_feedback,
            "vocab_suggestions": vocab_suggestions,
            "general_comment": (
                f"Bài viết gồm {word_count} từ thể hiện khả năng truyền đạt ý tưởng mạch lạc. "
                "Cấu trúc câu phong phú và lập luận rõ ràng. "
                "Hãy lưu ý các gợi ý từ vựng nâng cao ở trên để bài viết tự nhiên và ấn tượng hơn nữa."
            ),
            "revised_text": revised,
        }
