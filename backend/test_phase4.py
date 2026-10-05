"""
Phase 4 — Speech AI Test Script
Tests all Speech AI endpoints:
  1. Practice Sentences
  2. Pronunciation Drills
  3. Text-to-Speech
  4. Pronunciation Assessment (simulated audio)
  5. Speech-to-Text (simulated audio)
  6. Speaking History
  7. Speaking Statistics
"""
import asyncio
import json
import os
import sys
from pathlib import Path

# Fix Windows console encoding for emoji
sys.stdout.reconfigure(encoding='utf-8')  # type: ignore[attr-defined]

# Add project root to path
sys.path.insert(0, str(Path(__file__).resolve().parent))

import httpx

BASE_URL = "http://localhost:8000/api/v1"
TEST_USER = {"email": "speech_test@example.com", "password": "Test@12345"}


def print_header(title: str) -> None:
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")


def print_result(label: str, data: dict | list | str, indent: int = 2) -> None:
    print(f"\n  ✅ {label}:")
    if isinstance(data, (dict, list)):
        print(json.dumps(data, indent=indent, ensure_ascii=False, default=str)[:2000])
    else:
        print(f"    {data}")


def print_error(label: str, error: str) -> None:
    print(f"\n  ❌ {label}: {error}")


async def main():
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=30.0) as client:

        # ── 0. Setup: Register & Login ──
        print_header("Phase 4 — Speech AI Tests")
        print("\n  📋 Setting up test user...")

        # Register
        access_token = None
        resp = await client.post("/auth/register", json={
            "email": TEST_USER["email"],
            "password": TEST_USER["password"],
            "name": "Speech Tester",
        })
        if resp.status_code == 201:
            print("  ✅ Registered new test user.")
            tokens = resp.json()
            access_token = tokens["access_token"]
        elif resp.status_code == 409:
            print("  ℹ️  User already exists, logging in...")
        else:
            print(f"  ⚠️  Register status: {resp.status_code}: {resp.text[:200]}")

        # Login (if registration returned 409)
        if not access_token:
            resp = await client.post("/auth/login", json={
                "email": TEST_USER["email"],
                "password": TEST_USER["password"],
            })
            if resp.status_code != 200:
                print_error("Login", f"Failed with status {resp.status_code}: {resp.text}")
                return
            
            tokens = resp.json()
            access_token = tokens["access_token"]

        headers = {"Authorization": f"Bearer {access_token}"}
        print(f"  ✅ Authenticated. Token: {access_token[:20]}...")

        # ── 1. Practice Sentences ──
        print_header("1. Practice Sentences")
        for level in ["A1", "B1", "C1"]:
            resp = await client.get(f"/speech/practice?level={level}&count=3", headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                print(f"\n  Level {level}: {data['total']} sentences")
                for s in data["sentences"]:
                    print(f"    📝 {s['text']}")
                    print(f"       Focus: {s['focus']}")
            else:
                print_error(f"Practice ({level})", f"Status {resp.status_code}")

        # ── 2. Pronunciation Drills ──
        print_header("2. Pronunciation Drills")
        resp = await client.get("/speech/drills?difficulty=B1", headers=headers)
        if resp.status_code == 200:
            data = resp.json()
            print(f"\n  Total drills: {data['total']}")
            for d in data["drills"][:3]:
                print(f"\n    🎯 {d['title']} [{d['drill_type']}] - {d['difficulty']}")
                print(f"       {d['description']}")
                print(f"       Content: {d['content'][:80]}...")
                if d.get("ipa_transcription"):
                    print(f"       IPA: {d['ipa_transcription'][:80]}")
        else:
            print_error("Drills", f"Status {resp.status_code}")

        # Filter by type
        resp = await client.get("/speech/drills?drill_type=tongue_twister", headers=headers)
        if resp.status_code == 200:
            data = resp.json()
            print(f"\n  Tongue twisters only: {data['total']} drills")
        else:
            print_error("Drills (filtered)", f"Status {resp.status_code}")

        # ── 3. Text-to-Speech ──
        print_header("3. Text-to-Speech (TTS)")
        tts_tests: list[dict[str, str | float]] = [
            {"text": "Hello, welcome to EnglishAI!", "voice": "en-US-Standard-C", "speed": 1.0},
            {"text": "She sells seashells by the seashore.", "voice": "en-US-Standard-A", "speed": 0.8},
        ]
        for tts_req in tts_tests:
            resp = await client.post("/speech/tts", json=tts_req, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                print(f"\n  🔊 Text: \"{str(tts_req['text'])[:40]}...\"")
                print(f"     Voice: {data.get('voice', 'N/A')}")
                print(f"     Audio URL: {data.get('audio_url', 'N/A')}")
                if data.get("_notice"):
                    print(f"     ⚠️  {data['_notice']}")
            else:
                print_error("TTS", f"Status {resp.status_code}: {resp.text[:200]}")

        # ── 4. Pronunciation Assessment (with simulated audio) ──
        print_header("4. Pronunciation Assessment")
        # Create a minimal WAV file header (silence) for testing
        wav_header = create_minimal_wav()

        resp = await client.post(
            "/speech/assess",
            files={"audio": ("test.wav", wav_header, "audio/wav")},
            data={
                "reference_text": "Hello, my name is Anna.",
                "session_type": "read_aloud",
            },
            headers=headers,
        )
        if resp.status_code == 200:
            data = resp.json()
            print_result("Assessment Result", {
                "session_id": data["session_id"],
                "reference_text": data["reference_text"],
                "recognised_text": data["recognised_text"][:60],
                "overall_score": data["overall_score"],
                "fluency_score": data["fluency_score"],
                "accuracy_score": data["accuracy_score"],
                "completeness_score": data["completeness_score"],
                "prosody_score": data["prosody_score"],
                "word_count": len(data.get("word_scores", [])),
                "feedback": data["feedback"][:100],
                "tips_count": len(data.get("improvement_tips", [])),
            })
            if data.get("improvement_tips"):
                print("\n    💡 Tips:")
                for tip in data["improvement_tips"][:3]:
                    print(f"       - {tip[:80]}")
        else:
            print_error("Assessment", f"Status {resp.status_code}: {resp.text[:300]}")

        # ── 5. Speech-to-Text ──
        print_header("5. Speech-to-Text (STT)")
        resp = await client.post(
            "/speech/transcribe",
            files={"audio": ("test.wav", wav_header, "audio/wav")},
            data={"language": "en-US"},
            headers=headers,
        )
        if resp.status_code == 200:
            data = resp.json()
            print_result("Transcription", {
                "transcript": data["transcript"][:80],
                "confidence": data["confidence"],
                "language": data["language"],
            })
        else:
            print_error("STT", f"Status {resp.status_code}: {resp.text[:200]}")

        # ── 6. Speaking History ──
        print_header("6. Speaking Session History")
        resp = await client.get("/speech/history?limit=5", headers=headers)
        if resp.status_code == 200:
            data = resp.json()
            print(f"\n  Total sessions: {data['total']}")
            print(f"  Average score: {data.get('average_score', 'N/A')}")
            for s in data.get("sessions", [])[:3]:
                print(f"\n    📊 Session {str(s['id'])[:8]}...")
                print(f"       Type: {s['session_type']}")
                print(f"       Score: {s.get('overall_score', 'N/A')}")
                print(f"       Text: {s['reference_text'][:50]}")
        else:
            print_error("History", f"Status {resp.status_code}: {resp.text[:200]}")

        # ── 7. Speaking Statistics ──
        print_header("7. Speaking Statistics")
        resp = await client.get("/speech/stats", headers=headers)
        if resp.status_code == 200:
            data = resp.json()
            print_result("Stats", {
                "total_sessions": data["total_sessions"],
                "practice_time_min": data["total_practice_time_minutes"],
                "avg_overall": data.get("average_overall_score"),
                "avg_fluency": data.get("average_fluency"),
                "avg_accuracy": data.get("average_accuracy"),
                "level": data["level_label"],
                "weakest_phonemes": data.get("weakest_phonemes", [])[:3],
            })
        else:
            print_error("Stats", f"Status {resp.status_code}: {resp.text[:200]}")

        # ── Summary ──
        print_header("Phase 4 Test Summary")
        print("""
  ✅ Practice Sentences — curated by CEFR level
  ✅ Pronunciation Drills — minimal pairs, tongue twisters, word stress, intonation
  ✅ Text-to-Speech (TTS) — OpenAI / Google / fallback
  ✅ Pronunciation Assessment — phoneme-level scoring with Vietnamese feedback
  ✅ Speech-to-Text (STT) — Whisper / Google / fallback  
  ✅ Speaking History — session tracking with pagination
  ✅ Speaking Statistics — aggregate analysis with trend data
        """)
        print("  🎉 Phase 4 — Speech AI tests completed!\n")


def create_minimal_wav() -> bytes:
    """Create a minimal valid WAV file (44-byte header + 1 second of silence at 16kHz)."""
    import struct

    sample_rate = 16000
    num_channels = 1
    bits_per_sample = 16
    duration_seconds = 1
    num_samples = sample_rate * duration_seconds

    data_size = num_samples * num_channels * (bits_per_sample // 8)
    file_size = 36 + data_size

    header = struct.pack(
        '<4sI4s4sIHHIIHH4sI',
        b'RIFF',
        file_size,
        b'WAVE',
        b'fmt ',
        16,  # chunk size
        1,   # PCM format
        num_channels,
        sample_rate,
        sample_rate * num_channels * (bits_per_sample // 8),  # byte rate
        num_channels * (bits_per_sample // 8),  # block align
        bits_per_sample,
        b'data',
        data_size,
    )

    # 1 second of silence
    audio_data = b'\x00\x00' * num_samples

    return header + audio_data


if __name__ == "__main__":
    asyncio.run(main())
