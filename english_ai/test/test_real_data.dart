import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:english_ai/features/vocabulary/data/models/vocabulary_models.dart';
import 'package:english_ai/features/vocabulary/presentation/providers/vocabulary_provider.dart';
import 'package:english_ai/features/vocabulary/presentation/screens/vocabulary_topics_screen.dart';

void main() {
  testWidgets('Test VocabularyTopicsScreen with API data', (tester) async {
    final apiJson = [
      {
        'id': '4d3b7838-7b9b-5095-8794-0141cde4cb3a',
        'slug': 'daily-communication',
        'title': 'Daily Communication & Socializing',
        'description': 'Essential words and natural phrases for everyday English conversations.',
        'icon_name': 'chat_bubble',
        'level': 'A1-A2',
        'total_words': 7,
      }
    ];

    final topics = apiJson.map((e) => VocabularyTopicModel.fromJson(e)).toList();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vocabularyTopicsProvider.overrideWith((ref) async => topics),
        ],
        child: const MaterialApp(
          home: VocabularyTopicsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daily Communication & Socializing'), findsOneWidget);
  });
}
