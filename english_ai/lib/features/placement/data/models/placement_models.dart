class PlacementQuestionModel {
  final String id;
  final String skill;
  final String difficultyLevel;
  final String questionText;
  final String? contextText;
  final String? audioUrl;
  final List<String> options;
  final int orderIndex;

  const PlacementQuestionModel({
    required this.id,
    required this.skill,
    required this.difficultyLevel,
    required this.questionText,
    this.contextText,
    this.audioUrl,
    required this.options,
    required this.orderIndex,
  });

  factory PlacementQuestionModel.fromJson(Map<String, dynamic> json) {
    return PlacementQuestionModel(
      id: json['id'] as String,
      skill: json['skill'] as String,
      difficultyLevel: json['difficulty_level'] as String,
      questionText: json['question_text'] as String,
      contextText: json['context_text'] as String?,
      audioUrl: json['audio_url'] as String?,
      options: (json['options'] as List<dynamic>).map((e) => e.toString()).toList(),
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }
}

class PlacementResultModel {
  final int totalQuestions;
  final int correctCount;
  final double scorePercentage;
  final String assessedLevel;
  final Map<String, double> skillBreakdown;
  final String recommendation;
  final List<String> weaknesses;

  const PlacementResultModel({
    required this.totalQuestions,
    required this.correctCount,
    required this.scorePercentage,
    required this.assessedLevel,
    required this.skillBreakdown,
    required this.recommendation,
    required this.weaknesses,
  });

  factory PlacementResultModel.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['skill_breakdown'] as Map<String, dynamic>? ?? {};
    final breakdown = <String, double>{};
    breakdownRaw.forEach((k, v) {
      breakdown[k] = (v as num).toDouble();
    });

    return PlacementResultModel(
      totalQuestions: json['total_questions'] as int,
      correctCount: json['correct_count'] as int,
      scorePercentage: (json['score_percentage'] as num).toDouble(),
      assessedLevel: json['assessed_level'] as String,
      skillBreakdown: breakdown,
      recommendation: json['recommendation'] as String? ?? '',
      weaknesses: (json['weaknesses'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}
