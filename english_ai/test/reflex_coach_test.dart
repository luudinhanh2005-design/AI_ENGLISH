import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:english_ai/features/reflex_coach/data/models/reflex_model.dart';
import 'package:english_ai/features/reflex_coach/data/services/reflex_coach_service.dart';
import 'package:english_ai/features/reflex_coach/presentation/screens/reflex_coach_screen.dart';

void main() {
  group('Reflex Coach Model Tests', () {
    test('ReflexOption and ReflexEvaluation parse correctly from json', () {
      final json = {
        'score': 65,
        'is_valid': false,
        'feedback_vi': 'Câu của bạn hơi lủng củng và thừa từ.',
        'better_options': [
          {
            'english': 'What time is check-in?',
            'vietnamese': 'Mấy giờ là giờ nhận phòng?',
            'context_note': 'Cách nói ngắn gọn nhất',
          },
          {
            'english': 'When can I check in?',
            'vietnamese': 'Khi nào tôi có thể nhận phòng?',
            'context_note': 'Lịch sự, tự nhiên',
          }
        ],
        'grammar_note': 'Dùng What time is + danh từ.',
        'vocabulary_highlights': ['check-in (nhận phòng)'],
      };

      final eval = ReflexEvaluation.fromJson(json);
      expect(eval.score, 65);
      expect(eval.isValid, false);
      expect(eval.betterOptions.length, 2);
      expect(eval.betterOptions.first.english, 'What time is check-in?');
      expect(eval.vocabularyHighlights.first, 'check-in (nhận phòng)');
    });

    test('ReflexCoachService fallback identifies awkward sentences', () async {
      final service = ReflexCoachService.instance;
      final eval = await service.assessReflex(
        promptVi: 'Tôi có thể nhận phòng lúc mấy giờ?',
        userEn: 'What time is it I can check in',
      );

      expect(eval.score, 65);
      expect(eval.isValid, false);
      expect(eval.betterOptions.isNotEmpty, true);
      expect(eval.betterOptions.any((opt) => opt.english == 'What time is check-in?'), true);
    });

    test('ReflexCoachService loads topics with challenges', () async {
      final service = ReflexCoachService.instance;
      final topics = await service.getReflexTopics();
      expect(topics.isNotEmpty, true);
      expect(topics.first.challenges.isNotEmpty, true);
      expect(topics.first.challenges.first.promptVi, 'Tôi có thể nhận phòng lúc mấy giờ?');
    });
  });

  group('ReflexCoachScreen Widget Test', () {
    testWidgets('Renders prompt card and action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReflexCoachScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Phản Xạ Giao Tiếp AI 🤖'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Gửi AI Đánh Giá & Gợi Ý ✨'), findsOneWidget);
    });
  });
}
