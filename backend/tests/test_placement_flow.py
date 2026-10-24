"""Offline integration tests for placement session orchestration."""

from __future__ import annotations

import tempfile
import unittest
import uuid
from pathlib import Path
from unittest import mock

from app.models.user import User
from app.services import placement_service as service
from app.services import placement_store
from app.services.placement_ai import PlacementAIService
from app.services.placement_store import _JsonStore


class PlacementFlowTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        placement_store._json_store = _JsonStore(Path(self.temp_dir.name))
        self.audio_patch = mock.patch.object(
            service, "_prepare_listening_audio", new=mock.AsyncMock()
        )
        self.audio_patch.start()
        self.user = User(
            id=uuid.uuid4(),
            email="placement@test.local",
            password_hash="x",
            name="Placement Tester",
        )

    async def asyncTearDown(self) -> None:
        self.audio_patch.stop()
        self.temp_dir.cleanup()

    async def _answer_current_stage(self, session: dict, correct: bool) -> dict:
        current = session["current"]
        bank = service.get_bank()
        for item in current["items"]:
            full = bank.get_item(item["id"])
            selected = full["answer"] if correct else ["__wrong__"]
            await service.save_answer(
                None,
                session["session_id"],
                str(self.user.id),
                item["id"],
                selected,
                1200,
            )
        return await service.complete_stage(
            None,
            session["session_id"],
            str(self.user.id),
            stage_token=current["stage_token"],
        )

    async def test_quick_session_all_correct_reaches_high_level(self) -> None:
        session = await service.create_session(None, self.user, "quick", "ielts")
        self.assertEqual(session["current"]["section"], "receptive")
        for _ in range(10):
            if session["completed"]:
                break
            session = await self._answer_current_stage(session, correct=True)
        self.assertTrue(session["completed"])
        result = session["result"]
        self.assertIn(result["overall"]["level"], {"B2", "C1", "C2"})
        self.assertEqual(len(result["skills"]), 3)
        self.assertEqual(result["xp_awarded"], 80)

    async def test_quick_session_all_wrong_is_a1(self) -> None:
        session = await service.create_session(None, self.user, "quick", "general")
        for _ in range(10):
            if session["completed"]:
                break
            session = await self._answer_current_stage(session, correct=False)
        self.assertTrue(session["completed"])
        self.assertEqual(session["result"]["overall"]["level"], "A1")

    async def test_stage_token_prevents_double_advance(self) -> None:
        session = await service.create_session(None, self.user, "quick", "general")
        token = session["current"]["stage_token"]
        await service.complete_stage(
            None, session["session_id"], str(self.user.id), stage_token=token
        )
        with self.assertRaises(service.PlacementStateError):
            await service.complete_stage(
                None, session["session_id"], str(self.user.id), stage_token=token
            )

    async def test_standard_writing_task_finishes_session(self) -> None:
        async def fake_writing(task, text, user_level="B1"):
            return {
                "criteria": {
                    "task_achievement": 3,
                    "coherence_cohesion": 3,
                    "lexical_resource": 3,
                    "grammar_accuracy": 3,
                },
                "average": 3.0,
                "cefr": "B1",
                "theta": -0.2,
                "se": 0.42,
                "feedback": "Ổn.",
                "strengths": ["Mạch lạc"],
                "improvements": ["Thêm ví dụ"],
                "corrected_excerpts": [],
                "word_count": len(text.split()),
                "within_word_limit": True,
                "engine": "test",
            }

        with mock.patch.object(
            PlacementAIService, "evaluate_writing", new=mock.AsyncMock(side_effect=fake_writing)
        ):
            session = await service.create_session(None, self.user, "standard", "toefl")
            for _ in range(10):
                if session["current"]["section"] == "writing":
                    break
                session = await self._answer_current_stage(session, correct=True)
            self.assertEqual(session["current"]["section"], "writing")
            self.assertEqual(len(session["current"]["tasks"]), 1)
            task = session["current"]["tasks"][0]
            session = await service.submit_writing(
                None,
                session["session_id"],
                str(self.user.id),
                task["id"],
                "This is a sufficiently long response. " * 20,
                1000,
            )
            self.assertTrue(session["completed"])
            self.assertIn("writing", session["result"]["skills"])


if __name__ == "__main__":
    unittest.main()
