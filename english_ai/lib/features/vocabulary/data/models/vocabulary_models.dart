class VocabularyWordModel {
  final String id;
  final String topicId;
  final String word;
  final String phonetic;
  final String partOfSpeech;
  final String meaningVi;
  final String meaningEn;
  final String exampleSentence;
  final String exampleTranslation;
  final String? audioUrl;
  final String? imageUrl;
  final String level;

  const VocabularyWordModel({
    required this.id,
    required this.topicId,
    required this.word,
    required this.phonetic,
    required this.partOfSpeech,
    required this.meaningVi,
    required this.meaningEn,
    required this.exampleSentence,
    required this.exampleTranslation,
    this.audioUrl,
    this.imageUrl,
    required this.level,
  });

  factory VocabularyWordModel.fromJson(Map<String, dynamic> json) {
    return VocabularyWordModel(
      id: json['id'] as String,
      topicId: json['topic_id'] as String,
      word: json['word'] as String,
      phonetic: json['phonetic'] as String? ?? '',
      partOfSpeech: json['part_of_speech'] as String? ?? 'noun',
      meaningVi: json['meaning_vi'] as String,
      meaningEn: json['meaning_en'] as String? ?? '',
      exampleSentence: json['example_sentence'] as String,
      exampleTranslation: json['example_translation'] as String,
      audioUrl: json['audio_url'] as String?,
      imageUrl: json['image_url'] as String?,
      level: json['level'] as String? ?? 'A1',
    );
  }
}

class VocabularyTopicModel {
  final String id;
  final String slug;
  final String title;
  final String? description;
  final String iconName;
  final String level;
  final int totalWords;

  const VocabularyTopicModel({
    required this.id,
    required this.slug,
    required this.title,
    this.description,
    required this.iconName,
    required this.level,
    required this.totalWords,
  });

  factory VocabularyTopicModel.fromJson(Map<String, dynamic> json) {
    return VocabularyTopicModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      iconName: json['icon_name'] as String? ?? 'book',
      level: json['level'] as String? ?? 'A1',
      totalWords: json['total_words'] as int? ?? 0,
    );
  }
}

class DueReviewItemModel {
  final VocabularyWordModel word;
  final int intervalDays;
  final int repetitionCount;
  final double easeFactor;
  final String status;

  const DueReviewItemModel({
    required this.word,
    this.intervalDays = 0,
    this.repetitionCount = 0,
    this.easeFactor = 2.5,
    this.status = 'new',
  });

  factory DueReviewItemModel.fromJson(Map<String, dynamic> json) {
    final word =
        VocabularyWordModel.fromJson(json['word'] as Map<String, dynamic>);
    final progress = json['progress'] as Map<String, dynamic>?;

    return DueReviewItemModel(
      word: word,
      intervalDays: progress?['interval_days'] as int? ?? 0,
      repetitionCount: progress?['repetition_count'] as int? ?? 0,
      easeFactor: (progress?['ease_factor'] as num?)?.toDouble() ?? 2.5,
      status: progress?['status'] as String? ?? 'new',
    );
  }
}
