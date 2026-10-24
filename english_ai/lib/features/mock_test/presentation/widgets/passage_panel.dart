import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Readable, palette-aware rendering of a Reading passage.
///
/// Paragraphs are separated by blank lines (`\n\n`) and each one gets a
/// letter label (A, B, C, ...) which is handy for `matching_information`
/// questions that refer to a paragraph.
class PassagePanel extends StatelessWidget {
  const PassagePanel({
    super.key,
    required this.title,
    required this.text,
    this.instructions,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 28),
  });

  final String title;
  final String text;
  final String? instructions;
  final EdgeInsetsGeometry padding;

  static final RegExp _paragraphBreak = RegExp(r'\n\s*\n');

  List<String> get _paragraphs => text
      .split(_paragraphBreak)
      .map((paragraph) => paragraph.trim())
      .where((paragraph) => paragraph.isNotEmpty)
      .toList();

  String _labelFor(int index) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index < letters.length) return letters[index];
    return '${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final paragraphs = _paragraphs;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h3.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (instructions != null && instructions!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              instructions!.trim(),
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: palette.divider.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 18),
          if (paragraphs.isEmpty)
            Text(
              'Chưa có nội dung bài đọc.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: palette.textHint,
              ),
            )
          else
            for (var i = 0; i < paragraphs.length; i++) ...[
              if (i > 0) const SizedBox(height: 18),
              _ParagraphBlock(
                label: _labelFor(i),
                text: paragraphs[i],
              ),
            ],
        ],
      ),
    );
  }
}

class _ParagraphBlock extends StatelessWidget {
  const _ParagraphBlock({
    required this.label,
    required this.text,
  });

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: 16.5,
              height: 1.65,
              color: palette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
