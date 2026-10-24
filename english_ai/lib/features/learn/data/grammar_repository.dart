import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_config.dart';
import 'grammar_data.dart';
import 'grammar_remote_repository.dart';

/// Loads the A1-C2 grammar curriculum.
///
/// Local bundled JSON is always available. [loadLessonsWithSync] tries the
/// server bundle first, then a SharedPreferences cache, then the bundled seed.
class GrammarRepository {
  static const List<String> _levelFiles = [
    'a1',
    'a2',
    'b1',
    'b2',
    'c1',
    'c2',
  ];

  static const String _cacheKey = 'grammar_content_cache_v2';

  /// Local-only loader. Used by tests and as the guaranteed offline fallback.
  static Future<List<GrammarLesson>> loadLessons() => loadLocalLessons();

  static Future<List<GrammarLesson>> loadLocalLessons() async {
    final lessons = <GrammarLesson>[];

    for (final level in _levelFiles) {
      try {
        final raw = await rootBundle.loadString(
          'assets/data/grammar/$level.json',
        );
        final decoded = jsonDecode(raw);
        if (decoded is! List) continue;

        for (final item in decoded) {
          if (item is! Map) continue;
          try {
            final lesson =
                GrammarLesson.fromJson(Map<String, dynamic>.from(item));
            if (lesson.id.isNotEmpty) {
              lessons.add(lesson);
            }
          } catch (_) {
            // Skip a malformed lesson without dropping the rest of the level.
          }
        }
      } catch (_) {
        // Keep loading the other levels if one file is missing or invalid.
      }
    }

    return lessons;
  }

  /// Remote-first content with cache and bundled offline fallback.
  static Future<List<GrammarLesson>> loadLessonsWithSync() async {
    if (!AppConfig.useRemoteGrammar) return loadLocalLessons();
    try {
      final bundle = await GrammarRemoteRepository.fetchBundle();
      if (bundle != null && bundle.lessons.isNotEmpty) {
        await _saveCache(bundle.rawLessons, bundle.version);
        return bundle.lessons;
      }
    } catch (_) {
      // Offline or backend down: continue to cache/seed.
    }

    final cached = await loadCachedLessons();
    if (cached.isNotEmpty) return cached;
    return loadLocalLessons();
  }

  static Future<List<GrammarLesson>> loadCachedLessons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final rawLessons = decoded['lessons'];
      if (rawLessons is! List) return const [];
      final lessons = <GrammarLesson>[];
      for (final item in rawLessons.whereType<Map>()) {
        try {
          final lesson =
              GrammarLesson.fromJson(Map<String, dynamic>.from(item));
          if (lesson.id.isNotEmpty) lessons.add(lesson);
        } catch (_) {
          // Ignore one malformed cached lesson.
        }
      }
      return lessons;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _saveCache(
    List<Map<String, dynamic>> rawLessons,
    String version,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'version': version,
          'cached_at': DateTime.now().toUtc().toIso8601String(),
          'lessons': rawLessons,
        }),
      );
    } catch (_) {
      // A failed cache write must never break lesson loading.
    }
  }
}
