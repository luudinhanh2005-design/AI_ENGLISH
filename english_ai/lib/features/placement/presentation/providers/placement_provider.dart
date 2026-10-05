import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/placement_models.dart';

class PlacementState {
  final bool isLoading;
  final String? errorMessage;
  final List<PlacementQuestionModel> questions;
  final int currentQuestionIndex;
  final Map<String, int> selectedAnswers; // questionId -> optionIndex
  final PlacementResultModel? result;

  const PlacementState({
    this.isLoading = false,
    this.errorMessage,
    this.questions = const [],
    this.currentQuestionIndex = 0,
    this.selectedAnswers = const {},
    this.result,
  });

  PlacementState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<PlacementQuestionModel>? questions,
    int? currentQuestionIndex,
    Map<String, int>? selectedAnswers,
    PlacementResultModel? result,
  }) {
    return PlacementState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      result: result ?? this.result,
    );
  }

  bool get isCompleted =>
      questions.isNotEmpty && selectedAnswers.length == questions.length;
}

final placementProvider =
    StateNotifierProvider<PlacementNotifier, PlacementState>((ref) {
  return PlacementNotifier(ref.watch(dioProvider));
});

class PlacementNotifier extends StateNotifier<PlacementState> {
  final dynamic _dio;

  PlacementNotifier(this._dio) : super(const PlacementState()) {
    loadQuestions();
  }

  Future<void> loadQuestions() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.get(ApiEndpoints.placementQuestions);
      final list = (response.data as List<dynamic>)
          .map((item) =>
              PlacementQuestionModel.fromJson(item as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        isLoading: false,
        questions: list,
        currentQuestionIndex: 0,
        selectedAnswers: {},
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải câu hỏi đánh giá. Vui lòng thử lại.',
      );
    }
  }

  void selectAnswer(String questionId, int optionIndex) {
    final updated = Map<String, int>.from(state.selectedAnswers);
    updated[questionId] = optionIndex;
    state = state.copyWith(selectedAnswers: updated);
  }

  void nextQuestion() {
    if (state.currentQuestionIndex < state.questions.length - 1) {
      state = state.copyWith(
          currentQuestionIndex: state.currentQuestionIndex + 1);
    }
  }

  void previousQuestion() {
    if (state.currentQuestionIndex > 0) {
      state = state.copyWith(
          currentQuestionIndex: state.currentQuestionIndex - 1);
    }
  }

  Future<bool> submitTest() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final answersPayload = state.selectedAnswers.entries.map((e) {
        return {
          'question_id': e.key,
          'selected_option': e.value,
        };
      }).toList();

      final response = await _dio.post(
        ApiEndpoints.placementSubmit,
        data: {'answers': answersPayload},
      );

      final result = PlacementResultModel.fromJson(
          response.data as Map<String, dynamic>);

      state = state.copyWith(
        isLoading: false,
        result: result,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gửi bài kiểm tra thất bại. Vui lòng thử lại.',
      );
      return false;
    }
  }
}
