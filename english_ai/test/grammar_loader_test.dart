import 'package:english_ai/features/learn/data/grammar_data.dart';
import 'package:english_ai/features/learn/data/grammar_progress_store.dart';
import 'package:english_ai/features/learn/data/grammar_remote_repository.dart';
import 'package:english_ai/features/learn/data/grammar_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repository loads 96 lessons', () async {
    final lessons = await GrammarRepository.loadLessons();
    expect(lessons.length, 96);
    expect(lessons.first.id, 'verb_to_be');
    expect(lessons.last.id, 'register_style_precision');
  });

  test('progress store round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await GrammarProgressStore.load(), isEmpty);
    await GrammarProgressStore.save({
      'present_simple': const GrammarProgress(
        completed: true,
        bestCorrect: 5,
        total: 5,
      ),
    });
    final loaded = await GrammarProgressStore.load();
    expect(loaded['present_simple']?.bestCorrect, 5);
    expect(loaded['present_simple']?.completed, true);
  });

  test('server payload aliases parse into the local model', () {
    final lesson = GrammarLesson.fromJson({
      'id': 'present_simple',
      'title': 'Present Simple',
      'level': 'A1',
      'summary': 'Server summary',
      'examples': [
        {'en': 'I work here.', 'vi': 'Tôi làm việc ở đây.'},
      ],
      'practice_questions': [
        {
          'question': 'She ___ here.',
          'options': ['work', 'works', 'working', 'worked'],
          'correct_option': 1,
          'explanation_vi': 'She dùng works.',
        },
      ],
      'is_beta': false,
      'version': 3,
    });

    expect(lesson.id, 'present_simple');
    expect(lesson.description, 'Server summary');
    expect(lesson.examples.single.english, 'I work here.');
    expect(lesson.quiz.single.correctIndex, 1);
    expect(lesson.quiz.single.explanation, 'She dùng works.');
    expect(lesson.version, 3);
  });

  test('C1/C2 default to beta but a reviewed flag can clear it', () {
    final draftC2 = GrammarLesson.fromJson({
      'id': 'c2_lesson',
      'title': 'C2',
      'level': 'C2',
    });
    final reviewedC2 = GrammarLesson.fromJson({
      'id': 'c2_lesson',
      'title': 'C2',
      'level': 'C2',
      'is_beta': false,
    });
    expect(draftC2.isBeta, isTrue);
    expect(reviewedC2.isBeta, isFalse);
  });

  test('all seeded C1/C2 lessons remain beta', () async {
    final lessons = await GrammarRepository.loadLessons();
    final advanced = lessons.where(
      (lesson) => lesson.level == 'C1' || lesson.level == 'C2',
    );
    expect(advanced, hasLength(20));
    expect(advanced.every((lesson) => lesson.isBeta), isTrue);
    expect(
      lessons
          .where((lesson) => lesson.level == 'A1' || lesson.level == 'A2')
          .every((lesson) => !lesson.isBeta),
      isTrue,
    );
  });

  test('pending attempts round-trip and deduplicate by id', () async {
    SharedPreferences.setMockInitialValues({});
    final id = generateGrammarAttemptId();
    final attempt = GrammarPendingAttempt(
      attemptId: id,
      lessonId: 'present_simple',
      lessonVersion: 2,
      answers: const {0: 1, 1: 2},
      createdAt: DateTime.utc(2026, 10, 23),
    );
    await GrammarProgressStore.enqueueAttempt(attempt);
    await GrammarProgressStore.enqueueAttempt(attempt);
    final loaded = await GrammarProgressStore.loadPending();
    expect(loaded, hasLength(1));
    expect(loaded.single.answers[1], 2);
    expect(loaded.single.lessonVersion, 2);
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(id),
      isTrue,
    );
  });
}
