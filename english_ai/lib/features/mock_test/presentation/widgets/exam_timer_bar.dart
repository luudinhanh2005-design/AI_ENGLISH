import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Compact countdown used by the mock-test runner.
///
/// Colours follow the exam urgency convention:
/// - normal: brand teal
/// - under 5 minutes: amber
/// - under 1 minute: red
class ExamTimerBar extends StatelessWidget {
  final int remainingSeconds;
  final int? totalSeconds;
  final bool paused;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  const ExamTimerBar({
    super.key,
    required this.remainingSeconds,
    this.totalSeconds,
    this.paused = false,
    this.onPause,
    this.onResume,
  });

  static const int _warningThreshold = 5 * 60;
  static const int _criticalThreshold = 60;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final remaining = remainingSeconds < 0 ? 0 : remainingSeconds;
    final color = _timerColor(remaining);
    final isUrgent = remaining <= _warningThreshold;
    final total = totalSeconds ?? 0;
    final fraction =
        total > 0 ? (remaining / total).clamp(0.0, 1.0) : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      decoration: BoxDecoration(
        color: isUrgent ? color.withOpacity(0.10) : palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUrgent ? color.withOpacity(0.45) : palette.divider,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                paused ? Icons.pause_circle_outline_rounded : Icons.timer_outlined,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _format(remaining),
                style: AppTextStyles.h3.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              if (paused)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tạm dừng',
                    style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Text(
                  'còn lại',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              const Spacer(),
              if (paused && onResume != null)
                TextButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Tiếp tục'),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else if (!paused && onPause != null)
                IconButton(
                  onPressed: onPause,
                  tooltip: 'Tạm dừng',
                  icon: const Icon(Icons.pause_rounded, size: 20),
                  color: palette.textSecondary,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          if (fraction != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                backgroundColor: color.withOpacity(0.16),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _timerColor(int remaining) {
    if (remaining <= _criticalThreshold) return AppColors.error;
    if (remaining <= _warningThreshold) return AppColors.warning;
    return AppColors.secondary;
  }

  String _format(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    if (hours > 0) return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
    return '$mm:$ss';
  }
}
