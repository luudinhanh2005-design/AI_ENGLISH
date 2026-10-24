import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/placement_models.dart';
import '../providers/placement_provider.dart';

class PlacementIntroScreen extends ConsumerStatefulWidget {
  const PlacementIntroScreen({super.key});

  @override
  ConsumerState<PlacementIntroScreen> createState() =>
      _PlacementIntroScreenState();
}

class _PlacementIntroScreenState extends ConsumerState<PlacementIntroScreen> {
  String _mode = 'standard';
  String _targetExam = 'general';

  static const _examOptions = <String, String>{
    'general': 'Tổng quát',
    'ielts': 'IELTS',
    'toeic': 'TOEIC',
    'toefl': 'TOEFL',
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(placementProvider);
    final notifier = ref.read(placementProvider.notifier);
    final config = state.config;

    final modes = config?.modes ?? const <String, PlacementModeModel>{};
    final modeKeys = ['quick', 'standard', 'full']
        .where((key) => modes.containsKey(key))
        .toList();
    if (modeKeys.isEmpty) {
      modeKeys.addAll(modes.keys);
    }
    if (modeKeys.isNotEmpty && !modeKeys.contains(_mode)) {
      _mode = modeKeys.contains('standard') ? 'standard' : modeKeys.first;
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.palette.textSecondary),
          tooltip: 'Đóng',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/learn');
            }
          },
        ),
        title: Text(
          'Xác định trình độ',
          style: AppTextStyles.titleMedium.copyWith(
            color: context.palette.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => notifier.initialize(force: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.screenPaddingH,
              8,
              AppDimensions.screenPaddingH,
              32,
            ),
            children: [
              _HeroCard(config: config),
              const SizedBox(height: 18),
              if (state.latestResult != null) ...[
                _LatestResultCard(
                  result: state.latestResult!,
                  onTap: () => notifier.openHistoryResult(
                    state.latestResult!.resultId,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (state.errorMessage != null) ...[
                _ErrorBanner(
                  message: state.errorMessage!,
                  onRetry: () => notifier.initialize(force: true),
                  onDismiss: notifier.clearError,
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Chọn hình thức kiểm tra',
                style: AppTextStyles.titleSmall.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ...modeKeys.map(
                (key) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ModeCard(
                    mode: modes[key]!,
                    selected: _mode == key,
                    onTap: () => setState(() => _mode = key),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mục tiêu của bạn',
                style: AppTextStyles.titleSmall.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _examOptions.entries.map((entry) {
                  final selected = _targetExam == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) => setState(() => _targetExam = entry.key),
                    labelStyle: AppTextStyles.labelMedium.copyWith(
                      color: selected
                          ? Colors.white
                          : context.palette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedColor: AppColors.primary,
                    backgroundColor: context.palette.surface,
                    side: BorderSide(
                      color: selected
                          ? AppColors.primary
                          : context.palette.divider,
                    ),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              AppButton(
                text: state.isSubmitting
                    ? 'Đang khởi tạo...'
                    : 'Bắt đầu kiểm tra',
                icon: Icons.play_arrow_rounded,
                isLoading: state.isSubmitting,
                onPressed: modeKeys.isEmpty
                    ? null
                    : () async {
                        await notifier.start(
                          mode: _mode,
                          targetExam: _targetExam,
                        );
                      },
              ),
              const SizedBox(height: 12),
              Text(
                'Kết quả CEFR được quy đổi tham khảo sang IELTS, TOEIC, TOEFL '
                'và Cambridge. Đây không phải chứng chỉ chính thức.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.palette.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              if (state.history.isNotEmpty) ...[
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lịch sử kiểm tra',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${state.history.length} lần gần đây',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...state.history.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HistoryTile(
                      entry: entry,
                      onTap: () => notifier.openHistoryResult(entry.resultId),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final PlacementConfigModel? config;

  const _HeroCard({this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'CEFR A1 → C2',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Biết chính xác bạn đang ở đâu',
            style: AppTextStyles.h2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bài kiểm tra thích ứng đa chặng, chấm theo mô hình IRT và rubric CEFR. '
            'Kết quả gồm điểm từng kỹ năng, điểm mạnh, điểm yếu và lộ trình 4 tuần.',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(icon: Icons.headphones_rounded, text: 'Nghe'),
              _HeroPill(icon: Icons.menu_book_rounded, text: 'Đọc'),
              _HeroPill(icon: Icons.spellcheck_rounded, text: 'Ngữ pháp'),
              _HeroPill(icon: Icons.edit_note_rounded, text: 'Viết'),
              _HeroPill(icon: Icons.mic_rounded, text: 'Nói'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final PlacementModeModel mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (mode.key) {
      'quick' => Icons.bolt_rounded,
      'full' => Icons.psychology_alt_rounded,
      _ => Icons.tune_rounded,
    };
    final minutes = (mode.timeLimitSeconds / 60).round();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : context.palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : context.palette.divider,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : context.palette.cardLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        mode.label,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (mode.key == 'standard') ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Đề xuất',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.palette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _Meta(icon: Icons.timer_outlined, text: '$minutes phút'),
                      _Meta(
                        icon: Icons.quiz_outlined,
                        text: '${mode.totalItems} mục',
                      ),
                      _Meta(
                        icon: Icons.layers_outlined,
                        text: '${mode.stages} chặng',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : context.palette.divider,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.palette.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _LatestResultCard extends StatelessWidget {
  final PlacementResultModel result;
  final VoidCallback onTap;

  const _LatestResultCard({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              result.overall.level,
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kết quả gần nhất',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.overall.levelLabel} · ${result.mode.toUpperCase()}',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: context.palette.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final PlacementHistoryEntryModel entry;
  final VoidCallback onTap;

  const _HistoryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = entry.completedDate;
    final dateText = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year}';
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              entry.overallLevel,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              '${entry.mode.toUpperCase()} · ${entry.targetExam.toUpperCase()}',
              style: AppTextStyles.labelMedium.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            dateText,
            style: AppTextStyles.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: context.palette.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: context.palette.textSecondary,
          ),
        ],
      ),
    );
  }
}
