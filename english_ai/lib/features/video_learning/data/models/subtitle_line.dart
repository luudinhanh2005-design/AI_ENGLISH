/// Model cho một từ vựng trọng tâm trong phụ đề
class SubtitleVocabItem {
  final String word;
  final String partOfSpeech; // 'noun', 'verb', 'adj', 'idiom'...
  final String ipa;
  final String meaningVi;
  final String exampleSentence;

  const SubtitleVocabItem({
    required this.word,
    required this.partOfSpeech,
    required this.ipa,
    required this.meaningVi,
    required this.exampleSentence,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'partOfSpeech': partOfSpeech,
        'ipa': ipa,
        'meaningVi': meaningVi,
        'exampleSentence': exampleSentence,
      };

  factory SubtitleVocabItem.fromJson(Map<String, dynamic> json) =>
      SubtitleVocabItem(
        word: json['word'] as String? ?? '',
        partOfSpeech: json['partOfSpeech'] as String? ?? '',
        ipa: json['ipa'] as String? ?? '',
        meaningVi: json['meaningVi'] as String? ?? '',
        exampleSentence: json['exampleSentence'] as String? ?? '',
      );
}

/// Model cho một dòng phụ đề đồng bộ theo thời gian
class SubtitleLine {
  final String id;
  final int startMs;
  final int endMs;
  final String englishText;
  final String vietnameseText;
  final String? ipa;
  final List<SubtitleVocabItem> vocabulary;
  final List<String> grammarNotes;
  final String? reflexQuestion;
  final String? suggestedResponse;

  const SubtitleLine({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.englishText,
    required this.vietnameseText,
    this.ipa,
    this.vocabulary = const [],
    this.grammarNotes = const [],
    this.reflexQuestion,
    this.suggestedResponse,
  });

  Duration get startDuration => Duration(milliseconds: startMs);
  Duration get endDuration => Duration(milliseconds: endMs);

  bool isActiveAt(Duration position) {
    final ms = position.inMilliseconds;
    return ms >= startMs && ms <= endMs;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startMs': startMs,
        'endMs': endMs,
        'englishText': englishText,
        'vietnameseText': vietnameseText,
        'ipa': ipa,
        'vocabulary': vocabulary.map((v) => v.toJson()).toList(),
        'grammarNotes': grammarNotes,
        'reflexQuestion': reflexQuestion,
        'suggestedResponse': suggestedResponse,
      };

  factory SubtitleLine.fromJson(Map<String, dynamic> json) => SubtitleLine(
        id: json['id'] as String? ?? '',
        startMs: json['startMs'] as int? ?? 0,
        endMs: json['endMs'] as int? ?? 0,
        englishText: json['englishText'] as String? ?? '',
        vietnameseText: json['vietnameseText'] as String? ?? '',
        ipa: json['ipa'] as String?,
        vocabulary: (json['vocabulary'] as List<dynamic>?)
                ?.map((e) =>
                    SubtitleVocabItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        grammarNotes: (json['grammarNotes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        reflexQuestion: json['reflexQuestion'] as String?,
        suggestedResponse: json['suggestedResponse'] as String?,
      );
}
