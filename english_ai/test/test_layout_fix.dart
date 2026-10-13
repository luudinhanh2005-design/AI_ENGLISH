import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:english_ai/features/vocabulary/data/models/vocabulary_models.dart';
import 'package:english_ai/features/vocabulary/presentation/providers/vocabulary_provider.dart';
import 'package:english_ai/features/vocabulary/presentation/screens/vocabulary_topics_screen.dart';

void main() {
  testWidgets('Test VocabularyTopicsScreen with real API JSON', (tester) async {
    // Exact response from backend
    final realBackendData = [
      {
        'id': '4d3b7838-7b9b-5095-8794-0141cde4cb3a',
        'slug': 'daily-communication',
        'title': 'Daily Communication & Socializing',
        'description': 'Essential words and natural phrases for everyday English conversations.',
        'icon_name': 'chat_bubble',
        'level': 'A1-A2',
        'total_words': 7,
        'words': [
          {
            'id': '8157747f-4216-510c-846e-f38c41c7ce5c',
            'topic_id': '4d3b7838-7b9b-5095-8794-0141cde4cb3a',
            'word': 'greetings',
            'phonetic': '/ˈɡriːtɪŋz/',
            'part_of_speech': 'noun',
            'meaning_vi': 'Lời chào hỏi, câu chào xã giao',
            'meaning_en': 'Words or actions used to welcome someone',
            'example_sentence': 'She exchanged warm greetings with her colleagues this morning.',
            'example_translation': 'Cô ấy đã chào hỏi đồng nghiệp một cách ấm áp sáng nay.',
            'audio_url': null,
            'image_url': null,
            'level': 'A1'
          }
        ]
      }
    ];

    final topics = realBackendData.map((e) => VocabularyTopicModel.fromJson(e)).toList();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vocabularyTopicsProvider.overrideWith((ref) => Future.value(topics)),
        ],
        child: const MaterialApp(
          home: VocabularyTopicsScreen(),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    // Next pump after Future resolves
    await tester.pumpAndSettle();

    expect(find.text('Daily Communication & Socializing'), findsOneWidget);
  });
}
