import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/services/storage_service.dart';
import 'grammar_data.dart';
import 'grammar_progress_store.dart';

/// Server-side grammar content, progress, and attempts.
///
/// Every method is safe to call when the backend is unavailable; failures are
/// surfaced to [GrammarSyncService], which keeps local learning usable.
class GrammarRemoteRepository {
  GrammarRemoteRepository._();

  static Dio? _dio;

  /// Test seam for live-backend integration tests; production reads the
  /// token from [StorageService].
  @visibleForTesting
  static String? debugAccessToken;

  /// Optional base URL override for the live-backend integration test.
  @visibleForTesting
  static String? debugBaseUrl;

  static Dio get _client {
    return _dio ??= Dio(
      BaseOptions(
        baseUrl: debugBaseUrl ?? ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  static Future<Map<String, String>> _headers() async {
    if (debugAccessToken != null && debugAccessToken!.isNotEmpty) {
      return {'Authorization': 'Bearer $debugAccessToken'};
    }
    try {
      final token = await StorageService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        return {'Authorization': 'Bearer $token'};
      }
    } catch (_) {
      // Storage is not initialized in unit tests or before main().
    }
    return const {};
  }

  static Future<GrammarBundle?> fetchBundle() async {
    // Bundle content is public; do not let an expired token block offline
    // cache refreshes.
    final response = await _client.get(ApiEndpoints.grammarBundle);
    final data = response.data;
    if (data is! Map) return null;
    final rawLessons = data['lessons'];
    if (rawLessons is! List) return null;
    final lessons = <GrammarLesson>[];
    final rawMaps = <Map<String, dynamic>>[];
    for (final item in rawLessons.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      try {
        final lesson = GrammarLesson.fromJson(map);
        if (lesson.id.isNotEmpty) {
          lessons.add(lesson);
          rawMaps.add(map);
        }
      } catch (_) {
        // Ignore one malformed lesson; keep the rest of the bundle.
      }
    }
    if (lessons.isEmpty) return null;
    return GrammarBundle(
      lessons: lessons,
      rawLessons: rawMaps,
      version: (data['version'] ?? '').toString(),
    );
  }

  static Future<Map<String, GrammarProgress>> fetchProgress(
    List<GrammarLesson> lessons,
  ) async {
    final headers = await _headers();
    if (!headers.containsKey('Authorization')) return const {};
    final response = await _client.get(
      ApiEndpoints.grammarProgress,
      options: Options(headers: headers),
    );
    final data = response.data;
    if (data is! Map) return const {};
    final rawItems = data['items'];
    if (rawItems is! List) return const {};
    final totals = <String, int>{
      for (final lesson in lessons) lesson.id: lesson.quiz.length,
    };
    final result = <String, GrammarProgress>{};
    for (final item in rawItems.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final slug = (map['lesson_slug'] ?? map['id'] ?? '').toString();
      if (slug.isEmpty) continue;
      result[slug] = GrammarProgress.fromRemoteJson(
        map,
        total: totals[slug] ?? 0,
      );
    }
    return result;
  }

  static Future<GrammarAttemptResult?> submitAttempt({
    required GrammarLesson lesson,
    required Map<int, int> answers,
    required String attemptId,
  }) async {
    final headers = await _headers();
    if (!headers.containsKey('Authorization')) return null;
    final response = await _client.post(
      ApiEndpoints.grammarAttempts,
      options: Options(headers: headers),
      data: {
        'attempt_id': attemptId,
        'lesson_slug': lesson.id,
        'lesson_version': lesson.version,
        'answers': answers.entries
            .map(
              (entry) => {
                'question_index': entry.key,
                'selected_option': entry.value,
              },
            )
            .toList(),
      },
    );
    final data = response.data;
    if (data is! Map) return null;
    return GrammarAttemptResult.fromJson(Map<String, dynamic>.from(data));
  }
}

class GrammarBundle {
  final List<GrammarLesson> lessons;
  final List<Map<String, dynamic>> rawLessons;
  final String version;

  const GrammarBundle({
    required this.lessons,
    required this.rawLessons,
    required this.version,
  });
}

class GrammarAttemptResult {
  final String attemptId;
  final double score;
  final int total;
  final int correct;
  final bool isPassed;
  final int xpEarned;
  final double bestScore;
  final bool isCompleted;
  final bool duplicate;

  const GrammarAttemptResult({
    required this.attemptId,
    required this.score,
    required this.total,
    required this.correct,
    required this.isPassed,
    required this.xpEarned,
    required this.bestScore,
    required this.isCompleted,
    required this.duplicate,
  });

  factory GrammarAttemptResult.fromJson(Map<String, dynamic> json) {
    return GrammarAttemptResult(
      attemptId: (json['attempt_id'] ?? '').toString(),
      score: _toDouble(json['score']),
      total: _toInt(json['total']),
      correct: _toInt(json['correct']),
      isPassed: json['is_passed'] == true,
      xpEarned: _toInt(json['xp_earned']),
      bestScore: _toDouble(json['best_score']),
      isCompleted: json['is_completed'] == true,
      duplicate: json['duplicate'] == true,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse('$value') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

/// RFC 4122 v4 UUID without adding another package.
String generateGrammarAttemptId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
