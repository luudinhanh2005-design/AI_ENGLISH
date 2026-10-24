import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/mock_test_models.dart';
import '../providers/mock_test_provider.dart';

/// Landing page of the 4-skill IELTS mock test.
class MockTestHubScreen extends ConsumerStatefulWidget {
  const MockTestHubScreen({super.key});

  @override
  ConsumerState<MockTestHubScreen> createState() => _MockTestHubScreenState();
}

class _MockTestHubScreenState extends ConsumerState<MockTestHubScreen> {
  bool _initialLoadRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initialLoadRequested = true;
      ref.read(mockTestProvider.notifier).loadSets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockTestProvider);
    final palette = context.palette;
    final hasSets = state.sets.isNotEmpty;
    final inProgress = state.attempt != null &&
        (state.phase == MockTestPhase.running ||
            state.phase == MockTestPhase.sectionDone ||
            state.phase == MockTestPhase.evaluating);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context, state),
                  const SizedBox(height: 16),
                  _buildHero(context),
                  if (inProgress) ...[
                    const SizedBox(height: 16),
                    _buildRestoreBanner(context, state),
                  ],
                  const SizedBox(height: 16),
                  _buildQuickLinks(context, state.sets),
                  if (state.error != null && hasSets) ...[
                    const SizedBox(height: 16),
                    _buildInlineError(context, state.error!),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, state),
                  const SizedBox(height: 12),
                  _buildBody(context, state),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header / hero ────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, MockTestState state) {
    final palette = context.palette;
    return Row(
      children: [
        if (context.canPop())
          IconButton(
            tooltip: 'Quay lại',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: palette.textPrimary,
          )
        else
          IconButton(
            tooltip: 'Trang luyện tập',
            onPressed: () => context.go('/practice'),
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
        if (state.isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            tooltip: 'Tải lại danh sách đề',
            onPressed: () => ref.read(mockTestProvider.notifier).loadSets(),
            icon: const Icon(Icons.refresh_rounded),
            color: palette.textSecondary,
          ),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Phòng thi IELTS 4 kỹ năng',
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Trải nghiệm trọn vẹn một buổi thi IELTS như phòng thi thật: '
            'làm đủ 4 kỹ năng, đồng hồ chạy liên tục và nhận band điểm tổng. '
            'Bạn có thể chọn chế độ thi nghiêm túc hoặc luyện tập thoải mái hơn.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.88),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(icon: Icons.headphones_rounded, label: 'Listening 30′'),
              _HeroChip(icon: Icons.menu_book_rounded, label: 'Reading 60′'),
              _HeroChip(icon: Icons.edit_note_rounded, label: 'Writing 60′'),
              _HeroChip(icon: Icons.mic_rounded, label: 'Speaking 11–14′'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: Colors.white.withOpacity(0.8),
              ),
              const SizedBox(width: 6),
              Text(
                'Tổng thời lượng khoảng 2 giờ 45 phút',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreBanner(BuildContext context, MockTestState state) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.pending_actions_rounded,
              color: AppColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buổi thi đang diễn ra',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bạn có một bài thi chưa hoàn thành. Tiếp tục để không mất tiến độ.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => context.push('/mock-test/run'),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Tiếp tục'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(mockTestProvider.notifier).loadSets(),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  // ── Quick links ──────────────────────────────────────────

  Widget _buildQuickLinks(
    BuildContext context,
    List<MockTestSummary> sets,
  ) {
    final speakingSetId = _speakingSetId(sets);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 620
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _QuickLinkCard(
                icon: Icons.history_rounded,
                color: AppColors.primary,
                title: 'Lịch sử thi',
                subtitle: 'Xem lại các buổi thi và band điểm đã đạt',
                onTap: () => context.push('/mock-test/history'),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _QuickLinkCard(
                icon: Icons.mic_none_rounded,
                color: AppColors.speaking,
                title: 'Thi Speaking riêng',
                subtitle: speakingSetId == null
                    ? 'Chưa có bộ đề Speaking'
                    : 'Luyện trọn 3 phần, chấm band Speaking',
                onTap: speakingSetId == null
                    ? null
                    : () => context.push(
                          '/mock-test/intro',
                          extra: <String, dynamic>{
                            'setId': speakingSetId,
                            'mode': 'practice',
                            'skills': const <String>['speaking'],
                          },
                        ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Set list ─────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext context, MockTestState state) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Bộ đề có sẵn',
            style: AppTextStyles.h3.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (state.sets.isNotEmpty)
          Text(
            '${state.sets.length} bộ đề',
            style: AppTextStyles.labelSmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, MockTestState state) {
    if (state.sets.isEmpty) {
      if (state.phase == MockTestPhase.loading || !_initialLoadRequested) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (state.phase == MockTestPhase.error) {
        return _MessageCard(
          icon: Icons.cloud_off_rounded,
          color: AppColors.error,
          title: 'Không tải được danh sách đề',
          message: state.error ??
              'Vui lòng kiểm tra kết nối mạng rồi thử lại.',
          actionLabel: 'Thử lại',
          onAction: () => ref.read(mockTestProvider.notifier).loadSets(),
        );
      }
      return _MessageCard(
        icon: Icons.inbox_rounded,
        color: AppColors.primary,
        title: 'Chưa có bộ đề nào',
        message:
            'Hiện chưa có đề thi thử được xuất bản. Hãy quay lại sau nhé!',
        actionLabel: 'Tải lại',
        onAction: () => ref.read(mockTestProvider.notifier).loadSets(),
      );
    }

    return Column(
      children: [
        for (final set in state.sets) ...[
          _SetCard(
            set: set,
            onStrict: () => _openIntro(set, 'strict'),
            onPractice: () => _openIntro(set, 'practice'),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  void _openIntro(MockTestSummary set, String mode) {
    context.push(
      '/mock-test/intro',
      extra: <String, dynamic>{
        'setId': set.id,
        'mode': mode,
      },
    );
  }

  String? _speakingSetId(List<MockTestSummary> sets) {
    for (final set in sets) {
      if (set.skills.map((s) => s.toLowerCase()).contains('speaking')) {
        return set.id;
      }
    }
    return sets.isEmpty ? null : sets.first.id;
  }
}

// ─────────────────────────────────────────────────────────────
// Small presentation helpers
// ─────────────────────────────────────────────────────────────

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
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

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onTap != null;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? color.withOpacity(0.35) : palette.divider,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (enabled ? color : palette.textHint).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled ? color : palette.textHint,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: enabled
                            ? palette.textPrimary
                            : palette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: palette.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(
                  Icons.chevron_right_rounded,
                  color: palette.textHint,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  final MockTestSummary set;
  final VoidCallback onStrict;
  final VoidCallback onPractice;

  const _SetCard({
    required this.set,
    required this.onStrict,
    required this.onPractice,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skills = _orderedSkills(set.skills);
    final isGeneral = set.type == 'general';
    final badgeColor = isGeneral ? AppColors.secondary : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
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
                      set.title,
                      style: AppTextStyles.h4.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (set.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        set.description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: palette.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withOpacity(0.35)),
                ),
                child: Text(
                  set.typeLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: '${set.durationMinutes} phút',
              ),
              _MetaChip(
                icon: Icons.layers_rounded,
                label: '${skills.length} kỹ năng',
              ),
              for (final skill in skills) _SkillChip(skill: skill),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onStrict,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Thi thật'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPractice,
                icon: const Icon(Icons.fitness_center_rounded, size: 18),
                label: const Text('Luyện tập'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  side: BorderSide(
                    color: AppColors.secondary.withOpacity(0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: palette.textHint),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: palette.textSecondary),
        ),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String skill;

  const _SkillChip({required this.skill});

  @override
  Widget build(BuildContext context) {
    final color = _skillColor(skill);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_skillIcon(skill), size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            _skillLabel(skill),
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
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
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared skill presentation helpers (screen-local)
// ─────────────────────────────────────────────────────────────

const List<String> _canonicalSkills = <String>[
  'listening',
  'reading',
  'writing',
  'speaking',
];

List<String> _orderedSkills(List<String> skills) {
  final normalized = skills.map((s) => s.trim().toLowerCase()).toSet();
  final ordered = <String>[
    for (final skill in _canonicalSkills)
      if (normalized.contains(skill)) skill,
  ];
  for (final skill in skills) {
    final normalizedSkill = skill.trim().toLowerCase();
    if (!_canonicalSkills.contains(normalizedSkill) &&
        !ordered.contains(normalizedSkill)) {
      ordered.add(normalizedSkill);
    }
  }
  return ordered;
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
