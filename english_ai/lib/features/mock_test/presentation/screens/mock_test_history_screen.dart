import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/mock_test_models.dart';
import '../providers/mock_test_provider.dart';

/// Past attempts, newest first, with a compact detail sheet.
class MockTestHistoryScreen extends ConsumerStatefulWidget {
  const MockTestHistoryScreen({super.key});

  @override
  ConsumerState<MockTestHistoryScreen> createState() =>
      _MockTestHistoryScreenState();
}

class _MockTestHistoryScreenState extends ConsumerState<MockTestHistoryScreen> {
  bool _loading = true;
  String? _loadingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await ref.read(mockTestProvider.notifier).loadHistory();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _openDetail(MockTestHistoryItem item) async {
    if (_loadingId != null) return;
    setState(() => _loadingId = item.attemptId);

    final ok = await ref
        .read(mockTestProvider.notifier)
        .loadAttemptDetail(item.attemptId);
    if (!mounted) return;
    setState(() => _loadingId = null);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(mockTestProvider).error ??
                'Không tải được chi tiết bài thi.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final detail = ref.read(mockTestProvider).attemptDetail;
    if (detail == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _AttemptDetailSheet(
          item: item,
          detail: detail,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockTestProvider);
    final palette = context.palette;
    final items = List<MockTestHistoryItem>.from(state.history)
      ..sort((a, b) {
        final left = a.completedAt;
        final right = b.completedAt;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(context, state),
                    const SizedBox(height: 12),
                    _buildHeader(context, items.length),
                    const SizedBox(height: 16),
                    _buildBody(context, state, items),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, MockTestState state) {
    final palette = context.palette;
    return Row(
      children: [
        IconButton(
          tooltip: 'Quay lại',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/mock-test');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          color: palette.textPrimary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'IELTS Mock Test',
            style: AppTextStyles.labelLarge.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Tải lại lịch sử',
          onPressed: _loading ? null : _load,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          color: palette.textSecondary,
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LỊCH SỬ THI',
          style: AppTextStyles.overline.copyWith(
            color: AppColors.secondary,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Các buổi thi đã làm',
          style: AppTextStyles.h2.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          count == 0
              ? 'Hoàn thành một bài thi thử để bắt đầu theo dõi tiến bộ.'
              : '$count buổi thi · mới nhất trước',
          style: AppTextStyles.bodySmall.copyWith(
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    MockTestState state,
    List<MockTestHistoryItem> items,
  ) {
    if (_loading && items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (items.isEmpty) {
      final hasError = state.error != null;
      return _MessageCard(
        icon: hasError ? Icons.cloud_off_rounded : Icons.history_toggle_off_rounded,
        color: hasError ? AppColors.error : AppColors.primary,
        title: hasError ? 'Không tải được lịch sử' : 'Chưa có buổi thi nào',
        message: hasError
            ? (state.error ?? 'Vui lòng kiểm tra kết nối và thử lại.')
            : 'Bạn chưa hoàn thành bài thi thử nào. Hãy bắt đầu một bài thi để '
                'lưu lại kết quả và theo dõi tiến bộ nhé.',
        actionLabel: hasError ? 'Thử lại' : 'Về phòng thi',
        onAction: hasError ? _load : () => context.go('/mock-test'),
        secondaryLabel: hasError ? 'Về phòng thi' : null,
        onSecondary: hasError ? () => context.go('/mock-test') : null,
      );
    }

    return Column(
      children: [
        if (state.error != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.error!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _load,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ],
        for (final item in items) ...[
          _HistoryTile(
            item: item,
            loading: _loadingId == item.attemptId,
            onTap: () => _openDetail(item),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// History tile
// ─────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final MockTestHistoryItem item;
  final bool loading;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.item,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final band = item.overallBand;
    final bandColor = _bandColor(band);
    final isPractice = item.mode == 'practice';
    final skills = _orderedSkills(item.skills.keys.toList());

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title.isEmpty ? item.setId : item.title,
                          style: AppTextStyles.h4.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _SmallBadge(
                              label: item.typeLabel,
                              color: item.type == 'general'
                                  ? AppColors.secondary
                                  : AppColors.primary,
                            ),
                            _SmallBadge(
                              label: isPractice ? 'Luyện tập' : 'Thi thật',
                              color: isPractice
                                  ? AppColors.secondary
                                  : AppColors.primary,
                              filled: false,
                            ),
                            if (item.status != 'completed')
                              const _SmallBadge(
                                label: 'Chưa hoàn thành',
                                color: AppColors.warning,
                                filled: false,
                              ),
                            Text(
                              _formatDate(item.completedAt),
                              style: AppTextStyles.caption.copyWith(
                                color: palette.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: bandColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: bandColor.withOpacity(0.32)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          band == null ? '—' : band.toStringAsFixed(1),
                          style: AppTextStyles.h4.copyWith(
                            color: bandColor,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        Text(
                          'BAND',
                          style: AppTextStyles.overline.copyWith(
                            color: bandColor,
                            fontSize: 8,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in skills)
                      _SkillBandChip(
                        skill: skill,
                        band: item.skills[skill],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    loading
                        ? Icons.hourglass_top_rounded
                        : Icons.touch_app_rounded,
                    size: 14,
                    color: palette.textHint,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    loading ? 'Đang tải chi tiết...' : 'Chạm để xem tóm tắt điểm',
                    style: AppTextStyles.caption.copyWith(
                      color: palette.textHint,
                    ),
                  ),
                  const Spacer(),
                  if (loading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: palette.textHint,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Detail bottom sheet
// ─────────────────────────────────────────────────────────────

class _AttemptDetailSheet extends StatelessWidget {
  final MockTestHistoryItem item;
  final Map<String, dynamic> detail;

  const _AttemptDetailSheet({required this.item, required this.detail});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final summaries = _parseSummaries(detail);
    final overall = _overallBand(detail) ?? item.overallBand;
    final bandColor = _bandColor(overall);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.divider),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title.isEmpty ? item.setId : item.title,
                          style: AppTextStyles.h4.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_formatDate(item.completedAt)} · '
                          '${item.mode == 'practice' ? 'Luyện tập' : 'Thi thật'}',
                          style: AppTextStyles.caption.copyWith(
                            color: palette.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: bandColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bandColor.withOpacity(0.32)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          overall == null ? '—' : overall.toStringAsFixed(1),
                          style: AppTextStyles.h3.copyWith(
                            color: bandColor,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        Text(
                          'OVERALL',
                          style: AppTextStyles.overline.copyWith(
                            color: bandColor,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: palette.textSecondary,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.divider),
            Flexible(
              child: summaries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'Chưa có điểm chi tiết cho bài thi này.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: palette.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                      children: [
                        for (final summary in summaries) ...[
                          _SummaryRow(summary: summary),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Điểm thô và band từng phần được lưu sau khi bạn nộp bài. '
                          'Vào trang kết quả ngay sau khi thi để xem nhận xét chi tiết.',
                          style: AppTextStyles.caption.copyWith(
                            color: palette.textHint,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final _SkillSummary summary;

  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = _skillColor(summary.skill);
    final bandColor = _bandColor(summary.band);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_skillIcon(summary.skill), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _skillLabel(summary.skill),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary.raw != null && summary.total != null
                      ? '${summary.raw}/${summary.total} câu đúng'
                      : 'Điểm do AI chấm',
                  style: AppTextStyles.caption.copyWith(
                    color: palette.textHint,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: bandColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              summary.band == null
                  ? '—'
                  : 'Band ${summary.band!.toStringAsFixed(1)}',
              style: AppTextStyles.labelSmall.copyWith(
                color: bandColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Parsing helpers
// ─────────────────────────────────────────────────────────────

class _SkillSummary {
  final String skill;
  final double? band;
  final int? raw;
  final int? total;

  const _SkillSummary({
    required this.skill,
    this.band,
    this.raw,
    this.total,
  });
}

List<_SkillSummary> _parseSummaries(Map<String, dynamic> detail) {
  final scores = _locateScores(detail);
  final bandOnly = _asMap(detail['skills']);
  final attempt = _asMap(detail['attempt']);
  final attemptBands = _asMap(attempt['skills']);

  final skills = _orderedSkills(<String>[
    ...scores.keys,
    ...bandOnly.keys,
    ...attemptBands.keys,
  ]);

  final summaries = <_SkillSummary>[];
  for (final skill in skills) {
    final entry = scores[skill];
    double? band;
    int? raw;
    int? total;

    if (entry is Map) {
      band = _toDouble(entry['band']);
      raw = _toInt(entry['raw_score']);
      total = _toInt(entry['total']);
    } else if (entry is num) {
      band = entry.toDouble();
    }

    band ??= _toDouble(bandOnly[skill]) ?? _toDouble(attemptBands[skill]);
    if (band == null && raw == null) continue;

    summaries.add(
      _SkillSummary(skill: skill, band: band, raw: raw, total: total),
    );
  }
  return summaries;
}

Map<String, dynamic> _locateScores(Map<String, dynamic> detail) {
  final candidates = <dynamic>[
    detail['scores'],
    detail['score'],
    detail['result'],
    _asMap(detail['attempt'])['scores'],
    _asMap(detail['result'])['skills'],
  ];

  for (final candidate in candidates) {
    final map = _asMap(candidate);
    if (map.isEmpty) continue;
    if (map.keys.any((key) => _canonicalSkills.contains(key))) {
      return map;
    }
  }
  return const <String, dynamic>{};
}

double? _overallBand(Map<String, dynamic> detail) {
  return _toDouble(detail['overall_band']) ??
      _toDouble(_asMap(detail['attempt'])['overall_band']) ??
      _toDouble(_asMap(detail['result'])['overall_band']);
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

// ─────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────

class _SkillBandChip extends StatelessWidget {
  final String skill;
  final double? band;

  const _SkillBandChip({required this.skill, required this.band});

  @override
  Widget build(BuildContext context) {
    final color = _skillColor(skill);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_skillIcon(skill), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '${_skillLabel(skill)} '
            '${band == null ? '—' : band!.toStringAsFixed(1)}',
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _SmallBadge({
    required this.label,
    required this.color,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(filled ? 0.3 : 0.45)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTextStyles.h4.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: palette.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

const List<String> _canonicalSkills = <String>[
  'listening',
  'reading',
  'writing',
  'speaking',
];

List<String> _orderedSkills(List<String> skills) {
  final result = <String>[];
  for (final skill in _canonicalSkills) {
    if (skills.contains(skill)) result.add(skill);
  }
  for (final skill in skills) {
    if (!result.contains(skill)) result.add(skill);
  }
  return result;
}

Color _bandColor(double? band) {
  if (band == null) return AppColors.primary;
  if (band >= 7) return AppColors.success;
  if (band >= 6) return AppColors.secondary;
  if (band >= 5) return AppColors.warning;
  return AppColors.error;
}

String _skillLabel(String skill) {
  switch (skill) {
    case 'listening':
      return 'Listening';
    case 'reading':
      return 'Reading';
    case 'writing':
      return 'Writing';
    case 'speaking':
      return 'Speaking';
    default:
      return skill.isEmpty
          ? skill
          : skill[0].toUpperCase() + skill.substring(1);
  }
}

IconData _skillIcon(String skill) {
  switch (skill) {
    case 'listening':
      return Icons.headphones_rounded;
    case 'reading':
      return Icons.menu_book_rounded;
    case 'writing':
      return Icons.edit_note_rounded;
    case 'speaking':
      return Icons.mic_rounded;
    default:
      return Icons.school_rounded;
  }
}

Color _skillColor(String skill) {
  switch (skill) {
    case 'listening':
      return AppColors.listening;
    case 'reading':
      return AppColors.reading;
    case 'writing':
      return AppColors.writing;
    case 'speaking':
      return AppColors.speaking;
    default:
      return AppColors.primary;
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Chưa rõ ngày';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · '
      '${two(local.hour)}:${two(local.minute)}';
}
