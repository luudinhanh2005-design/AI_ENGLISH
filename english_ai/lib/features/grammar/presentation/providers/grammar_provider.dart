import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/grammar_models.dart';

class GrammarState {
  final List<GrammarLessonSummaryModel> lessons;
  final GrammarLessonDetailModel? currentLesson;
  final String levelFilter; // 'All', 'A1-A2', 'B1', 'B2'
  final Map<int, int> selectedAnswers; // questionIndex -> optionIndex
  final GrammarResultModel? quizResult;
  final bool isLoading;
  final bool isLoadingDetail;
  final bool isSubmittingQuiz;
  final String? errorMessage;

  const GrammarState({
    this.lessons = const [],
    this.currentLesson,
    this.levelFilter = 'All',
    this.selectedAnswers = const {},
    this.quizResult,
    this.isLoading = false,
    this.isLoadingDetail = false,
    this.isSubmittingQuiz = false,
    this.errorMessage,
  });

  List<GrammarLessonSummaryModel> get filteredLessons {
    if (levelFilter == 'All') return lessons;
    return lessons.where((l) => l.level.contains(levelFilter)).toList();
  }

  GrammarState copyWith({
    List<GrammarLessonSummaryModel>? lessons,
    GrammarLessonDetailModel? currentLesson,
    String? levelFilter,
    Map<int, int>? selectedAnswers,
    GrammarResultModel? quizResult,
    bool? isLoading,
    bool? isLoadingDetail,
    bool? isSubmittingQuiz,
    String? errorMessage,
    bool clearDetail = false,
    bool clearQuizResult = false,
    bool clearError = false,
  }) {
    return GrammarState(
      lessons: lessons ?? this.lessons,
      currentLesson:
          clearDetail ? null : (currentLesson ?? this.currentLesson),
      levelFilter: levelFilter ?? this.levelFilter,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      quizResult:
          clearQuizResult ? null : (quizResult ?? this.quizResult),
      isLoading: isLoading ?? this.isLoading,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      isSubmittingQuiz: isSubmittingQuiz ?? this.isSubmittingQuiz,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final grammarProvider =
    StateNotifierProvider<GrammarNotifier, GrammarState>((ref) {
  return GrammarNotifier(ref.watch(dioProvider));
});

class GrammarNotifier extends StateNotifier<GrammarState> {
  final dynamic _dio;

  GrammarNotifier(this._dio) : super(const GrammarState()) {
    loadLessons();
  }

  Future<void> loadLessons() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _dio.get('/grammar/lessons');
      final rawList = res.data as List<dynamic>? ?? [];
      final lessons = rawList
          .map((item) =>
              GrammarLessonSummaryModel.fromJson(item as Map<String, dynamic>))
          .toList();
      state = state.copyWith(lessons: lessons, isLoading: false);
    } catch (e) {
      // Fallback sample lessons if offline
      state = state.copyWith(
        lessons: _fallbackLessons(),
        isLoading: false,
      );
    }
  }

  void setLevelFilter(String filter) {
    state = state.copyWith(levelFilter: filter);
  }

  Future<void> loadLessonDetail(String lessonId) async {
    state = state.copyWith(
      isLoadingDetail: true,
      clearDetail: true,
      selectedAnswers: {},
      clearQuizResult: true,
      clearError: true,
    );

    try {
      final res = await _dio.get('/grammar/lessons/$lessonId');
      final detail =
          GrammarLessonDetailModel.fromJson(res.data as Map<String, dynamic>);
      state = state.copyWith(
        currentLesson: detail,
        isLoadingDetail: false,
      );
    } catch (e) {
      // Fallback detail
      final fallback = _fallbackDetail(lessonId);
      state = state.copyWith(
        currentLesson: fallback,
        isLoadingDetail: false,
      );
    }
  }

  void selectAnswer(int questionIndex, int optionIndex) {
    final updated = Map<int, int>.from(state.selectedAnswers);
    updated[questionIndex] = optionIndex;
    state = state.copyWith(selectedAnswers: updated);
  }

  Future<bool> submitQuiz(String lessonId) async {
    final detail = state.currentLesson;
    if (detail == null) return false;

    state = state.copyWith(isSubmittingQuiz: true, clearError: true);

    final answers = state.selectedAnswers.entries
        .map((e) => {
              'question_index': e.key,
              'selected_option': e.value,
            })
        .toList();

    try {
      final res = await _dio.post(
        '/grammar/lessons/$lessonId/submit',
        data: {'answers': answers},
      );
      final result =
          GrammarResultModel.fromJson(res.data as Map<String, dynamic>);

      state = state.copyWith(
        quizResult: result,
        isSubmittingQuiz: false,
      );

      // Refresh lessons to update completion icon
      loadLessons();
      return true;
    } catch (e) {
      // Calculate local fallback score
      int correct = 0;
      for (int i = 0; i < detail.practiceQuestions.length; i++) {
        if (state.selectedAnswers[i] ==
            detail.practiceQuestions[i].correctIndex) {
          correct++;
        }
      }
      final total = detail.practiceQuestions.length;
      final score = total > 0 ? (correct / total) * 100.0 : 0.0;
      final localResult = GrammarResultModel(
        score: score,
        total: total,
        correct: correct,
        isPassed: score >= 60.0,
        xpEarned: (correct * 5),
      );

      state = state.copyWith(
        quizResult: localResult,
        isSubmittingQuiz: false,
      );
      return true;
    }
  }

  void resetQuiz() {
    state = state.copyWith(
      selectedAnswers: {},
      clearQuizResult: true,
      clearError: true,
    );
  }

  List<GrammarLessonSummaryModel> _fallbackLessons() {
    return [
      const GrammarLessonSummaryModel(
        id: 'g1',
        slug: 'present-simple-continuous',
        title: 'Present Simple vs. Present Continuous',
        level: 'A1-A2',
        summary:
            'Phân biệt thì Hiện tại đơn (thói quen, chân lý) và Hiện tại tiếp diễn (đang diễn ra).',
        orderIndex: 1,
        isCompleted: true,
        score: 90.0,
      ),
      const GrammarLessonSummaryModel(
        id: 'g2',
        slug: 'present-perfect',
        title: 'The Present Perfect Tense',
        level: 'B1',
        summary:
            'Thì Hiện tại hoàn thành (have/has + V3/ed) kết nối quá khứ với hiện tại.',
        orderIndex: 2,
        isCompleted: false,
      ),
      const GrammarLessonSummaryModel(
        id: 'g3',
        slug: 'past-simple-continuous',
        title: 'Past Simple & Past Continuous',
        level: 'A2',
        summary: 'Hành động xảy ra trong quá khứ xen vào hành động đang tiếp diễn.',
        orderIndex: 3,
        isCompleted: false,
      ),
      const GrammarLessonSummaryModel(
        id: 'g4',
        slug: 'conditional-sentences',
        title: 'Conditionals (Types 1, 2 & 3)',
        level: 'B1-B2',
        summary: 'Câu điều kiện loại 1, 2, 3 và cách sử dụng linh hoạt.',
        orderIndex: 4,
        isCompleted: false,
      ),
    ];
  }

  GrammarLessonDetailModel _fallbackDetail(String id) {
    return const GrammarLessonDetailModel(
      id: 'g2',
      slug: 'present-perfect',
      title: 'The Present Perfect Tense',
      level: 'B1',
      summary:
          'Thì Hiện tại hoàn thành (have/has + V3/ed) kết nối quá khứ với hiện tại.',
      formula: 'Khẳng định: S + have/has + V3/ed\nPhủ định: S + haven\'t/hasn\'t + V3/ed\nNghi vấn: (Wh-) + Have/Has + S + V3/ed?',
      contentMarkdown: '''
### 1. Cách sử dụng chính:
- **Hành động đã xảy ra không rõ thời gian**: I have seen that movie.
- **Hành động bắt đầu trong quá khứ và còn tiếp diễn**: She has lived here for 5 years.
- **Kinh nghiệm, trải nghiệm**: Have you ever visited London?

### 2. Dấu hiệu nhận biết:
- *already, yet, just, ever, never, since, for, recently, so far*.
''',
      examples: [
        GrammarExampleModel(
          en: 'I have already finished my project.',
          vi: 'Tôi đã hoàn thành xong dự án của mình rồi.',
        ),
        GrammarExampleModel(
          en: 'She has worked at this company since 2021.',
          vi: 'Cô ấy đã làm việc tại công ty này từ năm 2021.',
        ),
        GrammarExampleModel(
          en: 'Have you ever tried traditional Vietnamese pho?',
          vi: 'Bạn đã từng ăn phở truyền thống Việt Nam bao giờ chưa?',
        ),
      ],
      practiceQuestions: [
        GrammarQuizQuestionModel(
          question: 'She _____ in London for five years.',
          options: ['lives', 'has lived', 'living', 'lived since'],
          correctIndex: 1,
          explanationVi: 'Dấu hiệu "for five years" chỉ khoảng thời gian kéo dài đến hiện tại nên dùng Hiện tại hoàn thành (has lived).',
        ),
        GrammarQuizQuestionModel(
          question: 'Have you _____ been to Japan?',
          options: ['yet', 'already', 'ever', 'never'],
          correctIndex: 2,
          explanationVi: 'Trong câu hỏi trải nghiệm, ta dùng "ever" (đã từng bao giờ chưa).',
        ),
        GrammarQuizQuestionModel(
          question: 'I haven\'t finished my homework _____.',
          options: ['already', 'yet', 'since', 'just'],
          correctIndex: 1,
          explanationVi: '"Yet" thường đứng cuối câu phủ định hoặc nghi vấn với nghĩa "chưa".',
        ),
      ],
    );
  }
}
