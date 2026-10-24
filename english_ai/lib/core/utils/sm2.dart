/// SM-2 scheduling shared by mistake notebooks and vocabulary review.
///
/// Keep this formula in sync with `backend/app/services/sm2.py`:
/// - quality >= 3 means a successful recall
/// - first success: 1 day, second: 6 days, then interval * ease factor
/// - mastered when the interval reaches 21 days
class Sm2Result {
  final int repetitionCount;
  final double easeFactor;
  final int intervalDays;
  final DateTime nextReviewAt;
  final String status;

  const Sm2Result({
    required this.repetitionCount,
    required this.easeFactor,
    required this.intervalDays,
    required this.nextReviewAt,
    required this.status,
  });
}

Sm2Result calculateSm2({
  required int repetitionCount,
  required double easeFactor,
  required int intervalDays,
  required int quality,
}) {
  final q = quality.clamp(0, 5);
  var rawEf = easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
  if (rawEf < 1.3) rawEf = 1.3;
  final newEf = (rawEf * 100).round() / 100;

  int newRep;
  int newInterval;
  String status;

  if (q >= 3) {
    if (repetitionCount == 0) {
      newInterval = 1;
    } else if (repetitionCount == 1) {
      newInterval = 6;
    } else {
      newInterval = (intervalDays * rawEf).round();
    }
    newRep = repetitionCount + 1;
    status = newInterval >= 21 ? 'mastered' : 'reviewing';
  } else {
    newRep = 0;
    newInterval = 1;
    status = 'learning';
  }

  return Sm2Result(
    repetitionCount: newRep,
    easeFactor: newEf,
    intervalDays: newInterval,
    nextReviewAt: DateTime.now().add(Duration(days: newInterval)),
    status: status,
  );
}
