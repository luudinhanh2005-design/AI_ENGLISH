import 'dart:io';

import 'package:dio/dio.dart';
import 'package:english_ai/features/learn/data/grammar_progress_store.dart';
import 'package:english_ai/features/learn/data/grammar_remote_repository.dart';
import 'package:english_ai/features/learn/data/grammar_repository.dart';
import 'package:english_ai/features/learn/data/grammar_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live-backend contract test for the Flutter sync layer.
///
/// Run only when the backend is up:
///   GRAMMAR_INTEGRATION=true flutter test test/grammar_sync_integration_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['GRAMMAR_INTEGRATION'] == 'true';

  test(
    'bundle, attempt idempotency, progress merge, and queue flush',
    () async {
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1'));
      final login = await dio.post(
        '/auth/login',
        data: {'email': 'test@gmail.com', 'password': 'Password123'},
      );
      final token = (login.data as Map)['access_token'].toString();
      final headers = {'Authorization': 'Bearer $token'};
      GrammarRemoteRepository.debugBaseUrl = 'http://127.0.0.1:8000/api/v1';
      GrammarRemoteRepository.debugAccessToken = token;
      GrammarSyncService.forceEnabledForTests = true;

      final bundle = await GrammarRemoteRepository.fetchBundle();
      expect(bundle, isNotNull);
      expect(bundle!.lessons.length, 96);

      final lessons = await GrammarRepository.loadLessons();
      final lesson = lessons.firstWhere((item) => item.id == 'present_simple');
      final answers = <int, int>{
        for (var index = 0; index < lesson.quiz.length; index++)
          index: lesson.quiz[index].correctIndex,
      };

      final attemptId = generateGrammarAttemptId();
      final first = await GrammarRemoteRepository.submitAttempt(
        lesson: lesson,
        answers: answers,
        attemptId: attemptId,
      );
      expect(first, isNotNull);
      expect(first!.score, 100);
      expect(first.duplicate, isFalse);
      expect(first.xpEarned, 30);

      final duplicate = await GrammarRemoteRepository.submitAttempt(
        lesson: lesson,
        answers: answers,
        attemptId: attemptId,
      );
      expect(duplicate, isNotNull);
      expect(duplicate!.duplicate, isTrue);
      expect(duplicate.xpEarned, first.xpEarned);

      final serviceProgress = await GrammarSyncService.submitAttempt(
        lesson: lesson,
        answers: answers,
      );
      expect(serviceProgress, isNotNull);
      expect(serviceProgress!.synced, isTrue);
      expect(serviceProgress.bestCorrect, lesson.quiz.length);

      await GrammarProgressStore.enqueueAttempt(
        GrammarPendingAttempt(
          attemptId: generateGrammarAttemptId(),
          lessonId: lesson.id,
          lessonVersion: lesson.version,
          answers: answers,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      expect(await GrammarProgressStore.loadPending(), hasLength(1));
      await GrammarSyncService.flushPending(lessons: lessons);
      expect(await GrammarProgressStore.loadPending(), isEmpty);

      // A failed sync must keep the attempt queued for the next retry.
      await GrammarProgressStore.enqueueAttempt(
        GrammarPendingAttempt(
          attemptId: generateGrammarAttemptId(),
          lessonId: lesson.id,
          lessonVersion: lesson.version,
          answers: answers,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      final validToken = GrammarRemoteRepository.debugAccessToken;
      GrammarRemoteRepository.debugAccessToken = 'invalid-token';
      await GrammarSyncService.flushPending(lessons: lessons);
      expect(await GrammarProgressStore.loadPending(), hasLength(1));
      GrammarRemoteRepository.debugAccessToken = validToken;
      await GrammarSyncService.flushPending(lessons: lessons);
      expect(await GrammarProgressStore.loadPending(), isEmpty);

      final merged = await GrammarSyncService.fetchAndMergeProgress(lessons);
      expect(merged['present_simple']?.completed, isTrue);
      expect(merged['present_simple']?.bestCorrect, lesson.quiz.length);
      expect(merged['present_simple']?.synced, isTrue);

      final progress = await dio.get(
        '/grammar/progress',
        options: Options(headers: headers),
      );
      final items = (progress.data as Map)['items'] as List;
      final serverItem = items
          .cast<Map>()
          .firstWhere((item) => item['lesson_slug'] == 'present_simple');
      expect(serverItem['best_score'], 100);
      expect(serverItem['is_completed'], isTrue);
    },
    skip: enabled
        ? false
        : 'Set GRAMMAR_INTEGRATION=true and start the backend first.',
  );

  tearDown(() {
    GrammarRemoteRepository.debugAccessToken = null;
    GrammarRemoteRepository.debugBaseUrl = null;
    GrammarSyncService.forceEnabledForTests = false;
  });
}
