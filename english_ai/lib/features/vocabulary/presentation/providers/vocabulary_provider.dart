import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/sm2.dart';
import '../../../../core/utils/uuid.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/vocabulary_models.dart';
import '../../data/vocabulary_data.dart';
import '../../data/vocabulary_progress_store.dart';

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

// ── Vocabulary bank summary ──
final vocabularyStatsProvider =
    FutureProvider<VocabularyStatsModel>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio
        .get(ApiEndpoints.vocabularyStats)
        .timeout(const Duration(seconds: 4));
    return VocabularyStatsModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  } catch (_) {
    final total = buildStaticWords().length;
    return VocabularyStatsModel(totalWords: total, newWords: total);
  }
});

// ── Words for a specific topic ──
// Falls back to the generated catalog, keyed by UUID and slug. This keeps old
// offline decks usable while the API is unavailable.
final topicWordsProvider =
    FutureProvider.family<List<VocabularyWordModel>, String>(
        (ref, topicId) async {
  final fallback = buildTopicWords(topicId);
  if (!isUuid(topicId)) return fallback;
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio
        .get(ApiEndpoints.vocabularyTopicWords(topicId))
        .timeout(const Duration(seconds: 4));
    final words = (response.data as List<dynamic>)
        .map((e) => VocabularyWordModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return words.isEmpty ? fallback : words;
  } catch (_) {
    return fallback;
  }
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

  DueReviewItemModel? get currentCard =>
      currentIndex < cards.length ? cards[currentIndex] : null;
}

final flashcardSessionProvider =
    StateNotifierProvider<FlashcardSessionNotifier, FlashcardSessionState>(
        (ref) {
  final userId = ref.watch(authStateProvider).valueOrNull?.id ?? 'guest';
  return FlashcardSessionNotifier(
    ref.watch(dioProvider),
    userId: userId,
  );
});

class FlashcardSessionNotifier extends StateNotifier<FlashcardSessionState> {
  final dynamic _dio;
  final VocabularyProgressStore _store;

  // Mỗi lần nạp/bắt đầu phiên mới sẽ tăng số này. Kết quả của request cũ
  // (đến muộn) sẽ bị bỏ qua để không ghi đè phiên hiện tại.
  int _requestId = 0;
  bool _isSavingRating = false;

  FlashcardSessionNotifier(this._dio, {String userId = 'guest'})
      : _store = VocabularyProgressStore(userId: userId),
        super(const FlashcardSessionState()) {
    loadDueWords();
  }

  Future<void> loadDueWords() async {
    final requestId = ++_requestId;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio
          .get(ApiEndpoints.vocabularyDue)
          .timeout(const Duration(seconds: 4));
      if (!mounted || requestId != _requestId) return;

      final list = (response.data as List<dynamic>)
          .map((e) => DueReviewItemModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // An empty 200 means "nothing is due", not "fall back to random cards".
      // Otherwise the same words would be shown again every session.
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        cards: list,
        currentIndex: 0,
        isFlipped: false,
        reviewedCount: 0,
        currentTopicTitle: 'Ôn tập ngắt quãng (SM-2)',
      );
      return;
    } catch (_) {
      // API error - use the local deck below.
    }

    if (!mounted || requestId != _requestId) return;

    final localProgress = await _store.load();
    if (!mounted || requestId != _requestId) return;

    final dueWords = <VocabularyWordModel>[];
    for (final word in buildStaticWords()) {
      final progress = localProgress[word.id];
      if (progress == null || progress.isDue) {
        dueWords.add(word);
      }
      if (dueWords.length >= 15) break;
    }

    final fallbackCards = dueWords.map((w) {
      final progress = localProgress[w.id];
      return DueReviewItemModel(
        word: w,
        intervalDays: progress?.intervalDays ?? 0,
        repetitionCount: progress?.repetitionCount ?? 0,
        easeFactor: progress?.easeFactor ?? 2.5,
        status: progress?.status ?? 'new',
      );
    }).toList();

    state = state.copyWith(
      isLoading: false,
      errorMessage: null,
      cards: fallbackCards,
      currentIndex: 0,
      isFlipped: false,
      reviewedCount: 0,
      currentTopicTitle: fallbackCards.isEmpty
          ? 'Ôn tập ngắt quãng (SM-2)'
          : 'Ôn tập ngoại tuyến (SM-2)',
    );
  }

  /// Starts a specific topic deck using words loaded from the API (or the
  /// static fallback supplied by the caller).
  Future<void> startWordsSession(
    List<VocabularyWordModel> words,
    String topicTitle,
  ) async {
    _requestId++; // huỷ mọi request loadDueWords() đang chạy dở
    final localProgress = await _store.load();
    if (!mounted) return;

    final cards = words.map((w) {
      final progress = localProgress[w.id];
      return DueReviewItemModel(
        word: w,
        intervalDays: progress?.intervalDays ?? 0,
        repetitionCount: progress?.repetitionCount ?? 0,
        easeFactor: progress?.easeFactor ?? 2.5,
        status: progress?.status ?? 'new',
      );
    }).toList();

    state = state.copyWith(
      isLoading: false,
      errorMessage: null,
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
    if (_isSavingRating) return;
    if (state.currentIndex >= state.cards.length) return;

    _isSavingRating = true;
    try {
      final currentCard = state.cards[state.currentIndex];
      final sm2 = calculateSm2(
        repetitionCount: currentCard.repetitionCount,
        easeFactor: currentCard.easeFactor,
        intervalDays: currentCard.intervalDays,
        quality: quality,
      );

      // Advance immediately so a double tap cannot rate the same card twice.
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        isFlipped: false,
        reviewedCount: state.reviewedCount + 1,
      );

      // Persist the fallback/offline schedule. This is also a safety net if
      // the network drops mid-session.
      await _store.save(
        currentCard.word.id,
        VocabularyProgress(
          repetitionCount: sm2.repetitionCount,
          easeFactor: sm2.easeFactor,
          intervalDays: sm2.intervalDays,
          nextReviewAt: sm2.nextReviewAt,
          status: sm2.status,
        ),
      );

      if (!mounted) return;

      // Static fallback words (`s1`, `dc_1`, ...) are not UUIDs and cannot be
      // reviewed on the server, so only sync real backend ids.
      if (!isUuid(currentCard.word.id)) return;

      try {
        final response = await _dio.post(
          ApiEndpoints.vocabularyReviewWord(currentCard.word.id),
          data: {'quality': quality},
        );
        final data = response.data;
        if (data is Map && mounted) {
          final canonical = VocabularyProgress(
            repetitionCount: (data['repetition_count'] as num?)?.toInt() ??
                sm2.repetitionCount,
            easeFactor:
                (data['ease_factor'] as num?)?.toDouble() ?? sm2.easeFactor,
            intervalDays:
                (data['interval_days'] as num?)?.toInt() ?? sm2.intervalDays,
            nextReviewAt:
                DateTime.tryParse(data['next_review_at']?.toString() ?? '') ??
                    sm2.nextReviewAt,
            status: data['status'] as String? ?? sm2.status,
          );
          await _store.save(currentCard.word.id, canonical);
        }
      } catch (_) {
        // Offline: the local schedule above is already saved.
      }
    } finally {
      _isSavingRating = false;
    }
  }
}
