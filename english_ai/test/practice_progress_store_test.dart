import 'package:english_ai/features/practice/data/practice_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dayKey is a local yyyy-MM-dd key', () {
    expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
    expect(dayKey(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('recordAnswer updates totals, accuracy, and today count', () {
    final now = DateTime(2026, 10, 25, 9);
    final empty = PracticeProgress.empty().normalized(now: now);

    final first = empty.recordAnswer(correct: true, now: now);
    final second = first.recordAnswer(correct: false, now: now);

    expect(second.totalAnswered, 2);
    expect(second.totalCorrect, 1);
    expect(second.dailyAnswered, 2);
    expect(second.dailyDone, 2);
    expect(second.accuracyPercent, 50);
    expect(second.dailyGoalMet, isFalse);
  });

  test('daily count resets when the day changes', () {
    final yesterday = DateTime(2026, 10, 24, 23);
    final today = DateTime(2026, 10, 25, 1);
    final progress = PracticeProgress.empty()
        .normalized(now: yesterday)
        .recordAnswer(correct: true, now: yesterday)
        .recordAnswer(correct: true, now: yesterday);

    final reset = progress.normalized(now: today);
    expect(reset.totalAnswered, 2);
    expect(reset.totalCorrect, 2);
    expect(reset.dailyAnswered, 0);
    expect(reset.dailyDate, '2026-10-25');

    final next = reset.recordAnswer(correct: false, now: today);
    expect(next.dailyAnswered, 1);
    expect(next.totalAnswered, 3);
    expect(next.accuracyPercent, 67);
  });

  test('dailyDone clamps at the goal', () {
    const progress = PracticeProgress(dailyAnswered: 9);
    expect(progress.dailyDone, PracticeProgress.dailyGoal);
    expect(progress.dailyGoalMet, isTrue);
  });

  test('store round-trips and normalizes stale daily data', () async {
    SharedPreferences.setMockInitialValues({});
    const stale = PracticeProgress(
      totalAnswered: 20,
      totalCorrect: 15,
      dailyAnswered: 4,
      dailyDate: '2020-01-01',
    );
    await PracticeProgressStore.save(stale);

    final loaded = await PracticeProgressStore.load();
    expect(loaded.totalAnswered, 20);
    expect(loaded.totalCorrect, 15);
    expect(loaded.dailyAnswered, 0);
    expect(loaded.dailyDate, dayKey(DateTime.now()));
  });

  test('empty load returns today normalized progress', () async {
    SharedPreferences.setMockInitialValues({});
    final loaded = await PracticeProgressStore.load();
    expect(loaded.totalAnswered, 0);
    expect(loaded.dailyDate, dayKey(DateTime.now()));
    expect(loaded.accuracyPercent, isNull);
  });
}
