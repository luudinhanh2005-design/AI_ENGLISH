"""Pure unit tests for the IELTS Mock Test service (no database required)."""

from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from app.services import mock_test_service as service
from app.services.mock_test_service import (
    IncompleteAttemptError,
    canonical_boolean,
    grade_choice,
    grade_completion,
    grade_section,
    normalize_answer,
    overall_band,
    raw_to_band,
    sanitize_set,
)


def _synthetic_set() -> dict:
    """A tiny set with a deliberately out-of-order question list."""
    return {
        "id": "synthetic_01",
        "type": "academic",
        "title": "Synthetic Mock Test",
        "description": "Unit-test fixture",
        "skills": ["reading"],
        "sections": {
            "reading": {
                "duration_seconds": 600,
                "passages": [
                    {
                        "id": "R1",
                        "title": "Passage 1",
                        "text": "Some passage text.",
                        "groups": [
                            {
                                "id": "R1-G1",
                                "type": "tfng",
                                "options": [],
                                "questions": [
                                    {
                                        "id": "R1-2",
                                        "number": 2,
                                        "prompt": "Statement two",
                                        "answer": ["FALSE"],
                                        "alternatives": ["F", "NO"],
                                        "explanation": "Because the text says so.",
                                    },
                                    {
                                        "id": "R1-1",
                                        "number": 1,
                                        "prompt": "Statement one",
                                        "answer": ["TRUE"],
                                        "alternatives": ["T", "YES"],
                                        "explanation": "Directly stated.",
                                    },
                                ],
                            },
                            {
                                "id": "R1-G2",
                                "type": "mcq",
                                "options": [
                                    {"key": "A", "text": "First option"},
                                    {"key": "B", "text": "Second option"},
                                ],
                                "questions": [
                                    {
                                        "id": "R1-3",
                                        "number": 3,
                                        "prompt": "Pick one",
                                        "answer": ["B"],
                                        "alternatives": [],
                                        "explanation": "Option B matches paragraph 2.",
                                    }
                                ],
                            },
                        ],
                    }
                ],
            }
        },
    }


class LoaderTests(unittest.TestCase):
    def _write_set(self, root: Path, set_id: str = "academic_99") -> Path:
        folder = root / set_id
        folder.mkdir(parents=True)
        (folder / "meta.json").write_text(
            json.dumps(
                {
                    "id": set_id,
                    "type": "academic",
                    "title": "Temp Set",
                    "description": "temp",
                    "skills": ["listening", "reading", "writing", "speaking"],
                }
            ),
            encoding="utf-8",
        )
        (folder / "listening.json").write_text(
            json.dumps({"duration_seconds": 30, "review_seconds": 30, "parts": []}),
            encoding="utf-8",
        )
        for skill in ("reading", "writing", "speaking"):
            (folder / f"{skill}.json").write_text(
                json.dumps({"duration_seconds": 30}), encoding="utf-8"
            )
        return folder

    def test_list_sets_and_get_set_from_a_temp_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write_set(root)
            summaries = service.list_sets(root=root)
            self.assertEqual(len(summaries), 1)
            summary = summaries[0]
            self.assertEqual(summary["id"], "academic_99")
            # (30 + 30 + 30 + 30 + 30 review) / 60 -> ceil = 3
            self.assertEqual(summary["duration_minutes"], 3)
            self.assertEqual(
                summary["skills"], ["listening", "reading", "writing", "speaking"]
            )

            data = service.get_set("academic_99", root=root)
            self.assertEqual(data["title"], "Temp Set")
            self.assertEqual(set(data["sections"]), set(service.ALL_SKILLS))

    def test_missing_set_and_missing_section_raise_clean_errors(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaises(service.MockTestNotFound):
                service.get_set("does_not_exist", root=root)

            folder = self._write_set(root)
            (folder / "writing.json").unlink()
            with self.assertRaises(service.MockTestNotFound):
                service.get_set("academic_99", root=root)

    def test_missing_root_lists_no_sets(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(service.list_sets(root=Path(tmp) / "nope"), [])


class BandTableTests(unittest.TestCase):
    def test_listening_boundaries(self):
        cases = {
            40: 9.0,
            39: 9.0,
            38: 8.5,
            37: 8.5,
            36: 8.0,
            30: 7.0,
            29: 6.5,
            23: 6.0,
            18: 5.5,
            16: 5.0,
            13: 4.5,
            10: 4.0,
            8: 3.5,
            6: 3.0,
            4: 2.5,
            0: 2.0,
        }
        for raw, band in cases.items():
            with self.subTest(raw=raw):
                self.assertEqual(raw_to_band("listening", "academic", raw), band)

    def test_academic_vs_general_reading(self):
        self.assertEqual(raw_to_band("reading", "academic", 40), 9.0)
        self.assertEqual(raw_to_band("reading", "general", 40), 9.0)
        self.assertEqual(raw_to_band("reading", "academic", 39), 9.0)
        self.assertEqual(raw_to_band("reading", "general", 39), 8.5)
        self.assertEqual(raw_to_band("reading", "academic", 30), 7.0)
        self.assertEqual(raw_to_band("reading", "general", 30), 6.0)
        self.assertEqual(raw_to_band("reading", "academic", 23), 6.0)
        self.assertEqual(raw_to_band("reading", "general", 23), 5.0)
        self.assertEqual(raw_to_band("reading", "general", 8), 3.0)

    def test_raw_scores_are_clamped(self):
        self.assertEqual(raw_to_band("listening", "academic", 99), 9.0)
        self.assertEqual(raw_to_band("listening", "academic", -5), 2.0)

    def test_overall_rounding(self):
        self.assertEqual(overall_band([6.5, 6.0, 6.5, 6.0]), 6.5)  # mean 6.25
        self.assertEqual(overall_band([7.0, 6.5, 7.0, 6.5]), 7.0)  # mean 6.75
        self.assertEqual(overall_band([6.5, 6.5, 6.5, 6.5]), 6.5)  # mean 6.5
        self.assertEqual(overall_band([0, 0, 0, 0]), 0.0)
        self.assertEqual(overall_band([9, 9, 9, 9]), 9.0)

    def test_overall_accepts_dict(self):
        scores = {"listening": 6.5, "reading": 6.0, "writing": 6.5, "speaking": 6.0}
        self.assertEqual(overall_band(scores), 6.5)


class NormalizeAndGradeTests(unittest.TestCase):
    def test_normalize_answer(self):
        self.assertEqual(normalize_answer("  Sarah   Whitfield. "), "sarah whitfield")
        self.assertEqual(normalize_answer("(don't)"), "don't")
        self.assertEqual(normalize_answer('"well-known"'), "well-known")
        self.assertEqual(normalize_answer("NOT GIVEN."), "not given")
        self.assertEqual(normalize_answer(None), "")

    def test_tfng(self):
        question = {"answer": ["TRUE"], "alternatives": ["T", "YES"]}
        for value in ("TRUE", "true", "T", "t", "YES", "y"):
            with self.subTest(value=value):
                self.assertTrue(service.grade_boolean(question, value))
        self.assertFalse(service.grade_boolean(question, "FALSE"))

        ng_question = {"answer": ["NOT GIVEN"], "alternatives": ["NG"]}
        for value in ("not given", "NOT GIVEN", "ng", "notgiven"):
            with self.subTest(value=value):
                self.assertTrue(service.grade_boolean(ng_question, value))
        self.assertFalse(service.grade_boolean(ng_question, "TRUE"))

    def test_ynng(self):
        question = {"answer": ["NO"], "alternatives": ["N", "FALSE"]}
        self.assertTrue(service.grade_boolean(question, "no", ynng=True))
        self.assertTrue(service.grade_boolean(question, "false", ynng=True))
        self.assertFalse(service.grade_boolean(question, "yes", ynng=True))
        self.assertEqual(canonical_boolean("yes", ynng=True), "YES")
        self.assertEqual(canonical_boolean("t", ynng=False), "TRUE")
        self.assertEqual(canonical_boolean("ng", ynng=False), "NOT GIVEN")

    def test_completion_accepts_alternatives_and_normalizes(self):
        question = {
            "answer": ["Sarah Whitfield"],
            "alternatives": ["Sarah"],
        }
        self.assertTrue(grade_completion(question, "  sarah   whitfield. "))
        self.assertTrue(grade_completion(question, "Sarah"))
        self.assertFalse(grade_completion(question, "Whitfield"))
        self.assertFalse(grade_completion(question, ""))

    def test_completion_numeric_words(self):
        question = {"answer": ["18"], "alternatives": []}
        self.assertTrue(grade_completion(question, "eighteen"))
        self.assertTrue(grade_completion(question, "18"))
        self.assertFalse(grade_completion(question, "80"))

    def test_mcq_accepts_key_or_text(self):
        question = {
            "answer": ["B"],
            "alternatives": [],
            "options": [
                {"key": "A", "text": "First option"},
                {"key": "B", "text": "Second option"},
            ],
        }
        self.assertTrue(grade_choice(question, "b"))
        self.assertTrue(grade_choice(question, "Second Option."))
        self.assertFalse(grade_choice(question, "A"))
        self.assertFalse(grade_choice(question, "First option"))

    def test_grade_question_dispatch(self):
        tfng = {"answer": ["TRUE"], "alternatives": []}
        self.assertTrue(service.grade_question("tfng", tfng, "yes"))
        self.assertTrue(service.grade_question("ynng", tfng, "yes"))
        self.assertTrue(service.grade_question("ynng", {"answer": ["TRUE"]}, "true"))


class SanitizeTests(unittest.TestCase):
    def test_sanitize_removes_answer_keys_at_any_depth(self):
        payload = _synthetic_set()
        payload["sections"]["listening"] = {
            "duration_seconds": 30,
            "parts": [
                {
                    "id": "L1",
                    "transcript": "Speaker 1: secret script",
                    "groups": [
                        {
                            "type": "form_completion",
                            "questions": [
                                {
                                    "id": "L1-1",
                                    "prompt": "Name: ______",
                                    "answer": ["Sarah"],
                                    "alternatives": ["Sara"],
                                    "explanation": "Heard clearly.",
                                }
                            ],
                        }
                    ],
                }
            ],
        }
        payload["sections"]["writing"] = {
            "tasks": [{"id": "W1", "prompt": "...", "sample_answer": "Band 8 answer"}]
        }
        original = copy.deepcopy(payload)

        clean = sanitize_set(payload)

        def _keys(node):
            if isinstance(node, dict):
                for key, value in node.items():
                    yield key
                    yield from _keys(value)
            elif isinstance(node, list):
                for item in node:
                    yield from _keys(item)

        found = set(_keys(clean))
        for concealed in ("answer", "alternatives", "explanation", "transcript", "sample_answer"):
            self.assertNotIn(concealed, found)
        # Non-sensitive content survives ...
        self.assertEqual(clean["sections"]["reading"]["passages"][0]["groups"][0]["questions"][0]["prompt"],
                         "Statement two")
        self.assertIn("duration_seconds", clean["sections"]["listening"])
        # ... and the source dict is untouched.
        self.assertEqual(payload, original)


class GradeSectionTests(unittest.TestCase):
    def test_grade_section_contract_shape_and_ordering(self):
        data = _synthetic_set()
        result = grade_section(
            "synthetic_01",
            "reading",
            {"R1-1": "T", "R1-2": "TRUE", "R1-3": "second option"},
            set_data=data,
        )
        self.assertEqual(result["skill"], "reading")
        self.assertEqual(result["raw_score"], 2)
        self.assertEqual(result["total"], 3)
        self.assertEqual(result["criteria"], {})
        self.assertEqual([d["number"] for d in result["details"]], [1, 2, 3])
        self.assertEqual([d["is_correct"] for d in result["details"]], [True, False, True])
        self.assertEqual(result["details"][1]["user_answer"], "TRUE")
        self.assertEqual(result["details"][1]["correct_answer"], "FALSE")
        self.assertIn("explanation", result["details"][0])
        self.assertEqual(result["band"], raw_to_band("reading", "academic", 2))
        self.assertEqual(
            set(result),
            {
                "skill", "band", "raw_score", "total", "criteria", "comment",
                "details", "strengths", "improvements", "corrections", "extra",
            },
        )

    def test_grade_section_uses_number_keys_too(self):
        result = grade_section(
            "synthetic_01", "reading", {"1": "TRUE"}, set_data=_synthetic_set()
        )
        self.assertTrue(result["details"][0]["is_correct"])


class AttemptLifecycleTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        service.reset_memory_attempts()
        self.data = _synthetic_set()
        self.patch = mock.patch.object(service, "get_set", return_value=self.data)
        self.patch.start()

    def tearDown(self):
        self.patch.stop()
        service.reset_memory_attempts()

    async def test_memory_only_lifecycle(self):
        created = await service.create_attempt(None, "synthetic_01", mode="strict")
        self.assertEqual(created["set_id"], "synthetic_01")
        self.assertEqual(created["mode"], "strict")
        self.assertEqual(created["sections"][0]["skill"], "reading")
        self.assertEqual(created["sections"][0]["duration_seconds"], 600)
        self.assertEqual(created["sections"][0]["status"], "pending")
        self.assertTrue(created["started_at"].endswith("Z"))

        attempt_id = created["attempt_id"]
        await service.save_section(
            None, attempt_id, "reading", answers={"R1-1": "TRUE"}, flagged=["R1-2"]
        )
        detail = await service.get_attempt_detail(None, attempt_id)
        self.assertEqual(detail["answers"]["reading"], {"R1-1": "TRUE"})
        self.assertEqual(detail["flagged"]["reading"], ["R1-2"])
        self.assertNotIn("answer", str(detail["sections"]))

        with self.assertRaises(IncompleteAttemptError):
            await service.complete_attempt(None, attempt_id)

        score = await service.submit_section(
            None, attempt_id, "reading", {"answers": {"R1-2": "FALSE", "R1-3": "B"}}
        )
        self.assertEqual(score["raw_score"], 3)
        self.assertEqual(score["total"], 3)

        # Idempotent: re-submitting returns the stored score and does not change it.
        again = await service.submit_section(
            None, attempt_id, "reading", {"answers": {"R1-1": "FALSE"}}
        )
        self.assertEqual(again, score)

        completed = await service.complete_attempt(None, attempt_id)
        self.assertEqual(completed["overall_band"], score["band"])
        self.assertEqual(completed["xp_awarded"], 50)
        self.assertIsNotNone(completed["completed_at"])

        # Completing twice keeps the same XP (no double award).
        repeat = await service.complete_attempt(None, attempt_id)
        self.assertEqual(repeat["xp_awarded"], 50)

    async def test_unknown_attempt_raises_not_found(self):
        with self.assertRaises(service.MockTestNotFound):
            await service.get_attempt_detail(None, "not-a-uuid")

    async def test_guest_has_no_history(self):
        created = await service.create_attempt(None, "synthetic_01")
        await service.submit_section(
            None, created["attempt_id"], "reading", {"answers": {"R1-1": "TRUE"}}
        )
        self.assertEqual(await service.list_attempts(None, None), [])


if __name__ == "__main__":
    unittest.main()
