import 'dart:math';

import 'package:english_ai/features/learn/data/grammar_data.dart';
import 'package:english_ai/features/learn/data/grammar_progress_store.dart';
import 'package:english_ai/features/learn/data/grammar_remote_repository.dart';
import 'package:english_ai/features/learn/data/grammar_sync_service.dart';
import 'package:english_ai/features/practice/presentation/providers/practice_quiz_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads a lesson at the user level', () async {
    final lesson = _lesson('b1_present', 'B1');
    final notifier = PracticeQuizNotifier(
      loadLessons: () async => [lesson],
      loadProgress: () async => {},
      submitAttempt: _successfulSubmit,
      random: Random(1),
    );

    await notifier.load(userLevel: 'B1');

    expect(notifier.state.phase, PracticeQuizPhase.ready);
    expect(notifier.state.lesson?.id, 'b1_present');
    expect(notifier.state.questionIndex, 0);
    expect(notifier.state.totalQuestions, 5);
    expect(notifier.state.question, isNotNull);
  });

  test('C1/C2 users fall back to reviewed lessons', () async {
    final b1 = _lesson('b1_present', 'B1');
    final c1 = _lesson('c1_advanced', 'C1', isBeta: true);
    final notifier = PracticeQuizNotifier(
      loadLessons: () async => [b1, c1],
      loadProgress: () async => {},
      submitAttempt: _successfulSubmit,
      random: Random(1),
    );

    await notifier.load(userLevel: 'C1');

    expect(notifier.state.phase, PracticeQuizPhase.ready);
    expect(notifier.state.lesson?.id, 'b1_present');
    expect(notifier.state.lesson?.isBeta, isFalse);
  });

  test('prefers an incomplete lesson at the closest level', () async {
    final completedB1 = _lesson('b1_completed', 'B1');
    final freshB2 = _lesson('b2_fresh', 'B2');
    final notifier = PracticeQuizNotifier(
      loadLessons: () async => [completedB1, freshB2],
      loadProgress: () async => {
        'b1_completed': const GrammarProgress(
          completed: true,
          bestCorrect: 5,
          total: 5,
        ),
      },
      submitAttempt: _successfulSubmit,
      random: Random(1),
    );

    await notifier.load(userLevel: 'B1');

    expect(notifier.state.lesson?.id, 'b2_fresh');
  });

  test('answers reveal once and build a combo', () async {
    final lesson = _lesson('b1_present', 'B1');
    final notifier = PracticeQuizNotifier(
      loadLessons: () async => [lesson],
      loadProgress: () async => {},
      submitAttempt: _successfulSubmit,
      random: Random(1),
    );
    await notifier.load(userLevel: 'B1');

    await notifier.next();
    expect(notifier.state.questionIndex, 0);

    final correct = notifier.state.question!.correctIndex;
    expect(notifier.selectAnswer(correct), isTrue);
    expect(notifier.state.revealed, isTrue);
    expect(notifier.state.isCorrect, isTrue);
    expect(notifier.state.combo, 1);

    expect(notifier.selectAnswer((correct + 1) % 4), isFalse);
    expect(notifier.state.selectedOption, correct);
    expect(notifier.state.combo, 1);

    await notifier.next();
    expect(notifier.state.questionIndex, 1);

    final wrong = (notifier.state.question!.correctIndex + 1) % 4;
    notifier.selectAnswer(wrong);
    expect(notifier.state.isCorrect, isFalse);
    expect(notifier.state.combo, 0);
  });

  test('finishes and exposes the attempt XP/result', () async {
    final lesson = _lesson('b1_present', 'B1');
    final notifier = PracticeQuizNotifier(
      loadLessons: () async => [lesson],
      loadProgress: () async => {},
      submitAttempt: _successfulSubmit,
      random: Random(1),
    );
    await notifier.load(userLevel: 'B1');

    for (var index = 0; index < lesson.quiz.length; index++) {
      notifier.selectAnswer(notifier.state.question!.correctIndex);
      await notifier.next();
    }

    expect(notifier.state.phase, PracticeQuizPhase.finished);
    expect(notifier.state.percent, 100);
    expect(notifier.state.correctCount, 5);
    expect(notifier.state.outcome?.synced, isTrue);
    expect(notifier.state.outcome?.xpEarned, 30);
    expect(notifier.state.outcome?.attempt?.correct, 5);
  });

  test('queued attempts stay visible as offline', () async {
    final lesson = _lesson('b1_present', 'B1');
    final notifier = PracticeQuizNotifier(
      loadLessons: () async => [lesson],
      loadProgress: () async => {},
      submitAttempt: ({required lesson, required answers}) async {
        return const GrammarAttemptSyncResult(queued: true);
      },
      random: Random(1),
    );
    await notifier.load(userLevel: 'B1');

    for (var index = 0; index < lesson.quiz.length; index++) {
      notifier.selectAnswer(notifier.state.question!.correctIndex);
      await notifier.next();
    }

    expect(notifier.state.phase, PracticeQuizPhase.finished);
    expect(notifier.state.outcome?.queued, isTrue);
    expect(notifier.state.outcome?.synced, isFalse);
    expect(notifier.state.outcome?.xpEarned, 0);
  });

  test('restart and next lesson reset the session', () async {
    final first = _lesson('b1_present', 'B1');
    final second = _lesson('b1_past', 'B1');
    final notifier = PracticeQuizNotifier(
      loadLessons: () async => [first, second],
      loadProgress: () async => {},
      submitAttempt: _successfulSubmit,
      random: Random(2),
    );
    await notifier.load(userLevel: 'B1');
    final firstId = notifier.state.lesson!.id;

    notifier.selectAnswer(notifier.state.question!.correctIndex);
    await notifier.next();
    expect(notifier.state.questionIndex, 1);

    notifier.restart();
    expect(notifier.state.phase, PracticeQuizPhase.ready);
    expect(notifier.state.questionIndex, 0);
    expect(notifier.state.answers, isEmpty);
    expect(notifier.state.lesson?.id, firstId);

    await notifier.nextLesson();
    expect(notifier.state.phase, PracticeQuizPhase.ready);
    expect(notifier.state.questionIndex, 0);
    expect(notifier.state.lesson?.id, isNot(firstId));
  });

  test('next lesson still starts when progress cannot be re-read', () async {
    final first = _lesson('b1_present', 'B1');
    final second = _lesson('b1_past', 'B1');
    var progressReads = 0;
    final notifier = PracticeQuizNotifier(
      loadLessons: () async => [first, second],
      loadProgress: () async {
        progressReads++;
        if (progressReads > 1) throw StateError('offline');
        return {};
      },
      submitAttempt: _successfulSubmit,
      random: Random(2),
    );
    await notifier.load(userLevel: 'B1');
    final firstId = notifier.state.lesson!.id;

    await notifier.nextLesson();

    expect(notifier.state.phase, PracticeQuizPhase.ready);
    expect(notifier.state.lesson?.id, isNot(firstId));
    expect(notifier.state.errorMessage, isNull);
  });

  test('no lessons produces an error state', () async {
    final notifier = PracticeQuizNotifier(
      loadLessons: () async => [],
      loadProgress: () async => {},
      submitAttempt: _successfulSubmit,
      random: Random(1),
    );

    await notifier.load(userLevel: 'B1');

    expect(notifier.state.phase, PracticeQuizPhase.error);
    expect(notifier.state.errorMessage, isNotEmpty);
  });
}

Future<GrammarAttemptSyncResult> _successfulSubmit({
  required GrammarLesson lesson,
  required Map<int, int> answers,
}) async {
  return GrammarAttemptSyncResult(
    attempt: GrammarAttemptResult(
      attemptId: 'attempt-1',
      score: 100,
      total: lesson.quiz.length,
      correct: lesson.quiz.length,
      isPassed: true,
      xpEarned: 30,
      bestScore: 100,
      isCompleted: true,
      duplicate: false,
    ),
    progress: GrammarProgress(
      completed: true,
      bestCorrect: lesson.quiz.length,
      total: lesson.quiz.length,
      xpEarned: 30,
      synced: true,
    ),
  );
}

GrammarLesson _lesson(
  String id,
  String level, {
  bool isBeta = false,
}) {
  return GrammarLesson.fromJson({
    'id': id,
    'title': 'Lesson $id',
    'title_vi': 'Bài $id',
    'level': level,
    'category': 'Grammar',
    'description': 'Description',
    'is_beta': isBeta,
    'version': 1,
    'quiz': List.generate(
      5,
      (index) => {
        'question': 'Question ${index + 1}',
        'options': const ['A', 'B', 'C', 'D'],
        'correct_index': index % 4,
        'explanation': 'Explanation ${index + 1}',
      },
    ),
  });
}
