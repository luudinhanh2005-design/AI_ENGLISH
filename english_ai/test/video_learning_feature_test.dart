import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_ai/features/video_learning/data/video_learning_data.dart';
import 'package:english_ai/features/video_learning/presentation/screens/video_list_screen.dart';
import 'package:english_ai/features/video_learning/presentation/screens/voice_translator_screen.dart';

void main() {
  group('Video Learning Data Tests', () {
    test('Sample lessons are properly populated', () {
      final lessons = VideoLearningData.sampleLessons;
      expect(lessons.isNotEmpty, isTrue);

      final firstLesson = lessons.first;
      expect(firstLesson.title, isNotEmpty);
      expect(firstLesson.subtitles, isNotEmpty);
      expect(firstLesson.videoUrl, isNotEmpty);
    });

    test('SubtitleLine isActiveAt correctly identifies timestamp', () {
      final firstLesson = VideoLearningData.sampleLessons.first;
      final sub = firstLesson.subtitles.first; // startMs: 0, endMs: 4500

      expect(sub.isActiveAt(const Duration(milliseconds: 2000)), isTrue);
      expect(sub.isActiveAt(const Duration(milliseconds: 5000)), isFalse);
    });
  });

  group('Video Learning UI Tests', () {
    testWidgets('VideoListScreen renders list and search box', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VideoListScreen(),
          ),
        ),
      );

      expect(find.text('Học Qua Video & Phản Xạ 🎬'), findsOneWidget);
      expect(find.text('Dịch Bằng Giọng Nói AI 🎙️'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tất Cả'), findsOneWidget);
    });

    testWidgets('VoiceTranslatorScreen renders direction switcher and inputs', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VoiceTranslatorScreen(),
          ),
        ),
      );

      expect(find.text('Dịch Giọng Nói AI (Bước 3)'), findsOneWidget);
      expect(find.text('Tiếng Anh'), findsOneWidget);
      expect(find.text('Tiếng Việt'), findsOneWidget);
      expect(find.text('Dịch Ngay'), findsOneWidget);
    });
  });
}
