import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/grammar_models.dart';
import '../providers/grammar_provider.dart';

class GrammarLessonScreen extends ConsumerStatefulWidget {
  final String lessonId;

  const GrammarLessonScreen({
    super.key,
    required this.lessonId,
  });

  @override
  ConsumerState<GrammarLessonScreen> createState() =>
      _GrammarLessonScreenState();
}

class _GrammarLessonScreenState extends ConsumerState<GrammarLessonScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(grammarProvider.notifier).loadLessonDetail(widget.lessonId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(grammarProvider);
    final detail = state.currentLesson;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: context.palette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          detail?.title ?? 'Bài học Ngữ pháp',
          style: AppTextStyles.h4.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.5)),
                  ),
                  child: Text(
                    detail.level,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: context.palette.textPrimary,
          unselectedLabelColor: context.palette.textHint,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Lý thuyết & Ví dụ'),
            Tab(text: 'Bài tập thực hành'),
          ],
        ),
      ),
      body: state.isLoadingDetail
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : detail == null
              ? Center(
                  child: Text(
                    'Không tìm thấy bài học ngữ pháp.',
                    style: TextStyle(color: context.palette.textSecondary),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTheoryTab(detail),
                    _buildQuizTab(detail, state),
                  ],
                ),
    );
  }

  Widget _buildTheoryTab(GrammarLessonDetailModel detail) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Summary Card ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.palette.divider),
          ),
          child: Text(
            detail.summary,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Formula Box ──
        if (detail.formula != null && detail.formula!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  const Color(0xFF3B82F6).withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.functions_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Công thức chuẩn (Grammar Formula)',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  detail.formula!,
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Theory Content (Markdown) ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.palette.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book_rounded,
                      color: Color(0xFF00D2D3), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Chi tiết cách dùng & Dấu hiệu',
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                detail.contentMarkdown,
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Examples Section ──
        Text(
          'Ví dụ minh họa (${detail.examples.length})',
          style: AppTextStyles.h4.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        ...detail.examples.map(
          (ex) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.en,
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ex.vi,
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Button Switch to Quiz ──
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.quiz_rounded),
            label: const Text(
              'Làm bài tập thực hành ngay ✍️',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onPressed: () {
              _tabController.animateTo(1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuizTab(GrammarLessonDetailModel detail, GrammarState state) {
    final quiz = detail.practiceQuestions;
    final isSubmitted = state.quizResult != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Result Banner if submitted
        if (state.quizResult != null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: (state.quizResult!.isPassed
                      ? const Color(0xFF2ED573)
                      : const Color(0xFFFFA502))
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: state.quizResult!.isPassed
                    ? const Color(0xFF2ED573)
                    : const Color(0xFFFFA502),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  state.quizResult!.isPassed
                      ? Icons.emoji_events_rounded
                      : Icons.info_outline_rounded,
                  color: state.quizResult!.isPassed
                      ? const Color(0xFF2ED573)
                      : const Color(0xFFFFA502),
                  size: 36,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.quizResult!.isPassed
                            ? 'Chúc mừng! Bạn đã vượt qua bài học!'
                            : 'Cần luyện thêm chút nữa!',
                        style: TextStyle(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Đúng: ${state.quizResult!.correct}/${state.quizResult!.total} câu (${state.quizResult!.score.round()}%) • +${state.quizResult!.xpEarned} XP',
                        style: TextStyle(
                          color: state.quizResult!.isPassed
                              ? const Color(0xFF2ED573)
                              : const Color(0xFFFFA502),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Questions List
        ...List.generate(quiz.length, (qIndex) {
          final q = quiz[qIndex];
          final selectedOption = state.selectedAnswers[qIndex];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Câu ${qIndex + 1}/${quiz.length}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isSubmitted)
                      Icon(
                        selectedOption == q.correctIndex
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: selectedOption == q.correctIndex
                            ? const Color(0xFF2ED573)
                            : const Color(0xFFFF4757),
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  q.question,
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),

                // Options
                ...List.generate(q.options.length, (optIndex) {
                  final optText = q.options[optIndex];
                  final isThisSelected = selectedOption == optIndex;

                  Color optBg = context.palette.card;
                  Color optBorder = context.palette.divider;
                  Color optTextColor = context.palette.textPrimary;

                  if (isSubmitted) {
                    if (optIndex == q.correctIndex) {
                      optBg = const Color(0xFF2ED573).withOpacity(0.2);
                      optBorder = const Color(0xFF2ED573);
                      optTextColor = const Color(0xFF2ED573);
                    } else if (isThisSelected && optIndex != q.correctIndex) {
                      optBg = const Color(0xFFFF4757).withOpacity(0.2);
                      optBorder = const Color(0xFFFF4757);
                      optTextColor = const Color(0xFFFF4757);
                    }
                  } else if (isThisSelected) {
                    optBg = AppColors.primary.withOpacity(0.2);
                    optBorder = AppColors.primary;
                    optTextColor = context.palette.textPrimary;
                  }

                  return InkWell(
                    onTap: isSubmitted
                        ? null
                        : () => ref
                            .read(grammarProvider.notifier)
                            .selectAnswer(qIndex, optIndex),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: optBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: optBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isThisSelected
                                  ? AppColors.primary
                                  : context.palette.divider,
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(
                                    65 + optIndex), // A, B, C, D
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              optText,
                              style: TextStyle(
                                color: optTextColor,
                                fontSize: 14,
                                fontWeight: isThisSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Explanation if submitted
                if (isSubmitted && q.explanationVi.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            size: 16, color: Color(0xFFFFA502)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q.explanationVi,
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 16),

        // Action Button
        if (!isSubmitted)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: state.isSubmittingQuiz
                  ? null
                  : () =>
                      ref.read(grammarProvider.notifier).submitQuiz(detail.id),
              icon: state.isSubmittingQuiz
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text(
                'Nộp bài & Chấm điểm trắc nghiệm 🚀',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: context.palette.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Làm lại bài'),
                  onPressed: () =>
                      ref.read(grammarProvider.notifier).resetQuiz(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Danh sách bài'),
                  onPressed: () => context.pop(),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
