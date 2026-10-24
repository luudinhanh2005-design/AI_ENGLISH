"""Pure grammar-content tests (no database required)."""
from __future__ import annotations

import unittest

from app.schemas.grammar import GrammarSubmitAnswer
from app.services.grammar_service import (
    _grade_attempt,
    content_hash,
    deterministic_lesson_id,
    load_seed_lessons,
    normalize_lesson,
    validate_payload,
)


class GrammarContentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lessons = list(load_seed_lessons())

    def test_seed_has_96_lessons_and_480_questions(self):
        self.assertEqual(len(self.lessons), 96)
        self.assertEqual(sum(len(lesson["quiz"]) for lesson in self.lessons), 480)
        levels = {}
        for lesson in self.lessons:
            levels[lesson["level"]] = levels.get(lesson["level"], 0) + 1
        self.assertEqual(
            levels,
            {"A1": 18, "A2": 18, "B1": 20, "B2": 20, "C1": 10, "C2": 10},
        )

    def test_every_seed_lesson_passes_validation(self):
        failures = {}
        for lesson in self.lessons:
            result = validate_payload(lesson)
            if not result.valid:
                failures[lesson["id"]] = result.errors
        self.assertEqual(failures, {})

    def test_content_hash_is_stable_and_sensitive(self):
        lesson = self.lessons[0]
        self.assertEqual(content_hash(lesson), content_hash(dict(lesson)))
        changed = dict(lesson)
        changed["title"] = changed["title"] + " (changed)"
        self.assertNotEqual(content_hash(lesson), content_hash(changed))

    def test_normalize_accepts_legacy_aliases(self):
        payload = normalize_lesson(
            {
                "slug": "legacy_lesson",
                "title": "Legacy",
                "level": "B1",
                "summary": "Legacy summary",
                "formula": "S + V",
                "examples": [{"en": "Hello", "vi": "Xin chào"}],
                "practice_questions": [
                    {
                        "question": "Pick one",
                        "options": ["a", "b", "c", "d"],
                        "correct_option": 2,
                        "explanation_vi": "Because c",
                    }
                ],
            }
        )
        self.assertEqual(payload["id"], "legacy_lesson")
        self.assertEqual(payload["description"], "Legacy summary")
        self.assertEqual(payload["examples"][0]["english"], "Hello")
        self.assertEqual(payload["quiz"][0]["correct_index"], 2)
        self.assertEqual(payload["quiz"][0]["explanation"], "Because c")

    def test_grading_uses_correct_index(self):
        lesson = self.lessons[0]
        answers = [
            GrammarSubmitAnswer(
                question_index=index,
                selected_option=question["correct_index"],
            )
            for index, question in enumerate(lesson["quiz"])
        ]
        correct, total, score = _grade_attempt(lesson, answers)
        self.assertEqual(correct, total)
        self.assertEqual(score, 100.0)

    def test_deterministic_id_matches_import_strategy(self):
        self.assertEqual(
            deterministic_lesson_id("present_simple"),
            deterministic_lesson_id("present_simple"),
        )
        self.assertNotEqual(
            deterministic_lesson_id("present_simple"),
            deterministic_lesson_id("present_continuous"),
        )


if __name__ == "__main__":
    unittest.main()
