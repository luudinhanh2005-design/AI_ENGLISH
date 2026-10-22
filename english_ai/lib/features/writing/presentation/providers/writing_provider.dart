import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/writing_models.dart';

class WritingState {
  final List<WritingPromptModel> prompts;
  final WritingPromptModel? selectedPrompt;
  final String topic;
  final String content;
  final int wordCount;
  final int timerSeconds;
  final bool isTimerRunning;
  final bool isEvaluating;
  final WritingEvaluationResultModel? result;
  final String? errorMessage;
  final List<WritingEvaluationResultModel> history;

  const WritingState({
    this.prompts = const [],
    this.selectedPrompt,
    this.topic = '',
    this.content = '',
    this.wordCount = 0,
    this.timerSeconds = 0,
    this.isTimerRunning = false,
    this.isEvaluating = false,
    this.result,
    this.errorMessage,
    this.history = const [],
  });

  String get formattedTimer {
    final minutes = timerSeconds ~/ 60;
    final seconds = timerSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  WritingState copyWith({
    List<WritingPromptModel>? prompts,
    WritingPromptModel? selectedPrompt,
    String? topic,
    String? content,
    int? wordCount,
    int? timerSeconds,
    bool? isTimerRunning,
    bool? isEvaluating,
    WritingEvaluationResultModel? result,
    String? errorMessage,
    List<WritingEvaluationResultModel>? history,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return WritingState(
      prompts: prompts ?? this.prompts,
      selectedPrompt: selectedPrompt ?? this.selectedPrompt,
      topic: topic ?? this.topic,
      content: content ?? this.content,
      wordCount: wordCount ?? this.wordCount,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      isEvaluating: isEvaluating ?? this.isEvaluating,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      history: history ?? this.history,
    );
  }
}

final writingProvider =
    StateNotifierProvider<WritingNotifier, WritingState>((ref) {
  return WritingNotifier(ref.watch(dioProvider));
});

class WritingNotifier extends StateNotifier<WritingState> {
  final dynamic _dio;
  Timer? _timer;

  WritingNotifier(this._dio) : super(const WritingState()) {
    _initCuratedPrompts();
  }

  void _initCuratedPrompts() {
    final list = [
      const WritingPromptModel(
        id: 'p1',
        title: 'Trí tuệ nhân tạo & Giáo dục',
        category: 'IELTS Task 2',
        promptDescription:
            'Some people believe that artificial intelligence will replace teachers in classrooms. To what extent do you agree or disagree?',
        recommendedWords: 250,
        targetBand: 'Band 7.0',
        sampleOpening: 'In recent years, the rapid advancement of artificial intelligence...',
      ),
      const WritingPromptModel(
        id: 'p2',
        title: 'Học phí đại học miễn phí',
        category: 'IELTS Task 2',
        promptDescription:
            'Should university education be free for all students, or should students pay tuition fees? Discuss both views and give your opinion.',
        recommendedWords: 250,
        targetBand: 'Band 6.5+',
        sampleOpening: 'The debate over whether higher education should be publicly funded...',
      ),
      const WritingPromptModel(
        id: 'p3',
        title: 'Email xin tăng ngân sách dự án',
        category: 'Business Email',
        promptDescription:
            'Write a professional email to your Department Director requesting a 15% budget increase for your ongoing software project.',
        recommendedWords: 150,
        targetBand: 'Professional',
        sampleOpening: 'Dear Mr. Harrison, I am writing to formally request an adjustment...',
      ),
      const WritingPromptModel(
        id: 'p4',
        title: 'Email xin lỗi khách hàng vì chậm trễ',
        category: 'Business Email',
        promptDescription:
            'Write an email to an international client apologizing for a project delay, explaining the technical reason, and offering a concrete updated delivery date.',
        recommendedWords: 140,
        targetBand: 'Professional',
        sampleOpening: 'Dear Client, Please accept our sincere apologies regarding...',
      ),
      const WritingPromptModel(
        id: 'p5',
        title: 'Làm việc từ xa (Remote Work)',
        category: 'Opinion Essay',
        promptDescription:
            'Discuss the advantages and disadvantages of working remotely compared to traditional office environments.',
        recommendedWords: 180,
        targetBand: 'Band 6.5',
        sampleOpening: 'Remote work has emerged as a prevailing trend in the modern workforce...',
      ),
    ];

    state = state.copyWith(
      prompts: list,
      selectedPrompt: list.first,
      topic: list.first.title,
    );
  }

  void selectPrompt(WritingPromptModel prompt) {
    state = state.copyWith(
      selectedPrompt: prompt,
      topic: prompt.title,
      clearError: true,
    );
  }

  void setCustomTopic(String customTopic) {
    state = state.copyWith(
      topic: customTopic,
      selectedPrompt: null,
      clearError: true,
    );
  }

  void updateContent(String text) {
    final words = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    state = state.copyWith(
      content: text,
      wordCount: words,
      clearError: true,
    );

    if (!_isTimerRunning && text.trim().isNotEmpty) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _isTimerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(timerSeconds: state.timerSeconds + 1);
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _isTimerRunning = false;
  }

  bool _isTimerRunning = false;

  Future<bool> submitForEvaluation() async {
    final text = state.content.trim();
    final topic = state.topic.trim().isNotEmpty
        ? state.topic.trim()
        : (state.selectedPrompt?.title ?? 'English Essay');

    if (text.length < 20) {
      state = state.copyWith(
        errorMessage: 'Bài viết của bạn quá ngắn (tối thiểu 20 ký tự). Hãy viết thêm nhé!',
      );
      return false;
    }

    stopTimer();
    state = state.copyWith(isEvaluating: true, clearError: true);

    try {
      final response = await _dio.post(
        '/ai/evaluate-writing',
        data: {
          'topic': topic,
          'text': text,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final result = WritingEvaluationResultModel.fromJson(
        data,
        userText: text,
        topic: topic,
      );

      final updatedHistory = List<WritingEvaluationResultModel>.from(state.history)
        ..insert(0, result);

      state = state.copyWith(
        isEvaluating: false,
        result: result,
        history: updatedHistory,
      );
      return true;
    } catch (e) {
      String message =
          'Lỗi chấm bài từ máy chủ AI. Vui lòng kiểm tra kết nối và thử lại!';
      if (e is DioException) {
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          message = 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại rồi nộp bài nhé!';
        } else if (e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionTimeout) {
          message = 'AI chấm bài quá lâu. Hãy thử lại sau ít giây.';
        } else if (e.type == DioExceptionType.connectionError) {
          message = 'Không kết nối được backend (cổng 8000). Hãy kiểm tra server đang chạy.';
        } else if (code != null) {
          message = 'Máy chủ lỗi ($code). Xem log backend để biết chi tiết.';
        }
      }
      state = state.copyWith(isEvaluating: false, errorMessage: message);
      return false;
    }
  }

  void resetForNewEssay() {
    stopTimer();
    state = state.copyWith(
      content: '',
      wordCount: 0,
      timerSeconds: 0,
      clearResult: true,
      clearError: true,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
