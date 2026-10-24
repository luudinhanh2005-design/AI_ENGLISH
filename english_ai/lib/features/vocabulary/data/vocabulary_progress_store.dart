import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local SM-2 state for vocabulary words reviewed while offline.
///
/// Online reviews are still sent to the backend (the server owns the canonical
/// schedule). This store keeps the fallback word list usable without a network
/// connection instead of silently dropping ratings.
class VocabularyProgress {
  final int repetitionCount;
  final double easeFactor;
  final int intervalDays;
  final DateTime nextReviewAt;
  final String status;

  const VocabularyProgress({
    required this.repetitionCount,
    required this.easeFactor,
    required this.intervalDays,
    required this.nextReviewAt,
    required this.status,
  });

  bool get isDue => !DateTime.now().isBefore(nextReviewAt);

  Map<String, dynamic> toJson() => {
        'repetition_count': repetitionCount,
        'ease_factor': easeFactor,
        'interval_days': intervalDays,
        'next_review_at': nextReviewAt.toIso8601String(),
        'status': status,
      };

  factory VocabularyProgress.fromJson(Map<String, dynamic> json) {
    return VocabularyProgress(
      repetitionCount: (json['repetition_count'] as num?)?.toInt() ?? 0,
      easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: (json['interval_days'] as num?)?.toInt() ?? 0,
      nextReviewAt: DateTime.tryParse(
            json['next_review_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      status: json['status'] as String? ?? 'new',
    );
  }
}

class VocabularyProgressStore {
  final String userId;

  VocabularyProgressStore({this.userId = 'guest'});

  String get _key => 'vocabulary_progress_v1_$userId';

  Future<Map<String, VocabularyProgress>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (key, value) => MapEntry(
          key,
          VocabularyProgress.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> save(String wordId, VocabularyProgress progress) async {
    final all = await load();
    all[wordId] = progress;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(all.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }
}
