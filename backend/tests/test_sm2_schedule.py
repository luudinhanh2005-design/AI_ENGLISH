from datetime import datetime, timezone

from app.services.sm2 import SM2Calculator


def test_first_success_is_one_day():
    rep, ef, interval, next_review, status = SM2Calculator.calculate_next_review(
        repetition_count=0,
        ease_factor=2.5,
        interval_days=0,
        quality=4,
    )
    assert rep == 1
    assert interval == 1
    assert status == "reviewing"
    assert next_review > datetime.now(timezone.utc)


def test_second_success_is_six_days():
    rep, ef, interval, _, _ = SM2Calculator.calculate_next_review(
        repetition_count=1,
        ease_factor=2.5,
        interval_days=1,
        quality=4,
    )
    assert (rep, interval) == (2, 6)


def test_failure_resets_schedule():
    rep, ef, interval, _, status = SM2Calculator.calculate_next_review(
        repetition_count=5,
        ease_factor=2.2,
        interval_days=60,
        quality=2,
    )
    assert rep == 0
    assert interval == 1
    assert status == "learning"


def test_ease_factor_floor():
    _, ef, _, _, _ = SM2Calculator.calculate_next_review(
        repetition_count=0,
        ease_factor=1.3,
        interval_days=1,
        quality=0,
    )
    assert ef >= 1.3
