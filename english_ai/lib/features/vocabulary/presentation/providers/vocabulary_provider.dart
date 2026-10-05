import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/vocabulary_models.dart';

// ── Topics Provider ──
final vocabularyTopicsProvider =
    FutureProvider<List<VocabularyTopicModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.vocabularyTopics);
  return (response.data as List<dynamic>)
      .map((e) => VocabularyTopicModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Due Words / Flashcard Session Provider ──
class FlashcardSessionState {
  final bool isLoading;
  final String? errorMessage;
  final List<DueReviewItemModel> cards;
  final int currentIndex;
  final bool isFlipped;
  final int reviewedCount;

  const FlashcardSessionState({
    this.isLoading = false,
    this.errorMessage,
    this.cards = const [],
    this.currentIndex = 0,
    this.isFlipped = false,
    this.reviewedCount = 0,
  });

  FlashcardSessionState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<DueReviewItemModel>? cards,
    int? currentIndex,
    bool? isFlipped,
    int? reviewedCount,
  }) {
    return FlashcardSessionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      cards: cards ?? this.cards,
      currentIndex: currentIndex ?? this.currentIndex,
      isFlipped: isFlipped ?? this.isFlipped,
      reviewedCount: reviewedCount ?? this.reviewedCount,
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

      state = state.copyWith(
        isLoading: false,
        cards: list,
        currentIndex: 0,
        isFlipped: false,
        reviewedCount: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải phiên ôn tập từ vựng.',
      );
    }
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
    } catch (e) {
      // Background retry or logging
    }
  }
}
