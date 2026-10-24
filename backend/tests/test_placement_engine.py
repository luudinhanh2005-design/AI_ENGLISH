"""Unit tests for the CEFR placement engine and content bank."""

from __future__ import annotations

import unittest

from app.services.placement_engine import (
    CEFR_LEVELS,
    PlacementBank,
    estimate_theta,
    grade_item,
    level_from_theta,
    level_range,
    rubric_to_theta,
)


class PlacementEngineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.bank = PlacementBank()

    def test_bank_is_balanced(self) -> None:
        self.assertEqual(len(self.bank.items), 90)
        self.assertEqual(len(self.bank.writing_tasks), 12)
        self.assertEqual(len(self.bank.speaking_tasks), 18)
        for skill in ("listening", "reading", "use_of_english"):
            for level in CEFR_LEVELS:
                self.assertEqual(len(self.bank.by_skill_level[skill][level]), 5)

    def test_every_answer_key_is_valid(self) -> None:
        for item in self.bank.items.values():
            keys = {str(option["key"]) for option in item["options"]}
            self.assertTrue(item["answer"])
            for answer in item["answer"]:
                self.assertIn(str(answer), keys, item["id"])

    def test_grading_mcq_and_multi_select(self) -> None:
        item = self.bank.get_item("ls_a1_01")
        self.assertTrue(grade_item(item, ["B"]))
        self.assertTrue(grade_item(item, "b"))
        self.assertFalse(grade_item(item, ["A"]))
        self.assertFalse(grade_item(item, []))

        multi = {
            "type": "multi_select",
            "options": [{"key": "A"}, {"key": "B"}, {"key": "C"}],
            "answer": ["A", "C"],
        }
        self.assertTrue(grade_item(multi, ["A", "C"]))
        self.assertFalse(grade_item(multi, ["A"]))
        self.assertFalse(grade_item(multi, ["A", "B"]))

    def test_theta_estimation_moves_in_expected_direction(self) -> None:
        mostly_easy_correct = [
            {"b": -2.0, "a": 1.0, "c": 0.25, "correct": True},
            {"b": -1.2, "a": 1.0, "c": 0.25, "correct": True},
            {"b": 0.0, "a": 1.0, "c": 0.25, "correct": False},
        ]
        mostly_hard_correct = [
            {"b": 0.0, "a": 1.0, "c": 0.25, "correct": True},
            {"b": 1.2, "a": 1.0, "c": 0.25, "correct": True},
            {"b": 2.0, "a": 1.0, "c": 0.25, "correct": True},
        ]
        low = estimate_theta(mostly_easy_correct)
        high = estimate_theta(mostly_hard_correct)
        self.assertLess(low.theta, high.theta)
        self.assertGreater(low.se, 0)
        self.assertGreater(high.se, 0)

    def test_level_boundaries_and_range(self) -> None:
        self.assertEqual(level_from_theta(-3.0), "A1")
        self.assertEqual(level_from_theta(0.0), "B2")
        self.assertEqual(level_from_theta(3.0), "C2")
        low, high = level_range(0.0, 0.6)
        self.assertLessEqual(CEFR_LEVELS.index(low), CEFR_LEVELS.index(high))

    def test_stage_selection_excludes_served_items(self) -> None:
        first = self.bank.select_stage("reading", 1, 0.0, count=4)
        ids = [item["id"] for item in first]
        second = self.bank.select_stage("reading", 2, 0.0, exclude_ids=ids, count=4)
        self.assertTrue(second)
        self.assertTrue(set(ids).isdisjoint({item["id"] for item in second}))

    def test_rubric_mapping(self) -> None:
        low_theta, low_se = rubric_to_theta({"a": 1, "b": 1})
        high_theta, high_se = rubric_to_theta({"a": 4.5, "b": 5})
        self.assertLess(low_theta, high_theta)
        self.assertAlmostEqual(low_se, 0.42)

    def test_sanitised_payload_hides_answers(self) -> None:
        item = self.bank.sanitize_item(self.bank.get_item("rd_b1_01"))
        self.assertNotIn("answer", item)
        self.assertNotIn("explanation_vi", item)
        self.assertIn("passage", item)
        self.assertEqual(len(item["options"]), 4)


if __name__ == "__main__":
    unittest.main()
