import 'package:english_ai/features/vocabulary/data/vocabulary_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local vocabulary progress persists per user', () async {
    SharedPreferences.setMockInitialValues({});

    final alice = VocabularyProgressStore(userId: 'alice');
    final bob = VocabularyProgressStore(userId: 'bob');
    final nextReview = DateTime.now().add(const Duration(days: 6));

    await alice.save(
      'word-1',
      VocabularyProgress(
        repetitionCount: 2,
        easeFactor: 2.5,
        intervalDays: 6,
        nextReviewAt: nextReview,
        status: 'reviewing',
      ),
    );

    final aliceProgress = await alice.load();
    expect(aliceProgress['word-1']?.intervalDays, 6);
    expect(aliceProgress['word-1']?.repetitionCount, 2);
    expect(aliceProgress['word-1']?.status, 'reviewing');

    final bobProgress = await bob.load();
    expect(bobProgress, isEmpty);
  });
}
