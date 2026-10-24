"""Unit tests for the honest pronunciation scoring module.

Run from backend/:
    .\\venv\\Scripts\\python.exe -m unittest discover -s tests -t . -v
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.pronunciation_scoring import (  # noqa: E402
    build_assessment,
    normalize_words,
    score_alignment,
    score_timing,
)

REFERENCE = "Could I get a medium caramel latte to go please"


def make_timing_words(count=10, step=0.3, duration=0.3):
    return [
        {
            "word": f"w{index}",
            "start_time": round(index * step, 2),
            "end_time": round(index * step + duration, 2),
        }
        for index in range(count)
    ]


class TestPerfectReading(unittest.TestCase):
    def test_identical_text_scores_full(self):
        result = build_assessment(REFERENCE, REFERENCE)

        self.assertTrue(result["scored"])
        self.assertIsNone(result["reason"])
        self.assertEqual(result["accuracy_score"], 100.0)
        self.assertEqual(result["completeness_score"], 100.0)
        self.assertEqual(result["overall_score"], 95.0)
        self.assertFalse(result["has_timing"])
        self.assertIsNone(result["tempo_score"])
        self.assertIsNone(result["fluency_score"])
        self.assertTrue(result["word_scores"])
        for entry in result["word_scores"]:
            self.assertEqual(entry["error_type"], "None")
            self.assertEqual(entry["phonemes"], [])

    def test_identical_text_with_timing_is_capped_at_96(self):
        result = build_assessment(REFERENCE, REFERENCE, stt_words=make_timing_words())

        self.assertTrue(result["has_timing"])
        self.assertEqual(result["accuracy_score"], 100.0)
        self.assertEqual(result["completeness_score"], 100.0)
        self.assertLessEqual(result["overall_score"], 96.0)
        self.assertGreater(result["overall_score"], 95.0)


class TestWrongReading(unittest.TestCase):
    def test_completely_different_sentence_scores_low(self):
        result = build_assessment(REFERENCE, "The quick brown fox jumps over the lazy dog")

        self.assertTrue(result["scored"])
        self.assertLess(result["overall_score"], 20)

    def test_half_sentence(self):
        result = build_assessment(REFERENCE, "Could I get a medium")

        self.assertGreaterEqual(result["accuracy_score"], 40)
        self.assertLessEqual(result["accuracy_score"], 60)

    def test_shuffled_words_scores_low(self):
        shuffled = "latte caramel medium a get I could please go to"
        result = build_assessment(REFERENCE, shuffled)

        self.assertLess(result["accuracy_score"], 60)

    def test_wrong_sentence_gets_no_timing_bonus(self):
        # Nói một câu hoàn toàn khác nhưng đúng nhịp KHÔNG được cộng điểm nhịp.
        words = make_timing_words(count=10, step=0.5, duration=0.5)
        result = build_assessment(
            REFERENCE,
            "the quick brown fox jumps over the lazy dog",
            stt_words=words,
            target_wpm=120,
        )

        self.assertLess(result["overall_score"], 20)
        self.assertIsNone(result["tempo_score"])
        self.assertIsNone(result["fluency_score"])
        self.assertTrue(
            any("không đánh giá tốc độ" in note for note in result["notes"])
        )

    def test_empty_recognition(self):
        result = build_assessment(REFERENCE, "")

        self.assertFalse(result["scored"])
        self.assertEqual(result["reason"], "no_speech")
        self.assertEqual(result["overall_score"], 0.0)
        self.assertEqual(result["accuracy_score"], 0.0)
        self.assertEqual(result["completeness_score"], 0.0)
        self.assertIsNone(result["tempo_score"])
        self.assertIsNone(result["fluency_score"])
        self.assertFalse(result["has_timing"])
        self.assertEqual(len(result["word_scores"]), len(normalize_words(REFERENCE)))
        for entry in result["word_scores"]:
            self.assertEqual(entry["error_type"], "Omission")
            self.assertEqual(entry["accuracy_score"], 0.0)

    def test_punctuation_only_recognition_is_no_speech(self):
        result = build_assessment(REFERENCE, "!!! ... ???")

        self.assertFalse(result["scored"])
        self.assertEqual(result["reason"], "no_speech")


class TestNormalisation(unittest.TestCase):
    def test_contraction_expansion(self):
        result = build_assessment("It's a test", "it is a test")

        self.assertEqual(result["accuracy_score"], 100.0)
        self.assertEqual(result["completeness_score"], 100.0)

    def test_case_and_punctuation_are_ignored(self):
        result = build_assessment("Hello, world!", "hello world")

        self.assertEqual(result["accuracy_score"], 100.0)
        self.assertEqual(result["completeness_score"], 100.0)

    def test_normalize_words(self):
        self.assertEqual(
            normalize_words("Don't stop, it's 2026!"),
            ["do", "not", "stop", "it", "is", "2026"],
        )

    def test_curly_apostrophe(self):
        self.assertEqual(
            normalize_words("I\u2019m here, you\u2019re late"),
            ["i", "am", "here", "you", "are", "late"],
        )

    def test_partial_and_omitted_words(self):
        result = score_alignment("I like green tea", "I like tea")

        self.assertEqual(result["accuracy_score"], round(3 / 4 * 100, 1))
        self.assertEqual(result["completeness_score"], 75.0)
        self.assertEqual(result["omitted_words"], 1)
        self.assertEqual(result["wrong_words"], 0)

    def test_inserted_word_reported(self):
        result = score_alignment("I like tea", "I really like tea")

        self.assertEqual(result["inserted_words"], 1)
        inserted = [entry for entry in result["word_scores"] if entry["error_type"] == "Insertion"]
        self.assertEqual(len(inserted), 1)
        self.assertEqual(inserted[0]["word"], "[really]")
        self.assertEqual(result["accuracy_score"], 100.0)
        self.assertEqual(result["completeness_score"], 100.0)
        self.assertEqual(result["total_ref_words"], 3)
        self.assertEqual(result["total_hyp_words"], 4)


class TestTiming(unittest.TestCase):
    def test_fast_speech_penalised(self):
        words = make_timing_words(count=10, step=0.3, duration=0.3)
        timing = score_timing(words, REFERENCE, target_wpm=120)

        self.assertTrue(timing["has_timing"])
        self.assertAlmostEqual(timing["speech_duration"], 3.0, places=2)
        self.assertAlmostEqual(timing["actual_wpm"], 200.0, places=1)
        self.assertLess(timing["tempo_score"], 70)
        self.assertLess(timing["fluency_score"], 100)
        self.assertEqual(timing["long_pause_count"], 0)

        result = build_assessment(REFERENCE, REFERENCE, stt_words=words, target_wpm=120)
        self.assertTrue(result["has_timing"])
        self.assertLess(result["tempo_score"], 70)
        self.assertLess(result["fluency_score"], 100)
        self.assertAlmostEqual(result["metrics"]["speech_duration"], 3.0, places=2)
        self.assertAlmostEqual(result["metrics"]["actual_wpm"], 200.0, places=1)
        self.assertEqual(result["metrics"]["target_wpm"], 120)

    def test_no_timestamps_means_no_timing_scores(self):
        result = build_assessment(REFERENCE, REFERENCE)

        self.assertFalse(result["has_timing"])
        self.assertIsNone(result["tempo_score"])
        self.assertIsNone(result["fluency_score"])
        self.assertIsNone(result["metrics"]["speech_duration"])
        self.assertIsNone(result["metrics"]["actual_wpm"])

    def test_long_pause_detected(self):
        words = [
            {"word": "a", "start_time": 0.0, "end_time": 0.4},
            {"word": "b", "start_time": 2.0, "end_time": 2.4},
            {"word": "c", "start_time": 2.8, "end_time": 3.2},
        ]
        timing = score_timing(words, "a b c", target_wpm=120)

        self.assertEqual(timing["long_pause_count"], 1)
        self.assertGreater(timing["pause_ratio"], 0.0)
        self.assertTrue(any("khoảng ngừng dài" in note for note in timing["notes"]))

    def test_timing_without_target_uses_pause_only(self):
        words = make_timing_words(count=4, step=0.25, duration=0.25)
        timing = score_timing(words, "one two three four")

        self.assertTrue(timing["has_timing"])
        self.assertIsNone(timing["tempo_score"])
        self.assertIsNotNone(timing["fluency_score"])
        self.assertLessEqual(timing["fluency_score"], 100.0)


class TestAssessmentShape(unittest.TestCase):
    def test_result_contract_keys(self):
        result = build_assessment(REFERENCE, REFERENCE)

        for key in (
            "scored",
            "reason",
            "reference_text",
            "recognised_text",
            "accuracy_score",
            "completeness_score",
            "tempo_score",
            "fluency_score",
            "overall_score",
            "has_timing",
            "weights_used",
            "word_scores",
            "notes",
            "metrics",
        ):
            self.assertIn(key, result)

        for key in (
            "matched_words",
            "near_words",
            "wrong_words",
            "omitted_words",
            "inserted_words",
            "total_ref_words",
            "total_hyp_words",
            "speech_duration",
            "actual_wpm",
            "target_wpm",
            "long_pause_count",
            "pause_ratio",
        ):
            self.assertIn(key, result["metrics"])

        self.assertEqual(result["metrics"]["matched_words"], 10)
        self.assertEqual(result["metrics"]["total_ref_words"], 10)
        self.assertEqual(result["metrics"]["total_hyp_words"], 10)
        self.assertEqual(result["metrics"]["omitted_words"], 0)
        self.assertEqual(result["metrics"]["inserted_words"], 0)

    def test_cap_note_always_present(self):
        result = build_assessment(REFERENCE, REFERENCE)
        self.assertTrue(any("Điểm tối đa 96" in note for note in result["notes"]))

    def test_scores_are_clamped(self):
        result = build_assessment(REFERENCE, "the quick brown fox jumps over the lazy dog")
        for key in ("accuracy_score", "completeness_score", "overall_score"):
            self.assertGreaterEqual(result[key], 0.0)
            self.assertLessEqual(result[key], 100.0)


if __name__ == "__main__":
    unittest.main()
