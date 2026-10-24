import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:english_ai/features/practice/presentation/screens/practice_screen.dart';
import 'package:english_ai/features/vocabulary/presentation/screens/vocabulary_topics_screen.dart';
import 'package:english_ai/features/vocabulary/presentation/screens/vocabulary_list_screen.dart';
import 'package:english_ai/features/learn/presentation/screens/listening_screen.dart';
import 'package:english_ai/features/learn/presentation/screens/reading_screen.dart';
import 'package:english_ai/features/learn/presentation/screens/grammar_screen.dart';

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
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    
    final hoiThoaiFinder = find.text('Hội thoại');
    expect(hoiThoaiFinder, findsOneWidget);

    // Simulate mouse move / hit test across the screen like Chrome does
    tester.hitTestOnBinding(const Offset(400, 300));
    tester.hitTestOnBinding(const Offset(960, 540));
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

    tester.hitTestOnBinding(const Offset(400, 300));
    tester.hitTestOnBinding(const Offset(960, 540));
  });

  testWidgets('Test GrammarScreen renders content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GrammarScreen(),
      ),
    );
    // Asset loading uses real async I/O; the fake-async pump loop cannot
    // complete it on its own. Pump while the loading spinner is visible.
    for (var i = 0;
        i < 30 &&
            find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    
    expect(find.text('Ngữ Pháp Toàn Diện (Grammar)'), findsOneWidget);
    tester.hitTestOnBinding(const Offset(400, 300));
    tester.hitTestOnBinding(const Offset(960, 540));
  });

  testWidgets('Test VocabularyListScreen renders content', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: VocabularyListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    
    expect(find.text('Kho Từ Vựng'), findsOneWidget);
    tester.hitTestOnBinding(const Offset(400, 300));
    tester.hitTestOnBinding(const Offset(960, 540));
  });
}
