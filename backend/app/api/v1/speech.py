"""
Phase 4 — Speech AI API Routes
Endpoints for:
  - POST /speech/assess          → Pronunciation assessment (upload audio)
  - POST /speech/transcribe      → Speech-to-Text only
  - POST /speech/tts             → Text-to-Speech (native audio)
  - GET  /speech/practice        → Get practice sentences by level
  - GET  /speech/drills          → Get pronunciation drills
  - GET  /speech/history         → User's speaking session history
  - GET  /speech/stats           → User's speaking statistics
  - GET  /speech/audio/{filename}→ Serve stored audio files
"""
import uuid
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import select, func as sa_func
from sqlalchemy.ext.asyncio import AsyncSession

from ...database import get_db
from ...models.speech import AudioRecording, PronunciationDrill, SpeakingSession
from ...models.user import User
from ...schemas.speech import (
    PronunciationAssessResponse,
    PronunciationDrillItem,
    PronunciationDrillListResponse,
    SpeakingSessionListResponse,
    SpeakingSessionSummary,
    SpeakingStatsResponse,
    STTResponse,
    TTSRequest,
    TTSResponse,
    WordScore,
)
from ...services.speech_service import SpeechAIService, AUDIO_DIR
from ..deps import get_current_user, get_optional_user

router = APIRouter()


# ──────────────────────────────────────────────
#  1. Pronunciation Assessment
# ──────────────────────────────────────────────

@router.post(
    "/assess",
    response_model=PronunciationAssessResponse,
    summary="Assess pronunciation from uploaded audio",
)
async def assess_pronunciation(
    audio: UploadFile = File(..., description="Audio file (WAV/MP3/WebM)"),
    reference_text: str = Form(..., description="Target text the user read"),
    session_type: str = Form(default="read_aloud"),
    current_user: Optional[User] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Upload an audio recording and receive detailed pronunciation assessment:
    - Overall, fluency, accuracy, completeness, prosody scores
    - Per-word accuracy with error classification
    - Phoneme-level scoring
    - Vietnamese-language feedback and tips
    """
    # Validate file type
    allowed_types = ["audio/wav", "audio/wave", "audio/x-wav", "audio/mpeg", "audio/mp3", "audio/webm", "audio/ogg"]
    if audio.content_type and audio.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported audio format: {audio.content_type}. Use WAV, MP3, or WebM.",
        )

    # Read audio data
    audio_data = await audio.read()
    if len(audio_data) > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio file too large. Maximum 10MB.",
        )

    # Determine file format
    file_format = "wav"
    if audio.filename:
        ext = audio.filename.rsplit(".", 1)[-1].lower()
        if ext in ("mp3", "webm", "ogg", "m4a"):
            file_format = ext

    # Get user level
    user_level = current_user.current_level if (current_user and current_user.current_level) else "B1"

    # Run assessment
    result = await SpeechAIService.assess_pronunciation(
        audio_data=audio_data,
        reference_text=reference_text,
        user_level=user_level,
    )

    session_id = uuid.uuid4()
    if current_user:
        # Save session to database
        session = SpeakingSession(
            user_id=current_user.id,
            session_type=session_type,
            reference_text=reference_text,
            overall_score=result["overall_score"],
            fluency_score=result["fluency_score"],
            accuracy_score=result["accuracy_score"],
            completeness_score=result["completeness_score"],
            prosody_score=result["prosody_score"],
            recognised_text=result["recognised_text"],
            word_scores=result["word_scores"],
            feedback=result["feedback"],
            improvement_tips=result["improvement_tips"],
        )
        db.add(session)

        # Save audio recording reference
        audio_filename = f"user_{uuid.uuid4().hex[:12]}.{file_format}"
        audio_path = AUDIO_DIR / audio_filename
        audio_path.write_bytes(audio_data)

        recording = AudioRecording(
            session_id=session.id,
            audio_type="user",
            file_url=f"/api/v1/speech/audio/{audio_filename}",
            file_format=file_format,
        )
        db.add(recording)
        await db.flush()
        session_id = session.id

    # Generate TTS for reference (native audio)
    tts_result = await SpeechAIService.text_to_speech(reference_text)
    native_audio_url = tts_result.get("audio_url") or None

    return PronunciationAssessResponse(
        session_id=session_id,
        reference_text=reference_text,
        recognised_text=result["recognised_text"],
        overall_score=result["overall_score"],
        fluency_score=result["fluency_score"],
        accuracy_score=result["accuracy_score"],
        completeness_score=result["completeness_score"],
        prosody_score=result["prosody_score"],
        word_scores=[WordScore(**ws) for ws in result["word_scores"]],
        feedback=result["feedback"],
        improvement_tips=result["improvement_tips"],
        native_audio_url=native_audio_url,
    )



# ──────────────────────────────────────────────
#  2. Speech-to-Text Only
# ──────────────────────────────────────────────

@router.post(
    "/transcribe",
    response_model=STTResponse,
    summary="Transcribe audio to text",
)
async def transcribe_audio(
    audio: UploadFile = File(..., description="Audio file to transcribe"),
    language: str = Form(default="en-US"),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Upload audio and get transcription without pronunciation scoring."""
    audio_data = await audio.read()
    if len(audio_data) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio file too large. Maximum 10MB.",
        )

    file_format = "wav"
    if audio.filename:
        ext = audio.filename.rsplit(".", 1)[-1].lower()
        if ext in ("mp3", "webm", "ogg", "m4a"):
            file_format = ext

    result = await SpeechAIService.transcribe_audio(
        audio_data=audio_data,
        language=language,
        file_format=file_format,
    )
    return STTResponse(**result)


# ──────────────────────────────────────────────
#  3. Text-to-Speech
# ──────────────────────────────────────────────

@router.post(
    "/tts",
    response_model=TTSResponse,
    summary="Generate native speaker audio from text",
)
async def text_to_speech(
    request: TTSRequest,
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Convert text to speech with selectable voice and speed."""
    result = await SpeechAIService.text_to_speech(
        text=request.text,
        voice=request.voice,
        speed=request.speed,
    )
    return TTSResponse(**result)


# ──────────────────────────────────────────────
#  4. Practice Content
# ──────────────────────────────────────────────

@router.get(
    "/practice",
    summary="Get practice sentences by CEFR level",
)
async def get_practice_sentences(
    level: str = "B1",
    count: int = 5,
    current_user: User = Depends(get_current_user),
):
    """Get curated practice sentences appropriate for the user's level."""
    sentences = SpeechAIService.get_practice_sentences(level=level, count=count)
    return {
        "level": level.upper(),
        "sentences": sentences,
        "total": len(sentences),
    }


@router.get(
    "/drills",
    response_model=PronunciationDrillListResponse,
    summary="Get pronunciation drills",
)
async def get_pronunciation_drills(
    difficulty: str = "B1",
    drill_type: str | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Get pronunciation drill exercises.
    Falls back to built-in data if database drills are empty.
    """
    # Try database first
    query = select(PronunciationDrill).where(PronunciationDrill.is_active == True)
    if drill_type:
        query = query.where(PronunciationDrill.drill_type == drill_type)

    result = await db.execute(query)
    db_drills = result.scalars().all()

    if db_drills:
        drills = [PronunciationDrillItem.model_validate(d) for d in db_drills]
    else:
        # Use built-in drill data
        built_in = SpeechAIService.get_pronunciation_drills_data(difficulty=difficulty)
        if drill_type:
            built_in = [d for d in built_in if d["drill_type"] == drill_type]
        drills = [
            PronunciationDrillItem(
                id=uuid.uuid4(),
                **d,
            )
            for d in built_in
        ]

    return PronunciationDrillListResponse(
        drills=drills,
        total=len(drills),
    )


# ──────────────────────────────────────────────
#  5. Session History & Stats
# ──────────────────────────────────────────────

@router.get(
    "/history",
    response_model=SpeakingSessionListResponse,
    summary="Get speaking practice history",
)
async def get_speaking_history(
    skip: int = 0,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get the user's speaking practice session history."""
    # Count total
    count_query = (
        select(sa_func.count(SpeakingSession.id))
        .where(SpeakingSession.user_id == current_user.id)
    )
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Get sessions
    query = (
        select(SpeakingSession)
        .where(SpeakingSession.user_id == current_user.id)
        .order_by(SpeakingSession.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(query)
    sessions = result.scalars().all()

    # Calculate average
    avg_query = (
        select(sa_func.avg(SpeakingSession.overall_score))
        .where(SpeakingSession.user_id == current_user.id)
        .where(SpeakingSession.overall_score.isnot(None))
    )
    avg_result = await db.execute(avg_query)
    avg_score = avg_result.scalar()

    return SpeakingSessionListResponse(
        sessions=[SpeakingSessionSummary.model_validate(s) for s in sessions],
        total=total,
        average_score=round(avg_score, 1) if avg_score else None,
    )


@router.get(
    "/stats",
    response_model=SpeakingStatsResponse,
    summary="Get speaking practice statistics",
)
async def get_speaking_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get aggregate speaking practice statistics for the user."""
    query = (
        select(SpeakingSession)
        .where(SpeakingSession.user_id == current_user.id)
        .order_by(SpeakingSession.created_at.asc())
    )
    result = await db.execute(query)
    sessions = result.scalars().all()

    sessions_data = [
        {
            "overall_score": s.overall_score,
            "fluency_score": s.fluency_score,
            "accuracy_score": s.accuracy_score,
            "word_scores": s.word_scores or [],
            "created_at": s.created_at.isoformat() if s.created_at else "",
        }
        for s in sessions
    ]

    stats = SpeechAIService.compute_speaking_stats(sessions_data)
    return SpeakingStatsResponse(**stats)


# ──────────────────────────────────────────────
#  6. Serve Audio Files
# ──────────────────────────────────────────────

@router.get(
    "/audio/{filename}",
    summary="Serve stored audio file",
)
async def serve_audio(filename: str):
    """Serve audio files from the storage directory."""
    # Sanitize filename
    safe_name = Path(filename).name
    filepath = AUDIO_DIR / safe_name

    if not filepath.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Audio file not found.",
        )

    # Determine media type
    ext = safe_name.rsplit(".", 1)[-1].lower()
    media_types = {
        "wav": "audio/wav",
        "mp3": "audio/mpeg",
        "webm": "audio/webm",
        "ogg": "audio/ogg",
        "m4a": "audio/mp4",
    }
    media_type = media_types.get(ext, "application/octet-stream")

    return FileResponse(filepath, media_type=media_type)
