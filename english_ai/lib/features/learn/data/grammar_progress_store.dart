import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local and server-synced grammar progress for one lesson.
class GrammarProgress {
  final bool completed;
  final int bestCorrect;
  final int total;
  final int xpEarned;
  final bool synced;

  const GrammarProgress({
    required this.completed,
    required this.bestCorrect,
    required this.total,
    this.xpEarned = 0,
    this.synced = false,
  });

  double get percent => total == 0 ? 0 : bestCorrect / total * 100;

  factory GrammarProgress.fromJson(Map<String, dynamic> json) {
    final rawCorrect = json['best_correct'] ?? json['bestCorrect'] ?? 0;
    final rawTotal = json['total'] ?? 0;

    return GrammarProgress(
      completed: json['completed'] == true,
      bestCorrect:
          rawCorrect is int ? rawCorrect : int.tryParse('$rawCorrect') ?? 0,
      total: rawTotal is int ? rawTotal : int.tryParse('$rawTotal') ?? 0,
      xpEarned: _asInt(json['xp_earned'] ?? json['xpEarned']),
      synced: json['synced'] == true,
    );
  }

  /// Build progress from the server's percent-based progress response.
  factory GrammarProgress.fromRemoteJson(
    Map<String, dynamic> json, {
    required int total,
  }) {
    final rawCorrect = json['best_correct'] ?? json['bestCorrect'];
    final bestScore = _asDouble(json['best_score'] ?? json['bestScore']);
    final correct = rawCorrect != null
        ? _asInt(rawCorrect)
        : bestScore == null || total == 0
            ? 0
            : ((bestScore / 100) * total).round();
    return GrammarProgress(
      completed:
          json['is_completed'] == true || json['completed'] == true,
      bestCorrect: correct,
      total: total,
      xpEarned: _asInt(json['xp_earned'] ?? json['xpEarned']),
      synced: true,
    );
  }

  GrammarProgress copyWith({
    bool? completed,
    int? bestCorrect,
    int? total,
    int? xpEarned,
    bool? synced,
  }) {
    return GrammarProgress(
      completed: completed ?? this.completed,
      bestCorrect: bestCorrect ?? this.bestCorrect,
      total: total ?? this.total,
      xpEarned: xpEarned ?? this.xpEarned,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson() => {
        'completed': completed,
        'best_correct': bestCorrect,
        'total': total,
        'xp_earned': xpEarned,
        'synced': synced,
      };
}

/// A quiz attempt waiting for a network connection or a signed-in session.
class GrammarPendingAttempt {
  final String attemptId;
  final String lessonId;
  final int lessonVersion;
  final Map<int, int> answers;
  final DateTime createdAt;

  const GrammarPendingAttempt({
    required this.attemptId,
    required this.lessonId,
    required this.lessonVersion,
    required this.answers,
    required this.createdAt,
  });

  factory GrammarPendingAttempt.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'];
    final answers = <int, int>{};
    if (rawAnswers is Map) {
      rawAnswers.forEach((key, value) {
        final index = int.tryParse('$key');
        final option = value is int ? value : int.tryParse('$value');
        if (index != null && option != null) {
          answers[index] = option;
        }
      });
    }
    return GrammarPendingAttempt(
      attemptId: (json['attempt_id'] ?? '').toString(),
      lessonId: (json['lesson_id'] ?? '').toString(),
      lessonVersion: _asInt(json['lesson_version'], fallback: 1),
      answers: answers,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
              DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'attempt_id': attemptId,
        'lesson_id': lessonId,
        'lesson_version': lessonVersion,
        'answers': answers.map((key, value) => MapEntry('$key', value)),
        'created_at': createdAt.toIso8601String(),
      };
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse('$value') ?? fallback;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

class GrammarProgressStore {
  static const String _key = 'grammar_progress_v1';
  static const String _pendingKey = 'grammar_pending_attempts_v1';

  static Future<Map<String, GrammarProgress>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return <String, GrammarProgress>{};

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, GrammarProgress>{};

      final result = <String, GrammarProgress>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is Map) {
          result[entry.key.toString()] = GrammarProgress.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
      return result;
    } catch (_) {
      return <String, GrammarProgress>{};
    }
  }

  static Future<void> save(Map<String, GrammarProgress> progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        progress.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      );
      await prefs.setString(_key, encoded);
    } catch (_) {
      // Local progress is best-effort; never block the quiz on storage errors.
    }
  }

  static Future<List<GrammarPendingAttempt>> loadPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null || raw.isEmpty) return <GrammarPendingAttempt>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <GrammarPendingAttempt>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => GrammarPendingAttempt.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.attemptId.isNotEmpty && item.lessonId.isNotEmpty)
          .toList();
    } catch (_) {
      return <GrammarPendingAttempt>[];
    }
  }

  static Future<void> savePending(
    List<GrammarPendingAttempt> attempts,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingKey,
        jsonEncode(attempts.map((attempt) => attempt.toJson()).toList()),
      );
    } catch (_) {
      // Queue persistence is best-effort.
    }
  }

  static Future<void> enqueueAttempt(GrammarPendingAttempt attempt) async {
    final pending = await loadPending();
    if (pending.any((item) => item.attemptId == attempt.attemptId)) return;
    pending.add(attempt);
    await savePending(pending);
  }
}
