import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local, all-time practice stats for the Practice arena.
///
/// Grammar XP/streak come from the authenticated user profile. Accuracy and the
/// daily question goal are tracked locally so they work offline and do not
/// require a backend endpoint.
class PracticeProgress {
  static const int dailyGoal = 5;

  final int totalAnswered;
  final int totalCorrect;
  final int dailyAnswered;
  final String dailyDate;

  const PracticeProgress({
    this.totalAnswered = 0,
    this.totalCorrect = 0,
    this.dailyAnswered = 0,
    this.dailyDate = '',
  });

  factory PracticeProgress.empty() => const PracticeProgress();

  int get dailyDone => dailyAnswered.clamp(0, dailyGoal);

  bool get dailyGoalMet => dailyAnswered >= dailyGoal;

  int? get accuracyPercent {
    if (totalAnswered == 0) return null;
    return (totalCorrect / totalAnswered * 100).round();
  }

  /// Reset the daily counter when the calendar day changes.
  PracticeProgress normalized({DateTime? now}) {
    final today = dayKey(now ?? DateTime.now());
    if (dailyDate == today) return this;
    return copyWith(dailyAnswered: 0, dailyDate: today);
  }

  PracticeProgress recordAnswer({
    required bool correct,
    DateTime? now,
  }) {
    final base = normalized(now: now);
    return base.copyWith(
      totalAnswered: base.totalAnswered + 1,
      totalCorrect: base.totalCorrect + (correct ? 1 : 0),
      dailyAnswered: base.dailyAnswered + 1,
    );
  }

  PracticeProgress copyWith({
    int? totalAnswered,
    int? totalCorrect,
    int? dailyAnswered,
    String? dailyDate,
  }) {
    return PracticeProgress(
      totalAnswered: totalAnswered ?? this.totalAnswered,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      dailyAnswered: dailyAnswered ?? this.dailyAnswered,
      dailyDate: dailyDate ?? this.dailyDate,
    );
  }

  factory PracticeProgress.fromJson(Map<String, dynamic> json) {
    return PracticeProgress(
      totalAnswered: _asInt(json['total_answered'] ?? json['totalAnswered']),
      totalCorrect: _asInt(json['total_correct'] ?? json['totalCorrect']),
      dailyAnswered: _asInt(json['daily_answered'] ?? json['dailyAnswered']),
      dailyDate: (json['daily_date'] ?? json['dailyDate'] ?? '').toString(),
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
        'total_answered': totalAnswered,
        'total_correct': totalCorrect,
        'daily_answered': dailyAnswered,
        'daily_date': dailyDate,
      };
}

/// `yyyy-MM-dd` in local time, used to reset the daily goal at midnight.
String dayKey(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse('$value') ?? 0;
}

class PracticeProgressStore {
  static const String _key = 'practice_progress_v1';

  static Future<PracticeProgress> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        return PracticeProgress.empty().normalized();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return PracticeProgress.empty().normalized();
      }
      return PracticeProgress.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return PracticeProgress.empty().normalized();
    }
  }

  static Future<void> save(PracticeProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(progress.toJson()));
    } catch (_) {
      // Practice stats are best-effort; never block the quiz on storage errors.
    }
  }
}
