import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:english_ai/features/practice/presentation/screens/practice_screen.dart';
import 'package:english_ai/features/vocabulary/presentation/screens/vocabulary_topics_screen.dart';
import 'package:english_ai/features/learn/presentation/screens/listening_screen.dart';
import 'package:english_ai/features/learn/presentation/screens/reading_screen.dart';

void main() {
  testWidgets('Test PracticeScreen renders content', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PracticeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    
    expect(find.text('Đấu Trường Luyện Tập ⚡'), findsOneWidget);
    expect(find.text('Trắc Nghiệm Tốc Độ ⚡'), findsOneWidget);
    expect(find.text('Xưởng Luyện Viết Câu Thông Minh 🖊️'), findsOneWidget);
  });

  testWidgets('Test ListeningScreen active lesson renders content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ListeningScreen(),
      ),
    );
    await tester.pumpAndSettle();
    
    final firstLessonFinder = find.text('At the Coffee Shop');
    expect(firstLessonFinder, findsOneWidget);
    await tester.tap(firstLessonFinder);
    await tester.pumpAndSettle();
    
    expect(find.text('Hội thoại'), findsOneWidget);
    expect(find.text('Nghe toàn bài'), findsOneWidget);
  });

  testWidgets('Test VocabularyTopicsScreen renders content', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: VocabularyTopicsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    
    expect(find.text('Chủ đề từ vựng cốt lõi'), findsOneWidget);
    expect(find.text('Giao Tiếp Hàng Ngày'), findsOneWidget);
  });

  testWidgets('Test ReadingScreen active article renders content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReadingScreen(),
      ),
    );
    await tester.pumpAndSettle();
    
    final firstArticleFinder = find.text('The Surprising Science of Morning Routines');
    expect(firstArticleFinder, findsOneWidget);
    await tester.tap(firstArticleFinder);
    await tester.pumpAndSettle();
    
    expect(find.text('Bài đọc'), findsOneWidget);
  });
}



