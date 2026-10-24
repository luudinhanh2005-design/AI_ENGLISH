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
from pathlib import Path
from typing import Any, Optional

import httpx

from ..config import settings
from .pronunciation_scoring import build_assessment

logger = logging.getLogger(__name__)

# Directory for storing generated audio files
AUDIO_DIR = Path("storage/audio")
AUDIO_DIR.mkdir(parents=True, exist_ok=True)


class SpeechAIService:
    """Central Speech AI engine for EnglishAI."""
    @classmethod
    def _ensure_wav(cls, audio_data: bytes, file_format: str = "wav") -> bytes:
        """Ensure audio bytes are in standard WAV format (16kHz mono)."""
        if audio_data.startswith(b"RIFF") and len(audio_data) > 44:
            return audio_data
        try:
            import subprocess
            import imageio_ffmpeg
            ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
            cmd = [
                ffmpeg_exe, "-y",
                "-i", "pipe:0",
                "-f", "wav",
                "-ar", "16000",
                "-ac", "1",
                "pipe:1"
            ]
            proc = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            stdout, _ = proc.communicate(input=audio_data, timeout=10)
            if stdout and stdout.startswith(b"RIFF"):
                return stdout
        except Exception as e:
            logger.warning(f"Audio conversion with ffmpeg failed: {e}")
        return audio_data

    @classmethod
    async def _local_speech_recognition(
        cls,
        audio_data: bytes,
        language: str = "en-US",
        file_format: str = "wav",
    ) -> dict[str, Any]:
        """Free, robust Speech-to-Text via Google Speech Recognition & speech_recognition library."""
        import asyncio
        import io
        import speech_recognition as sr

        def _do():
            wav_bytes = cls._ensure_wav(audio_data, file_format)
            r = sr.Recognizer()
            r.energy_threshold = 250
            r.dynamic_energy_threshold = True
            with sr.AudioFile(io.BytesIO(wav_bytes)) as source:
                audio = r.record(source)

            lang_code = language.strip()
            if not lang_code or lang_code.lower() in ("en", "auto"):
                lang_code = "en-US"

            try:
                text = r.recognize_google(audio, language=lang_code)
            except sr.UnknownValueError:
                text = ""
            except Exception as e:
                logger.warning(f"Google Web Speech STT error: {e}")
                text = ""

            words = []
            clean_text = text.strip()
            if clean_text:
                for w in clean_text.split():
                    words.append({
                        "word": w,
                        "start_time": 0.0,
                        "end_time": 0.0,
                        "confidence": 0.0,  # Google Web Speech via speech_recognition returns no confidence
                    })

            return {
                "transcript": clean_text,
                "confidence": 0.0,  # engine does not expose confidence — do not invent one
                "language": lang_code,
                "duration_seconds": round(len(wav_bytes) / 32000.0, 2),
                "words": words,
            }

        return await asyncio.to_thread(_do)

    @classmethod
    async def _local_whisper_transcribe(
        cls,
        audio_data: bytes,
        language: str = "en-US",
        file_format: str = "wav",
        assessment_mode: bool = False,
    ) -> dict:
        import asyncio
        import tempfile

        def _do():
            import torch
            if not hasattr(cls, "_whisper_model") or cls._whisper_model is None:
                from faster_whisper import WhisperModel
                dev = "cuda" if torch.cuda.is_available() else "cpu"
                ct = "float16" if dev == "cuda" else "int8"
                cls._whisper_model = WhisperModel("base", device=dev, compute_type=ct)

            with tempfile.NamedTemporaryFile(suffix=f".{file_format}", delete=False) as tmp:
                tmp.write(audio_data)
                tmp_path = tmp.name

            try:
                # Set to English by default for optimal ESL speaking accuracy
                lang_code = language.split("-")[0].lower() if (language and "-" in language) else (language.lower() if language else "en")
                if lang_code in ("auto", "none", "", "en-us"):
                    lang_code = "en"

                # Use initial prompt to bias Whisper towards clean conversational English
                initial_prompt = "English conversation, clear pronunciation, ESL speaking practice." if lang_code == "en" else None

                if assessment_mode:
                    # Assessment must be deterministic and unbiased: no priming prompt,
                    # no context carry-over between segments, greedy-stable decoding.
                    transcribe_kwargs: dict[str, Any] = {
                        "language": lang_code,
                        "initial_prompt": None,
                        "condition_on_previous_text": False,
                        "temperature": 0.0,
                        "word_timestamps": True,
                        "vad_filter": True,
                        "vad_parameters": dict(min_silence_duration_ms=400),
                        "beam_size": 5,
                    }
                else:
                    transcribe_kwargs = {
                        "language": lang_code,
                        "initial_prompt": initial_prompt,
                        "word_timestamps": True,
                        "vad_filter": True,
                        "vad_parameters": dict(min_silence_duration_ms=400),
                        "beam_size": 5,
                    }

                # Transcribe with VAD to eliminate background silence / ellipsis hallucinations
                segments, info = cls._whisper_model.transcribe(tmp_path, **transcribe_kwargs)

                words = []
                full_text = []
                for s in segments:
                    clean_s = s.text.strip()
                    if clean_s:
                        full_text.append(clean_s)
                    if s.words:
                        for w in s.words:
                            words.append({
                                "word": w.word.strip(),
                                "start_time": w.start,
                                "end_time": w.end,
                                "confidence": round(w.probability, 2),
                            })
                raw_transcript = " ".join(full_text).strip()
                # Clean out repetitive punctuation / dots like '... ... ...'
                cleaned_transcript = re.sub(r'^[.\s,!?]+|[.\s,!?]+$', '', raw_transcript).strip()
                # If there are no alphanumeric characters, it was just noise/silence
                if not re.search(r'[a-zA-Z0-9\u00C0-\u1EF9]', cleaned_transcript):
                    cleaned_transcript = ""

                return {
                    "transcript": cleaned_transcript,
                    "confidence": round(min(1.0, max(0.0, math.exp(info.avg_logprob))), 3) if getattr(info, "avg_logprob", None) is not None else 0.0,
                    "language": getattr(info, "language", language),
                    "duration_seconds": round(info.duration, 2) if hasattr(info, "duration") else 0.0,
                    "words": words,
                }
            finally:
                if os.path.exists(tmp_path):
                    try:
                        os.remove(tmp_path)
                    except Exception:
                        pass
        return await asyncio.to_thread(_do)


    @classmethod
    async def _local_edge_tts(
        cls,
        text: str,
        voice: str = "en-US-JennyNeural",
        speed: float = 1.0,
    ) -> dict:
        import edge_tts
        import unicodedata

        # Map voices to Microsoft's latest ultra-natural Neural TTS voices
        edge_voice_map = {
            "sarah": "en-US-AvaNeural",           # Warm, expressive, natural conversational US Female
            "harrison": "en-US-AndrewNeural",     # Confident, polished, executive US Male
            "emma": "en-GB-SoniaNeural",          # Elegant, articulate British IELTS examiner Female
            "en-US-Standard-C": "en-US-AvaNeural",
            "en-US-Standard-A": "en-US-AvaNeural",
            "en-US-Standard-B": "en-US-AndrewNeural",
            "en-GB-Standard-A": "en-GB-SoniaNeural",
        }
        voice_lower = voice.lower()
        en_voice = edge_voice_map.get(voice, edge_voice_map.get(voice_lower, "en-US-AvaNeural"))
        vi_voice = (
            "vi-VN-NamMinhNeural"
            if ("andrew" in en_voice.lower() or "guy" in en_voice.lower() or "harrison" in voice_lower)
            else "vi-VN-HoaiMyNeural"
        )

        rate_percent = int((speed - 1.0) * 100)
        rate_str = f"{rate_percent:+d}%"

        filename = f"{uuid.uuid4().hex}.mp3"
        filepath = AUDIO_DIR / filename

        # 1. Clean markdown, emojis, asterisks, code ticks, and special phonetic characters
        cleaned = re.sub(r'[\U00010000-\U0010ffff]', '', text)
        cleaned = re.sub(r'[\u2600-\u26FF\u2700-\u27BF]', '', cleaned)
        cleaned = re.sub(r'\*{1,3}([^*]+)\*{1,3}', r'\1', cleaned)
        cleaned = re.sub(r'_{1,3}([^_]+)_{1,3}', r'\1', cleaned)
        cleaned = re.sub(r'`+([^`]+)`+', r'\1', cleaned)
        cleaned = re.sub(r'#+\s*', '', cleaned)
        cleaned = re.sub(r'(?:^|\s)/[^/\n]{2,}/(?:\s|$)', ' ', cleaned)
        cleaned = re.sub(r'^\s*[-*•]\s+', '', cleaned, flags=re.MULTILINE)
        cleaned = re.sub(r'^\s*\d+[\.\)]\s+', '', cleaned, flags=re.MULTILINE)
        # Strip surrounding quotation marks around words without breaking contractions (e.g. "went" -> went, don't kept)
        cleaned = re.sub(r'(^|\s)["\'“”‘’`]+', r'\1', cleaned)
        cleaned = re.sub(r'["\'“”‘’`]+(\s|[.,!?;]|$)', r'\1', cleaned)
        # Clean letter-by-letter hyphens e.g. w-e-n-t -> went
        cleaned = re.sub(r'\b([a-zA-Z])\s*-\s*([a-zA-Z])\s*-\s*([a-zA-Z])\b', r'\1\2\3', cleaned)
        cleaned = re.sub(r'\s+', ' ', cleaned).strip()
        if not cleaned:
            cleaned = text.strip()

        # 2. Strict Vietnamese diacritics pattern
        vietnamese_pattern = re.compile(
            r'[\u00E0\u00E1\u00E2\u00E3\u00E8\u00E9\u00EA\u00EC\u00ED\u00F2\u00F3\u00F4\u00F5\u00F9\u00FA\u00FD'
            r'\u0103\u0111\u0129\u0169\u01A1\u01B0\u1EA0-\u1EF9'
            r'\u00C0\u00C1\u00C2\u00C3\u00C8\u00C9\u00CA\u00CC\u00CD\u00D2\u00D3\u00D4\u00D5\u00D9\u00DA\u00DD'
            r'\u0102\u0110\u0128\u0168\u01A0\u01AF]',
            re.IGNORECASE
        )

        # 3. Detect language: Is it predominantly Vietnamese or predominantly English?
        words = [w for w in cleaned.split() if re.search(r'[a-zA-Z\u00C0-\u1EF9]', w)]
        vi_word_count = len([w for w in words if vietnamese_pattern.search(w)]) if words else 0
        is_predominantly_vi = (vi_word_count / len(words) >= 0.45) if words else False

        if not is_predominantly_vi:
            # PREDOMINANTLY ENGLISH:
            # Normalize accented characters in proper names (e.g. "Hoàng" -> "Hoang")
            # so the native English neural voice speaks continuously without spelling out.
            def _strip_diacritics(s: str) -> str:
                s = s.replace('đ', 'd').replace('Đ', 'D')
                nfkd = unicodedata.normalize('NFKD', s)
                return ''.join([c for c in nfkd if not unicodedata.combining(c)])

            spoken_text = _strip_diacritics(cleaned)
            selected_voice = en_voice
        else:
            # PREDOMINANTLY VIETNAMESE (e.g. grammar explanation or translation):
            spoken_text = cleaned
            selected_voice = vi_voice

        # 4. Synthesize in a single fluent stream (no choppy chunking)
        communicate = edge_tts.Communicate(spoken_text, selected_voice, rate=rate_str)
        await communicate.save(str(filepath))

        audio_url = f"/api/v1/speech/audio/{filename}"
        return {
            "text": text,
            "audio_url": audio_url,
            "duration_seconds": round(len(text.split()) / (2.5 * speed), 1),
            "format": "mp3",
            "voice": selected_voice,
            "filename": filename,
        }


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
        assessment_mode: bool = False,
    ) -> dict[str, Any]:
        """
        Transcribe audio to text.
        Priority:
        1. Local faster-whisper (offline, installed)
        2. Free Google Speech Recognition via speech_recognition
        3. OpenAI Whisper (if API key set)
        4. Google Cloud Speech-to-Text (if API key set)
        5. Clean fallback (empty string)
        """
        # 1. Try Local faster-whisper first (offline on machine)
        try:
            result = await cls._local_whisper_transcribe(audio_data, language, file_format, assessment_mode)
            if result.get("transcript"):
                return result
        except Exception as e:
            logger.debug(f"Local faster-whisper skipped/failed: {e}")

        # 2. Try local/free Google Web Speech via speech_recognition
        try:
            result = await cls._local_speech_recognition(audio_data, language, file_format)
            if result.get("transcript"):
                return result
        except Exception as e:
            logger.warning(f"Local speech recognition failed, trying fallbacks: {e}")

        # 3. Try OpenAI Whisper
        if settings.openai_api_key:
            try:
                return await cls._whisper_transcribe(audio_data, language, file_format, assessment_mode)
            except Exception as e:
                logger.warning(f"Whisper STT failed: {e}")

        # 4. Try Google Speech-to-Text
        if settings.google_ai_api_key:
            try:
                return await cls._google_stt(audio_data, language)
            except Exception as e:
                logger.warning(f"Google STT failed: {e}")

        # 5. Clean fallback — return empty transcript
        return cls._fallback_stt(language)

    @classmethod
    async def _whisper_transcribe(
        cls,
        audio_data: bytes,
        language: str,
        file_format: str,
        assessment_mode: bool = False,
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
                    "confidence": 0.0,  # Whisper doesn't return per-word confidence
                })

            return {
                "transcript": result["text"],
                "confidence": 0.0,  # Whisper API returns no confidence score
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
        """Fallback when no speech is detected or transcribed."""
        return {
            "transcript": "",
            "confidence": 0.0,
            "language": language,
            "duration_seconds": 0.0,
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
        file_format: str = "wav",
    ) -> dict[str, Any]:
        """
        Full pronunciation assessment pipeline:
        1. Transcribe audio (STT) in assessment mode
        2. Align recognised words against the reference (ordered alignment)
        3. Score accuracy / completeness / fluency from real STT data only
        4. Provide per-word scores and targeted feedback
        """
        stt_result = await cls.transcribe_audio(
            audio_data, language, file_format, assessment_mode=True
        )
        recognised_text = stt_result["transcript"]

        assessment = build_assessment(
            reference_text=reference_text,
            recognised_text=recognised_text,
            stt_words=stt_result.get("words", []),
            target_wpm=None,
        )
        feedback = cls._generate_pronunciation_feedback(
            assessment=assessment,
            user_level=user_level,
        )

        return {
            "reference_text": reference_text,
            "recognised_text": recognised_text,
            "scored": assessment["scored"],
            "reason": assessment["reason"],
            "overall_score": assessment["overall_score"],
            "fluency_score": assessment["fluency_score"],
            "accuracy_score": assessment["accuracy_score"],
            "completeness_score": assessment["completeness_score"],
            "prosody_score": 0.0,
            "prosody_measured": False,
            "fluency_measured": assessment["fluency_score"] is not None,
            "has_timing": assessment["has_timing"],
            "scoring_notes": assessment["notes"],
            "word_scores": assessment["word_scores"],
            "feedback": feedback["feedback"],
            "improvement_tips": feedback["tips"],
        }

    @classmethod
    def _compute_pronunciation_scores(
        cls,
        reference_text: str,
        recognised_text: str,
        stt_confidence: float = 0.0,
        stt_words: list[dict] | None = None,
    ) -> dict[str, Any]:
        """Legacy wrapper — delegates to the honest scoring module."""
        a = build_assessment(reference_text, recognised_text, stt_words=stt_words or [])
        return {
            "overall_score": a["overall_score"],
            "fluency_score": a["fluency_score"] or 0.0,
            "accuracy_score": a["accuracy_score"],
            "completeness_score": a["completeness_score"],
            "prosody_score": 0.0,
            "word_scores": a["word_scores"],
        }

    @classmethod
    def _generate_pronunciation_feedback(
        cls,
        assessment: dict[str, Any],
        user_level: str,
    ) -> dict[str, Any]:
        """Generate honest feedback and actionable tips (no praise for low scores)."""
        overall = assessment["overall_score"]
        word_scores = assessment["word_scores"]

        if not assessment.get("scored", True):
            return {
                "feedback": "Chưa nghe rõ giọng đọc. Hãy đọc to, rõ hơn và thử lại.",
                "tips": ["Kiểm tra micro và giảm tiếng ồn xung quanh."],
            }

        if overall >= 90:
            feedback = "Rất sát bản mẫu. Điểm tối đa 96 vì chỉ chấm qua nhận dạng giọng nói."
        elif overall >= 80:
            feedback = "Tốt. Còn vài từ cần làm rõ hơn."
        elif overall >= 70:
            feedback = "Khá ổn nhưng còn từ sai hoặc bỏ sót. Xem danh sách từ bên dưới."
        elif overall >= 60:
            feedback = "Chưa khớp tốt. Hãy đọc chậm lại và rõ từng từ."
        elif overall >= 40:
            feedback = "Nhiều từ chưa khớp với câu mẫu. Nghe lại bản mẫu rồi đọc theo."
        else:
            feedback = "Chưa nhận diện được phần lớn câu. Hãy kiểm tra micro/tiếng ồn và đọc lại."

        tips: list[str] = []

        def _add(tip: str) -> None:
            if tip not in tips:
                tips.append(tip)

        mispronounced = [w for w in word_scores if w.get("error_type") == "Mispronunciation"]
        omitted = [w for w in word_scores if w.get("error_type") == "Omission"]
        inserted = [w for w in word_scores if w.get("error_type") == "Insertion"]

        if mispronounced:
            names = [w["word"] for w in mispronounced[:3]]
            _add(f"Luyện lại các từ: {', '.join(names)}.")
        if omitted:
            names = [w["word"] for w in omitted[:3]]
            _add(f"Bạn bỏ sót các từ: {', '.join(names)}.")
        if inserted:
            _add("Bạn nói thêm từ không có trong câu mẫu.")

        fluency = assessment.get("fluency_score")
        if fluency is None:
            _add("Không đo được độ trôi chảy vì STT không trả timestamp.")
        elif fluency < 60:
            _add(
                "Nhịp đọc chưa đều — chú ý ngắt nghỉ đúng chỗ "
                "và tránh dừng quá lâu giữa các từ."
            )

        accuracy_note = (
            "Điểm được chấm qua nhận dạng giọng nói, không phân tích âm học trực tiếp "
            "— hãy đọc to và rõ để kết quả chính xác."
        )
        if assessment.get("accuracy_score", 0.0) < 100:
            tips = tips[:3] + [accuracy_note]
        else:
            tips = tips[:4]

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
        # 0. Try Local Edge Neural TTS (Natural studio voices, zero API key)
        try:
            return await cls._local_edge_tts(text, voice, speed)
        except Exception as e:
            logger.warning(f"Local Edge TTS failed, trying cloud/fallback: {e}")

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

        # 3. Guaranteed zero-key Google Translate TTS fallback
        try:
            return await cls._google_translate_tts(text, voice)
        except Exception as e:
            logger.warning(f"Google Translate TTS fallback failed: {e}")

        # 4. Fallback
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
    async def _google_translate_tts(cls, text: str, voice: str) -> dict[str, Any]:
        """Free Google Translate TTS fallback ensuring audio ALWAYS plays."""
        import urllib.parse
        import unicodedata
        cleaned = re.sub(r'[\U00010000-\U0010ffff]', '', text).strip()[:500] or text[:500]
        vietnamese_pattern = re.compile(
            r'[\u00E0\u00E1\u00E2\u00E3\u00E8\u00E9\u00EA\u00EC\u00ED\u00F2\u00F3\u00F4\u00F5\u00F9\u00FA\u00FD'
            r'\u0103\u0111\u0129\u0169\u01A1\u01B0\u1EA0-\u1EF9]',
            re.IGNORECASE
        )
        words = [w for w in cleaned.split() if re.search(r'[a-zA-Z\u00C0-\u1EF9]', w)]
        vi_word_count = len([w for w in words if vietnamese_pattern.search(w)]) if words else 0
        is_predominantly_vi = (vi_word_count / len(words) >= 0.45) if words else False
        lang = "vi" if is_predominantly_vi else "en"
        if lang == "en":
            s = cleaned.replace('đ', 'd').replace('Đ', 'D')
            nfkd = unicodedata.normalize('NFKD', s)
            cleaned = ''.join([c for c in nfkd if not unicodedata.combining(c)])
        url = f"https://translate.google.com/translate_tts?ie=UTF-8&q={urllib.parse.quote(cleaned)}&tl={lang}&client=tw-ob"
        async with httpx.AsyncClient(timeout=10.0, headers={"User-Agent": "Mozilla/5.0"}) as client:
            resp = await client.get(url)
            resp.raise_for_status()
            audio_bytes = resp.content

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
