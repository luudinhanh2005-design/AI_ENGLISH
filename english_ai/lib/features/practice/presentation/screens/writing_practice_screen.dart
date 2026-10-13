import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/speech_service.dart';
import '../../data/writing_data.dart';

// ─────────────────────────────────────────────
// State
// ─────────────────────────────────────────────
enum WritingLevel { easy, medium, hard }

class WritingScreenState {
  final WritingLevel level;
  final int lessonIndex;
  final int questionIndex;
  final String userInput;
  final bool showResult;
  final bool isCorrect;
  final int score; // correct count per lesson
  final bool lessonFinished;
  final bool isSelectingLesson;

  const WritingScreenState({
    this.level = WritingLevel.easy,
    this.lessonIndex = 0,
    this.questionIndex = 0,
    this.userInput = '',
    this.showResult = false,
    this.isCorrect = false,
    this.score = 0,
    this.lessonFinished = false,
    this.isSelectingLesson = true,
  });

  WritingScreenState copyWith({
    WritingLevel? level,
    int? lessonIndex,
    int? questionIndex,
    String? userInput,
    bool? showResult,
    bool? isCorrect,
    int? score,
    bool? lessonFinished,
    bool? isSelectingLesson,
  }) =>
      WritingScreenState(
        level: level ?? this.level,
        lessonIndex: lessonIndex ?? this.lessonIndex,
        questionIndex: questionIndex ?? this.questionIndex,
        userInput: userInput ?? this.userInput,
        showResult: showResult ?? this.showResult,
        isCorrect: isCorrect ?? this.isCorrect,
        score: score ?? this.score,
        lessonFinished: lessonFinished ?? this.lessonFinished,
        isSelectingLesson: isSelectingLesson ?? this.isSelectingLesson,
      );
}

class WritingScreenNotifier extends StateNotifier<WritingScreenState> {
  WritingScreenNotifier() : super(const WritingScreenState());

  List<WritingLesson> get _lessons {
    switch (state.level) {
      case WritingLevel.easy:
        return easyLessons;
      case WritingLevel.medium:
        return mediumLessons;
      case WritingLevel.hard:
        return hardLessons;
    }
  }

  WritingLesson get currentLesson => _lessons[state.lessonIndex];
  WritingQuestion get currentQuestion =>
      currentLesson.questions[state.questionIndex];

  void setLevel(WritingLevel level) {
    state = state.copyWith(level: level, lessonIndex: 0, isSelectingLesson: true);
  }

  void selectLesson(WritingLevel level, int idx) {
    state = WritingScreenState(
      level: level,
      lessonIndex: idx,
      questionIndex: 0,
      userInput: '',
      showResult: false,
      isCorrect: false,
      score: 0,
      lessonFinished: false,
      isSelectingLesson: false,
    );
  }

  void backToLessons() {
    state = state.copyWith(
      isSelectingLesson: true,
      lessonFinished: false,
      showResult: false,
      userInput: '',
    );
  }

  void updateInput(String val) {
    state = state.copyWith(userInput: val, showResult: false);
  }

  void check() {
    if (state.userInput.trim().isEmpty) return;
    final correct = currentQuestion.sentence.trim().toLowerCase();
    final input = state.userInput.trim().toLowerCase();
    // Allow minor punctuation differences
    final normalizedCorrect = correct.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final normalizedInput = input.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final isCorrect = normalizedCorrect == normalizedInput ||
        _similarity(normalizedCorrect, normalizedInput) >= 0.90;
    state = state.copyWith(
      showResult: true,
      isCorrect: isCorrect,
      score: isCorrect ? state.score + 1 : state.score,
    );
  }

  void next() {
    if (state.questionIndex < currentLesson.questions.length - 1) {
      state = state.copyWith(
        questionIndex: state.questionIndex + 1,
        userInput: '',
        showResult: false,
        isCorrect: false,
      );
    } else {
      state = state.copyWith(lessonFinished: true);
    }
  }

  void previous() {
    if (state.questionIndex > 0) {
      state = state.copyWith(
        questionIndex: state.questionIndex - 1,
        userInput: '',
        showResult: false,
        isCorrect: false,
      );
    }
  }

  void resetLesson() {
    state = WritingScreenState(
      level: state.level,
      lessonIndex: state.lessonIndex,
      questionIndex: 0,
      userInput: '',
      showResult: false,
      isCorrect: false,
      score: 0,
      lessonFinished: false,
      isSelectingLesson: false,
    );
  }

  void nextLesson() {
    final nextIdx = state.lessonIndex + 1;
    if (nextIdx < _lessons.length) {
      selectLesson(state.level, nextIdx);
    } else {
      backToLessons();
    }
  }

  // Simple similarity check (Jaccard on word sets)
  double _similarity(String a, String b) {
    final setA = a.split(' ').where((w) => w.isNotEmpty).toSet();
    final setB = b.split(' ').where((w) => w.isNotEmpty).toSet();
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 1.0 : intersection / union;
  }
}

final writingScreenProvider =
    StateNotifierProvider<WritingScreenNotifier, WritingScreenState>(
        (ref) => WritingScreenNotifier());

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class WritingPracticeScreen extends ConsumerWidget {
  const WritingPracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(writingScreenProvider);
    final notifier = ref.read(writingScreenProvider.notifier);

    // Level & Lesson selector
    if (s.isSelectingLesson) {
      return _LevelSelectorView(notifier: notifier, state: s);
    }

    // Lesson finished
    if (s.lessonFinished) {
      return _LessonFinishedView(state: s, notifier: notifier);
    }

    // Active lesson
    return _ActiveLessonView(state: s, notifier: notifier);
  }
}

// ─────────────────────────────────────────────
// Level / Lesson Selector
// ─────────────────────────────────────────────
class _LevelSelectorView extends StatefulWidget {
  final WritingScreenNotifier notifier;
  final WritingScreenState state;
  const _LevelSelectorView({required this.notifier, required this.state});

  @override
  State<_LevelSelectorView> createState() => _LevelSelectorViewState();
}

class _LevelSelectorViewState extends State<_LevelSelectorView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 3,
      vsync: this,
      initialIndex: WritingLevel.values.indexOf(widget.state.level),
    );
    _tab.addListener(() {
      if (!_tab.indexIsChanging) {
        widget.notifier.setLevel(WritingLevel.values[_tab.index]);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<WritingLesson> get _lessons {
    switch (WritingLevel.values[_tab.index]) {
      case WritingLevel.easy:
        return easyLessons;
      case WritingLevel.medium:
        return mediumLessons;
      case WritingLevel.hard:
        return hardLessons;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLvl = WritingLevel.values[_tab.index];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimaryDark),
          tooltip: 'Thoát',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/practice');
            }
          },
        ),
        title: Text(
          'Luyện Viết Câu (30 Bài Học)',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryDark,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🟢', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 6),
                  Text('Dễ (A1-A2)', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🟡', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 6),
                  Text('Trung Bình (B1)', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🔴', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 6),
                  Text('Khó (B2-C1)', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _lessons.length,
              itemBuilder: (ctx, i) {
                final lesson = _lessons[i];
                final color = _levelColor(currentLvl);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        widget.notifier.selectLesson(currentLvl, i);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.borderDark.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${lesson.lessonNumber}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bài ${lesson.lessonNumber}: ${lesson.title}',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color: AppColors.textPrimaryDark,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${lesson.questions.length} câu luyện viết & nghe',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textSecondaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: AppColors.textSecondaryDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Color _levelColor(WritingLevel level) {
    switch (level) {
      case WritingLevel.easy:
        return const Color(0xFF2ED573);
      case WritingLevel.medium:
        return const Color(0xFFFFA502);
      case WritingLevel.hard:
        return const Color(0xFFFF4757);
    }
  }
}

// ─────────────────────────────────────────────
// Active Lesson View (matches screenshot 1 design)
// ─────────────────────────────────────────────
class _ActiveLessonView extends ConsumerStatefulWidget {
  final WritingScreenState state;
  final WritingScreenNotifier notifier;
  const _ActiveLessonView({required this.state, required this.notifier});

  @override
  ConsumerState<_ActiveLessonView> createState() => _ActiveLessonViewState();
}

class _ActiveLessonViewState extends ConsumerState<_ActiveLessonView> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.state.userInput);
  }

  @override
  void didUpdateWidget(_ActiveLessonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.questionIndex != widget.state.questionIndex) {
      _ctrl.text = widget.state.userInput;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final notifier = widget.notifier;
    final lesson = notifier.currentLesson;
    final question = notifier.currentQuestion;
    final total = lesson.questions.length;
    final progress = (s.questionIndex + 1) / total;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimaryDark),
          tooltip: 'Quay lại danh sách bài',
          onPressed: () => notifier.backToLessons(),
        ),
        title: Column(
          children: [
            Text(
              '🎧 Luyện Nghe – Viết',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Bài ${lesson.lessonNumber}: ${lesson.title}',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondaryDark),
            tooltip: 'Thoát',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/practice');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tiến độ bài học',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${s.questionIndex + 1}/$total câu',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceLightDark,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Card matching screenshot 1
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.borderDark.withOpacity(0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hint block
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.borderDark.withOpacity(0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '💡 Nghĩa tiếng Việt (gợi ý):',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                question.hint,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Audio button "Nghe câu" (Speaking aloud)
                        ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            SpeechService.speak(question.sentence);
                          },
                          icon: const Icon(Icons.volume_up_rounded, size: 20),
                          label: const Text(
                            'Nghe câu',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A4A6A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Text input
                        TextField(
                          controller: _ctrl,
                          onChanged: notifier.updateInput,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimaryDark,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Nhập câu tiếng Anh bạn nghe được...',
                            hintStyle: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.borderDark.withOpacity(0.4),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.borderDark.withOpacity(0.4),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                          maxLines: 2,
                        ),

                        const SizedBox(height: 16),

                        // Check button (green button like screenshot 1)
                        ElevatedButton(
                          onPressed: s.showResult ? null : notifier.check,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E8B57),
                            disabledBackgroundColor: AppColors.surfaceLightDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Kiểm tra',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Result feedback
                        if (s.showResult) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: (s.isCorrect
                                      ? AppColors.success
                                      : AppColors.error)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (s.isCorrect
                                        ? AppColors.success
                                        : AppColors.error)
                                    .withOpacity(0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      s.isCorrect
                                          ? Icons.check_circle_rounded
                                          : Icons.cancel_rounded,
                                      color: s.isCorrect
                                          ? AppColors.success
                                          : AppColors.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      s.isCorrect
                                          ? 'Chính xác! Hoàn hảo 🎉'
                                          : 'Đáp án chính xác:',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: s.isCorrect
                                            ? AppColors.success
                                            : AppColors.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.volume_up_rounded,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () =>
                                          SpeechService.speak(question.sentence),
                                    ),
                                  ],
                                ),
                                if (!s.isCorrect) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    question.sentence,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Navigation buttons: Câu trước & Câu sau
                        Row(
                          children: [
                            if (s.questionIndex > 0)
                              OutlinedButton.icon(
                                onPressed: notifier.previous,
                                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                label: const Text('Câu trước'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondaryDark,
                                  side: const BorderSide(
                                    color: AppColors.textSecondaryDark,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: notifier.next,
                              icon: Icon(
                                s.questionIndex < lesson.questions.length - 1
                                    ? Icons.arrow_forward_rounded
                                    : Icons.done_all_rounded,
                                size: 16,
                              ),
                              label: Text(
                                s.questionIndex < lesson.questions.length - 1
                                    ? 'Câu sau'
                                    : 'Hoàn thành 🏆',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Finished View
// ─────────────────────────────────────────────
class _LessonFinishedView extends StatelessWidget {
  final WritingScreenState state;
  final WritingScreenNotifier notifier;
  const _LessonFinishedView({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final total = notifier.currentLesson.questions.length;
    final percent = (state.score / total * 100).round();

    Color resultColor;
    String emoji;
    String message;
    if (percent >= 80) {
      resultColor = AppColors.success;
      emoji = '🏆';
      message = 'Xuất sắc!';
    } else if (percent >= 60) {
      resultColor = AppColors.warning;
      emoji = '👍';
      message = 'Khá tốt!';
    } else {
      resultColor = AppColors.error;
      emoji = '💪';
      message = 'Cần luyện thêm!';
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimaryDark),
          tooltip: 'Quay lại',
          onPressed: () => notifier.backToLessons(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondaryDark),
            tooltip: 'Thoát',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/practice');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: resultColor.withOpacity(0.15),
                      border: Border.all(color: resultColor, width: 2),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 44)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: resultColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${state.score}/$total câu đúng ($percent%)',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: notifier.resetLesson,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Làm lại',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: notifier.backToLessons,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Chọn bài khác',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/practice');
                      }
                    },
                    child: Text(
                      'Về trang Luyện tập',
                      style: TextStyle(color: AppColors.textSecondaryDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
