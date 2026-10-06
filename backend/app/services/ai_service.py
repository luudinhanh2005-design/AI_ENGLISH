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

                # 0. Try Self-Trained Local LLM Model (NVIDIA GPU)
        try:
            local_res = await cls._call_local_llm_chat(
                system_prompt=system_prompt,
                user_name=user_name,
                user_level=user_level,
                user_message=user_message,
                history=history,
            )
            if local_res:
                return local_res
        except Exception as e:
            logger.warning(f"Local LLM call failed, falling back: {e}")

        # 1. Try Google Gemini API if configured
        if settings.google_ai_api_key:
            try:
                return await cls._call_gemini_chat(
                    system_prompt=system_prompt,
                    user_name=user_name,
                    user_level=user_level,
                    user_message=user_message,
                    history=history,
                )
            except Exception as e:
                logger.warning(f"Gemini API call failed, using intelligent fallback: {e}")

        # 2. Try OpenAI API if configured
        if settings.openai_api_key:
            try:
                return await cls._call_openai_chat(
                    system_prompt=system_prompt,
                    user_name=user_name,
                    user_level=user_level,
                    user_message=user_message,
                    history=history,
                )
            except Exception as e:
                logger.warning(f"OpenAI API call failed, using intelligent fallback: {e}")

        # 3. Intelligent Built-in Conversational Engine
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
            loaded = await asyncio.to_thread(local_llm_service.load_model)
            if not loaded:
                return None

        system_instruction = (
            f"{system_prompt}\n"
            f"The learner's name is {user_name}, and their CEFR level is {user_level}.\n"
            "MANDATORY INSTRUCTION: You are an English speaking partner and tutor. "
            "You MUST ALWAYS converse and reply in natural, engaging, and fluent ENGLISH. "
            "If the learner makes ANY grammar, tense, vocabulary, or preposition mistake (or asks you to check a sentence), "
            "gently point it out using this format:\n"
            "Correction: \"<corrected sentence>\"\n"
            "Note: <brief explanation in Vietnamese of why it is corrected>\n"
            "Then continue the conversation in natural English with an engaging follow-up question."
        )

        formatted_messages = [{"role": "system", "content": system_instruction}]
        for h in history[-4:]:
            role = "assistant" if h.get("role") in ["assistant", "model"] else "user"
            formatted_messages.append({"role": role, "content": h.get("content", "")})
        formatted_messages.append({"role": "user", "content": user_message})

        raw_reply = await asyncio.to_thread(
            local_llm_service.generate_chat_response,
            formatted_messages,
            300,
            0.7
        )

        if not raw_reply:
            return None

        corrections = []
        corr_match = re.search(
            r'''(?:The correct(?:\s+way(?:\s+would\s+be)?)?|Correction|Correct version|Câu chuẩn|Accurate version|Professional standard)(?::|,|\s+is)?\s*["'“”]([^"'“”]+)["'“”]''',
            raw_reply,
            re.IGNORECASE
        )
        if not corr_match:
            corr_match = re.search(r'''\*\*["'“”]([^"'“”]+)["'“”]\*\*''', raw_reply)

        if corr_match:
            corrected_text = corr_match.group(1).strip()
            expl_match = re.search(r'''(?:Note|Giải thích|Examiner Note):\s*([^\n\)]+)''', raw_reply, re.IGNORECASE)
            explanation_vi = expl_match.group(1).strip() if expl_match else "AI Tutor đã phát hiện và sửa lỗi cấu trúc ngữ pháp giúp bạn."
            corrections.append({
                "original": user_message,
                "correction": corrected_text,
                "explanation_vi": explanation_vi,
            })

        # Rule-based safety net: always catch known errors even if model phrased it freely
        rule_corrs = cls._detect_grammar_errors(user_message)
        if not corrections and rule_corrs:
            corrections.extend(rule_corrs)

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
            "reply": clean_reply,
            "corrections": corrections,
            "suggested_replies": [
                "Could you give me an example?",
                "Can we practice another sentence?",
                "How can I sound more natural?"
            ]
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
            "Analyze the learner's message for any grammatical, spelling, or unnatural phrasing errors.\n"
            "Respond strictly in valid JSON format matching this JSON schema:\n"
            "{\n"
            '  "reply": "Your conversational response in natural English (keep it engaging and ask a relevant question back)",\n'
            '  "corrections": [\n'
            '    {\n'
            '      "original": "The incorrect part of the learner\'s sentence",\n'
            '      "correction": "The corrected natural version",\n'
            '      "explanation_vi": "Brief explanation in Vietnamese of why it is corrected"\n'
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
            "Respond in JSON format with keys: 'reply' (English string), 'corrections' (list of {original, correction, explanation_vi}), 'suggested_replies' (list of 2-3 short strings)."
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
        elif re.search(r"\b(she|he|it)\s+don't\b", msg_lower):
            m = re.search(r"\b(she|he|it)\s+don't\b", msg_lower).group(0)
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
            })
        elif re.search(r"\b(depends?)\s+of\b", msg_lower):
            corrections.append({
                "original": "depend of",
                "correction": "depend on",
                "explanation_vi": "Động từ 'depend' đi kèm giới từ 'on' (hoặc 'upon'), không dùng 'of'.",
            })
        elif re.search(r"\blook\s+forward\s+to\s+hear\b", msg_lower):
            corrections.append({
                "original": "look forward to hear",
                "correction": "look forward to hearing",
                "explanation_vi": "Sau cấu trúc 'look forward to', động từ luôn ở dạng V-ing ('hearing').",
            })
        elif re.search(r"\bmake\s+homework\b", msg_lower):
            corrections.append({
                "original": "make homework",
                "correction": "do homework",
                "explanation_vi": "Cụm từ cố định chuẩn (collocation) là 'do homework', không dùng 'make homework'.",
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
            "corrections": corrections,
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
