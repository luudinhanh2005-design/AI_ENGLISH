import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../learn/data/grammar_data.dart';
import '../../../learn/data/grammar_progress_store.dart';
import '../../../learn/data/grammar_repository.dart';
import '../../../learn/data/grammar_sync_service.dart';

enum PracticeQuizPhase { loading, ready, submitting, finished, error }

typedef PracticeLessonLoader = Future<List<GrammarLesson>> Function();
typedef PracticeProgressLoader = Future<Map<String, GrammarProgress>>
    Function();
typedef PracticeAttemptSubmitter = Future<GrammarAttemptSyncResult> Function({
  required GrammarLesson lesson,
  required Map<int, int> answers,
});

class PracticeQuizState {
  final PracticeQuizPhase phase;
  final List<GrammarLesson> lessons;
  final GrammarLesson? lesson;
  final int questionIndex;
  final int? selectedOption;
  final bool revealed;
  final Map<int, int> answers;
  final int combo;
  final GrammarAttemptSyncResult? outcome;
  final String? errorMessage;

  const PracticeQuizState({
    this.phase = PracticeQuizPhase.loading,
    this.lessons = const [],
    this.lesson,
    this.questionIndex = 0,
    this.selectedOption,
    this.revealed = false,
    this.answers = const {},
    this.combo = 0,
    this.outcome,
    this.errorMessage,
  });

  GrammarQuizItem? get question {
    final current = lesson;
    if (current == null || current.quiz.isEmpty) return null;
    if (questionIndex < 0 || questionIndex >= current.quiz.length) return null;
    return current.quiz[questionIndex];
  }

  int get totalQuestions => lesson?.quiz.length ?? 0;

  bool get isLastQuestion =>
      totalQuestions > 0 && questionIndex >= totalQuestions - 1;

  bool get isCorrect =>
      question != null &&
      selectedOption != null &&
      selectedOption == question!.correctIndex;

  int get correctCount {
    final current = lesson;
    if (current == null) return 0;
    var count = 0;
    for (final entry in answers.entries) {
      if (entry.key < 0 || entry.key >= current.quiz.length) continue;
      if (current.quiz[entry.key].correctIndex == entry.value) {
        count++;
      }
    }
    return count;
  }

  int get percent {
    if (totalQuestions == 0) return 0;
    return (correctCount / totalQuestions * 100).round();
  }

  PracticeQuizState copyWith({
    PracticeQuizPhase? phase,
    List<GrammarLesson>? lessons,
    GrammarLesson? lesson,
    int? questionIndex,
    int? selectedOption,
    bool? revealed,
    Map<int, int>? answers,
    int? combo,
    GrammarAttemptSyncResult? outcome,
    String? errorMessage,
    bool clearSelected = false,
    bool clearOutcome = false,
    bool clearError = false,
  }) {
    return PracticeQuizState(
      phase: phase ?? this.phase,
      lessons: lessons ?? this.lessons,
      lesson: lesson ?? this.lesson,
      questionIndex: questionIndex ?? this.questionIndex,
      selectedOption:
          clearSelected ? null : (selectedOption ?? this.selectedOption),
      revealed: revealed ?? this.revealed,
      answers: answers ?? this.answers,
      combo: combo ?? this.combo,
      outcome: clearOutcome ? null : (outcome ?? this.outcome),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final practiceQuizProvider =
    StateNotifierProvider<PracticeQuizNotifier, PracticeQuizState>((ref) {
  return PracticeQuizNotifier();
});

class PracticeQuizNotifier extends StateNotifier<PracticeQuizState> {
  final PracticeLessonLoader _loadLessons;
  final PracticeProgressLoader _loadProgress;
  final PracticeAttemptSubmitter _submitAttempt;
  final Random _random;

  String? _userLevel;
  bool _isLoading = false;

  PracticeQuizNotifier({
    PracticeLessonLoader? loadLessons,
    PracticeProgressLoader? loadProgress,
    PracticeAttemptSubmitter? submitAttempt,
    Random? random,
  })  : _loadLessons = loadLessons ?? GrammarRepository.loadLessonsWithSync,
        _loadProgress = loadProgress ?? GrammarProgressStore.load,
        _submitAttempt = submitAttempt ?? _defaultSubmitAttempt,
        _random = random ?? Random(),
        super(const PracticeQuizState());

  static Future<GrammarAttemptSyncResult> _defaultSubmitAttempt({
    required GrammarLesson lesson,
    required Map<int, int> answers,
  }) {
    return GrammarSyncService.submitAttemptDetailed(
      lesson: lesson,
      answers: answers,
    );
  }

  Future<void> load({String? userLevel}) async {
    if (_isLoading) return;
    _isLoading = true;
    _userLevel = userLevel;
    state = PracticeQuizState(
      phase: PracticeQuizPhase.loading,
      lessons: state.lessons,
    );

    try {
      final lessons = await _loadLessons();
      if (lessons.isEmpty) {
        throw StateError('No grammar lessons available');
      }
      final progress = await _loadProgress();
      final selected = _pickLesson(
        lessons: lessons,
        progress: progress,
        level: userLevel,
      );
      if (selected == null) {
        throw StateError('No practice lesson available');
      }
      state = _startLesson(selected, lessons);
    } catch (_) {
      state = PracticeQuizState(
        phase: PracticeQuizPhase.error,
        lessons: state.lessons,
        errorMessage:
            'Không tải được bài luyện. Kiểm tra kết nối rồi thử lại nhé.',
      );
    } finally {
      _isLoading = false;
    }
  }

  void retry() {
    load(userLevel: _userLevel);
  }

  /// Returns whether the answer was accepted. This lets the UI record local
  /// accuracy exactly once, even if a fast double-tap arrives before rebuild.
  bool selectAnswer(int option) {
    if (state.phase != PracticeQuizPhase.ready || state.revealed) return false;
    final lesson = state.lesson;
    final question = state.question;
    if (lesson == null || question == null) return false;
    if (option < 0 || option >= question.options.length) return false;

    final correct = option == question.correctIndex;
    final answers = Map<int, int>.from(state.answers)
      ..[state.questionIndex] = option;

    state = state.copyWith(
      selectedOption: option,
      revealed: true,
      answers: answers,
      combo: correct ? state.combo + 1 : 0,
    );
    return true;
  }

  Future<void> next() async {
    if (state.phase != PracticeQuizPhase.ready || !state.revealed) return;

    if (!state.isLastQuestion) {
      state = state.copyWith(
        questionIndex: state.questionIndex + 1,
        clearSelected: true,
        revealed: false,
        clearError: true,
      );
      return;
    }

    final lesson = state.lesson;
    if (lesson == null) return;

    state = state.copyWith(
      phase: PracticeQuizPhase.submitting,
      clearError: true,
      clearOutcome: true,
    );
    try {
      final outcome = await _submitAttempt(
        lesson: lesson,
        answers: Map<int, int>.from(state.answers),
      );
      state = state.copyWith(
        phase: PracticeQuizPhase.finished,
        outcome: outcome,
      );
    } catch (_) {
      state = state.copyWith(
        phase: PracticeQuizPhase.finished,
        clearOutcome: true,
        errorMessage:
            'Chưa gửi được kết quả. Bài làm vẫn được giữ trên thiết bị.',
      );
    }
  }

  void restart() {
    final lesson = state.lesson;
    if (lesson == null) return;
    state = _startLesson(lesson, state.lessons);
  }

  Future<void> nextLesson() async {
    if (state.lessons.isEmpty) {
      await load(userLevel: _userLevel);
      return;
    }

    final currentId = state.lesson?.id;
    Map<String, GrammarProgress> progress;
    try {
      progress = await _loadProgress();
    } catch (_) {
      // A failed progress read must not trap the learner on the result screen.
      progress = const {};
    }
    final selected = _pickLesson(
      lessons: state.lessons,
      progress: progress,
      level: _userLevel,
      excludeId: currentId,
    );
    if (selected == null) {
      state = state.copyWith(
        errorMessage: 'Chưa có bài khác để luyện. Thử lại sau nhé!',
      );
      return;
    }
    state = _startLesson(selected, state.lessons);
  }

  PracticeQuizState _startLesson(
    GrammarLesson lesson,
    List<GrammarLesson> lessons,
  ) {
    return PracticeQuizState(
      phase: PracticeQuizPhase.ready,
      lessons: lessons,
      lesson: lesson,
      questionIndex: 0,
      selectedOption: null,
      revealed: false,
      answers: const {},
      combo: 0,
      outcome: null,
      errorMessage: null,
    );
  }

  GrammarLesson? _pickLesson({
    required List<GrammarLesson> lessons,
    required Map<String, GrammarProgress> progress,
    required String? level,
    String? excludeId,
  }) {
    final nonBeta = lessons
        .where((lesson) => lesson.quiz.isNotEmpty && !lesson.isBeta)
        .toList();
    final pool = nonBeta.isNotEmpty
        ? nonBeta
        : lessons.where((lesson) => lesson.quiz.isNotEmpty).toList();
    if (pool.isEmpty) return null;

    final priorities = _levelPriority(level);
    final byLevel = <String, List<GrammarLesson>>{};
    for (final candidateLevel in priorities) {
      final atLevel = pool
          .where(
            (lesson) =>
                lesson.level == candidateLevel &&
                (excludeId == null || lesson.id != excludeId),
          )
          .toList();
      if (atLevel.isEmpty) continue;
      byLevel[candidateLevel] = atLevel;

      final incomplete = atLevel
          .where((lesson) => !(progress[lesson.id]?.completed ?? false))
          .toList();
      if (incomplete.isNotEmpty) {
        return incomplete[_random.nextInt(incomplete.length)];
      }
    }

    // All lessons at the closest levels are completed; repeat one of those
    // before jumping to a less relevant level.
    for (final candidateLevel in priorities) {
      final atLevel = byLevel[candidateLevel];
      if (atLevel != null && atLevel.isNotEmpty) {
        return atLevel[_random.nextInt(atLevel.length)];
      }
    }

    final fresh = pool
        .where(
          (lesson) =>
              (excludeId == null || lesson.id != excludeId) &&
              !(progress[lesson.id]?.completed ?? false),
        )
        .toList();
    if (fresh.isNotEmpty) {
      return fresh[_random.nextInt(fresh.length)];
    }

    final others = pool
        .where((lesson) => excludeId == null || lesson.id != excludeId)
        .toList();
    if (others.isNotEmpty) {
      return others[_random.nextInt(others.length)];
    }

    return pool[_random.nextInt(pool.length)];
  }

  List<String> _levelPriority(String? level) {
    switch (level?.toUpperCase()) {
      case 'A1':
        return const ['A1', 'A2'];
      case 'A2':
        return const ['A2', 'A1', 'B1'];
      case 'B1':
        return const ['B1', 'A2', 'B2'];
      case 'B2':
        return const ['B2', 'B1', 'A1', 'A2'];
      case 'C1':
      case 'C2':
        // C1/C2 are beta until human review, so Practice uses the highest
        // reviewed level instead of silently serving beta content.
        return const ['B2', 'B1'];
      default:
        return const ['B1', 'A2', 'B2'];
    }
  }
}
