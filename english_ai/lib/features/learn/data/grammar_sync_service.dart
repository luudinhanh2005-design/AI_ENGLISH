import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../../core/constants/app_config.dart';
import 'grammar_data.dart';
import 'grammar_progress_store.dart';
import 'grammar_remote_repository.dart';

/// Best-effort synchronization for grammar content, progress, and attempts.
///
/// The local JSON/`SharedPreferences` flow remains the source of truth when
/// there is no backend, no token, or no network.
class GrammarSyncService {
  GrammarSyncService._();

  /// Allows the live-backend integration test to run even though
  /// `FLUTTER_TEST=true` disables remote calls in regular widget tests.
  @visibleForTesting
  static bool forceEnabledForTests = false;

  static bool get _enabled =>
      AppConfig.useRemoteGrammar || forceEnabledForTests;

  /// Merge server progress into local progress. Never lets a lower server score
  /// overwrite a better offline result.
  static Future<Map<String, GrammarProgress>> fetchAndMergeProgress(
    List<GrammarLesson> lessons,
  ) async {
    final local = await GrammarProgressStore.load();
    if (!_enabled) return local;
    Map<String, GrammarProgress> remote;
    try {
      remote = await GrammarRemoteRepository.fetchProgress(lessons);
    } catch (_) {
      return local;
    }
    if (remote.isEmpty) return local;

    final merged = Map<String, GrammarProgress>.from(local);
    for (final lesson in lessons) {
      final server = remote[lesson.id];
      if (server == null) continue;
      final previous = merged[lesson.id];
      merged[lesson.id] = GrammarProgress(
        completed: (previous?.completed ?? false) || server.completed,
        bestCorrect:
            max(previous?.bestCorrect ?? 0, server.bestCorrect),
        total: lesson.quiz.length,
        xpEarned: max(previous?.xpEarned ?? 0, server.xpEarned),
        synced: true,
      );
    }
    await GrammarProgressStore.save(merged);
    return merged;
  }

  /// Submit an attempt. Returns the merged progress on success, or `null` when
  /// the attempt was queued for a later retry.
  static Future<GrammarProgress?> submitAttempt({
    required GrammarLesson lesson,
    required Map<int, int> answers,
  }) async {
    if (!_enabled) return null;
    final attemptId = generateGrammarAttemptId();
    try {
      final result = await GrammarRemoteRepository.submitAttempt(
        lesson: lesson,
        answers: answers,
        attemptId: attemptId,
      );
      if (result == null) {
        await _enqueue(lesson, answers, attemptId);
        return null;
      }
      return await _mergeResult(lesson, result);
    } catch (_) {
      await _enqueue(lesson, answers, attemptId);
      return null;
    }
  }

  /// Retry queued attempts when the app opens and a token is available.
  static Future<void> flushPending({
    required List<GrammarLesson> lessons,
  }) async {
    if (!_enabled) return;
    final pending = await GrammarProgressStore.loadPending();
    if (pending.isEmpty) return;
    final byId = {for (final lesson in lessons) lesson.id: lesson};
    final remaining = <GrammarPendingAttempt>[];

    for (final attempt in pending) {
      final lesson = byId[attempt.lessonId];
      if (lesson == null) {
        // Lesson was removed/archived; do not keep retrying forever.
        continue;
      }
      try {
        final result = await GrammarRemoteRepository.submitAttempt(
          lesson: lesson,
          answers: attempt.answers,
          attemptId: attempt.attemptId,
        );
        if (result == null) {
          remaining.add(attempt);
        } else {
          await _mergeResult(lesson, result);
        }
      } catch (_) {
        remaining.add(attempt);
      }
    }
    await GrammarProgressStore.savePending(remaining);
  }

  static Future<void> _enqueue(
    GrammarLesson lesson,
    Map<int, int> answers,
    String attemptId,
  ) async {
    await GrammarProgressStore.enqueueAttempt(
      GrammarPendingAttempt(
        attemptId: attemptId,
        lessonId: lesson.id,
        lessonVersion: lesson.version,
        answers: Map<int, int>.from(answers),
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  static Future<GrammarProgress> _mergeResult(
    GrammarLesson lesson,
    GrammarAttemptResult result,
  ) async {
    final progress = await GrammarProgressStore.load();
    final previous = progress[lesson.id];
    final total = lesson.quiz.length;
    final serverCorrect = result.bestScore > 0 && total > 0
        ? ((result.bestScore / 100) * total).round()
        : result.correct;
    final merged = GrammarProgress(
      completed:
          (previous?.completed ?? false) || result.isCompleted || result.isPassed,
      bestCorrect: max(previous?.bestCorrect ?? 0, serverCorrect),
      total: total,
      xpEarned: max(previous?.xpEarned ?? 0, result.xpEarned),
      synced: true,
    );
    progress[lesson.id] = merged;
    await GrammarProgressStore.save(progress);
    return merged;
  }
}

