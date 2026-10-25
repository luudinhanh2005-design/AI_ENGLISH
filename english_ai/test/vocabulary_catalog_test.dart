import 'package:flutter_test/flutter_test.dart';

import 'package:english_ai/features/vocabulary/data/vocabulary_data.dart';

void main() {
  test('generated vocabulary catalog is complete and consistent', () {
    final topics = buildStaticTopics();
    final words = buildStaticWords();

    expect(topics.length, 20);
    expect(words.length, 200);
    expect(words.map((word) => word.id).toSet().length, words.length);
    expect(words.map((word) => word.word.toLowerCase()).toSet().length,
        words.length);

    for (final topic in topics) {
      final topicWords = buildTopicWords(topic.id);
      expect(topicWords.length, topic.totalWords,
          reason: '${topic.slug} count mismatch');
      expect(topicWords.every((word) => word.topicId == topic.id), isTrue);
      expect(buildTopicWords(topic.slug).length, topic.totalWords,
          reason: '${topic.slug} lookup by slug failed');
    }
  });

  test('generated words include rich learning details', () {
    for (final word in buildStaticWords()) {
      expect(word.phonetic, isNotEmpty);
      expect(word.meaningVi, isNotEmpty);
      expect(word.exampleSentence, isNotEmpty);
      expect(word.collocations, isNotEmpty,
          reason: '${word.word} should include collocations');
    }
  });
}
