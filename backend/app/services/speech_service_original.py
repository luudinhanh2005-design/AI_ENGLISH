"""
Phase 4 — Speech AI Service
Provides:
  1. Speech-to-Text (STT) — OpenAI Whisper / Google Speech / built-in fallback
  2. Pronunciation Assessment — phoneme-level scoring with IPA analysis
  3. Text-to-Speech (TTS) — native speaker audio generation
  4. Intelligent fallback engine when no cloud API is configured
"""
import json
import logging
import math
import os
import re
import uuid
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any, Optional

import httpx

from ..config import settings

logger = logging.getLogger(__name__)

# Directory for storing generated audio files
AUDIO_DIR = Path("storage/audio")
AUDIO_DIR.mkdir(parents=True, exist_ok=True)


class SpeechAIService:
    """Central Speech AI engine for EnglishAI."""

    # ────────────────────────────────────────
    #  IPA Reference Data
    # ────────────────────────────────────────
    # Common English phonemes and their difficulty rankings for Vietnamese speakers
    DIFFICULT_PHONEMES_VI: dict[str, dict[str, Any]] = {
        "θ": {"example": "think", "tip_vi": "Đặt đầu lưỡi giữa hai hàm răng và thổi nhẹ.", "difficulty": 5},
        "ð": {"example": "this", "tip_vi": "Giống 'θ' nhưng rung dây thanh (có tiếng).", "difficulty": 5},
        "ʃ": {"example": "she", "tip_vi": "Giống âm 'sh' — uốn lưỡi ra sau hơn so với 's'.", "difficulty": 3},
        "ʒ": {"example": "measure", "tip_vi": "Giống 'ʃ' nhưng rung dây thanh.", "difficulty": 4},
        "r": {"example": "red", "tip_vi": "Cuộn lưỡi ra sau, KHÔNG chạm vòm miệng. Khác âm 'r' tiếng Việt.", "difficulty": 4},
        "l": {"example": "light", "tip_vi": "Đặt đầu lưỡi chạm vào lợi trên. Âm 'l' cuối từ cần kéo dài.", "difficulty": 3},
        "ɪ": {"example": "sit", "tip_vi": "Ngắn hơn 'i:' — miệng hé mở hơn, giống giữa 'i' và 'e'.", "difficulty": 2},
        "æ": {"example": "cat", "tip_vi": "Miệng mở rộng, giống nằm giữa 'e' và 'a'.", "difficulty": 3},
        "ʊ": {"example": "book", "tip_vi": "Ngắn hơn 'u:' — môi tròn nhẹ, lưỡi kéo nhẹ ra sau.", "difficulty": 2},
        "ɜː": {"example": "bird", "tip_vi": "Mở miệng trung bình, lưỡi ở giữa, kéo dài.", "difficulty": 4},
        "ŋ": {"example": "sing", "tip_vi": "Giống 'ng' trong tiếng Việt. Lưỡi chạm vòm mềm phía sau.", "difficulty": 1},
    }

    # Sample reference sentences at different levels
    PRACTICE_SENTENCES: dict[str, list[dict[str, str]]] = {
        "A1": [
            {"text": "Hello, my name is Anna.", "focus": "Basic greeting intonation"},
            {"text": "I like to eat apples and bananas.", "focus": "Vowel sounds: /æ/ and /ə/"},
            {"text": "The cat is sitting on the mat.", "focus": "Short vowel /æ/ and final consonants"},
            {"text": "Where is the bus stop?", "focus": "Rising intonation for questions"},
            {"text": "She has three brothers and two sisters.", "focus": "Th-sound /θ/ and plural /z/"},
        ],
        "A2": [
            {"text": "I usually go to the gym after work.", "focus": "Sentence stress and weak forms"},
            {"text": "Can you tell me the way to the library?", "focus": "Connected speech and intonation"},
            {"text": "The weather is getting warmer these days.", "focus": "/ð/ in 'the' and 'these'"},
            {"text": "She bought a beautiful red dress yesterday.", "focus": "Past tense -ed endings"},
            {"text": "Would you like a cup of tea or coffee?", "focus": "Linking and reduction"},
        ],
        "B1": [
            {"text": "I've been studying English for three years now.", "focus": "Present perfect continuous rhythm"},
            {"text": "The conference was absolutely fascinating.", "focus": "Word stress on multi-syllable words"},
            {"text": "If I had more time, I would travel around the world.", "focus": "Conditional intonation contour"},
            {"text": "She's thinking about changing her career path.", "focus": "/θ/ vs /ð/ contrast"},
            {"text": "The children were playing enthusiastically in the park.", "focus": "Adverb stress and linking"},
        ],
        "B2": [
            {"text": "The government has implemented several measures to reduce pollution.", "focus": "Multi-syllable word stress"},
            {"text": "Although the evidence suggests otherwise, many people still believe the myth.", "focus": "Clause boundary intonation"},
            {"text": "She's thoroughly prepared for the comprehensive examination.", "focus": "/θ/ cluster and schwa reduction"},
            {"text": "Innovative technologies are revolutionizing the healthcare industry.", "focus": "Technical vocabulary pronunciation"},
            {"text": "Despite the challenging circumstances, they persevered remarkably.", "focus": "Consonant clusters and rhythm"},
        ],
        "C1": [
            {"text": "The unprecedented economic downturn has disproportionately affected marginalized communities.", "focus": "Academic register rhythm"},
            {"text": "Notwithstanding the controversial nature of the proposal, the committee reached a unanimous decision.", "focus": "Formal discourse prosody"},
            {"text": "The archaeological excavation yielded extraordinary artefacts dating back millennia.", "focus": "Complex consonant clusters"},
            {"text": "Her characteristically meticulous approach to research has garnered international recognition.", "focus": "Multi-syllable stress patterns"},
            {"text": "The philosophical implications of artificial intelligence remain profoundly contentious.", "focus": "Academic vocabulary + linking"},
        ],
    }

    # ────────────────────────────────────────
    #  1. SPEECH-TO-TEXT (STT)
    # ────────────────────────────────────────

    @classmethod
    async def transcribe_audio(
        cls,
        audio_data: bytes,
        language: str = "en-US",
        file_format: str = "wav",
    ) -> dict[str, Any]:
        """
        Transcribe audio to text.
        Tries: OpenAI Whisper → Google Speech → rule-based fallback.
        """
        # 1. Try OpenAI Whisper
        if settings.openai_api_key:
            try:
                return await cls._whisper_transcribe(audio_data, language, file_format)
            except Exception as e:
                logger.warning(f"Whisper STT failed, trying fallback: {e}")

        # 2. Try Google Speech-to-Text (via Gemini API key for simplicity)
        if settings.google_ai_api_key:
            try:
                return await cls._google_stt(audio_data, language)
            except Exception as e:
                logger.warning(f"Google STT failed, using fallback: {e}")

        # 3. Fallback — return simulated result
        return cls._fallback_stt(language)

    @classmethod
    async def _whisper_transcribe(
        cls,
        audio_data: bytes,
        language: str,
        file_format: str,
    ) -> dict[str, Any]:
        """Transcribe via OpenAI Whisper API."""
        url = "https://api.openai.com/v1/audio/transcriptions"
        headers = {"Authorization": f"Bearer {settings.openai_api_key}"}

        lang_code = language.split("-")[0]  # "en-US" → "en"

        async with httpx.AsyncClient(timeout=30.0) as client:
            files = {"file": (f"audio.{file_format}", audio_data, f"audio/{file_format}")}
            data = {
                "model": "whisper-1",
                "language": lang_code,
                "response_format": "verbose_json",
                "timestamp_granularities[]": "word",
            }
            resp = await client.post(url, headers=headers, files=files, data=data)
            resp.raise_for_status()
            result = resp.json()

            words = []
            for w in result.get("words", []):
                words.append({
                    "word": w["word"],
                    "start_time": w.get("start", 0),
                    "end_time": w.get("end", 0),
                    "confidence": 0.95,  # Whisper doesn't return per-word confidence
                })

            return {
                "transcript": result["text"],
                "confidence": 0.95,
                "language": language,
                "duration_seconds": result.get("duration"),
                "words": words,
            }

    @classmethod
    async def _google_stt(
        cls,
        audio_data: bytes,
        language: str,
    ) -> dict[str, Any]:
        """Transcribe via Google Cloud Speech-to-Text REST API."""
        import base64

        url = f"https://speech.googleapis.com/v1/speech:recognize?key={settings.google_ai_api_key}"
        payload = {
            "config": {
                "encoding": "LINEAR16",
                "sampleRateHertz": 16000,
                "languageCode": language,
                "enableWordTimeOffsets": True,
                "model": "default",
            },
            "audio": {
                "content": base64.b64encode(audio_data).decode("utf-8"),
            },
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
            data = resp.json()

            if not data.get("results"):
                return cls._fallback_stt(language)

            result = data["results"][0]
            alt = result["alternatives"][0]

            words = []
            for w in alt.get("words", []):
                words.append({
                    "word": w["word"],
                    "start_time": float(w.get("startTime", "0s").rstrip("s")),
                    "end_time": float(w.get("endTime", "0s").rstrip("s")),
                    "confidence": alt.get("confidence", 0.9),
                })

            return {
                "transcript": alt["transcript"],
                "confidence": alt.get("confidence", 0.9),
                "language": language,
                "duration_seconds": None,
                "words": words,
            }

    @classmethod
    def _fallback_stt(cls, language: str) -> dict[str, Any]:
        """Simulated STT when no cloud API is available."""
        return {
            "transcript": "[Transcription requires API key — configure OPENAI_API_KEY or GOOGLE_AI_API_KEY]",
            "confidence": 0.0,
            "language": language,
            "duration_seconds": None,
            "words": [],
        }

    # ────────────────────────────────────────
    #  2. PRONUNCIATION ASSESSMENT
    # ────────────────────────────────────────

    @classmethod
    async def assess_pronunciation(
        cls,
        audio_data: bytes,
        reference_text: str,
        user_level: str = "B1",
        language: str = "en-US",
    ) -> dict[str, Any]:
        """
        Full pronunciation assessment pipeline:
        1. Transcribe audio (STT)
        2. Compare with reference text
        3. Score fluency, accuracy, completeness, prosody
        4. Generate per-word scores
        5. Provide targeted feedback
        """
        # Step 1: Transcribe
        stt_result = await cls.transcribe_audio(audio_data, language)
        recognised_text = stt_result["transcript"]

        # Step 2: Assess
        assessment = cls._compute_pronunciation_scores(
            reference_text=reference_text,
            recognised_text=recognised_text,
            stt_confidence=stt_result["confidence"],
            stt_words=stt_result.get("words", []),
        )

        # Step 3: Generate feedback
        feedback = cls._generate_pronunciation_feedback(
            assessment=assessment,
            user_level=user_level,
        )

        return {
            "reference_text": reference_text,
            "recognised_text": recognised_text,
            "overall_score": assessment["overall_score"],
            "fluency_score": assessment["fluency_score"],
            "accuracy_score": assessment["accuracy_score"],
            "completeness_score": assessment["completeness_score"],
            "prosody_score": assessment["prosody_score"],
            "word_scores": assessment["word_scores"],
            "feedback": feedback["feedback"],
            "improvement_tips": feedback["tips"],
        }

    @classmethod
    def _compute_pronunciation_scores(
        cls,
        reference_text: str,
        recognised_text: str,
        stt_confidence: float,
        stt_words: list[dict],
    ) -> dict[str, Any]:
        """
        Compare recognised text against reference and compute detailed scores.
        Uses SequenceMatcher for alignment when API word-level data is absent.
        """
        ref_words = reference_text.lower().strip().split()
        rec_words = recognised_text.lower().strip().split()

        # Sequence matching for word-level alignment
        matcher = SequenceMatcher(None, ref_words, rec_words)
        ratio = matcher.ratio()

        # Build word-level scores
        word_scores: list[dict] = []
        matched_ops = matcher.get_opcodes()

        for tag, i1, i2, j1, j2 in matched_ops:
            if tag == "equal":
                for idx in range(i1, i2):
                    word_scores.append({
                        "word": ref_words[idx],
                        "accuracy_score": round(85 + stt_confidence * 15, 1),
                        "error_type": "None",
                        "phonemes": cls._estimate_phoneme_scores(ref_words[idx], correct=True),
                    })
            elif tag == "replace":
                for idx in range(i1, i2):
                    rec_word = rec_words[j1 + (idx - i1)] if (j1 + (idx - i1)) < j2 else ""
                    word_sim = SequenceMatcher(None, ref_words[idx], rec_word).ratio()
                    word_scores.append({
                        "word": ref_words[idx],
                        "accuracy_score": round(word_sim * 100, 1),
                        "error_type": "Mispronunciation",
                        "phonemes": cls._estimate_phoneme_scores(ref_words[idx], correct=False),
                    })
            elif tag == "delete":
                for idx in range(i1, i2):
                    word_scores.append({
                        "word": ref_words[idx],
                        "accuracy_score": 0.0,
                        "error_type": "Omission",
                        "phonemes": [],
                    })
            elif tag == "insert":
                for idx in range(j1, j2):
                    word_scores.append({
                        "word": f"[{rec_words[idx]}]",
                        "accuracy_score": 0.0,
                        "error_type": "Insertion",
                        "phonemes": [],
                    })

        # Compute aggregate scores
        correct_words = [w for w in word_scores if w["error_type"] == "None"]
        total_ref = len(ref_words)

        accuracy = ratio * 100
        completeness = (len(correct_words) / max(total_ref, 1)) * 100
        fluency = min(100, accuracy * 0.8 + completeness * 0.2 + stt_confidence * 10)

        # Prosody is estimated from consistency of word scores
        if correct_words:
            scores = [w["accuracy_score"] for w in correct_words]
            avg = sum(scores) / len(scores)
            variance = sum((s - avg) ** 2 for s in scores) / len(scores)
            prosody = max(0, 100 - math.sqrt(variance) * 2)
        else:
            prosody = 30.0

        overall = (accuracy * 0.35 + fluency * 0.25 + completeness * 0.25 + prosody * 0.15)

        return {
            "overall_score": round(min(100, max(0, overall)), 1),
            "fluency_score": round(min(100, max(0, fluency)), 1),
            "accuracy_score": round(min(100, max(0, accuracy)), 1),
            "completeness_score": round(min(100, max(0, completeness)), 1),
            "prosody_score": round(min(100, max(0, prosody)), 1),
            "word_scores": word_scores,
        }

    @classmethod
    def _estimate_phoneme_scores(cls, word: str, correct: bool) -> list[dict]:
        """Estimate phoneme-level scores for a word (simplified)."""
        # Simple phoneme estimation based on common patterns
        phoneme_map: dict[str, list[str]] = {
            "th": ["θ"],
            "sh": ["ʃ"],
            "ch": ["tʃ"],
            "ng": ["ŋ"],
            "r": ["r"],
            "l": ["l"],
        }

        phonemes: list[dict] = []
        word_lower = word.lower()

        for pattern, ipa_list in phoneme_map.items():
            if pattern in word_lower:
                for ipa in ipa_list:
                    score = 85 + (15 * (1 if correct else 0)) - cls.DIFFICULT_PHONEMES_VI.get(ipa, {}).get("difficulty", 0) * 3
                    phonemes.append({
                        "phoneme": ipa,
                        "score": round(min(100, max(0, score)), 1),
                    })

        return phonemes

    @classmethod
    def _generate_pronunciation_feedback(
        cls,
        assessment: dict[str, Any],
        user_level: str,
    ) -> dict[str, Any]:
        """Generate human-readable feedback and actionable tips."""
        overall = assessment["overall_score"]
        word_scores = assessment["word_scores"]

        # Overall feedback
        if overall >= 90:
            feedback = (
                "Xuất sắc! 🎉 Phát âm của bạn rất tự nhiên và gần như bản xứ. "
                "Tiếp tục duy trì phong độ này nhé!"
            )
        elif overall >= 75:
            feedback = (
                "Rất tốt! 👏 Phát âm của bạn khá chuẩn. "
                "Chỉ cần chú ý thêm một vài âm tiết nhỏ để hoàn hảo hơn."
            )
        elif overall >= 60:
            feedback = (
                "Khá ổn! 😊 Bạn đã nắm được cơ bản. "
                "Hãy luyện tập thêm các âm khó và chú ý đến nhịp điệu câu."
            )
        elif overall >= 40:
            feedback = (
                "Tiếp tục cố gắng! 💪 Một số từ cần luyện thêm. "
                "Hãy nghe lại bản ghi âm mẫu và so sánh với phát âm của bạn."
            )
        else:
            feedback = (
                "Đừng nản lòng! 🌟 Phát âm là kỹ năng cần nhiều thời gian. "
                "Hãy bắt đầu chậm lại, nghe kỹ từng từ, và luyện từng câu ngắn."
            )

        # Specific tips based on problem areas
        tips: list[str] = []
        mispronounced = [w for w in word_scores if w["error_type"] == "Mispronunciation"]
        omitted = [w for w in word_scores if w["error_type"] == "Omission"]

        if mispronounced:
            problem_words = [w["word"] for w in mispronounced[:3]]
            tips.append(
                f"🔤 Luyện phát âm lại các từ: {', '.join(problem_words)}. "
                "Hãy nghe bản ghi âm mẫu và bắt chước."
            )

            # Check for specific difficult phonemes
            for w in mispronounced:
                for ph in w.get("phonemes", []):
                    phoneme = ph["phoneme"]
                    if phoneme in cls.DIFFICULT_PHONEMES_VI and ph["score"] < 70:
                        info = cls.DIFFICULT_PHONEMES_VI[phoneme]
                        tips.append(
                            f"💡 Âm /{phoneme}/ (ví dụ: '{info['example']}'): {info['tip_vi']}"
                        )

        if omitted:
            omitted_words = [w["word"] for w in omitted[:3]]
            tips.append(
                f"⚠️ Bạn bỏ sót các từ: {', '.join(omitted_words)}. "
                "Hãy đọc chậm hơn và phát âm rõ từng từ."
            )

        if assessment["fluency_score"] < 60:
            tips.append(
                "🎵 Hãy chú ý đến nhịp điệu và tốc độ nói. "
                "Đọc theo shadowing (nghe và nói theo) để cải thiện độ trôi chảy."
            )

        if assessment["prosody_score"] < 60:
            tips.append(
                "🎶 Ngữ điệu cần cải thiện. Câu hỏi thường lên giọng cuối câu, "
                "câu khẳng định thường xuống giọng. Hãy luyện tập intonation."
            )

        # Always add general encouragement
        if not tips:
            tips.append(
                "✅ Phát âm tổng thể rất tốt! Hãy thử thách bản thân với các câu khó hơn."
            )

        return {"feedback": feedback, "tips": tips}

    # ────────────────────────────────────────
    #  3. TEXT-TO-SPEECH (TTS)
    # ────────────────────────────────────────

    @classmethod
    async def text_to_speech(
        cls,
        text: str,
        voice: str = "en-US-Standard-C",
        speed: float = 1.0,
    ) -> dict[str, Any]:
        """
        Generate native-speaker audio for a text.
        Tries: OpenAI TTS → Google TTS → fallback.
        """
        # 1. Try OpenAI TTS
        if settings.openai_api_key:
            try:
                return await cls._openai_tts(text, voice, speed)
            except Exception as e:
                logger.warning(f"OpenAI TTS failed: {e}")

        # 2. Try Google TTS
        if settings.google_ai_api_key:
            try:
                return await cls._google_tts(text, voice, speed)
            except Exception as e:
                logger.warning(f"Google TTS failed: {e}")

        # 3. Fallback
        return cls._fallback_tts(text, voice)

    @classmethod
    async def _openai_tts(
        cls,
        text: str,
        voice: str,
        speed: float,
    ) -> dict[str, Any]:
        """Generate speech via OpenAI TTS API."""
        url = "https://api.openai.com/v1/audio/speech"
        headers = {
            "Authorization": f"Bearer {settings.openai_api_key}",
            "Content-Type": "application/json",
        }
        # Map generic voice ID to OpenAI voices
        openai_voice_map = {
            "en-US-Standard-C": "nova",
            "en-US-Standard-A": "alloy",
            "en-US-Standard-B": "echo",
            "en-GB-Standard-A": "fable",
            "en-US-Standard-D": "onyx",
            "en-US-Standard-E": "shimmer",
        }
        openai_voice = openai_voice_map.get(voice, "nova")

        payload = {
            "model": "tts-1",
            "input": text,
            "voice": openai_voice,
            "speed": speed,
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, headers=headers, json=payload)
            resp.raise_for_status()

            # Save audio file
            filename = f"tts_{uuid.uuid4().hex[:12]}.mp3"
            filepath = AUDIO_DIR / filename
            filepath.write_bytes(resp.content)

            return {
                "audio_url": f"/api/v1/speech/audio/{filename}",
                "text": text,
                "voice": openai_voice,
                "duration_seconds": None,
            }

    @classmethod
    async def _google_tts(
        cls,
        text: str,
        voice: str,
        speed: float,
    ) -> dict[str, Any]:
        """Generate speech via Google Cloud TTS API."""
        url = f"https://texttospeech.googleapis.com/v1/text:synthesize?key={settings.google_ai_api_key}"
        payload = {
            "input": {"text": text},
            "voice": {
                "languageCode": "en-US",
                "name": voice,
            },
            "audioConfig": {
                "audioEncoding": "MP3",
                "speakingRate": speed,
            },
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
            data = resp.json()

            import base64
            audio_bytes = base64.b64decode(data["audioContent"])

            filename = f"tts_{uuid.uuid4().hex[:12]}.mp3"
            filepath = AUDIO_DIR / filename
            filepath.write_bytes(audio_bytes)

            return {
                "audio_url": f"/api/v1/speech/audio/{filename}",
                "text": text,
                "voice": voice,
                "duration_seconds": None,
            }

    @classmethod
    def _fallback_tts(cls, text: str, voice: str) -> dict[str, Any]:
        """Fallback when no TTS API is available."""
        return {
            "audio_url": "",
            "text": text,
            "voice": voice,
            "duration_seconds": None,
            "_notice": "TTS requires API key — configure OPENAI_API_KEY or GOOGLE_AI_API_KEY",
        }

    # ────────────────────────────────────────
    #  4. PRACTICE CONTENT GENERATION
    # ────────────────────────────────────────

    @classmethod
    def get_practice_sentences(
        cls,
        level: str = "B1",
        count: int = 5,
    ) -> list[dict[str, str]]:
        """Get practice sentences for a given CEFR level."""
        level_upper = level.upper()
        sentences = cls.PRACTICE_SENTENCES.get(level_upper, cls.PRACTICE_SENTENCES["B1"])
        return sentences[:count]

    @classmethod
    def get_pronunciation_drills_data(
        cls,
        difficulty: str = "B1",
    ) -> list[dict[str, Any]]:
        """Get built-in pronunciation drill content."""
        drills = [
            {
                "drill_type": "minimal_pair",
                "difficulty": "A2",
                "title": "Ship vs Sheep",
                "description": "Luyện phân biệt nguyên âm ngắn /ɪ/ và nguyên âm dài /iː/",
                "content": "ship - sheep | sit - seat | bit - beat | fill - feel | hit - heat",
                "ipa_transcription": "/ʃɪp/ - /ʃiːp/ | /sɪt/ - /siːt/ | /bɪt/ - /biːt/",
                "target_phonemes": ["ɪ", "iː"],
            },
            {
                "drill_type": "minimal_pair",
                "difficulty": "A2",
                "title": "Bat vs But",
                "description": "Luyện phân biệt /æ/ và /ʌ/",
                "content": "bat - but | cat - cut | ran - run | cap - cup | match - much",
                "ipa_transcription": "/bæt/ - /bʌt/ | /kæt/ - /kʌt/ | /ræn/ - /rʌn/",
                "target_phonemes": ["æ", "ʌ"],
            },
            {
                "drill_type": "minimal_pair",
                "difficulty": "B1",
                "title": "Think vs Sink",
                "description": "Luyện phân biệt /θ/ và /s/ — một lỗi phổ biến của người Việt",
                "content": "think - sink | thick - sick | thin - sin | thumb - sum | thank - sank",
                "ipa_transcription": "/θɪŋk/ - /sɪŋk/ | /θɪk/ - /sɪk/ | /θɪn/ - /sɪn/",
                "target_phonemes": ["θ", "s"],
            },
            {
                "drill_type": "tongue_twister",
                "difficulty": "B1",
                "title": "She Sells Seashells",
                "description": "Luyện âm /ʃ/ và /s/ trong câu nối",
                "content": "She sells seashells by the seashore.",
                "ipa_transcription": "/ʃiː sɛlz ˈsiːʃɛlz baɪ ðə ˈsiːʃɔːr/",
                "target_phonemes": ["ʃ", "s"],
            },
            {
                "drill_type": "tongue_twister",
                "difficulty": "B2",
                "title": "Peter Piper",
                "description": "Luyện âm /p/ plosive và nhịp điệu nhanh",
                "content": "Peter Piper picked a peck of pickled peppers.",
                "ipa_transcription": "/ˈpiːtər ˈpaɪpər pɪkt ə pɛk əv ˈpɪkld ˈpɛpərz/",
                "target_phonemes": ["p"],
            },
            {
                "drill_type": "word_stress",
                "difficulty": "B1",
                "title": "Noun vs Verb Stress",
                "description": "Luyện trọng âm thay đổi giữa danh từ và động từ",
                "content": "REcord (n) vs reCORD (v) | PREsent (n) vs preSENT (v) | CONtract (n) vs conTRACT (v)",
                "ipa_transcription": "/ˈrɛkɔːrd/ vs /rɪˈkɔːrd/ | /ˈprɛzənt/ vs /prɪˈzɛnt/",
                "target_phonemes": [],
            },
            {
                "drill_type": "intonation",
                "difficulty": "B2",
                "title": "Question Intonation",
                "description": "Luyện ngữ điệu: Yes/No questions ↑ vs Wh-questions ↓",
                "content": "Do you like coffee? ↑ | Where do you live? ↓ | Is she coming? ↑ | What time is it? ↓ | Can I help you? ↑",
                "ipa_transcription": None,
                "target_phonemes": [],
            },
        ]

        # Filter by difficulty level
        level_order = {"A1": 0, "A2": 1, "B1": 2, "B2": 3, "C1": 4}
        target_idx = level_order.get(difficulty.upper(), 2)

        filtered = [
            d for d in drills
            if level_order.get(d["difficulty"], 2) <= target_idx
        ]
        return filtered if filtered else drills

    # ────────────────────────────────────────
    #  5. SPEAKING STATS ANALYSIS
    # ────────────────────────────────────────

    @classmethod
    def compute_speaking_stats(
        cls,
        sessions: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """Compute aggregate speaking practice statistics."""
        if not sessions:
            return {
                "total_sessions": 0,
                "total_practice_time_minutes": 0.0,
                "average_overall_score": None,
                "average_fluency": None,
                "average_accuracy": None,
                "weakest_phonemes": [],
                "score_trend": [],
                "level_label": "Beginner",
            }

        total = len(sessions)
        scores = [s["overall_score"] for s in sessions if s.get("overall_score")]
        fluency_scores = [s["fluency_score"] for s in sessions if s.get("fluency_score")]
        accuracy_scores = [s["accuracy_score"] for s in sessions if s.get("accuracy_score")]

        avg_overall = sum(scores) / len(scores) if scores else None
        avg_fluency = sum(fluency_scores) / len(fluency_scores) if fluency_scores else None
        avg_accuracy = sum(accuracy_scores) / len(accuracy_scores) if accuracy_scores else None

        # Determine level label
        if avg_overall is None:
            level_label = "Beginner"
        elif avg_overall >= 90:
            level_label = "Near-Native"
        elif avg_overall >= 75:
            level_label = "Advanced"
        elif avg_overall >= 60:
            level_label = "Intermediate"
        elif avg_overall >= 40:
            level_label = "Elementary"
        else:
            level_label = "Beginner"

        # Collect phoneme stats
        phoneme_data: dict[str, list[float]] = {}
        for session in sessions:
            for ws in session.get("word_scores", []) or []:
                for ph in ws.get("phonemes", []):
                    p = ph["phoneme"]
                    if p not in phoneme_data:
                        phoneme_data[p] = []
                    phoneme_data[p].append(ph["score"])

        weakest = sorted(
            [
                {
                    "phoneme": p,
                    "average_score": round(sum(scores_list) / len(scores_list), 1),
                    "practice_count": len(scores_list),
                }
                for p, scores_list in phoneme_data.items()
            ],
            key=lambda x: x["average_score"],
        )[:5]

        # Score trend (last 10 sessions)
        score_trend = [
            {
                "date": s.get("created_at", ""),
                "score": s.get("overall_score", 0),
            }
            for s in sessions[-10:]
            if s.get("overall_score")
        ]

        return {
            "total_sessions": total,
            "total_practice_time_minutes": round(total * 2.5, 1),  # estimate ~2.5 min/session
            "average_overall_score": round(avg_overall, 1) if avg_overall else None,
            "average_fluency": round(avg_fluency, 1) if avg_fluency else None,
            "average_accuracy": round(avg_accuracy, 1) if avg_accuracy else None,
            "weakest_phonemes": weakest,
            "score_trend": score_trend,
            "level_label": level_label,
        }
