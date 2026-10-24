import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Shown between two exam sections.
///
/// It reveals only the score of the section that was just submitted — never
/// the correct answers — so the remaining skills stay fair.
class SectionBridge extends StatelessWidget {
  final String skillLabel;
  final double band;
  final int? rawScore;
  final int? total;
  final String comment;
  final bool isLast;
  final VoidCallback onNext;
  final bool loading;

  const SectionBridge({
    super.key,
    required this.skillLabel,
    required this.band,
    this.rawScore,
    this.total,
    this.comment = '',
    this.isLast = false,
    required this.onNext,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasRaw = rawScore != null && total != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.success,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Hoàn thành $skillLabel',
                  style: AppTextStyles.h3.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Phần thi đã được nộp và chấm điểm.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      children: [
                        Text(
                          'BAND',
                          style: AppTextStyles.overline.copyWith(
                            color: palette.textHint,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          band.toStringAsFixed(1),
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 52,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                    if (hasRaw) ...[
                      const SizedBox(width: 20),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: palette.divider),
                        ),
                        child: Text(
                          '$rawScore/$total đúng',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (comment.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.divider),
                    ),
                    child: Text(
                      comment.trim(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: palette.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : onNext,
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isLast
                                ? Icons.emoji_events_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                    label: Text(
                      isLast ? 'Xem kết quả' : 'Section tiếp theo',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (!isLast) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Bạn không thể quay lại phần thi này trong chế độ thi thật.',
                    style: AppTextStyles.caption.copyWith(
                      color: palette.textHint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
