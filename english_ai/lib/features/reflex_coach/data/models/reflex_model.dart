class ReflexOption {
  final String english;
  final String vietnamese;
  final String contextNote;

  const ReflexOption({
    required this.english,
    required this.vietnamese,
    required this.contextNote,
  });

  factory ReflexOption.fromJson(Map<String, dynamic> json) {
    return ReflexOption(
      english: json['english'] as String? ?? '',
      vietnamese: json['vietnamese'] as String? ?? '',
      contextNote: json['context_note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'english': english,
    'vietnamese': vietnamese,
    'context_note': contextNote,
  };
}

class ReflexEvaluation {
  final int score;
  final bool isValid;
  final String feedbackVi;
  final List<ReflexOption> betterOptions;
  final String grammarNote;
  final List<String> vocabularyHighlights;

  const ReflexEvaluation({
    required this.score,
    required this.isValid,
    required this.feedbackVi,
    required this.betterOptions,
    required this.grammarNote,
    required this.vocabularyHighlights,
  });

  factory ReflexEvaluation.fromJson(Map<String, dynamic> json) {
    return ReflexEvaluation(
      score: (json['score'] as num?)?.toInt() ?? 70,
      isValid: json['is_valid'] as bool? ?? true,
      feedbackVi: json['feedback_vi'] as String? ?? '',
      betterOptions: (json['better_options'] as List<dynamic>?)
              ?.map((e) => ReflexOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      grammarNote: json['grammar_note'] as String? ?? '',
      vocabularyHighlights: (json['vocabulary_highlights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class ReflexChallenge {
  final String id;
  final String topicId;
  final String promptVi;
  final String level;
  final List<String> hints;
  final List<String> suggestedAnswers;
  final String contextDesc;

  const ReflexChallenge({
    required this.id,
    required this.topicId,
    required this.promptVi,
    required this.level,
    required this.hints,
    required this.suggestedAnswers,
    required this.contextDesc,
  });

  factory ReflexChallenge.fromJson(Map<String, dynamic> json) {
    return ReflexChallenge(
      id: json['id'] as String? ?? '',
      topicId: json['topic_id'] as String? ?? '',
      promptVi: json['prompt_vi'] as String? ?? '',
      level: json['level'] as String? ?? 'A2',
      hints: (json['hints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      suggestedAnswers: (json['suggested_answers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      contextDesc: json['context_desc'] as String? ?? '',
    );
  }
}

class ReflexTopic {
  final String id;
  final String title;
  final String titleEn;
  final String icon;
  final String description;
  final List<ReflexChallenge> challenges;

  const ReflexTopic({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.icon,
    required this.description,
    required this.challenges,
  });

  factory ReflexTopic.fromJson(Map<String, dynamic> json) {
    return ReflexTopic(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      icon: json['icon'] as String? ?? 'forum',
      description: json['description'] as String? ?? '',
      challenges: (json['challenges'] as List<dynamic>?)
              ?.map((e) => ReflexChallenge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
