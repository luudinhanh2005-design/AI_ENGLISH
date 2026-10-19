/// Pronunciation feature data models

// -----------------------------------------------------------------------------
// Word-level scoring from /api/v1/speech/assess
// -----------------------------------------------------------------------------
class WordScoreModel {
  final String word;
  final double score; // 0-100
  final String errorType; // None | Mispronunciation | Omission | Insertion

  const WordScoreModel({
    required this.word,
    required this.score,
    required this.errorType,
  });

  factory WordScoreModel.fromJson(Map<String, dynamic> json) {
    return WordScoreModel(
      word: json['word'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ??
          (json['accuracy_score'] as num?)?.toDouble() ??
          0.0,
      errorType: json['error_type'] as String? ?? 'None',
    );
  }

  /// Đọc đúng (xanh lá)
  bool get isCorrect => score >= 80.0;

  /// Tạm được (vàng)
  bool get isPartial => score >= 60.0 && score < 80.0;

  /// Sai / bỏ qua (đỏ)
  bool get isWrong => score < 60.0;
}

// -----------------------------------------------------------------------------
// Full pronunciation result returned by /api/v1/speech/assess
// -----------------------------------------------------------------------------
class PronunciationResultModel {
  final double overallScore;
  final double fluencyScore;
  final double accuracyScore;
  final double completenessScore;
  final double prosodyScore;
  final String feedbackVi;
  final List<String> improvementTips;
  final List<WordScoreModel> wordScores;
  final String recognizedText;
  final String referenceText;

  const PronunciationResultModel({
    required this.overallScore,
    required this.fluencyScore,
    required this.accuracyScore,
    required this.completenessScore,
    required this.prosodyScore,
    required this.feedbackVi,
    required this.improvementTips,
    required this.wordScores,
    required this.recognizedText,
    required this.referenceText,
  });

  factory PronunciationResultModel.fromJson(Map<String, dynamic> json) {
    final rawWords = json['word_scores'] as List<dynamic>? ?? [];
    final rawTips = json['improvement_tips'] as List<dynamic>? ?? [];
    return PronunciationResultModel(
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      fluencyScore: (json['fluency_score'] as num?)?.toDouble() ?? 0.0,
      accuracyScore: (json['accuracy_score'] as num?)?.toDouble() ?? 0.0,
      completenessScore: (json['completeness_score'] as num?)?.toDouble() ?? 0.0,
      prosodyScore: (json['prosody_score'] as num?)?.toDouble() ?? 0.0,
      feedbackVi: json['feedback_vi'] as String? ??
          json['feedback'] as String? ??
          '',
      improvementTips: rawTips.map((e) => e.toString()).toList(),
      wordScores: rawWords
          .map((w) => WordScoreModel.fromJson(w as Map<String, dynamic>))
          .toList(),
      recognizedText: json['recognized_text'] as String? ??
          json['recognised_text'] as String? ??
          '',
      referenceText: json['reference_text'] as String? ?? '',
    );
  }

  /// Nhãn tổng thể dựa trên điểm
  String get gradeLabel {
    if (overallScore >= 90) return 'Xuất sắc!';
    if (overallScore >= 80) return 'Rất tốt!';
    if (overallScore >= 70) return 'Tốt!';
    if (overallScore >= 60) return 'Tạm được';
    if (overallScore >= 50) return 'Cần luyện thêm';
    return 'Hãy thử lại!';
  }
}

// -----------------------------------------------------------------------------
// Practice sentence from /api/v1/speech/practice
// -----------------------------------------------------------------------------
class PracticeSentenceModel {
  final String text;
  final String level; // A1-C1
  final String topic;
  final String ipaTranscription;
  final String? tipVi;

  const PracticeSentenceModel({
    required this.text,
    required this.level,
    required this.topic,
    required this.ipaTranscription,
    this.tipVi,
  });

  factory PracticeSentenceModel.fromJson(Map<String, dynamic> json) {
    return PracticeSentenceModel(
      text: json['text'] as String? ?? '',
      level: json['level'] as String? ?? 'B1',
      topic: json['topic'] as String? ?? json['focus'] as String? ?? 'General',
      ipaTranscription: json['ipa'] as String? ?? '',
      tipVi: json['tip_vi'] as String?,
    );
  }
}

// -----------------------------------------------------------------------------
// History item from /api/v1/speech/history
// -----------------------------------------------------------------------------
class PronunciationHistoryModel {
  final String id;
  final String sentence;
  final double overallScore;
  final DateTime createdAt;

  const PronunciationHistoryModel({
    required this.id,
    required this.sentence,
    required this.overallScore,
    required this.createdAt,
  });

  factory PronunciationHistoryModel.fromJson(Map<String, dynamic> json) {
    return PronunciationHistoryModel(
      id: json['id']?.toString() ?? '',
      sentence: json['reference_text'] as String? ?? '',
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// -----------------------------------------------------------------------------
// Speaking stats from /api/v1/speech/stats
// -----------------------------------------------------------------------------
class PronunciationStatsModel {
  final int totalSessions;
  final double averageOverall;
  final double averageFluency;
  final double averageAccuracy;
  final int currentStreak;
  final double bestScore;

  const PronunciationStatsModel({
    this.totalSessions = 0,
    this.averageOverall = 0.0,
    this.averageFluency = 0.0,
    this.averageAccuracy = 0.0,
    this.currentStreak = 0,
    this.bestScore = 0.0,
  });

  factory PronunciationStatsModel.fromJson(Map<String, dynamic> json) {
    return PronunciationStatsModel(
      totalSessions: json['total_sessions'] as int? ?? 0,
      averageOverall: (json['average_overall'] as num?)?.toDouble() ?? 0.0,
      averageFluency: (json['average_fluency'] as num?)?.toDouble() ?? 0.0,
      averageAccuracy: (json['average_accuracy'] as num?)?.toDouble() ?? 0.0,
      currentStreak: json['current_streak'] as int? ?? 0,
      bestScore: (json['best_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}


