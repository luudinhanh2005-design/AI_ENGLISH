import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Generic question palette for exam sections.
///
/// It only knows about ids, so it works for Listening (`L1-1`), Reading
/// (`R2-5`) and any future id scheme. Visual states:
/// - current: outlined primary
/// - answered: filled primary
/// - flagged: amber warning ring + dot
class QuestionNavigator extends StatelessWidget {
  final List<String> questionIds;
  final Set<String> answeredIds;
  final Set<String> flaggedIds;
  final String? currentId;
  final ValueChanged<String> onTap;

  const QuestionNavigator({
    super.key,
    required this.questionIds,
    this.answeredIds = const <String>{},
    this.flaggedIds = const <String>{},
    this.currentId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (questionIds.isEmpty) return const SizedBox.shrink();

    final palette = context.palette;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < questionIds.length; index++)
          _buildItem(
            context,
            id: questionIds[index],
            number: index + 1,
            isAnswered: answeredIds.contains(questionIds[index]),
            isFlagged: flaggedIds.contains(questionIds[index]),
            isCurrent: currentId == questionIds[index],
            palette: palette,
          ),
      ],
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required String id,
    required int number,
    required bool isAnswered,
    required bool isFlagged,
    required bool isCurrent,
    required AppPalette palette,
  }) {
    final Color background;
    final Color border;
    final Color text;

    if (isCurrent) {
      background = AppColors.primary.withOpacity(0.18);
      border = AppColors.primary;
      text = AppColors.primary;
    } else if (isAnswered) {
      background = AppColors.primary;
      border = AppColors.primary;
      text = Colors.white;
    } else {
      background = palette.surface;
      border = isFlagged ? AppColors.warning : palette.divider;
      text = palette.textSecondary;
    }

    return Tooltip(
      message: isFlagged ? 'Câu $number · đã đánh dấu' : 'Câu $number',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(id),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: isCurrent ? 2 : 1),
            ),
            alignment: Alignment.center,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '$number',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isFlagged)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
