import 'dart:math';

import 'package:english_ai/core/theme/app_theme.dart';
import 'package:english_ai/features/auth/domain/entities/user.dart';
import 'package:english_ai/features/auth/domain/repositories/auth_repository.dart';
import 'package:english_ai/features/auth/presentation/providers/auth_provider.dart';
import 'package:english_ai/features/learn/data/grammar_data.dart';
import 'package:english_ai/features/learn/data/grammar_progress_store.dart';
import 'package:english_ai/features/learn/data/grammar_remote_repository.dart';
import 'package:english_ai/features/learn/data/grammar_sync_service.dart';
import 'package:english_ai/features/practice/presentation/providers/practice_quiz_provider.dart';
import 'package:english_ai/features/practice/presentation/screens/practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Practice arena lays out at 360px without overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = await _readyNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(_testUser),
          ),
          practiceQuizProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PracticeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đấu Trường Luyện Tập ⚡'), findsOneWidget);
    expect(find.text('220 XP'), findsOneWidget);
    expect(find.text('Chuỗi 5'), findsOneWidget);
    expect(find.text('Thử Thách Ngữ Pháp'), findsOneWidget);
    expect(find.text('Writing AI'), findsOneWidget);
    expect(find.text('BETA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Practice result card lays out at 360px without overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = await _readyNotifier();
    for (var index = 0; index < 5; index++) {
      notifier.selectAnswer(notifier.state.question!.correctIndex);
      await notifier.next();
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(_testUser),
          ),
          practiceQuizProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PracticeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xuất sắc! 100%'), findsOneWidget);
    expect(find.text('Đúng 5/5 câu'), findsOneWidget);
    expect(find.text('+30 XP'), findsOneWidget);
    expect(find.text('Bài tiếp theo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<PracticeQuizNotifier> _readyNotifier() async {
  final notifier = PracticeQuizNotifier(
    loadLessons: () async => [_lesson],
    loadProgress: () async => <String, GrammarProgress>{},
    submitAttempt: ({required lesson, required answers}) async {
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
    },
    random: Random(1),
  );
  await notifier.load(userLevel: 'B1');
  return notifier;
}

final _testUser = User(
  id: 'test-user',
  email: 'test@gmail.com',
  name: 'Test Learner',
  currentLevel: 'B1',
  streak: 5,
  totalXp: 220,
  hasCompletedOnboarding: true,
  createdAt: DateTime(2025, 1, 1),
);

final _lesson = GrammarLesson.fromJson({
  'id': 'b1_conditional',
  'title': 'First vs Second Conditional',
  'title_vi': 'Câu điều kiện loại 1 và 2',
  'level': 'B1',
  'category': 'Grammar',
  'description': 'Practice conditionals.',
  'is_beta': false,
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

class _FakeAuthRepository implements AuthRepository {
  final User? user;

  _FakeAuthRepository(this.user);

  @override
  Future<User?> getCurrentUser() async => user;

  @override
  Future<User> login({
    required String email,
    required String password,
  }) async =>
      user!;

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async =>
      user!;

  @override
  Future<User> loginWithGoogle({required String idToken}) async => user!;

  @override
  Future<void> logout() async {}

  @override
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}

  @override
  Future<void> saveOnboarding({
    required String learningGoal,
    required int dailyMinutes,
    required List<String> topics,
  }) async {}

  @override
  Future<User> updateProfile({
    String? name,
    String? avatarUrl,
    int? dailyLearningMinutes,
    String? targetLevel,
    String? currentLevel,
    String? learningGoal,
  }) async =>
      user!;
}
