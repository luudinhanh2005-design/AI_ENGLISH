import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/placement_provider.dart';
import 'placement_result_screen.dart';

class PlacementTestScreen extends ConsumerWidget {
  const PlacementTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(placementProvider);
    final notifier = ref.read(placementProvider.notifier);

    if (state.isLoading && state.questions.isEmpty) {
      return Scaffold(
        backgroundColor: context.palette.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (state.errorMessage != null && state.questions.isEmpty) {
      return Scaffold(
        backgroundColor: context.palette.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: context.palette.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Thử lại',
                  onPressed: () => notifier.loadQuestions(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.result != null) {
      return PlacementResultScreen(result: state.result!);
    }

    final totalQuestions = state.questions.length;
    final currentIdx = state.currentQuestionIndex;
    final currentQ = state.questions[currentIdx];
    final selectedOption = state.selectedAnswers[currentQ.id];

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.palette.textSecondary),
          tooltip: 'Thoát',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/learn');
            }
          },
        ),
        title: Text(
          'Đánh giá năng lực đầu vào',
          style: AppTextStyles.titleMedium
              .copyWith(color: context.palette.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Progress Bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Câu ${currentIdx + 1}/$totalQuestions',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.primary),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      currentQ.skill.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (currentIdx + 1) / totalQuestions,
                  backgroundColor: context.palette.cardLight,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                ),
              ),

              const SizedBox(height: 24),

              // ── Question Card ──
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Context if any (reading passage)
                      if (currentQ.contextText != null &&
                          currentQ.contextText!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.palette.cardLight.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.palette.divider),
                          ),
                          child: Text(
                            currentQ.contextText!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.palette.textSecondary,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text(
                        currentQ.questionText,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: context.palette.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Options
                      ...List.generate(currentQ.options.length, (optIdx) {
                        final isSelected = selectedOption == optIdx;
                        final optionLetter =
                            String.fromCharCode(65 + optIdx); // A, B, C, D

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: InkWell(
                            onTap: () {
                              notifier.selectAnswer(currentQ.id, optIdx);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.15)
                                    : context.palette.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : context.palette.divider,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.primary
                                          : context.palette.cardLight,
                                    ),
                                    child: Text(
                                      optionLetter,
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: isSelected
                                            ? Colors.white
                                            : context.palette.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      currentQ.options[optIdx],
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: isSelected
                                            ? Colors.white
                                            : context.palette.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // ── Action Buttons ──
              Row(
                children: [
                  if (currentIdx > 0) ...[
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => notifier.previousQuestion(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.palette.textSecondary,
                          side: BorderSide(color: context.palette.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Trước'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      text: currentIdx == totalQuestions - 1
                          ? (state.isLoading ? 'Đang chấm điểm...' : 'Nộp bài')
                          : 'Tiếp theo',
                      isLoading: state.isLoading,
                      onPressed: selectedOption == null
                          ? null
                          : () {
                              if (currentIdx == totalQuestions - 1) {
                                notifier.submitTest();
                              } else {
                                notifier.nextQuestion();
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
