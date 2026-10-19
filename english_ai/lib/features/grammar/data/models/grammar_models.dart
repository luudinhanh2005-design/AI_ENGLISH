class GrammarLessonSummaryModel {
  final String id;
  final String slug;
  final String title;
  final String level;
  final String summary;
  final int orderIndex;
  final bool isCompleted;
  final double? score;

  const GrammarLessonSummaryModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.level,
    required this.summary,
    required this.orderIndex,
    this.isCompleted = false,
    this.score,
  });

  factory GrammarLessonSummaryModel.fromJson(Map<String, dynamic> json) {
    return GrammarLessonSummaryModel(
      id: json['id']?.toString() ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      level: json['level'] as String? ?? 'A1',
      summary: json['summary'] as String? ?? '',
      orderIndex: json['order_index'] as int? ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

class GrammarExampleModel {
  final String en;
  final String vi;

  const GrammarExampleModel({
    required this.en,
    required this.vi,
  });

  factory GrammarExampleModel.fromJson(Map<String, dynamic> json) {
    return GrammarExampleModel(
      en: json['en'] as String? ?? '',
      vi: json['vi'] as String? ?? '',
    );
  }
}

class GrammarQuizQuestionModel {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanationVi;

  const GrammarQuizQuestionModel({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanationVi,
  });

  factory GrammarQuizQuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return GrammarQuizQuestionModel(
      question: json['question'] as String? ?? '',
      options: rawOptions.map((e) => e.toString()).toList(),
      correctIndex: json['correct_index'] as int? ?? 0,
      explanationVi: json['explanation_vi'] as String? ?? '',
    );
  }
}

class GrammarLessonDetailModel {
  final String id;
  final String slug;
  final String title;
  final String level;
  final String summary;
  final String contentMarkdown;
  final String? formula;
  final List<GrammarExampleModel> examples;
  final List<GrammarQuizQuestionModel> practiceQuestions;

  const GrammarLessonDetailModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.level,
    required this.summary,
    required this.contentMarkdown,
    this.formula,
    this.examples = const [],
    this.practiceQuestions = const [],
  });

  factory GrammarLessonDetailModel.fromJson(Map<String, dynamic> json) {
    final rawExamples = json['examples'] as List<dynamic>? ?? [];
    final rawQuestions = json['practice_questions'] as List<dynamic>? ?? [];

    return GrammarLessonDetailModel(
      id: json['id']?.toString() ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      level: json['level'] as String? ?? 'A1',
      summary: json['summary'] as String? ?? '',
      contentMarkdown: json['content_markdown'] as String? ?? '',
      formula: json['formula'] as String?,
      examples: rawExamples
          .map((e) => GrammarExampleModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      practiceQuestions: rawQuestions
          .map((q) => GrammarQuizQuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GrammarResultModel {
  final double score;
  final int total;
  final int correct;
  final bool isPassed;
  final int xpEarned;

  const GrammarResultModel({
    required this.score,
    required this.total,
    required this.correct,
    required this.isPassed,
    required this.xpEarned,
  });

  factory GrammarResultModel.fromJson(Map<String, dynamic> json) {
    return GrammarResultModel(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      total: json['total'] as int? ?? 0,
      correct: json['correct'] as int? ?? 0,
      isPassed: json['is_passed'] as bool? ?? false,
      xpEarned: json['xp_earned'] as int? ?? 0,
    );
  }
}
