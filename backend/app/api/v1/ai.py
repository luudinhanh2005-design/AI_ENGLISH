from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

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
from ..deps import get_current_user

router = APIRouter()


# ──────────────────────────────────────────────
# 1. AI Tutor Chat
# ──────────────────────────────────────────────

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
    # 1. Resolve or create chat session
    if request.session_id:
        s_res = await db.execute(
            select(AITutorSession).where(
                AITutorSession.id == request.session_id,
                AITutorSession.user_id == current_user.id,
            )
        )
        session = s_res.scalar_one_or_none()
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Chat session not found",
            )
    else:
        session = AITutorSession(
            user_id=current_user.id,
            persona=request.persona,
            topic=request.topic or "General Conversation",
        )
        db.add(session)
        await db.flush()

    # 2. Save user message
    user_msg = AITutorMessage(
        session_id=session.id,
        role="user",
        content=request.message,
    )
    db.add(user_msg)
    await db.flush()

    # 3. Fetch recent history for conversational context
    history_res = await db.execute(
        select(AITutorMessage)
        .where(AITutorMessage.session_id == session.id)
        .order_by(AITutorMessage.created_at)
    )
    all_msgs = history_res.scalars().all()
    history_payload = [
        {"role": m.role, "content": m.content}
        for m in all_msgs[:-1]  # Exclude current message
    ]

    # 4. Generate AI Tutor response with real-time error analysis
    user_level = current_user.current_level or "B1"
    ai_result = await AIService.chat_with_tutor(
        user_name=current_user.name,
        user_level=user_level,
        persona=session.persona,
        topic=session.topic,
        user_message=request.message,
        history=history_payload,
    )

    corrections_raw = ai_result.get("corrections", [])
    suggested_replies = ai_result.get("suggested_replies", [])
    reply_text = ai_result.get("reply", "I see! Could you tell me more about that?")

    # 5. Save assistant reply to database
    assistant_msg = AITutorMessage(
        session_id=session.id,
        role="assistant",
        content=reply_text,
        corrections=corrections_raw,
        suggested_replies=suggested_replies,
    )
    db.add(assistant_msg)

    # Award XP for conversation practice (+5 XP)
    current_user.total_xp += 5
    await db.flush()

    return AIChatResponse(
        session_id=session.id,
        reply=reply_text,
        corrections=[AICorrectionItem(**c) for c in corrections_raw],
        suggested_replies=suggested_replies,
    )


@router.get("/sessions", response_model=list[AITutorSessionSummary])
async def list_ai_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List recent AI Tutor chat sessions."""
    result = await db.execute(
        select(AITutorSession)
        .where(AITutorSession.user_id == current_user.id)
        .order_by(desc(AITutorSession.updated_at))
        .limit(20)
    )
    sessions = result.scalars().all()
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


@router.get("/sessions/{session_id}/messages", response_model=list[AITutorMessageItem])
async def get_session_messages(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve full conversation history for a chat session."""
    s_res = await db.execute(
        select(AITutorSession).where(
            AITutorSession.id == session_id,
            AITutorSession.user_id == current_user.id,
        )
    )
    session = s_res.scalar_one_or_none()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat session not found",
        )

    m_res = await db.execute(
        select(AITutorMessage)
        .where(AITutorMessage.session_id == session_id)
        .order_by(AITutorMessage.created_at)
    )
    messages = m_res.scalars().all()
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
    p_res = await db.execute(
        select(UserProfile).where(UserProfile.user_id == current_user.id)
    )
    profile = p_res.scalar_one_or_none()
    weaknesses = (profile.weaknesses if profile and profile.weaknesses else [])

    exercises_data = await AIService.generate_adaptive_exercises(
        user_level=user_level,
        weaknesses=weaknesses,
        count=request.count,
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

    # Save submission
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

    # Award XP (+25 XP for writing submission)
    current_user.total_xp += 25
    await db.flush()

    return AIWritingResponse(**eval_result)
