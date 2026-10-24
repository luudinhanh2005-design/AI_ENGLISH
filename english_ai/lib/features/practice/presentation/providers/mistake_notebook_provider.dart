import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/sm2.dart';
import '../../../../core/utils/uuid.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class MistakeItem {
  final String id;
  final String originalText;
  final String correctedText;
  final String explanation;
  final String type; // grammar, vocabulary, pronunciation
  final String source; // speaking, writing, ielts, practice, custom
  final DateTime createdAt;
  final int repetitionCount;
  final int intervalDays;
  final double easeFactor;
  final DateTime nextReviewAt;
  final DateTime? lastReviewedAt;
  final String status; // new, learning, reviewing, mastered

  const MistakeItem({
    required this.id,
    required this.originalText,
    required this.correctedText,
    required this.explanation,
    required this.type,
    required this.source,
    required this.createdAt,
    this.repetitionCount = 0,
    this.intervalDays = 1,
    this.easeFactor = 2.5,
    required this.nextReviewAt,
    this.lastReviewedAt,
    this.status = 'new',
  });

  bool get isDue => !DateTime.now().isBefore(nextReviewAt);

  MistakeItem copyWith({
    String? id,
    String? originalText,
    String? correctedText,
    String? explanation,
    String? type,
    String? source,
    DateTime? createdAt,
    int? repetitionCount,
    int? intervalDays,
    double? easeFactor,
    DateTime? nextReviewAt,
    DateTime? lastReviewedAt,
    String? status,
  }) {
    return MistakeItem(
      id: id ?? this.id,
      originalText: originalText ?? this.originalText,
      correctedText: correctedText ?? this.correctedText,
      explanation: explanation ?? this.explanation,
      type: type ?? this.type,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      repetitionCount: repetitionCount ?? this.repetitionCount,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'original_text': originalText,
        'corrected_text': correctedText,
        'explanation': explanation,
        'type': type,
        'source': source,
        'created_at': createdAt.toIso8601String(),
        'repetition_count': repetitionCount,
        'interval_days': intervalDays,
        'ease_factor': easeFactor,
        'next_review_at': nextReviewAt.toIso8601String(),
        'last_reviewed_at': lastReviewedAt?.toIso8601String(),
        'status': status,
      };

  /// Payload accepted by `POST /ai/mistakes`.
  Map<String, dynamic> toCreateJson() => {
        'id': id,
        'original_text': originalText,
        'corrected_text': correctedText,
        'explanation': explanation,
        'type': type,
        'source': source,
      };

  factory MistakeItem.fromJson(Map<String, dynamic> json) {
    return MistakeItem(
      id: json['id'] as String? ?? generateUuidV4(),
      originalText:
          json['original_text'] as String? ?? json['original'] as String? ?? '',
      correctedText: json['corrected_text'] as String? ??
          json['corrected'] as String? ??
          '',
      explanation: json['explanation'] as String? ?? '',
      type: json['type'] as String? ?? 'grammar',
      source: json['source'] as String? ?? 'practice',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      repetitionCount: (json['repetition_count'] as num?)?.toInt() ?? 0,
      intervalDays: (json['interval_days'] as num?)?.toInt() ?? 1,
      easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
      nextReviewAt: json['next_review_at'] != null
          ? DateTime.tryParse(json['next_review_at'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.tryParse(json['last_reviewed_at'].toString())
          : null,
      status: json['status'] as String? ?? 'new',
    );
  }
}

/// Preview used by the UI to show the real next interval for each rating.
int previewSm2Interval(MistakeItem item, int rating) {
  return calculateSm2(
    repetitionCount: item.repetitionCount,
    easeFactor: item.easeFactor,
    intervalDays: item.intervalDays,
    quality: rating,
  ).intervalDays;
}

class MistakeNotebookState {
  final List<MistakeItem> items;
  final bool isLoading;
  final String?
      filterType; // null / 'all', 'grammar', 'vocabulary', 'pronunciation'

  const MistakeNotebookState({
    this.items = const [],
    this.isLoading = false,
    this.filterType,
  });

  List<MistakeItem> get filteredItems {
    if (filterType == null || filterType == 'all') {
      return items;
    }
    return items
        .where((m) => m.type.toLowerCase() == filterType!.toLowerCase())
        .toList();
  }

  List<MistakeItem> get dueItems => items.where((m) => m.isDue).toList();

  int get totalCount => items.length;
  int get dueCount => items.where((m) => m.isDue).length;
  int get masteredCount => items.where((m) => m.status == 'mastered').length;

  MistakeNotebookState copyWith({
    List<MistakeItem>? items,
    bool? isLoading,
    String? filterType,
    bool resetFilter = false,
  }) {
    return MistakeNotebookState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      filterType: resetFilter ? null : (filterType ?? this.filterType),
    );
  }
}

class MistakeNotebookNotifier extends StateNotifier<MistakeNotebookState> {
  final Dio _dio;
  final String _userId;

  MistakeNotebookNotifier(this._dio, {String userId = 'guest'})
      : _userId = userId,
        super(const MistakeNotebookState()) {
    _loadMistakes();
  }

  String get _storageKey => 'mistake_notebook_items_v2_$_userId';
  static const String _legacyStorageKey = 'mistake_notebook_items_v1';

  static String _contentKey(String text) => text.trim().toLowerCase();

  Future<void> _loadMistakes() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    final localJson =
        prefs.getString(_storageKey) ?? prefs.getString(_legacyStorageKey);

    List<MistakeItem> loaded = [];
    if (localJson != null && localJson.isNotEmpty) {
      try {
        final list = jsonDecode(localJson) as List<dynamic>;
        loaded = list
            .map((e) => MistakeItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        loaded = [];
      }
    }

    // Remove the demo records that older builds injected as fake user data.
    loaded =
        loaded.where((m) => !m.id.startsWith('seed_')).toList(growable: true);

    // Legacy local records used timestamps as ids. Give them a real UUID so
    // review/delete/sync calls are accepted by the backend.
    loaded = loaded
        .map((m) => isUuid(m.id) ? m : m.copyWith(id: generateUuidV4()))
        .toList(growable: true);

    // Keep a single copy of every mistake even if older storage is dirty.
    loaded = _mergeCanonical(const [], loaded);

    state = state.copyWith(items: loaded, isLoading: false);
    if (localJson != null) {
      await _persist(loaded);
    }

    // Try syncing with the backend. The server is the source of truth for ids.
    try {
      final initial = await _dio.get(ApiEndpoints.aiMistakes);
      if (initial.statusCode != 200 || initial.data is! List) return;

      final server = (initial.data as List)
          .map((e) => MistakeItem.fromJson(e as Map<String, dynamic>))
          .toList();

      // Push locally-created mistakes that the server has not seen yet.
      final pending = _pendingUploads(loaded, server);
      if (pending.isNotEmpty) {
        await _dio.post(
          ApiEndpoints.aiMistakes,
          data: pending.map((m) => m.toCreateJson()).toList(),
        );
      }

      final refreshed =
          pending.isEmpty ? initial : await _dio.get(ApiEndpoints.aiMistakes);
      if (refreshed.statusCode == 200 && refreshed.data is List) {
        final canonical = (refreshed.data as List)
            .map((e) => MistakeItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final merged = _mergeCanonical(canonical, loaded);
        state = state.copyWith(items: merged);
        await _persist(merged);
      }
    } catch (_) {
      // Offline: local data remains the source of truth.
    }
  }

  List<MistakeItem> _pendingUploads(
    List<MistakeItem> local,
    List<MistakeItem> server,
  ) {
    final serverIds = server.map((m) => m.id).toSet();
    final serverContent =
        server.map((m) => _contentKey(m.originalText)).toSet();
    return local
        .where((m) =>
            !serverIds.contains(m.id) &&
            !serverContent.contains(_contentKey(m.originalText)))
        .toList();
  }

  /// Merges server and local records without creating duplicates.
  ///
  /// The server owns the canonical id; the side with the newest review wins the
  /// SM-2 fields. This keeps reviews made offline when the app reconnects.
  List<MistakeItem> _mergeCanonical(
    List<MistakeItem> server,
    List<MistakeItem> local,
  ) {
    final result = <MistakeItem>[];

    DateTime reviewStamp(MistakeItem item) =>
        item.lastReviewedAt ?? item.createdAt;

    MistakeItem withScheduleOf(MistakeItem target, MistakeItem source) {
      return target.copyWith(
        originalText: source.originalText,
        correctedText: source.correctedText,
        explanation: source.explanation,
        type: source.type,
        source: source.source,
        createdAt: source.createdAt,
        repetitionCount: source.repetitionCount,
        intervalDays: source.intervalDays,
        easeFactor: source.easeFactor,
        nextReviewAt: source.nextReviewAt,
        lastReviewedAt: source.lastReviewedAt,
        status: source.status,
      );
    }

    void add(MistakeItem item) {
      final content = _contentKey(item.originalText);
      var index = result.indexWhere((m) => m.id == item.id);
      if (index == -1) {
        index = result.indexWhere(
          (m) => _contentKey(m.originalText) == content,
        );
      }

      if (index == -1) {
        result.add(item);
        return;
      }

      final existing = result[index];
      final newer =
          reviewStamp(item).isAfter(reviewStamp(existing)) ? item : existing;
      // Keep the id of the first record added (server records are added first).
      result[index] = withScheduleOf(existing, newer);
    }

    for (final item in server) {
      add(item);
    }
    for (final item in local) {
      add(item);
    }

    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<void> _persist(List<MistakeItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  void setFilter(String? type) {
    state = type == null
        ? state.copyWith(resetFilter: true)
        : state.copyWith(filterType: type);
  }

  /// Adds a mistake locally and (best effort) on the server.
  /// Returns false when the content is empty or already exists.
  Future<bool> addMistake({
    required String originalText,
    required String correctedText,
    required String explanation,
    String type = 'grammar',
    String source = 'practice',
  }) async {
    final cleanOriginal = originalText.trim();
    if (cleanOriginal.isEmpty) return false;

    final duplicate = state.items.any(
      (m) => _contentKey(m.originalText) == _contentKey(cleanOriginal),
    );
    if (duplicate) return false;

    final newItem = MistakeItem(
      id: generateUuidV4(),
      originalText: cleanOriginal,
      correctedText: correctedText.trim(),
      explanation: explanation.trim(),
      type: type,
      source: source,
      createdAt: DateTime.now(),
      nextReviewAt: DateTime.now(),
      status: 'new',
    );

    var updated = [newItem, ...state.items];
    state = state.copyWith(items: updated);
    await _persist(updated);

    try {
      final res = await _dio.post(
        ApiEndpoints.aiMistakes,
        data: [newItem.toCreateJson()],
      );
      final saved = _savedList(res.data);
      if (saved.isNotEmpty) {
        final canonical = MistakeItem.fromJson(saved.first);
        updated = _mergeCanonical([canonical], state.items)
            .where((m) => m.id != newItem.id || canonical.id == newItem.id)
            .toList();
        state = state.copyWith(items: updated);
        await _persist(updated);
      }
    } catch (_) {
      // Offline: keep the local copy, it will be uploaded on next launch.
    }
    return true;
  }

  List<Map<String, dynamic>> _savedList(dynamic data) {
    if (data is Map && data['saved'] is List) {
      return (data['saved'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<int> addBatchMistakes(
    List<Map<String, dynamic>> items, {
    String source = 'speaking',
  }) async {
    int count = 0;
    for (final raw in items) {
      final orig =
          raw['original'] ?? raw['original_text'] ?? raw['error'] ?? '';
      final corr =
          raw['corrected'] ?? raw['corrected_text'] ?? raw['correction'] ?? '';
      final expl = raw['explanation'] ?? raw['rule'] ?? 'Lỗi cần lưu ý';
      final type = raw['type'] ?? 'grammar';

      if (orig.toString().trim().isNotEmpty) {
        final added = await addMistake(
          originalText: orig.toString(),
          correctedText: corr.toString(),
          explanation: expl.toString(),
          type: type.toString(),
          source: source,
        );
        if (added) count++;
      }
    }
    return count;
  }

  /// Applies SM-2 locally, then lets the server confirm the canonical schedule.
  Future<void> reviewMistake(String id, int rating) async {
    final index = state.items.indexWhere((m) => m.id == id);
    if (index == -1) return;

    final item = state.items[index];
    final sm2 = calculateSm2(
      repetitionCount: item.repetitionCount,
      easeFactor: item.easeFactor,
      intervalDays: item.intervalDays,
      quality: rating,
    );

    final updatedItem = item.copyWith(
      repetitionCount: sm2.repetitionCount,
      intervalDays: sm2.intervalDays,
      easeFactor: sm2.easeFactor,
      nextReviewAt: sm2.nextReviewAt,
      lastReviewedAt: DateTime.now(),
      status: sm2.status,
    );

    var updatedList = List<MistakeItem>.from(state.items);
    updatedList[index] = updatedItem;
    state = state.copyWith(items: updatedList);
    await _persist(updatedList);

    if (!isUuid(id)) return;

    try {
      final res = await _dio.post(
        ApiEndpoints.aiMistakeReview(id),
        data: {'rating': rating},
      );
      if (res.statusCode == 200 && res.data is Map) {
        final canonical =
            MistakeItem.fromJson(Map<String, dynamic>.from(res.data as Map));
        updatedList =
            state.items.map((m) => m.id == id ? canonical : m).toList();
        updatedList = _mergeCanonical(const [], updatedList);
        state = state.copyWith(items: updatedList);
        await _persist(updatedList);
      }
    } catch (_) {
      // Offline: local schedule above is already persisted.
    }
  }

  Future<void> deleteMistake(String id) async {
    final updatedList = state.items.where((m) => m.id != id).toList();
    state = state.copyWith(items: updatedList);
    await _persist(updatedList);

    if (!isUuid(id)) return;
    try {
      await _dio.delete(ApiEndpoints.aiMistakeDelete(id));
    } catch (_) {
      // Offline: deletion from local storage is enough for now.
    }
  }
}

final mistakeNotebookProvider =
    StateNotifierProvider<MistakeNotebookNotifier, MistakeNotebookState>((ref) {
  final dio = ref.watch(dioProvider);
  final userId = ref.watch(authStateProvider).valueOrNull?.id ?? 'guest';
  return MistakeNotebookNotifier(dio, userId: userId);
});
