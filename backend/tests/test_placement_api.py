"""Database-backed placement API integration test.

Run against a reachable development/PostgreSQL database:

    $env:PLACEMENT_INTEGRATION = "1"
    python -m unittest tests.test_placement_api -v
"""
from __future__ import annotations

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


async def _run_sql(statement: str, **params) -> int:
    engine = create_async_engine(settings.database_url, connect_args=_connect_args)
    try:
        async with engine.begin() as conn:
            result = await conn.execute(text(statement), params)
            return int(result.rowcount or 0)
    finally:
        await engine.dispose()


@unittest.skipUnless(
    os.getenv("PLACEMENT_INTEGRATION") == "1",
    "set PLACEMENT_INTEGRATION=1 to run database-backed placement API tests",
)
class PlacementApiIntegrationTest(unittest.TestCase):
    client: TestClient
    user_id: str = ""
    email: str = ""
    headers: dict[str, str] = {}

    @classmethod
    def setUpClass(cls) -> None:
        from main import app

        cls.client = TestClient(app)
        cls.client.__enter__()
        cls.email = f"placement-it-{uuid.uuid4().hex[:10]}@example.com"
        response = cls.client.post(
            "/api/v1/auth/register",
            json={
                "name": "Placement Integration Test",
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
                import asyncio

                asyncio.run(
                    _run_sql(
                        "DELETE FROM users WHERE id = :id",
                        id=UUID(cls.user_id),
                    )
                )
        finally:
            cls.client.__exit__(None, None, None)

    def test_quick_placement_flow_returns_result(self) -> None:
        config_response = self.client.get("/api/v1/placement/config")
        self.assertEqual(config_response.status_code, 200, config_response.text)
        config = config_response.json()
        self.assertIn("quick", config["modes"])

        create_response = self.client.post(
            "/api/v1/placement/sessions",
            headers=self.headers,
            json={"mode": "quick", "target_exam": "ielts"},
        )
        self.assertEqual(create_response.status_code, 200, create_response.text)
        session = create_response.json()
        self.assertEqual(session["mode"], "quick")
        self.assertFalse(session["completed"])

        # A quick test has two receptive stages per skill. The backend advances
        # the session after each completed stage; answer every item with A and
        # submit the whole stage at once.
        guard = 0
        while not session.get("completed"):
            guard += 1
            self.assertLess(guard, 20, "Placement session did not finish")
            current = session["current"]
            self.assertEqual(current["section"], "receptive", current)
            answers = [
                {
                    "item_id": item["id"],
                    "answer": ["A"],
                    "response_time_ms": 1000,
                }
                for item in current["items"]
            ]
            response = self.client.post(
                f"/api/v1/placement/sessions/{session['session_id']}/stages/complete",
                headers=self.headers,
                json={
                    "stage_token": current["stage_token"],
                    "answers": answers,
                },
            )
            self.assertEqual(response.status_code, 200, response.text)
            session = response.json()

        self.assertTrue(session["completed"])
        self.assertIsNotNone(session.get("result"))
        result = session["result"]
        self.assertIn(result["overall"]["level"], {"A1", "A2", "B1", "B2", "C1", "C2"})
        self.assertEqual(len(result["skills"]), 3)
        self.assertIn("listening", result["skills"])
        self.assertIn("reading", result["skills"])
        self.assertIn("use_of_english", result["skills"])
        self.assertIn("can_do", result)
        self.assertTrue(result["can_do"])

        latest = self.client.get(
            "/api/v1/placement/results/latest",
            headers=self.headers,
        )
        self.assertEqual(latest.status_code, 200, latest.text)
        self.assertEqual(latest.json()["result_id"], result["result_id"])

        history = self.client.get(
            "/api/v1/placement/history",
            headers=self.headers,
        )
        self.assertEqual(history.status_code, 200, history.text)
        self.assertGreaterEqual(len(history.json()), 1)


if __name__ == "__main__":
    unittest.main()
