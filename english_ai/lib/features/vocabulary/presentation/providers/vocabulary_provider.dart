import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/vocabulary_models.dart';
import '../../data/vocabulary_data.dart';
import 'vocabulary_list_provider.dart';

// ── Topics Provider (with robust fallback) ──
final vocabularyTopicsProvider =
    FutureProvider<List<VocabularyTopicModel>>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio
        .get(ApiEndpoints.vocabularyTopics)
        .timeout(const Duration(seconds: 4));
    final list = (response.data as List<dynamic>)
        .map((e) => VocabularyTopicModel.fromJson(e as Map<String, dynamic>))
        .toList();
    if (list.isNotEmpty) return list;
  } catch (_) {
    // API failed or offline - use rich static fallback
  }
  return buildStaticTopics();
});

// ── Words for specific topic ──
final topicWordsProvider =
    FutureProvider.family<List<VocabularyWordModel>, String>((ref, topicId) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio
        .get('${ApiEndpoints.vocabularyTopics}/$topicId/words')
        .timeout(const Duration(seconds: 4));
    final list = (response.data as List<dynamic>)
        .map((e) => VocabularyWordModel.fromJson(e as Map<String, dynamic>))
        .toList();
    if (list.isNotEmpty) return list;
  } catch (_) {
    // Fallback
  }
  return buildTopicWords(topicId);
});

// ── Due Words / Flashcard Session Provider ──
class FlashcardSessionState {
  final bool isLoading;
  final String? errorMessage;
  final List<DueReviewItemModel> cards;
  final int currentIndex;
  final bool isFlipped;
  final int reviewedCount;
  final String currentTopicTitle;

  const FlashcardSessionState({
    this.isLoading = false,
    this.errorMessage,
    this.cards = const [],
    this.currentIndex = 0,
    this.isFlipped = false,
    this.reviewedCount = 0,
    this.currentTopicTitle = 'Ôn tập ngắt quãng (SM-2)',
  });

  FlashcardSessionState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<DueReviewItemModel>? cards,
    int? currentIndex,
    bool? isFlipped,
    int? reviewedCount,
    String? currentTopicTitle,
  }) {
    return FlashcardSessionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      cards: cards ?? this.cards,
      currentIndex: currentIndex ?? this.currentIndex,
      isFlipped: isFlipped ?? this.isFlipped,
      reviewedCount: reviewedCount ?? this.reviewedCount,
      currentTopicTitle: currentTopicTitle ?? this.currentTopicTitle,
    );
  }

  bool get isSessionFinished =>
      cards.isNotEmpty && currentIndex >= cards.length;
}

final flashcardSessionProvider =
    StateNotifierProvider<FlashcardSessionNotifier, FlashcardSessionState>(
        (ref) {
  return FlashcardSessionNotifier(ref.watch(dioProvider));
});

class FlashcardSessionNotifier extends StateNotifier<FlashcardSessionState> {
  final dynamic _dio;

  FlashcardSessionNotifier(this._dio) : super(const FlashcardSessionState()) {
    loadDueWords();
  }

  Future<void> loadDueWords() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.get(ApiEndpoints.vocabularyDue);
      final list = (response.data as List<dynamic>)
          .map((e) => DueReviewItemModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          cards: list,
          currentIndex: 0,
          isFlipped: false,
          reviewedCount: 0,
          currentTopicTitle: 'Ôn tập ngắt quãng (SM-2)',
        );
        return;
      }
    } catch (_) {
      // API error - fallback to static words below
    }

    // Fallback: provide 15 rich flashcards from standard vocabulary pool
    final fallbackCards = buildStaticWords().take(15).map((w) => DueReviewItemModel(
      word: w,
      intervalDays: 1,
      status: 'learning',
    )).toList();

    state = state.copyWith(
      isLoading: false,
      cards: fallbackCards,
      currentIndex: 0,
      isFlipped: false,
      reviewedCount: 0,
      currentTopicTitle: 'Ôn tập ngắt quãng (SM-2)',
    );
  }

  void startTopicSession(String topicId, String topicTitle) {
    final words = buildTopicWords(topicId);
    final cards = words.map((w) => DueReviewItemModel(
      word: w,
      intervalDays: 1,
      status: 'learning',
    )).toList();

    state = state.copyWith(
      isLoading: false,
      cards: cards,
      currentIndex: 0,
      isFlipped: false,
      reviewedCount: 0,
      currentTopicTitle: topicTitle,
    );
  }

  void flipCard() {
    state = state.copyWith(isFlipped: !state.isFlipped);
  }

  Future<void> submitRating(int quality) async {
    if (state.currentIndex >= state.cards.length) return;

    final currentCard = state.cards[state.currentIndex];

    // Optimistically advance card
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      isFlipped: false,
      reviewedCount: state.reviewedCount + 1,
    );

    // Call API in background
    try {
      await _dio.post(
        ApiEndpoints.vocabularyReviewWord(currentCard.word.id),
        data: {'quality': quality},
      );
    } catch (_) {
      // Background retry or logging
    }
  }
}
