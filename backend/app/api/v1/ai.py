from datetime import datetime, timezone
import uuid
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from ...config import settings
from ...database import get_db
from ...models.ai import AITutorMessage, AITutorSession, AIWritingSubmission
from ...models.user import User, UserProfile
from ...schemas.ai import (
    AIChatRequest,
    AIChatResponse,
    AICorrectionItem,
    AIExerciseGenerateRequest,
    AIExerciseGenerateResponse,
    AIExerciseItem,
    AITutorMessageItem,
    AITutorSessionSummary,
    AIWritingResponse,
    AIWritingSubmitRequest,
)
from ...services.ai_service import AIService
from ..deps import get_current_user, get_optional_user

router = APIRouter()

# In-memory store for chat sessions/messages when DB is offline
_MEMORY_SESSIONS: dict[UUID, AITutorSession] = {}
_MEMORY_MESSAGES: dict[UUID, list[AITutorMessage]] = {}


# ──────────────────────────────────────────────
# 1. AI Tutor Chat
# ──────────────────────────────────────────────

from pydantic import BaseModel

class TranslationRequest(BaseModel):
    text: str
    target_lang: str = "vi"

class TranslationResponse(BaseModel):
    original_text: str
    translated_text: str
    target_lang: str = "vi"

@router.get("/status")
async def get_ai_status():
    from ...services.local_llm_service import local_llm_service

    local_status = local_llm_service.status()
    return {
        **local_status,
        "provider": settings.ai_provider,
        "cloud_fallback": settings.ai_cloud_fallback,
        "gemini_configured": bool(settings.google_ai_api_key),
        "openai_configured": bool(settings.openai_api_key),
    }

@router.post("/translate", response_model=TranslationResponse)
async def translate_text(request: TranslationRequest):
    """Translate text quickly to Vietnamese or other target languages."""
    import urllib.request
    import urllib.parse
    import json
    import asyncio

    # Pre-cached standard welcome messages and common tutor phrases
    _KNOWN_TRANSLATIONS: dict[str, str] = {
        "Hi there! I am Sarah, your AI English Tutor 👋 Let us chat and practice speaking English naturally. What is on your mind today?": (
            "Xin chào! Tôi là Sarah, gia sư tiếng Anh AI của bạn 👋 Hãy cùng trò chuyện và luyện nói tiếng Anh thật tự nhiên nhé. Hôm nay bạn đang nghĩ gì thế?"
        ),
        "Hello! I am Mr. Harrison, your Business English Coach. How can I assist with your professional communication today?": (
            "Xin chào! Tôi là ông Harrison, Huấn luyện viên Tiếng Anh Thương mại của bạn. Tôi có thể hỗ trợ gì cho giao tiếp công việc của bạn hôm nay?"
        ),
        "Good day! I am Mr. Harrison, your Business English Coach. How can I assist you with your professional communications today?": (
            "Chào bạn! Tôi là thầy Harrison, Huấn luyện viên Tiếng Anh Doanh nghiệp của bạn. Hôm nay tôi có thể hỗ trợ gì cho giao tiếp công việc chuyên nghiệp của bạn?"
        ),
        "Hello! I am Emma, your IELTS Academic Examiner. Let us work on expanding your vocabulary and grammatical complexity.": (
            "Xin chào! Tôi là Emma, giám khảo IELTS Academic của bạn. Hãy cùng mở rộng vốn từ vựng và nâng cao cấu trúc ngữ pháp nhé."
        ),
    }

    def _do_translate(text: str, target: str) -> str:
        clean = text.strip()
        if clean in _KNOWN_TRANSLATIONS and target == "vi":
            return _KNOWN_TRANSLATIONS[clean]

        # 1. Try MyMemory Translation API (Very fast, highly reliable for English -> Vietnamese)
        try:
            url_mm = f"https://api.mymemory.translated.net/get?q={urllib.parse.quote(clean)}&langpair=en|{target}"
            req_mm = urllib.request.Request(url_mm, headers={"User-Agent": "EnglishAI/1.0"})
            with urllib.request.urlopen(req_mm, timeout=6) as resp:
                data_mm = json.loads(resp.read().decode("utf-8"))
                trans_mm = data_mm.get("responseData", {}).get("translatedText", "").strip()
                if trans_mm and trans_mm.lower() != clean.lower():
                    return trans_mm
        except Exception:
            pass

        # 2. Try Google Translate API (gtx client)
        try:
            url_gtx = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl={target}&dt=t&q=" + urllib.parse.quote(clean)
            req_gtx = urllib.request.Request(url_gtx, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
            with urllib.request.urlopen(req_gtx, timeout=5) as resp:
                data_gtx = json.loads(resp.read().decode("utf-8"))
                trans_gtx = "".join([part[0] for part in data_gtx[0] if part and part[0]]).strip()
                if trans_gtx:
                    return trans_gtx
        except Exception:
            pass

        return clean

    translated = await asyncio.to_thread(_do_translate, request.text, request.target_lang)
    return TranslationResponse(
        original_text=request.text,
        translated_text=translated,
        target_lang=request.target_lang,
    )



@router.post("/chat", response_model=AIChatResponse)
async def chat_with_ai_tutor(
    request: AIChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Send a message to the AI Tutor (Sarah, Harrison, or Emma).
    Receives conversational reply, real-time error correction, and follow-up suggestion chips.
    """
    session_id = request.session_id or uuid.uuid4()
    persona = request.persona
    topic = request.topic or "General Conversation"
    history_payload = []

    # 1. Resolve or create chat session
    session = None
    try:
        if request.session_id:
            s_res = await db.execute(
                select(AITutorSession).where(
                    AITutorSession.id == request.session_id,
                    AITutorSession.user_id == current_user.id,
                )
            )
            session = s_res.scalar_one_or_none()
            if session:
                persona = session.persona
                topic = session.topic
        else:
            session = AITutorSession(
                id=session_id,
                user_id=current_user.id,
                persona=request.persona,
                topic=topic,
            )
            db.add(session)
            await db.flush()
            session_id = session.id
    except Exception:
        if db is not None:
            await db.rollback()

    if session_id not in _MEMORY_SESSIONS:
        _MEMORY_SESSIONS[session_id] = AITutorSession(
            id=session_id,
            user_id=current_user.id,
            persona=persona,
            topic=topic,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )

    # 2. Record user message
    user_msg = AITutorMessage(
        id=uuid.uuid4(),
        session_id=session_id,
        role="user",
        content=request.message,
        corrections=[],
        suggested_replies=[],
        created_at=datetime.now(timezone.utc),
    )
    if session_id not in _MEMORY_MESSAGES:
        _MEMORY_MESSAGES[session_id] = []
    _MEMORY_MESSAGES[session_id].append(user_msg)

    try:
        db.add(user_msg)
        await db.flush()

        # 3. Fetch recent history from DB
        history_res = await db.execute(
            select(AITutorMessage)
            .where(AITutorMessage.session_id == session_id)
            .order_by(AITutorMessage.created_at)
        )
        all_msgs = history_res.scalars().all()
        history_payload = [
            {"role": m.role, "content": m.content}
            for m in all_msgs[:-1]
        ]
    except Exception:
        if db is not None:
            await db.rollback()
        # Fallback to in-memory history
        all_mem_msgs = _MEMORY_MESSAGES.get(session_id, [])
        history_payload = [
            {"role": m.role, "content": m.content}
            for m in all_mem_msgs[:-1]
        ]

    # 4. Generate AI Tutor response
    user_level = current_user.current_level or "B1"
    ai_result = await AIService.chat_with_tutor(
        user_name=current_user.name,
        user_level=user_level,
        persona=persona,
        topic=topic,
        user_message=request.message,
        history=history_payload,
    )

    corrections_raw = AIService.normalize_corrections(
        ai_result.get("corrections", []), request.message
    )
    suggested_replies = AIService.normalize_suggestions(
        ai_result.get("suggested_replies", [])
    )
    reply_text = AIService._clean_text(
        ai_result.get("reply"), 4000
    ) or "I see! Could you tell me more about that?"

    # 5. Save assistant reply safely
    assistant_msg = AITutorMessage(
        id=uuid.uuid4(),
        session_id=session_id,
        role="assistant",
        content=reply_text,
        corrections=corrections_raw,
        suggested_replies=suggested_replies,
        created_at=datetime.now(timezone.utc),
    )
    _MEMORY_MESSAGES[session_id].append(assistant_msg)

    try:
        db.add(assistant_msg)
        current_user.total_xp = (current_user.total_xp or 0) + 5
        await db.flush()
    except Exception:
        if db is not None:
            await db.rollback()
        current_user.total_xp = (current_user.total_xp or 0) + 5

    return AIChatResponse(
        session_id=session_id,
        reply=reply_text,
        corrections=[AICorrectionItem.model_validate(c) for c in corrections_raw],
        suggested_replies=suggested_replies,
    )


@router.get("/sessions", response_model=list[AITutorSessionSummary])
async def list_ai_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List recent AI Tutor chat sessions."""
    try:
        result = await db.execute(
            select(AITutorSession)
            .where(AITutorSession.user_id == current_user.id)
            .order_by(desc(AITutorSession.updated_at))
            .limit(20)
        )
        sessions = result.scalars().all()
        if sessions:
            return [
                AITutorSessionSummary(
                    id=s.id,
                    persona=s.persona,
                    topic=s.topic,
                    created_at=s.created_at,
                    updated_at=s.updated_at,
                    message_count=len(s.messages) if s.messages else 0,
                )
                for s in sessions
            ]
    except Exception:
        pass

    return [
        AITutorSessionSummary(
            id=s.id,
            persona=s.persona,
            topic=s.topic,
            created_at=s.created_at or datetime.now(timezone.utc),
            updated_at=s.updated_at or datetime.now(timezone.utc),
            message_count=len(_MEMORY_MESSAGES.get(s.id, [])),
        )
        for s in _MEMORY_SESSIONS.values()
        if s.user_id == current_user.id
    ]


@router.get("/sessions/{session_id}/messages", response_model=list[AITutorMessageItem])
async def get_session_messages(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve full conversation history for a chat session."""
    messages = []
    try:
        s_res = await db.execute(
            select(AITutorSession).where(
                AITutorSession.id == session_id,
                AITutorSession.user_id == current_user.id,
            )
        )
        session = s_res.scalar_one_or_none()
        if session:
            m_res = await db.execute(
                select(AITutorMessage)
                .where(AITutorMessage.session_id == session_id)
                .order_by(AITutorMessage.created_at)
            )
            messages = m_res.scalars().all()
    except Exception:
        pass

    if not messages:
        messages = _MEMORY_MESSAGES.get(session_id, [])

    return messages


# ──────────────────────────────────────────────
# 2. AI Adaptive Exercise Generator
# ──────────────────────────────────────────────

@router.post("/generate-exercises", response_model=AIExerciseGenerateResponse)
async def generate_adaptive_exercises(
    request: AIExerciseGenerateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Generate dynamic quiz exercises targeting the learner's weaknesses.
    """
    user_level = current_user.current_level or "B1"

    # Fetch user weaknesses
    weaknesses = []
    try:
        p_res = await db.execute(
            select(UserProfile).where(UserProfile.user_id == current_user.id)
        )
        profile = p_res.scalar_one_or_none()
        weaknesses = (profile.weaknesses if profile and profile.weaknesses else [])
    except Exception:
        pass

    exercises_data = await AIService.generate_adaptive_exercises(
        user_level=user_level,
        weaknesses=weaknesses,
        count=request.count,
        skill=request.skill,
        topic=request.topic,
    )

    return AIExerciseGenerateResponse(
        target_level=user_level,
        targeted_weaknesses=weaknesses,
        exercises=[AIExerciseItem(**ex) for ex in exercises_data],
    )


# ──────────────────────────────────────────────
# 3. AI Writing Evaluator
# ──────────────────────────────────────────────

@router.post("/evaluate-writing", response_model=AIWritingResponse)
async def evaluate_writing(
    request: AIWritingSubmitRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Submit an essay or paragraph for multi-dimensional AI evaluation:
    Overall score, CEFR level, IELTS equivalent band, grammar corrections,
    vocabulary suggestions, and a polished rewritten version.
    """
    user_level = current_user.current_level or "B1"

    eval_result = await AIService.evaluate_writing(
        user_text=request.text,
        topic=request.topic,
        user_level=user_level,
    )

    # Save submission safely
    try:
        record = AIWritingSubmission(
            user_id=current_user.id,
            topic=request.topic,
            user_text=request.text,
            overall_score=eval_result["overall_score"],
            cefr_level=eval_result["cefr_level"],
            ielts_equivalent=eval_result["ielts_equivalent"],
            grammar_feedback=eval_result["grammar_feedback"],
            vocab_suggestions=eval_result["vocab_suggestions"],
            general_comment=eval_result["general_comment"],
            revised_text=eval_result["revised_text"],
        )
        db.add(record)
        current_user.total_xp = (current_user.total_xp or 0) + 25
        await db.flush()
    except Exception:
        current_user.total_xp = (current_user.total_xp or 0) + 25

    return AIWritingResponse(**eval_result)


# ──────────────────────────────────────────────
# 4. IELTS Speaking Mock Test
# ──────────────────────────────────────────────

class IELTSPartQA(BaseModel):
    question: str
    answer: str

class IELTSSpeakingSubmitRequest(BaseModel):
    topic: str
    part1_qa: list[IELTSPartQA]
    part2_answer: str
    part3_qa: list[IELTSPartQA]

@router.get("/ielts/prompt")
async def get_ielts_prompt(topic_id: str | None = None):
    """Retrieve an IELTS Speaking mock test prompt."""
    return AIService.get_ielts_speaking_prompt(topic_id)

@router.post("/ielts/evaluate")
async def evaluate_ielts_speaking(
    request: IELTSSpeakingSubmitRequest,
    current_user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Evaluate candidate's full 3-part IELTS Speaking Mock Test.
    Grades Band 1.0 - 9.0 across Fluency, Lexical, Grammar, Pronunciation.
    Awards +50 XP to the user if authenticated.
    """
    user_level = (current_user.current_level if current_user else None) or "B2"
    result = await AIService.evaluate_ielts_speaking(
        topic=request.topic,
        part1_qa=[item.model_dump() for item in request.part1_qa],
        part2_answer=request.part2_answer,
        part3_qa=[item.model_dump() for item in request.part3_qa],
        user_level=user_level,
    )

    # Award XP if user is logged in
    if current_user:
        try:
            current_user.total_xp = (current_user.total_xp or 0) + 50
            await db.flush()
        except Exception:
            current_user.total_xp = (current_user.total_xp or 0) + 50

    return result


# ──────────────────────────────────────────────
# 5. Mistake Notebook & SM-2 Spaced Repetition
# ──────────────────────────────────────────────

_DEFAULT_GUEST_ID = UUID("00000000-0000-0000-0000-000000000001")
_MEMORY_MISTAKES: dict[UUID, list[dict]] = {}

class MistakeCreateItem(BaseModel):
    original_text: str
    corrected_text: str
    explanation: str
    type: str = "grammar"  # grammar, vocabulary, pronunciation
    source: str = "practice"  # voice_call, writing, ielts, practice

class MistakeReviewSubmit(BaseModel):
    rating: int  # 0 to 5

@router.get("/mistakes")
async def get_mistakes(
    type: str | None = None,
    current_user: User | None = Depends(get_optional_user),
):
    """Get all saved mistakes in the user's notebook."""
    user_id = current_user.id if current_user else _DEFAULT_GUEST_ID
    items = _MEMORY_MISTAKES.get(user_id, [])
    if type and type != "all":
        items = [m for m in items if m.get("type") == type]
    return items

@router.post("/mistakes")
async def save_mistakes(
    mistakes: list[MistakeCreateItem],
    current_user: User | None = Depends(get_optional_user),
):
    """Save a list of mistakes to the user's notebook."""
    user_id = current_user.id if current_user else _DEFAULT_GUEST_ID
    if user_id not in _MEMORY_MISTAKES:
        _MEMORY_MISTAKES[user_id] = []

    now = datetime.now(timezone.utc).isoformat()
    saved = []
    for item in mistakes:
        # Avoid duplicate exact originals
        if any(m["original_text"].strip().lower() == item.original_text.strip().lower() for m in _MEMORY_MISTAKES[user_id]):
            continue
        entry = {
            "id": str(uuid.uuid4()),
            "original_text": item.original_text,
            "corrected_text": item.corrected_text,
            "explanation": item.explanation,
            "type": item.type,
            "source": item.source,
            "created_at": now,
            "repetition_count": 0,
            "interval_days": 1,
            "ease_factor": 2.5,
            "next_review_at": now,
            "status": "new",  # new, learning, mastered
        }
        _MEMORY_MISTAKES[user_id].insert(0, entry)
        saved.append(entry)

    return {"message": f"Saved {len(saved)} mistakes", "saved": saved}

@router.post("/mistakes/{mistake_id}/review")
async def review_mistake(
    mistake_id: str,
    request: MistakeReviewSubmit,
    current_user: User | None = Depends(get_optional_user),
):
    """
    Review a mistake using the SM-2 algorithm.
    Rating 0-2 = repeat, 3-5 = interval increases.
    """
    from ...services.sm2 import SM2Calculator

    user_id = current_user.id if current_user else _DEFAULT_GUEST_ID
    items = _MEMORY_MISTAKES.get(user_id, [])
    target = next((m for m in items if m["id"] == mistake_id), None)
    if not target:
        raise HTTPException(status_code=404, detail="Mistake item not found")

    rep_count = target.get("repetition_count", 0)
    ef = target.get("ease_factor", 2.5)
    interval = target.get("interval_days", 1)

    new_rep, new_ef, new_interval, next_review, status_str = SM2Calculator.calculate_next_review(
        repetition_count=rep_count,
        ease_factor=ef,
        interval_days=interval,
        quality=request.rating,
    )

    target["repetition_count"] = new_rep
    target["ease_factor"] = new_ef
    target["interval_days"] = new_interval
    target["next_review_at"] = next_review.isoformat()
    target["status"] = status_str

    # Reward XP for review if logged in
    if current_user:
        current_user.total_xp = (current_user.total_xp or 0) + 10

    return target

@router.delete("/mistakes/{mistake_id}")
async def delete_mistake(
    mistake_id: str,
    current_user: User | None = Depends(get_optional_user),
):
    """Remove a mistake from the notebook."""
    user_id = current_user.id if current_user else _DEFAULT_GUEST_ID
    if user_id in _MEMORY_MISTAKES:
        _MEMORY_MISTAKES[user_id] = [m for m in _MEMORY_MISTAKES[user_id] if m["id"] != mistake_id]
    return {"message": "Deleted successfully"}
