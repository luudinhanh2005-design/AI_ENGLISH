"""Database-backed grammar API integration test.

Run against a reachable development/PostgreSQL database:

    $env:GRAMMAR_INTEGRATION = "1"
    python -m unittest tests.test_grammar_api_integration -v

The test creates a disposable user, exercises the public attempt/progress
contracts and the reviewer role guard, then deletes the user. Existing users
and their progress are never modified.
"""
from __future__ import annotations

import asyncio
import os
import unittest
import uuid
from uuid import UUID

os.environ.setdefault("DEBUG", "false")
os.environ.setdefault("LOCAL_LLM_PRELOAD", "false")

from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

from app.config import settings
from app.database import _connect_args

LESSON = "present_simple"


async def _run_sql(statement: str, **params) -> int:
    """Run a small statement on an isolated engine/event loop."""
    engine = create_async_engine(settings.database_url, connect_args=_connect_args)
    try:
        async with engine.begin() as conn:
            result = await conn.execute(text(statement), params)
            return int(result.rowcount or 0)
    finally:
        await engine.dispose()


@unittest.skipUnless(
    os.getenv("GRAMMAR_INTEGRATION") == "1",
    "set GRAMMAR_INTEGRATION=1 to run database-backed grammar API tests",
)
class GrammarApiIntegrationTest(unittest.TestCase):
    client: TestClient
    user_id: str = ""
    email: str = ""
    headers: dict[str, str] = {}

    @classmethod
    def setUpClass(cls) -> None:
        from main import app

        cls.client = TestClient(app)
        cls.client.__enter__()
        cls.email = f"grammar-it-{uuid.uuid4().hex[:10]}@example.com"
        response = cls.client.post(
            "/api/v1/auth/register",
            json={
                "name": "Grammar Integration Test",
                "email": cls.email,
                "password": "Password123",
            },
        )
        if response.status_code != 201:
            cls.client.__exit__(None, None, None)
            raise RuntimeError(
                "Could not create disposable integration-test user: "
                f"{response.status_code} {response.text}"
            )

        body = response.json()
        cls.user_id = body["user"]["id"]
        cls.headers = {"Authorization": f"Bearer {body['access_token']}"}

    @classmethod
    def tearDownClass(cls) -> None:
        try:
            if cls.user_id:
                # Cascades remove attempts, progress, and XP for this user.
                asyncio.run(
                    _run_sql(
                        "DELETE FROM users WHERE id = :id",
                        id=UUID(cls.user_id),
                    )
                )
        finally:
            cls.client.__exit__(None, None, None)

    def _lesson(self) -> dict:
        response = self.client.get(f"/api/v1/grammar/lessons/{LESSON}")
        self.assertEqual(response.status_code, 200, response.text)
        lesson = response.json()
        self.assertGreaterEqual(len(lesson["quiz"]), 1)
        return lesson

    @staticmethod
    def _answers(lesson: dict, correct_count: int) -> list[dict]:
        answers = []
        for index, question in enumerate(lesson["quiz"]):
            correct = int(question["correct_index"])
            selected = (
                correct
                if index < correct_count
                else (correct + 1) % len(question["options"])
            )
            answers.append(
                {"question_index": index, "selected_option": selected}
            )
        return answers

    def _submit(
        self,
        lesson: dict,
        attempt_id: str,
        correct_count: int,
    ) -> dict:
        response = self.client.post(
            "/api/v1/grammar/attempts",
            headers=self.headers,
            json={
                "attempt_id": attempt_id,
                "lesson_slug": LESSON,
                "lesson_version": lesson["version"],
                "answers": self._answers(lesson, correct_count),
            },
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def _progress(self) -> dict:
        response = self.client.get(
            "/api/v1/grammar/progress",
            headers=self.headers,
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_01_attempts_are_idempotent_and_keep_best_score(self) -> None:
        lesson = self._lesson()
        first_id = str(uuid.uuid4())

        first = self._submit(lesson, first_id, correct_count=3)
        self.assertEqual(first["score"], 60.0)
        self.assertEqual(first["xp_earned"], 10)
        self.assertEqual(first["best_score"], 60.0)
        self.assertFalse(first["duplicate"])

        duplicate = self._submit(lesson, first_id, correct_count=3)
        self.assertTrue(duplicate["duplicate"])
        self.assertEqual(duplicate["xp_earned"], 10)
        self.assertEqual(duplicate["best_score"], 60.0)
        self.assertEqual(self._progress()["total_xp"], 10)

        better = self._submit(lesson, str(uuid.uuid4()), correct_count=5)
        self.assertEqual(better["score"], 100.0)
        self.assertEqual(better["xp_earned"], 5)
        self.assertEqual(better["best_score"], 100.0)

        lower = self._submit(lesson, str(uuid.uuid4()), correct_count=4)
        self.assertEqual(lower["score"], 80.0)
        self.assertEqual(lower["xp_earned"], 0)
        self.assertEqual(lower["best_score"], 100.0)

        progress = self._progress()
        self.assertEqual(progress["total_xp"], 15)
        item = next(
            item
            for item in progress["items"]
            if item["lesson_slug"] == LESSON
        )
        self.assertEqual(item["best_score"], 100.0)
        self.assertTrue(item["is_completed"])

    def test_02_reviewer_cannot_publish(self) -> None:
        updated = asyncio.run(
            _run_sql(
                "UPDATE users SET role = 'reviewer' WHERE id = :id",
                id=UUID(self.user_id),
            )
        )
        self.assertEqual(updated, 1)

        # Reviewers may read the staff workspace.
        listing = self.client.get(
            "/api/v1/admin/grammar/lessons",
            headers=self.headers,
        )
        self.assertEqual(listing.status_code, 200, listing.text)

        # Publishing is restricted to admins.
        response = self.client.post(
            f"/api/v1/admin/grammar/lessons/{LESSON}/publish",
            headers=self.headers,
        )
        self.assertEqual(response.status_code, 403, response.text)


if __name__ == "__main__":
    unittest.main()
