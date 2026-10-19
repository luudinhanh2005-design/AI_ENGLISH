class WritingPromptModel {
  final String id;
  final String title;
  final String category; // 'IELTS Task 2', 'Business Email', 'Daily Journal'
  final String promptDescription;
  final int recommendedWords;
  final String targetBand;
  final String? sampleOpening;

  const WritingPromptModel({
    required this.id,
    required this.title,
    required this.category,
    required this.promptDescription,
    this.recommendedWords = 150,
    this.targetBand = '6.5+',
    this.sampleOpening,
  });
}

class WritingGrammarFeedbackModel {
  final String original;
  final String correction;
  final String explanationVi;

  const WritingGrammarFeedbackModel({
    required this.original,
    required this.correction,
    required this.explanationVi,
  });

  factory WritingGrammarFeedbackModel.fromJson(Map<String, dynamic> json) {
    return WritingGrammarFeedbackModel(
      original: json['original'] as String? ?? '',
      correction: json['correction'] as String? ?? '',
      explanationVi: json['explanation_vi'] as String? ?? '',
    );
  }
}

class WritingVocabSuggestionModel {
  final String original;
  final String suggestion;
  final String explanationVi;
  final String context;

  const WritingVocabSuggestionModel({
    required this.original,
    required this.suggestion,
    required this.explanationVi,
    this.context = '',
  });

  factory WritingVocabSuggestionModel.fromJson(Map<String, dynamic> json) {
    return WritingVocabSuggestionModel(
      original: json['original'] as String? ?? '',
      suggestion: json['suggestion'] as String? ?? '',
      explanationVi: json['explanation_vi'] as String? ?? '',
      context: json['context'] as String? ?? '',
    );
  }
}

class WritingEvaluationResultModel {
  final double overallScore;
  final String cefrLevel;
  final double ieltsEquivalent;
  final List<WritingGrammarFeedbackModel> grammarFeedback;
  final List<WritingVocabSuggestionModel> vocabSuggestions;
  final String generalComment;
  final String revisedText;
  final String userText;
  final String topic;
  final DateTime submittedAt;

  const WritingEvaluationResultModel({
    required this.overallScore,
    required this.cefrLevel,
    required this.ieltsEquivalent,
    this.grammarFeedback = const [],
    this.vocabSuggestions = const [],
    required this.generalComment,
    required this.revisedText,
    required this.userText,
    required this.topic,
    required this.submittedAt,
  });

  factory WritingEvaluationResultModel.fromJson(
    Map<String, dynamic> json, {
    required String userText,
    required String topic,
  }) {
    final rawGrammar = json['grammar_feedback'] as List<dynamic>? ?? [];
    final rawVocab = json['vocab_suggestions'] as List<dynamic>? ?? [];

    return WritingEvaluationResultModel(
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      cefrLevel: json['cefr_level'] as String? ?? 'B1',
      ieltsEquivalent: (json['ielts_equivalent'] as num?)?.toDouble() ?? 5.5,
      grammarFeedback: rawGrammar
          .map((g) => WritingGrammarFeedbackModel.fromJson(g as Map<String, dynamic>))
          .toList(),
      vocabSuggestions: rawVocab
          .map((v) => WritingVocabSuggestionModel.fromJson(v as Map<String, dynamic>))
          .toList(),
      generalComment: json['general_comment'] as String? ?? '',
      revisedText: json['revised_text'] as String? ?? '',
      userText: userText,
      topic: topic,
      submittedAt: DateTime.now(),
    );
  }

  String get scoreGrade {
    if (overallScore >= 85) return 'Xuất sắc';
    if (overallScore >= 70) return 'Tốt & Tự nhiên';
    if (overallScore >= 55) return 'Đạt yêu cầu';
    return 'Cần rèn luyện thêm';
  }
}
