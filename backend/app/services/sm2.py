from datetime import datetime, timedelta, timezone


class SM2Calculator:
    """
    SuperMemo 2 (SM-2) Spaced Repetition Algorithm implementation.
    
    Quality Ratings:
    - 5: Perfect recall without hesitation
    - 4: Correct recall after minor hesitation
    - 3: Correct recall with difficulty
    - 2: Incorrect response; where the correct one seemed easy to recall
    - 1: Incorrect response; the correct one remembered
    - 0: Complete blackout
    """

    MIN_EASE_FACTOR = 1.3
    DEFAULT_EASE_FACTOR = 2.5

    @classmethod
    def calculate_next_review(
        cls,
        repetition_count: int,
        ease_factor: float,
        interval_days: int,
        quality: int,
    ) -> tuple[int, float, int, datetime, str]:
        """
        Calculate the next repetition, interval, and ease factor.
        
        Returns:
            (new_repetition, new_ease_factor, new_interval_days, next_review_at, new_status)
        """
        # Clamp quality to 0-5
        q = max(0, min(5, quality))
        
        # Calculate new ease factor
        # EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        new_ef = ease_factor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        new_ef = max(cls.MIN_EASE_FACTOR, new_ef)

        if q >= 3:
            # Successful recall
            if repetition_count == 0:
                new_interval = 1
            elif repetition_count == 1:
                new_interval = 6
            else:
                new_interval = int(round(interval_days * new_ef))

            new_rep = repetition_count + 1
            status = "mastered" if new_interval >= 21 else "reviewing"
        else:
            # Failed recall: reset repetition count
            new_rep = 0
            new_interval = 1
            status = "learning"

        next_review_at = datetime.now(timezone.utc) + timedelta(days=new_interval)

        return new_rep, round(new_ef, 2), new_interval, next_review_at, status
