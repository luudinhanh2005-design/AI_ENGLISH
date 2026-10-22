import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

class MistakeItem {
  final String id;
  final String originalText;
  final String correctedText;
  final String explanation;
  final String type; // grammar, vocabulary, pronunciation
  final String source; // speaking, writing, ielts, practice
  final DateTime createdAt;
  final int repetitionCount;
  final int intervalDays;
  final double easeFactor;
  final DateTime nextReviewAt;
  final String status; // new, learning, mastered

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
    this.status = 'new',
  });

  bool get isDue => DateTime.now().isAfter(nextReviewAt);

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
        'status': status,
      };

  factory MistakeItem.fromJson(Map<String, dynamic> json) {
    return MistakeItem(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      originalText: json['original_text'] as String? ?? json['original'] as String? ?? '',
      correctedText: json['corrected_text'] as String? ?? json['corrected'] as String? ?? '',
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
          ? DateTime.tryParse(json['next_review_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? 'new',
    );
  }
}

class MistakeNotebookState {
  final List<MistakeItem> items;
  final bool isLoading;
  final String? filterType; // null / 'all', 'grammar', 'vocabulary', 'pronunciation'

  const MistakeNotebookState({
    this.items = const [],
    this.isLoading = false,
    this.filterType,
  });

  List<MistakeItem> get filteredItems {
    if (filterType == null || filterType == 'all') {
      return items;
    }
    return items.where((m) => m.type.toLowerCase() == filterType!.toLowerCase()).toList();
  }

  int get totalCount => items.length;
  int get dueCount => items.where((m) => m.isDue).length;
  int get masteredCount => items.where((m) => m.status == 'mastered').length;

  MistakeNotebookState copyWith({
    List<MistakeItem>? items,
    bool? isLoading,
    String? filterType,
  }) {
    return MistakeNotebookState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      filterType: filterType ?? this.filterType,
    );
  }
}

class MistakeNotebookNotifier extends StateNotifier<MistakeNotebookState> {
  final Dio _dio;
  static const String _storageKey = 'mistake_notebook_items_v1';

  MistakeNotebookNotifier(this._dio) : super(const MistakeNotebookState()) {
    _loadMistakes();
  }

  Future<void> _loadMistakes() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString(_storageKey);

    List<MistakeItem> loaded = [];
    if (localJson != null && localJson.isNotEmpty) {
      try {
        final list = jsonDecode(localJson) as List<dynamic>;
        loaded = list.map((e) => MistakeItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // If local storage is empty, initialize with high-yield realistic mistakes so user can immediately experience the feature!
    if (loaded.isEmpty) {
      loaded = [
        MistakeItem(
          id: 'seed_1',
          originalText: 'She don\'t likes working late on weekend.',
          correctedText: 'She doesn\'t like working late on weekends.',
          explanation:
              'Chủ ngữ ngôi thứ 3 số ít "She" đi với trợ động từ phủ định "doesn\'t", và động từ theo sau giữ nguyên thể "like". "On weekends" thêm "s" để chỉ thói quen.',
          type: 'grammar',
          source: 'voice_call',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          nextReviewAt: DateTime.now(),
          status: 'new',
        ),
        MistakeItem(
          id: 'seed_2',
          originalText: 'I am agree with your opinion about modern education.',
          correctedText: 'I completely agree with your opinion on modern education.',
          explanation:
              '"Agree" vốn là động từ thường, KHÔNG dùng "am agree". Hãy nói "I agree" hoặc "I completely agree". Giới từ đi cùng: "opinion on/about".',
          type: 'vocabulary',
          source: 'writing',
          createdAt: DateTime.now().subtract(const Duration(hours: 12)),
          nextReviewAt: DateTime.now(),
          status: 'new',
        ),
        MistakeItem(
          id: 'seed_3',
          originalText: 'Although he is very busy, but he always helps his friends.',
          correctedText: 'Although he is very busy, he always helps his friends.',
          explanation:
              'Trong tiếng Anh, mệnh đề đã dùng "Although" thì TUYỆT ĐỐI không dùng "but" ở mệnh đề chính (tránh lỗi lặp liên từ "mặc dù ... nhưng").',
          type: 'grammar',
          source: 'ielts',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          nextReviewAt: DateTime.now(),
          status: 'new',
        ),
        MistakeItem(
          id: 'seed_4',
          originalText: 'He made an advice to me to improve my pronunciation.',
          correctedText: 'He gave me some valuable advice on improving my pronunciation.',
          explanation:
              '"Advice" là danh từ không đếm được (không dùng "an advice") và đi với cụm động từ "give advice", không dùng "make an advice".',
          type: 'vocabulary',
          source: 'speaking',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          nextReviewAt: DateTime.now(),
          status: 'learning',
        ),
      ];
      await prefs.setString(_storageKey, jsonEncode(loaded.map((e) => e.toJson()).toList()));
    }

    state = state.copyWith(items: loaded, isLoading: false);

    // Try fetching from backend asynchronously
    try {
      final res = await _dio.get(ApiEndpoints.aiMistakes);
      if (res.statusCode == 200 && res.data is List) {
        final serverList = (res.data as List)
            .map((e) => MistakeItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (serverList.isNotEmpty) {
          // Merge unique server items with local items
          final currentIds = loaded.map((e) => e.id).toSet();
          for (final s in serverList) {
            if (!currentIds.contains(s.id)) {
              loaded.insert(0, s);
            }
          }
          state = state.copyWith(items: loaded);
          await prefs.setString(_storageKey, jsonEncode(loaded.map((e) => e.toJson()).toList()));
        }
      }
    } catch (_) {}
  }

  void setFilter(String? type) {
    state = state.copyWith(filterType: type);
  }

  Future<void> addMistake({
    required String originalText,
    required String correctedText,
    required String explanation,
    String type = 'grammar',
    String source = 'practice',
  }) async {
    final cleanOriginal = originalText.trim();
    if (cleanOriginal.isEmpty) return;

    // Check duplicate
    if (state.items.any((m) => m.originalText.trim().toLowerCase() == cleanOriginal.toLowerCase())) {
      return;
    }

    final newItem = MistakeItem(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      originalText: cleanOriginal,
      correctedText: correctedText.trim(),
      explanation: explanation.trim(),
      type: type,
      source: source,
      createdAt: DateTime.now(),
      nextReviewAt: DateTime.now(),
      status: 'new',
    );

    final updated = [newItem, ...state.items];
    state = state.copyWith(items: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(updated.map((e) => e.toJson()).toList()));

    // Sync to backend
    try {
      await _dio.post(
        ApiEndpoints.aiMistakes,
        data: [
          {
            'original_text': newItem.originalText,
            'corrected_text': newItem.correctedText,
            'explanation': newItem.explanation,
            'type': newItem.type,
            'source': newItem.source,
          }
        ],
      );
    } catch (_) {}
  }

  Future<int> addBatchMistakes(List<Map<String, dynamic>> items, {String source = 'speaking'}) async {
    int count = 0;
    for (final raw in items) {
      final orig = raw['original'] ?? raw['original_text'] ?? raw['error'] ?? '';
      final corr = raw['corrected'] ?? raw['corrected_text'] ?? raw['correction'] ?? '';
      final expl = raw['explanation'] ?? raw['rule'] ?? 'Lỗi cần lưu ý';
      final type = raw['type'] ?? 'grammar';

      if (orig.toString().trim().isNotEmpty) {
        await addMistake(
          originalText: orig.toString(),
          correctedText: corr.toString(),
          explanation: expl.toString(),
          type: type.toString(),
          source: source,
        );
        count++;
      }
    }
    return count;
  }

  /// SM-2 Spaced Repetition calculation
  Future<void> reviewMistake(String id, int rating) async {
    final index = state.items.indexWhere((m) => m.id == id);
    if (index == -1) return;

    final item = state.items[index];
    int rep = item.repetitionCount;
    double ef = item.easeFactor;
    int interval = item.intervalDays;

    if (rating >= 3) {
      if (rep == 0) {
        interval = 1;
      } else if (rep == 1) {
        interval = 3;
      } else if (rep == 2) {
        interval = 7;
      } else {
        interval = (interval * ef).round();
      }
      rep++;
    } else {
      rep = 0;
      interval = 1;
    }

    ef = ef + (0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02));
    if (ef < 1.3) ef = 1.3;

    final nextReview = DateTime.now().add(Duration(days: interval));
    final status = rep >= 4 ? 'mastered' : (rep > 0 ? 'learning' : 'new');

    final updatedItem = item.copyWith(
      repetitionCount: rep,
      intervalDays: interval,
      easeFactor: ef,
      nextReviewAt: nextReview,
      status: status,
    );

    final updatedList = List<MistakeItem>.from(state.items);
    updatedList[index] = updatedItem;
    state = state.copyWith(items: updatedList);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(updatedList.map((e) => e.toJson()).toList()));

    // Sync to backend
    try {
      await _dio.post(
        ApiEndpoints.aiMistakeReview(id),
        data: {'rating': rating},
      );
    } catch (_) {}
  }

  Future<void> deleteMistake(String id) async {
    final updatedList = state.items.where((m) => m.id != id).toList();
    state = state.copyWith(items: updatedList);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(updatedList.map((e) => e.toJson()).toList()));

    try {
      await _dio.delete(ApiEndpoints.aiMistakeDelete(id));
    } catch (_) {}
  }
}

final mistakeNotebookProvider =
    StateNotifierProvider<MistakeNotebookNotifier, MistakeNotebookState>((ref) {
  final dio = ref.watch(dioProvider);
  return MistakeNotebookNotifier(dio);
});
