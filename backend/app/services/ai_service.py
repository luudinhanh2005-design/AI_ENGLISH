from .local_llm_service import local_llm_service
import json
import logging
import re
import unicodedata
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
    def _clean_first_name(user_name: str) -> str:
        if not user_name:
            return "Friend"
        raw = re.sub(r'[\d_]+', ' ', str(user_name)).strip()
        if not raw:
            return "Friend"
        # Convert Vietnamese tones to plain Latin for natural TTS pronunciation
        s = raw.replace('đ', 'd').replace('Đ', 'D')
        nfkd = unicodedata.normalize('NFKD', s)
        ascii_name = ''.join([c for c in nfkd if not unicodedata.combining(c)]).strip()
        parts = ascii_name.split()
        return parts[0].capitalize() if parts else "Friend"

    @classmethod
    def _clean_spoken_reply(cls, reply: str) -> str:
        if not reply:
            return "That sounds wonderful! Could you tell me more about that?"
        text = str(reply).strip()
        # Strip markdown bold/italics
        text = re.sub(r'\*{1,3}([^*]+)\*{1,3}', r'\1', text)
        text = re.sub(r'_{1,3}([^_]+)_{1,3}', r'\1', text)
        text = re.sub(r'`+([^`]+)`+', r'\1', text)
        # Strip phonetic slash notations e.g. /wɛnt/
        text = re.sub(r'(?:^|\s)/[^/\n]{2,}/(?:\s|$)', ' ', text)
        # Strip outer quotes around words without breaking contractions (e.g. "went" -> went, 'hello' -> hello, don't kept)
        text = re.sub(r'(^|\s)["\'“”‘’`]+', r'\1', text)
        text = re.sub(r'["\'“”‘’`]+(\s|[.,!?;]|$)', r'\1', text)
        # Strip emojis and pictographs
        text = re.sub(r'[\U00010000-\U0010ffff]', '', text)
        text = re.sub(r'[\u2600-\u26FF\u2700-\u27BF]', '', text)
        # Clean letter-by-letter hyphens e.g. w-e-n-t -> went
        text = re.sub(r'\b([a-zA-Z])\s*-\s*([a-zA-Z])\s*-\s*([a-zA-Z])\b', r'\1\2\3', text)
        # Collapse multiple spaces
        text = re.sub(r'\s+', ' ', text).strip()
        return text

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
        reply = cls._clean_spoken_reply(reply)
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

        first_name = cls._clean_first_name(user_name)
        system_instruction = (
            f"{system_prompt}\n"
            f"The learner's first name is {first_name}, and their CEFR level is {user_level}.\n"
            "You are an English speaking partner and tutor having a live voice call. Always reply in natural, "
            "warm, continuous spoken ENGLISH (1-2 sentences) and end with an engaging follow-up question. "
            "Never use Vietnamese in 'reply'. Never lecture or quote grammar in 'reply'.\n"
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

        first_name = cls._clean_first_name(user_name)
        instruction = (
            f"{system_prompt}\n"
            f"The learner's first name is {first_name}, and their CEFR level is {user_level}.\n"
            "You are having a LIVE SPOKEN PHONE CALL with the learner. "
            "Everything in your 'reply' field will be read aloud immediately by an expressive Text-To-Speech engine directly into the learner's earphones.\n\n"
            "CRITICAL SPOKEN CONVERSATION RULES FOR 'reply':\n"
            "1. 'reply' MUST be 100% natural, expressive, continuous spoken English — exactly how a real native English speaker talks on a warm phone call.\n"
            "2. Keep it to 1 or 2 concise, fluent spoken sentences. Always end with an easy, engaging question to keep the chat going naturally.\n"
            "3. NEVER include any Vietnamese words or sentences in 'reply' under any circumstances! (All Vietnamese explanations belong ONLY in 'corrections[].explanation_vi').\n"
            "4. NEVER give robotic grammar lectures or mention quotes inside 'reply' (e.g. NEVER say 'You said X instead of Y' or 'Remember to use Z'). Simply converse warmly and naturally like a human friend while modeling correct English.\n"
            "5. NO formatting that disrupts speech: NEVER use asterisks (*), quotes, slashes (/), phonetic symbols, bullet points, numbered lists, or letter-by-letter hyphens. NEVER spell out words.\n"
            f"6. When addressing the learner, use their friendly first name '{first_name}'.\n\n"
            "Analyze the learner's message for grammar, tense, preposition, or vocabulary errors and put all corrections into the 'corrections' array.\n"
            "Respond strictly in valid JSON format matching this JSON schema:\n"
            "{\n"
            '  "reply": "Your 100% natural conversational spoken English response ending with a follow-up question",\n'
            '  "corrections": [\n'
            '    {\n'
            '      "original": "The incorrect part of the learner\'s sentence",\n'
            '      "correction": "The corrected natural version",\n'
            '      "explanation_vi": "Giải thích ngắn gọn bằng tiếng Việt có dấu về lý do và cách dùng đúng",\n'
            '      "type": "grammar or vocabulary"\n'
            '    }\n'
            "  ],\n"
            '  "suggested_replies": ["Short suggestion 1", "Short suggestion 2", "Short suggestion 3"]\n'
            "}"
        )

        contents = []
        for h in history[-10:]:
            role = "user" if h["role"] == "user" else "model"
            contents.append({"role": role, "parts": [{"text": h["content"]}]})

        contents.append({"role": "user", "parts": [{"text": user_message}]})

        payload = {
            "systemInstruction": {"parts": [{"text": instruction}]},
            "contents": contents,
            "generationConfig": {
                "temperature": 0.8,
                "responseMimeType": "application/json",
            },
        }

        models_to_try = list(dict.fromkeys([
            settings.ai_model_name or "gemini-2.5-flash-lite",
            "gemini-2.5-flash-lite",
            "gemini-3-flash-preview",
            "gemini-flash-lite-latest",
        ]))

        last_error = None
        for model in models_to_try:
            api_url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={settings.google_ai_api_key}"
            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    resp = await client.post(api_url, json=payload)
                    if resp.status_code != 200:
                        logger.warning(f"Model {model} returned {resp.status_code}: {resp.text[:100]}")
                        last_error = f"{model} status {resp.status_code}"
                        continue
                    data = resp.json()
                    candidates = data.get("candidates") or []
                    if not candidates:
                        continue
                    text_response = candidates[0]["content"]["parts"][0]["text"]
                    parsed = cls._parse_json_object(text_response)
                    if parsed:
                        return parsed
                    return json.loads(text_response)
            except Exception as e:
                logger.warning(f"Failed calling Gemini model {model}: {e}")
                last_error = e
                continue

        raise RuntimeError(f"All Gemini models failed: {last_error}")

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

        first_name = cls._clean_first_name(user_name)
        instruction = (
            f"{system_prompt}\n"
            f"The learner's first name is {first_name}, and their CEFR level is {user_level}.\n"
            "You are having a live spoken call with the learner. "
            "The 'reply' field MUST be 100% natural, continuous conversational spoken English (1-2 sentences) ending with an engaging question. "
            "NEVER include Vietnamese in 'reply'. NEVER lecture or quote grammar in 'reply'. "
            "Respond strictly in JSON format with keys: 'reply' (English string), "
            "'corrections' (list of {original, correction, explanation_vi, type}), "
            "and 'suggested_replies' (list of 2-3 short strings)."
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
            parsed = cls._parse_json_object(content_str)
            if parsed:
                return parsed
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
            _match = re.search(r"\b(she|he|it)\s+don't\b(?!\s+has)", msg_lower)
            m = _match.group(0) if _match else ""
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
            _match = re.search(r"\b(she|he)\s+(study|go|play|have)\b", msg_lower)
            m = _match.group(0) if _match else ""
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
            _match = re.search(r"\bi\s+(goed|eated|comed)\b", msg_lower)
            wrong = _match.group(1) if _match else "goed"
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
            _match = re.search(r"\b(she|he|it)\s+don't\s+has\b", msg_lower)
            m = _match.group(0) if _match else ""
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
                    "That is a very interesting point. "
                    "Could you elaborate on how you would propose this in a professional meeting?"
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
                    "Interesting perspective on that topic. "
                    "What do you believe are the primary societal consequences of this trend?"
                )
                suggested = [
                    "On the one hand, it significantly increases efficiency.",
                    "However, there are notable environmental concerns.",
                    "Could you provide an advanced idiom for this?",
                ]
        else:  # Sarah (default friendly tutor)
            if "hello" in msg_lower or "hi" in msg_lower:
                reply = (
                    "Hello! It is so wonderful to chat with you today! "
                    "How has your day been so far? Tell me about something interesting you did!"
                )
                suggested = [
                    "I had a busy day at work.",
                    "I am learning English with you!",
                    "Can we talk about travel destinations?",
                ]
            elif "learn" in msg_lower or "study" in msg_lower:
                reply = (
                    "Learning a language is an exciting journey! You are making great progress. "
                    "What English skill do you feel like practicing most right now — speaking, vocabulary, or grammar?"
                )
                suggested = [
                    "I want to expand my daily vocabulary.",
                    "Let's practice speaking about food and hobbies.",
                    "Can you test my grammar?",
                ]
            else:
                reply = (
                    "That sounds really interesting! I love hearing your thoughts. "
                    "Could you tell me a little bit more about that?"
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
    async def _llm_json(
        cls,
        system_prompt: str,
        user_prompt: str,
        max_tokens: int = 700,
        temperature: float = 0.3,
    ) -> Optional[dict[str, Any]]:
        """Run a one-shot prompt through the provider chain (local -> cloud) and return parsed JSON."""
        import asyncio

        provider = (settings.ai_provider or "local").strip().lower()
        for name in cls._provider_order():
            try:
                parsed: Optional[dict[str, Any]] = None
                if name == "local":
                    if not settings.local_llm_enabled:
                        continue
                    if not local_llm_service.is_loaded:
                        if local_llm_service.is_loading:
                            continue
                        loaded = await asyncio.wait_for(
                            asyncio.to_thread(local_llm_service.load_model),
                            timeout=settings.local_llm_load_timeout_seconds,
                        )
                        if not loaded:
                            continue
                    timeout = max(90.0, settings.local_llm_timeout_seconds * 2)
                    raw = await asyncio.wait_for(
                        asyncio.to_thread(
                            local_llm_service.generate_chat_response,
                            [
                                {"role": "system", "content": system_prompt},
                                {"role": "user", "content": user_prompt},
                            ],
                            max_tokens,
                            temperature,
                            timeout_seconds=timeout - 5.0,
                        ),
                        timeout=timeout,
                    )
                    parsed = cls._parse_json_object(raw)
                elif name == "gemini":
                    if not settings.google_ai_api_key:
                        continue
                    if provider == "local" and not settings.ai_cloud_fallback:
                        continue
                    url = (
                        "https://generativelanguage.googleapis.com/v1beta/models/"
                        f"{settings.ai_model_name}:generateContent?key={settings.google_ai_api_key}"
                    )
                    payload = {
                        "systemInstruction": {"parts": [{"text": system_prompt}]},
                        "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
                        "generationConfig": {
                            "temperature": temperature,
                            "responseMimeType": "application/json",
                            "maxOutputTokens": 8192,
                            "thinkingConfig": {"thinkingBudget": 0},
                        },
                    }
                    async with httpx.AsyncClient(timeout=30.0) as client:
                        resp = await client.post(url, json=payload)
                        resp.raise_for_status()
                        text = resp.json()["candidates"][0]["content"]["parts"][0]["text"]
                    parsed = cls._parse_json_object(text)
                elif name == "openai":
                    if not settings.openai_api_key:
                        continue
                    if provider == "local" and not settings.ai_cloud_fallback:
                        continue
                    headers = {"Authorization": f"Bearer {settings.openai_api_key}"}
                    payload = {
                        "model": "gpt-4o-mini",
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": user_prompt},
                        ],
                        "response_format": {"type": "json_object"},
                        "temperature": temperature,
                    }
                    async with httpx.AsyncClient(timeout=30.0) as client:
                        resp = await client.post(
                            "https://api.openai.com/v1/chat/completions",
                            headers=headers,
                            json=payload,
                        )
                        resp.raise_for_status()
                        text = resp.json()["choices"][0]["message"]["content"]
                    parsed = cls._parse_json_object(text)
                if parsed:
                    return parsed
            except Exception as e:
                logger.warning(f"_llm_json provider '{name}' failed: {e}")
        return None

    @classmethod
    def _validate_exercises(cls, raw: Any, default_skill: str) -> list[dict[str, Any]]:
        """Keep only well-formed multiple-choice questions (4 distinct options, valid answer)."""
        if not isinstance(raw, list):
            return []
        valid: list[dict[str, Any]] = []
        seen: set[str] = set()
        for item in raw:
            if not isinstance(item, dict):
                continue
            question = cls._clean_text(item.get("question"), 400)
            options_raw = item.get("options")
            if not question or not isinstance(options_raw, list):
                continue
            options = [cls._clean_text(o, 200) for o in options_raw]
            options = [o for o in options if o]
            if len(options) != 4 or len({o.casefold() for o in options}) != 4:
                continue
            answer: Any = item.get("correct_option")
            if isinstance(answer, str) and answer.strip().upper() in {"A", "B", "C", "D"}:
                answer = "ABCD".index(answer.strip().upper())
            try:
                answer = int(answer)
            except (TypeError, ValueError):
                continue
            if not 0 <= answer < 4:
                continue
            if question.casefold() in seen:
                continue
            seen.add(question.casefold())
            skill = cls._clean_text(item.get("skill"), 30).lower() or default_skill
            valid.append({
                "question": question,
                "skill": skill,
                "options": options,
                "correct_option": answer,
                "explanation": cls._clean_text(item.get("explanation"), 500)
                or "Xem lại quy tắc liên quan để hiểu vì sao đáp án này đúng.",
            })
        return valid

    @classmethod
    async def generate_adaptive_exercises(
        cls,
        user_level: str,
        weaknesses: list[str],
        count: int = 3,
        skill: Optional[str] = None,
        topic: Optional[str] = None,
    ) -> list[dict[str, Any]]:
        """Generate multiple-choice exercises by level, skill, topic and learner weaknesses."""
        skill_text = (skill or "grammar and vocabulary").strip()
        default_skill = (skill or "grammar").strip().lower()
        focus = ", ".join(weaknesses) if weaknesses else "none recorded"
        system_prompt = (
            "You are an expert English exam writer. Reply with ONE valid JSON object only, "
            "no markdown and no extra text."
        )
        user_prompt = (
            f"Write {count} multiple-choice questions for a learner at CEFR level {user_level}.\n"
            f"Skill: {skill_text}. Topic: {topic or 'everyday life'}. Learner weak areas: {focus}.\n"
            "Rules: exactly 4 distinct options per question; exactly one correct option; "
            "correct_option is the 0-based index of the right option; the correct option must be "
            "truly correct English; explanation must be written in Vietnamese and be short.\n"
            'Format: {"exercises":[{"question":"...","skill":"grammar","options":["a","b","c","d"],'
            '"correct_option":1,"explanation":"..."}]}'
        )
        data = await cls._llm_json(
            system_prompt, user_prompt, max_tokens=300 * count + 100, temperature=0.5
        )
        exercises = cls._validate_exercises(
            data.get("exercises") if isinstance(data, dict) else None, default_skill
        )
        if len(exercises) < count:
            logger.warning(
                f"Only {len(exercises)}/{count} valid AI exercises; topping up from fallback bank"
            )
            existing = {e["question"].casefold() for e in exercises}
            for ex in await cls._fallback_exercises(user_level, weaknesses, 10):
                if ex["question"].casefold() not in existing:
                    exercises.append(ex)
        return exercises[:count]

    @classmethod
    def _validate_writing(
        cls, raw: Any, user_text: str
    ) -> Optional[dict[str, Any]]:
        """Validate an LLM writing evaluation; drop hallucinated feedback not found in the essay."""
        if not isinstance(raw, dict):
            return None
        try:
            raw_score: Any = raw.get("overall_score")
            score = float(raw_score)
        except (TypeError, ValueError):
            return None
        score = round(min(100.0, max(0.0, score)), 1)

        text_fold = user_text.casefold()

        grammar: list[dict[str, str]] = []
        raw_grammar = raw.get("grammar_feedback")
        for g in raw_grammar if isinstance(raw_grammar, list) else []:
            if not isinstance(g, dict):
                continue
            error = cls._clean_text(g.get("error") or g.get("original"), 300)
            fix = cls._clean_text(g.get("correction") or g.get("corrected"), 300)
            if not error or not fix or error.casefold() == fix.casefold():
                continue
            if error.casefold() not in text_fold:
                continue  # hallucinated: the quoted error is not in the essay
            grammar.append({
                "error": error,
                "correction": fix,
                "rule": cls._clean_text(g.get("rule") or g.get("explanation_vi"), 500)
                or "Sửa lại cho đúng ngữ pháp.",
            })
            if len(grammar) >= 8:
                break

        vocab: list[dict[str, Any]] = []
        raw_vocab = raw.get("vocab_suggestions")
        for v in raw_vocab if isinstance(raw_vocab, list) else []:
            if not isinstance(v, dict):
                continue
            original = cls._clean_text(v.get("original"), 100)
            alts_raw = v.get("advanced_alternatives") or v.get("alternatives")
            alts = [
                cls._clean_text(a, 60)
                for a in (alts_raw if isinstance(alts_raw, list) else [])
            ]
            alts = [a for a in alts if a][:4]
            if not original or not alts or original.casefold() not in text_fold:
                continue
            vocab.append({
                "original": original,
                "advanced_alternatives": alts,
                "reason": cls._clean_text(v.get("reason"), 300)
                or "Từ vựng phong phú hơn giúp bài viết tự nhiên và học thuật hơn.",
            })
            if len(vocab) >= 6:
                break

        revised = cls._clean_text(raw.get("revised_text"), 6000)
        comment = cls._clean_text(raw.get("general_comment"), 1200)
        if len(revised) < 20 or not comment:
            return None

        cefr = cls._clean_text(raw.get("cefr_level"), 4).upper()
        if cefr not in {"A1", "A2", "B1", "B2", "C1", "C2"}:
            cefr = (
                "C1" if score >= 85 else "B2" if score >= 70
                else "B1" if score >= 55 else "A2" if score >= 35 else "A1"
            )
        ielts = round(min(9.0, max(1.0, (score / 100) * 9)), 1)

        return {
            "overall_score": score,
            "cefr_level": cefr,
            "ielts_equivalent": ielts,
            "grammar_feedback": grammar,
            "vocab_suggestions": vocab,
            "general_comment": comment,
            "revised_text": revised,
        }

    @classmethod
    async def evaluate_writing(
        cls,
        user_text: str,
        topic: str,
        user_level: str = "B1",
    ) -> dict[str, Any]:
        """Evaluate writing with the LLM; fall back to basic rule checks if no valid AI result."""
        system_prompt = (
            "You are a strict but fair English writing examiner. "
            "Reply with ONE valid JSON object only, no markdown."
        )
        user_prompt = (
            f"Topic: {topic}\nLearner level: {user_level}\n"
            f'Essay:\n"""{user_text}"""\n\n'
            "Evaluate the essay and return JSON with these keys:\n"
            "overall_score: number 0-100 reflecting grammar, vocabulary, coherence and task relevance;\n"
            "cefr_level: one of A1,A2,B1,B2,C1,C2;\n"
            'grammar_feedback: list of {"error","correction","rule"} where "error" is copied EXACTLY '
            'from the essay and "rule" is a short Vietnamese explanation (empty list if no errors);\n'
            'vocab_suggestions: list of {"original","advanced_alternatives":[...],"reason"} where '
            '"original" is a word or phrase copied EXACTLY from the essay and reason is Vietnamese;\n'
            "general_comment: 2-3 Vietnamese sentences specific to THIS essay;\n"
            "revised_text: an improved version of the whole essay that keeps the same meaning."
        )
        data = await cls._llm_json(system_prompt, user_prompt, max_tokens=900, temperature=0.2)
        result = cls._validate_writing(data, user_text)
        if result:
            return result
        logger.warning("No valid AI writing evaluation; using rule-based fallback")
        return await cls._fallback_writing(user_text, topic, user_level)

    @classmethod
    async def _fallback_exercises(
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
    async def _fallback_writing(
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

        # Only suggest words that actually appear in the essay
        vocab_suggestions = [
            v for v in vocab_suggestions if str(v["original"]) in user_text.lower()
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
                "(Chế độ ước lượng: mô hình AI chưa khả dụng nên chỉ kiểm tra lỗi cơ bản.) "
                "Hãy bật mô hình AI để nhận phản hồi chi tiết và chính xác hơn."
            ),
            "revised_text": revised,
        }

    # ──────────────────────────────────────────────
    # 5. IELTS Speaking Mock Test Evaluation
    # ──────────────────────────────────────────────
    IELTS_TOPICS = [
        {
            "id": "tech_comm",
            "topic": "Technology & Modern Communication",
            "part1": [
                "How often do you use social media to communicate with friends?",
                "Do you prefer texting or calling someone, and why?",
                "What new technology has made your daily life easier recently?",
            ],
            "part2": {
                "cue_card": "Describe a piece of electronic equipment that you find useful.",
                "prompts": [
                    "What it is and when you got it",
                    "What you use it for regularly",
                    "How easy or difficult it is to use",
                    "Explain why you find it particularly useful in your life",
                ],
                "prep_time_seconds": 60,
                "speak_time_seconds": 120,
            },
            "part3": [
                "In what ways has modern technology changed traditional human relationships?",
                "Do you think artificial intelligence will replace human workers in the future?",
                "How can elderly people be encouraged to adopt modern digital tools?",
            ],
        },
        {
            "id": "travel_exp",
            "topic": "Travel & Memorable Journeys",
            "part1": [
                "Do you prefer traveling alone or in a group, and why?",
                "What is your favorite mode of transport when taking a long journey?",
                "Have you ever experienced any unexpected delays while traveling?",
            ],
            "part2": {
                "cue_card": "Describe a memorable journey you took by public transport.",
                "prompts": [
                    "Where you were going and when it took place",
                    "What type of transport you used (train, bus, plane, ferry)",
                    "Who you were traveling with and what happened on the way",
                    "Explain why this particular journey remains memorable to you",
                ],
                "prep_time_seconds": 60,
                "speak_time_seconds": 120,
            },
            "part3": [
                "What are the benefits of investing heavily in high-speed public rail networks?",
                "How does international tourism positively and negatively impact local communities?",
                "Will virtual reality travel ever completely replace actual physical tourism?",
            ],
        },
        {
            "id": "education_career",
            "topic": "Education, Skills & Lifelong Learning",
            "part1": [
                "What subject did you enjoy studying most when you were in school?",
                "Do you find it easy to concentrate when studying alone?",
                "What new skill or language would you like to master in the next year?",
            ],
            "part2": {
                "cue_card": "Describe an important skill you learned that helped you in your studies or career.",
                "prompts": [
                    "What the skill is and who taught you or how you learned it",
                    "How long it took you to become proficient at it",
                    "How you currently apply this skill in daily situations",
                    "Explain why mastering this skill has been crucial to your growth",
                ],
                "prep_time_seconds": 60,
                "speak_time_seconds": 120,
            },
            "part3": [
                "Should university curriculums focus more on practical vocational skills or theoretical concepts?",
                "How can online learning platforms democratize quality higher education globally?",
                "What role should employers play in the continuous reskilling of their workforce?",
            ],
        },
    ]

    @classmethod
    def get_ielts_speaking_prompt(cls, topic_id: Optional[str] = None) -> dict[str, Any]:
        """Fetch an IELTS Speaking test prompt bundle."""
        if topic_id:
            for item in cls.IELTS_TOPICS:
                if item["id"] == topic_id:
                    return item
        return cls.IELTS_TOPICS[0]

    @classmethod
    async def evaluate_ielts_speaking(
        cls,
        topic: str,
        part1_qa: list[dict[str, str]],
        part2_answer: str,
        part3_qa: list[dict[str, str]],
        user_level: str = "B2",
    ) -> dict[str, Any]:
        """
        Evaluate full 3-part IELTS Speaking Mock Test according to the 4 official criteria:
        1. Fluency & Coherence
        2. Lexical Resource
        3. Grammatical Range & Accuracy
        4. Pronunciation
        Returns band scores (1.0 - 9.0) and detailed feedback from Examiner Emma.
        """
        # Strict validation: Check candidate's actual spoken/typed words
        p1_answers = [q.get("answer", "").strip() for q in part1_qa if q.get("answer", "").strip()]
        p2_answer_clean = part2_answer.strip()
        p3_answers = [q.get("answer", "").strip() for q in part3_qa if q.get("answer", "").strip()]

        all_candidate_text = " ".join(p1_answers + ([p2_answer_clean] if p2_answer_clean else []) + p3_answers)
        total_words = len(re.findall(r"\b\w+\b", all_candidate_text))

        # Case 1: Candidate was silent or left everything blank -> Band 1.0 (Did not attempt / Non-user)
        if total_words == 0:
            return {
                "overall_band": 1.0,
                "fluency_band": 1.0,
                "lexical_band": 1.0,
                "grammar_band": 1.0,
                "pronunciation_band": 1.0,
                "cefr_level": "Pre-A1",
                "examiner_comment": (
                    "Thí sinh không đưa ra câu trả lời hoặc không ghi nhận được giọng nói nào trong toàn bộ 3 phần thi. "
                    "Theo thang điểm chính thức của IELTS, bài thi được đánh giá Band 1.0 (Non-user / Did not attempt). "
                    "Vui lòng bật Micro nói trực tiếp hoặc nhập câu trả lời tiếng Anh để Giám khảo Emma chấm điểm cho bạn nhé!"
                ),
                "strengths": [
                    "Chưa ghi nhận câu trả lời để đánh giá điểm mạnh.",
                ],
                "improvements": [
                    "Bấm vào biểu tượng Micro và nói rõ ràng câu trả lời của bạn vào thiết bị.",
                    "Nếu không dùng mic, hãy gõ nội dung trả lời vào khung văn bản trước khi bấm tiếp tục.",
                    "Mỗi câu hỏi Part 1 nên trả lời tối thiểu từ 2 đến 3 câu hoàn chỉnh.",
                ],
                "corrections": [],
                "band8_samples": [],
            }

        # Case 2: Extremely short answers (e.g. 1-2 words like 'yes', 'no') -> Band 2.0
        if total_words < 15:
            return {
                "overall_band": 2.0,
                "fluency_band": 2.0,
                "lexical_band": 2.0,
                "grammar_band": 2.0,
                "pronunciation_band": 2.0,
                "cefr_level": "A1",
                "examiner_comment": (
                    f"Thí sinh chỉ đưa ra câu trả lời cực kỳ ngắn gọn (tổng cộng {total_words} từ), "
                    "chưa đủ để hình thành câu giao tiếp hoàn chỉnh. "
                    "Bài thi đạt mức Band 2.0 (Intermittent user - Người dùng ngắt quãng). "
                    "Cần phát triển câu hoàn chỉnh có đầy đủ Chủ ngữ - Vị ngữ và nêu lý do giải thích."
                ),
                "strengths": [
                    "Đã có phản hồi ban đầu với câu hỏi của giám khảo.",
                ],
                "improvements": [
                    "Tránh chỉ trả lời 'Yes/No' hoặc cụm từ cộc lốc; hãy diễn đạt thành câu hoàn chỉnh.",
                    "Sử dụng công thức 'I prefer... because...' để mở rộng ý kiến.",
                ],
                "corrections": [],
                "band8_samples": [],
            }

        system_prompt = (
            "You are Emma, a certified senior British IELTS Speaking Examiner. "
            "You grade strictly according to the official IELTS 9-band descriptors. "
            "Reply with ONE valid JSON object only, without markdown backticks."
        )

        p1_text = "\n".join([f"Q: {q.get('question','')}\nA: {q.get('answer','')}" for q in part1_qa])
        p3_text = "\n".join([f"Q: {q.get('question','')}\nA: {q.get('answer','')}" for q in part3_qa])

        user_prompt = (
            f"Topic: {topic}\nCandidate baseline level: {user_level}\n"
            f"Candidate total words spoken/written: {total_words}\n\n"
            f"--- PART 1 ---\n{p1_text}\n\n"
            f"--- PART 2 (Cue Card Long Turn) ---\n{part2_answer}\n\n"
            f"--- PART 3 (Analytical Discussion) ---\n{p3_text}\n\n"
            "CRITICAL SCORING CONSTRAINTS:\n"
            f"- The candidate produced {total_words} words in total across the entire test.\n"
            "- If total words < 35, overall_band MUST NOT exceed 3.0.\n"
            "- If total words < 75, overall_band MUST NOT exceed 4.0.\n"
            "- If total words < 140, overall_band MUST NOT exceed 5.0.\n"
            "- Band 6.0+ is ONLY reserved for candidates with coherent discourse (>140 words) across all parts.\n\n"
            "Evaluate this candidate's performance across all 3 parts and return JSON with keys:\n"
            "overall_band: number between 1.0 and 9.0 in increments of 0.5 (e.g. 2.0, 3.5, 5.0, 6.0, 6.5, 7.0);\n"
            "fluency_band: number 1.0-9.0 in 0.5 increments;\n"
            "lexical_band: number 1.0-9.0 in 0.5 increments;\n"
            "grammar_band: number 1.0-9.0 in 0.5 increments;\n"
            "pronunciation_band: number 1.0-9.0 in 0.5 increments;\n"
            "cefr_level: string A1, A2, B1, B2, C1, or C2;\n"
            "examiner_comment: 3-4 sentences in Vietnamese with warm, professional British examiner Emma persona, summarizing performance based on actual length and quality;\n"
            "strengths: list of 2-3 specific Vietnamese bullet points on what candidate did well;\n"
            "improvements: list of 2-3 actionable Vietnamese tips;\n"
            'corrections: list of {"original": "exact error", "corrected": "improved phrasing", "explanation": "Vietnamese explanation", "type": "grammar|vocabulary|pronunciation"};\n'
            'band8_samples: list of {"question": "...", "original": "...", "band8_upgrade": "sophisticated academic answer with idioms/complex structures"}'
        )

        data = await cls._llm_json(system_prompt, user_prompt, max_tokens=1400, temperature=0.3)
        if isinstance(data, dict) and "overall_band" in data:
            try:
                overall = float(data.get("overall_band", 5.0))
                # ensure 0.5 increment
                overall = round(overall * 2) / 2
                overall = min(9.0, max(1.0, overall))
                data["overall_band"] = overall
                return data
            except Exception as e:
                logger.warning(f"Error normalizing IELTS evaluation: {e}")

        # Rule-based fallback if LLM is offline
        return cls._fallback_ielts_speaking(topic, part1_qa, part2_answer, part3_qa, user_level)

    @classmethod
    def _fallback_ielts_speaking(
        cls,
        topic: str,
        part1_qa: list[dict[str, str]],
        part2_answer: str,
        part3_qa: list[dict[str, str]],
        user_level: str = "B2",
    ) -> dict[str, Any]:
        """Heuristic evaluation for IELTS Speaking when model is offline."""
        p1_answers = [q.get("answer", "").strip() for q in part1_qa if q.get("answer", "").strip()]
        p2_answer_clean = part2_answer.strip()
        p3_answers = [q.get("answer", "").strip() for q in part3_qa if q.get("answer", "").strip()]

        all_text = " ".join(p1_answers + ([p2_answer_clean] if p2_answer_clean else []) + p3_answers)
        words = len(re.findall(r"\b\w+\b", all_text))

        # Realistic IELTS Band calculation based on substantive output
        if words == 0:
            return {
                "overall_band": 1.0,
                "fluency_band": 1.0,
                "lexical_band": 1.0,
                "grammar_band": 1.0,
                "pronunciation_band": 1.0,
                "cefr_level": "Pre-A1",
                "examiner_comment": (
                    "Thí sinh không đưa ra câu trả lời nào trong suốt buổi thi thử. "
                    "Theo chuẩn khảo thí IELTS quốc tế, bài thi được chấm Band 1.0 (Did not attempt / Non-user). "
                    "Vui lòng bật Micro hoặc gõ câu trả lời tiếng Anh để Giám khảo Emma chấm điểm cho bạn nhé!"
                ),
                "strengths": ["Chưa ghi nhận câu trả lời để đánh giá."],
                "improvements": [
                    "Bấm mic để nói trực tiếp câu trả lời của bạn.",
                    "Trả lời tối thiểu 2-3 câu cho mỗi câu hỏi Part 1.",
                ],
                "corrections": [],
                "band8_samples": [],
            }
        elif words < 25:
            overall = 2.5
            fluency = 2.5
            lexical = 2.5
            grammar = 2.5
            pronunciation = 2.5
            cefr = "A1"
            comment = f"Thí sinh chỉ trả lời rất ít với tổng cộng {words} từ. Đạt Band 2.5 (Intermittent user). Cần luyện tập trả lời thành câu hoàn chỉnh và kéo dài câu trả lời."
        elif words < 60:
            overall = 3.5
            fluency = 3.5
            lexical = 3.5
            grammar = 3.5
            pronunciation = 4.0
            cefr = "A2"
            comment = f"Thí sinh đã trả lời được ý cơ bản ({words} từ) nhưng còn quá ngắn so với yêu cầu bài thi IELTS. Đạt Band 3.5 (Extremely Limited User). Hãy thêm lý do vì sao và ví dụ cụ thể cho mỗi câu hỏi."
        elif words < 120:
            overall = 4.5
            fluency = 4.5
            lexical = 4.5
            grammar = 5.0
            pronunciation = 5.0
            cefr = "B1"
            comment = f"Thí sinh hoàn thành bài thi ở mức cơ bản ({words} từ). Đạt Band 4.5 (Limited User). Cần luyện nói lưu loát hơn ở Part 2 và dùng các từ nối như 'furthermore', 'however' ở Part 3."
        elif words < 180:
            overall = 5.5
            fluency = 5.5
            lexical = 5.5
            grammar = 5.5
            pronunciation = 6.0
            cefr = "B1+"
            comment = f"Thí sinh duy trì đối thoại tương đối ổn định ({words} từ). Đạt Band 5.5 (Modest User). Để bứt phá lên Band 6.5+, hãy mở rộng vốn từ vựng học thuật và tránh các lỗi ngữ pháp chia thì."
        else:
            # Full substantive answers
            fluency = 6.0
            if words > 240:
                fluency += 0.5
            if any(w in all_text.lower() for w in ["well", "actually", "to be honest", "as far as i'm concerned", "in addition"]):
                fluency += 0.5

            lexical = 6.0
            advanced_words = ["significant", "crucial", "empower", "convenient", "fascinating", "essential", "innovative", "opportunity"]
            found_adv = sum(1 for w in advanced_words if w in all_text.lower())
            lexical += min(1.0, found_adv * 0.5)

            grammar = 6.0
            if any(w in all_text.lower() for w in ["if", "although", "which", "because", "would have"]):
                grammar += 0.5

            pronunciation = 6.5
            overall = round(((fluency + lexical + grammar + pronunciation) / 4) * 2) / 2
            overall = min(8.5, max(6.0, overall))
            cefr = "B2" if overall >= 6.5 else "B1+"
            comment = (
                f"Thí sinh thể hiện phong thái tự tin và khả năng duy trì dòng đối thoại tốt (tổng cộng {words} từ). "
                "Ý tưởng được triển khai tương đối mạch lạc. Để bứt phá lên Band 7.5+, hãy sử dụng thêm các cấu trúc đảo ngữ "
                "hoặc mệnh đề quan hệ phức hợp, đồng thời giảm bớt các quãng ngập ngừng giữa các câu."
            )

        corrections = [
            {
                "original": "I very like it",
                "corrected": "I really enjoy it / I am particularly fond of it",
                "explanation": "Trong tiếng Anh không dùng 'very' trực tiếp trước động từ; hãy dùng 'really enjoy' hoặc 'am fond of'.",
                "type": "vocabulary",
            },
            {
                "original": "it make me happy",
                "corrected": "it makes me feel delighted",
                "explanation": "Chủ ngữ 'it' ngôi 3 số ít cần chia động từ thêm 's': 'makes'. Nâng cấp 'happy' thành 'delighted'.",
                "type": "grammar",
            },
        ]

        band8_samples = [
            {
                "question": "What technology has made your life easier?",
                "original": "My smartphone is very useful for chatting and studying.",
                "band8_upgrade": "Without a shadow of a doubt, my smartphone has become an indispensable asset in my daily routine, seamlessly bridging communication and autonomous learning.",
            }
        ]

        return {
            "overall_band": overall,
            "fluency_band": round(fluency * 2) / 2,
            "lexical_band": round(lexical * 2) / 2,
            "grammar_band": round(grammar * 2) / 2,
            "pronunciation_band": pronunciation,
            "cefr_level": cefr,
            "examiner_comment": comment,
            "strengths": [
                "Duy trì dòng câu trả lời liên tục, không bị ngắt quãng quá lâu.",
                "Sử dụng đúng thì và cấu trúc câu cơ bản cho các phần thi.",
                "Thể hiện thái độ tự nhiên, phản xạ câu hỏi tương đối nhanh.",
            ] if words >= 120 else ["Có nỗ lực hoàn thành các câu hỏi trong đề thi."],
            "improvements": [
                "Mở rộng câu trả lời ở Part 3 bằng cách đưa ra ví dụ thực tế hoặc so sánh giữa các thế hệ.",
                "Sử dụng đa dạng các từ nối học thuật như 'conversely', 'subsequently', 'nevertheless'.",
                "Chú ý phát âm chuẩn các âm đuôi /s/, /z/, /t/ và nhấn đúng trọng âm câu.",
            ],
            "corrections": corrections if words >= 40 else [],
            "band8_samples": band8_samples if words >= 40 else [],
        }
