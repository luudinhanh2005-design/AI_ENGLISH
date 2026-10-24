import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/mock_test_models.dart';
import '../providers/mock_test_provider.dart';

/// Full result & review for a completed mock test.
class MockTestResultScreen extends ConsumerWidget {
  const MockTestResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockTestProvider);
    final result = state.result;
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context, result),
                  const SizedBox(height: 8),
                  if (result == null)
                    _buildMissingResult(context)
                  else ...[
                    _buildOverallCard(context, state, result),
                    if (state.isPractice) ...[
                      const SizedBox(height: 12),
                      _buildPracticeBanner(context),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      context,
                      'Điểm từng kỹ năng',
                      Icons.insights_rounded,
                      AppColors.secondary,
                    ),
                    const SizedBox(height: 12),
                    _buildSkillCards(context, result),
                    _buildDetails(context, result),
                    _buildReview(context, result),
                    const SizedBox(height: 26),
                    _buildActions(context, state, result),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header / empty ──────────────────────────────────────

  Widget _buildTopBar(BuildContext context, MockTestResult? result) {
    final palette = context.palette;
    return Row(
      children: [
        IconButton(
          tooltip: 'Về phòng thi',
          onPressed: () => context.go('/mock-test'),
          icon: const Icon(Icons.close_rounded),
          color: palette.textSecondary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KẾT QUẢ BÀI THI',
                style: AppTextStyles.overline.copyWith(
                  color: AppColors.secondary,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                result?.completedAt == null
                    ? 'IELTS Mock Test'
                    : _formatDate(result!.completedAt),
                style: AppTextStyles.labelLarge.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMissingResult(BuildContext context) {
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Chưa có kết quả',
            style: AppTextStyles.h4.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bạn chưa hoàn thành bài thi nào trong phiên này. Hãy quay lại phòng thi '
            'để bắt đầu hoặc xem lại lịch sử các bài đã làm.',
            style: AppTextStyles.bodySmall.copyWith(
              color: palette.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/mock-test'),
                icon: const Icon(Icons.school_rounded, size: 18),
                label: const Text('Về phòng thi'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/mock-test/history'),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Xem lịch sử'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Overall band ────────────────────────────────────────

  Widget _buildOverallCard(
    BuildContext context,
    MockTestState state,
    MockTestResult result,
  ) {
    final band = result.overallBand.clamp(0.0, 9.0).toDouble();
    final info = _bandInfo(band);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: AppColors.xpGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'OVERALL BAND',
            style: AppTextStyles.overline.copyWith(
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            band.toStringAsFixed(1),
            style: AppTextStyles.score.copyWith(
              color: Colors.white,
              fontSize: 82,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Band ${band.toStringAsFixed(1)} · ${info.english}',
            style: AppTextStyles.h4.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            info.vietnamese,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.82),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _LightBadge(label: 'CEFR ${info.cefr} · ${info.cefrLabel}'),
              if (result.xpAwarded > 0)
                _LightBadge(
                  label: '+${result.xpAwarded} XP',
                  icon: Icons.bolt_rounded,
                ),
              _LightBadge(
                label: state.isPractice ? 'Luyện tập' : 'Thi thật',
                icon: state.isPractice
                    ? Icons.fitness_center_rounded
                    : Icons.verified_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Band ước tính – chế độ luyện tập. Điểm số có thể khác với bài thi chính thức.',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Skill cards ─────────────────────────────────────────

  Widget _buildSkillCards(BuildContext context, MockTestResult result) {
    final skills = _orderedScores(result.skills);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 700
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final score in skills)
              SizedBox(width: width, child: _SkillCard(score: score)),
          ],
        );
      },
    );
  }

  // ── Detailed feedback ───────────────────────────────────

  Widget _buildDetails(BuildContext context, MockTestResult result) {
    final scores = _orderedScores(result.skills).where((score) {
      return score.comment.trim().isNotEmpty ||
          score.strengths.isNotEmpty ||
          score.improvements.isNotEmpty ||
          score.corrections.isNotEmpty;
    }).toList();

    if (scores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionTitle(
          context,
          'Nhận xét chi tiết',
          Icons.rate_review_rounded,
          AppColors.speaking,
        ),
        const SizedBox(height: 12),
        for (final score in scores) ...[
          _SectionDetail(score: score),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ── Listening / Reading review ──────────────────────────

  Widget _buildReview(BuildContext context, MockTestResult result) {
    final reviews = _orderedScores(result.skills).where((score) {
      return (score.skill == 'listening' || score.skill == 'reading') &&
          score.details.isNotEmpty;
    }).toList();

    if (reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionTitle(
          context,
          'Xem lại đáp án',
          Icons.fact_check_rounded,
          AppColors.reading,
        ),
        const SizedBox(height: 12),
        for (final score in reviews) ...[
          _ReviewPanel(score: score),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ── Actions ─────────────────────────────────────────────

  Widget _buildActions(
    BuildContext context,
    MockTestState state,
    MockTestResult result,
  ) {
    final setId = state.set?.id ?? state.attempt?.setId ?? '';
    final mode = state.attempt?.mode ?? (state.isPractice ? 'practice' : 'strict');
    final skills = state.plannedSkills.isEmpty
        ? null
        : List<String>.from(state.plannedSkills);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: setId.isEmpty
              ? () => context.go('/mock-test')
              : () => context.pushReplacement(
                    '/mock-test/intro',
                    extra: <String, dynamic>{
                      'setId': setId,
                      'mode': mode,
                      'skills': skills,
                    },
                  ),
          icon: const Icon(Icons.replay_rounded, size: 18),
          label: const Text('Thi lại'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push('/mock-test/history'),
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('Xem lịch sử'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => context.go('/practice'),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Về trang luyện tập'),
          style: TextButton.styleFrom(
            foregroundColor: context.palette.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppTextStyles.h4.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Skill summary card
// ─────────────────────────────────────────────────────────────

class _SkillCard extends StatelessWidget {
  final SectionScore score;

  const _SkillCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = _skillColor(score.skill);
    final band = score.band.clamp(0.0, 9.0).toDouble();
    final criteria = _criteriaEntries(score);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_skillIcon(score.skill), color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _skillLabel(score.skill),
                  style: AppTextStyles.h4.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              Text(
                band.toStringAsFixed(1),
                style: AppTextStyles.h2.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: band / 9,
              minHeight: 7,
              backgroundColor: color.withOpacity(0.14),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Band ${band.toStringAsFixed(1)} / 9.0',
                style: AppTextStyles.caption.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const Spacer(),
              if (score.rawScore != null && score.total != null)
                Text(
                  '${score.rawScore}/${score.total} đúng',
                  style: AppTextStyles.caption.copyWith(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (criteria.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: palette.divider, height: 1),
            const SizedBox(height: 10),
            for (final entry in criteria)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.band.toStringAsFixed(1),
                        style: AppTextStyles.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
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
  }
}

// ─────────────────────────────────────────────────────────────
// Detailed feedback panel
// ─────────────────────────────────────────────────────────────

class _SectionDetail extends StatelessWidget {
  final SectionScore score;

  const _SectionDetail({required this.score});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = _skillColor(score.skill);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_skillIcon(score.skill), color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _skillLabel(score.skill),
                  style: AppTextStyles.h4.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Band ${score.band.toStringAsFixed(1)}',
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (score.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.divider),
              ),
              child: Text(
                score.comment.trim(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: palette.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ],
          if (score.strengths.isNotEmpty || score.improvements.isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 600;
                final strength = _FeedbackList(
                  title: 'Điểm mạnh',
                  icon: Icons.thumb_up_alt_rounded,
                  color: AppColors.success,
                  items: score.strengths,
                );
                final improvement = _FeedbackList(
                  title: 'Cần cải thiện',
                  icon: Icons.lightbulb_outline_rounded,
                  color: AppColors.warning,
                  items: score.improvements,
                );
                if (!wide) {
                  return Column(
                    children: [
                      if (score.strengths.isNotEmpty) strength,
                      if (score.strengths.isNotEmpty &&
                          score.improvements.isNotEmpty)
                        const SizedBox(height: 10),
                      if (score.improvements.isNotEmpty) improvement,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (score.strengths.isNotEmpty)
                      Expanded(child: strength),
                    if (score.strengths.isNotEmpty &&
                        score.improvements.isNotEmpty)
                      const SizedBox(width: 10),
                    if (score.improvements.isNotEmpty)
                      Expanded(child: improvement),
                  ],
                );
              },
            ),
          ],
          if (score.corrections.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Sửa lỗi',
              style: AppTextStyles.labelMedium.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final correction in score.corrections)
              _CorrectionRow(data: correction),
          ],
        ],
      ),
    );
  }
}

class _FeedbackList extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _FeedbackList({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: palette.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CorrectionRow extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CorrectionRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final original = _firstString(data, const [
      'original',
      'original_text',
      'before',
      'source',
      'sentence',
      'text',
      'from',
    ]);
    final corrected = _firstString(data, const [
      'corrected',
      'corrected_text',
      'after',
      'target',
      'correction',
      'to',
      'suggestion',
    ]);
    final explanation = _firstString(data, const [
      'explanation',
      'note',
      'reason',
      'comment',
      'why',
    ]);

    if (original.isEmpty && corrected.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (original.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: AppColors.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    original,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                      decoration: TextDecoration.lineThrough,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          if (corrected.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    corrected,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanation,
              style: AppTextStyles.caption.copyWith(
                color: palette.textHint,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Answer review (Listening / Reading)
// ─────────────────────────────────────────────────────────────

class _ReviewPanel extends StatelessWidget {
  final SectionScore score;

  const _ReviewPanel({required this.score});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = _skillColor(score.skill);
    final details = List<QuestionReview>.from(score.details)
      ..sort((a, b) => a.number.compareTo(b.number));
    final correctCount = details.where((item) => item.isCorrect).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_skillIcon(score.skill), color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Xem lại ${_skillLabel(score.skill)}',
                  style: AppTextStyles.h4.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '$correctCount/${details.length} đúng',
                style: AppTextStyles.labelSmall.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in details) _ReviewRow(review: item, accent: color),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final QuestionReview review;
  final Color accent;

  const _ReviewRow({required this.review, required this.accent});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final statusColor = review.isCorrect ? AppColors.success : AppColors.error;
    final userAnswer =
        review.userAnswer.trim().isEmpty ? '—' : review.userAnswer.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${review.number}',
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Bạn trả lời: ',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: userAnswer,
                            style: AppTextStyles.bodySmall.copyWith(
                              color:
                                  review.isCorrect ? AppColors.success : AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!review.isCorrect) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Đáp án đúng: ',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                            TextSpan(
                              text: review.correctAnswer.trim().isEmpty
                                  ? '—'
                                  : review.correctAnswer.trim(),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                review.isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 18,
                color: statusColor,
              ),
            ],
          ),
          if (review.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                review.explanation.trim(),
                style: AppTextStyles.caption.copyWith(
                  color: palette.textHint,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────

class _LightBadge extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _LightBadge({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

class _CriterionEntry {
  final String label;
  final double band;

  const _CriterionEntry({required this.label, required this.band});
}

class _BandInfo {
  final String english;
  final String vietnamese;
  final String cefr;
  final String cefrLabel;

  const _BandInfo({
    required this.english,
    required this.vietnamese,
    required this.cefr,
    required this.cefrLabel,
  });
}

_BandInfo _bandInfo(double band) {
  final rounded = band.round().clamp(0, 9);
  late final String english;
  late final String vietnamese;
  switch (rounded) {
    case 9:
      english = 'Expert user';
      vietnamese = 'Thành thạo như người bản ngữ';
      break;
    case 8:
      english = 'Very good user';
      vietnamese = 'Rất tốt, chỉ mắc lỗi nhỏ không hệ thống';
      break;
    case 7:
      english = 'Good user';
      vietnamese = 'Tốt, sử dụng tiếng Anh hiệu quả';
      break;
    case 6:
      english = 'Competent user';
      vietnamese = 'Khá, giao tiếp được trong hầu hết tình huống';
      break;
    case 5:
      english = 'Modest user';
      vietnamese = 'Trung bình, có thể xử lý ngôn ngữ cơ bản';
      break;
    case 4:
      english = 'Limited user';
      vietnamese = 'Hạn chế, chưa dùng được ngôn ngữ phức tạp';
      break;
    case 3:
      english = 'Extremely limited user';
      vietnamese = 'Rất hạn chế, chỉ hiểu ý quen thuộc';
      break;
    case 2:
      english = 'Intermittent user';
      vietnamese = 'Gián đoạn, gặp nhiều khó khăn khi giao tiếp';
      break;
    case 1:
      english = 'Non-user';
      vietnamese = 'Chưa sử dụng được tiếng Anh';
      break;
    default:
      english = 'Did not attempt';
      vietnamese = 'Không có bài làm';
  }

  late final String cefr;
  late final String cefrLabel;
  if (band >= 8.5) {
    cefr = 'C2';
    cefrLabel = 'Thành thạo';
  } else if (band >= 7.0) {
    cefr = 'C1';
    cefrLabel = 'Nâng cao';
  } else if (band >= 5.5) {
    cefr = 'B2';
    cefrLabel = 'Trung cấp cao';
  } else if (band >= 4.5) {
    cefr = 'B1';
    cefrLabel = 'Trung cấp';
  } else if (band >= 3.5) {
    cefr = 'A2';
    cefrLabel = 'Sơ cấp';
  } else {
    cefr = 'A1';
    cefrLabel = 'Nhập môn';
  }

  return _BandInfo(
    english: english,
    vietnamese: vietnamese,
    cefr: cefr,
    cefrLabel: cefrLabel,
  );
}

List<SectionScore> _orderedScores(Map<String, SectionScore> skills) {
  const order = <String>['listening', 'reading', 'writing', 'speaking'];
  final result = <SectionScore>[];
  for (final skill in order) {
    final score = skills[skill];
    if (score != null) result.add(score);
  }
  for (final entry in skills.entries) {
    if (!order.contains(entry.key)) result.add(entry.value);
  }
  return result;
}

List<_CriterionEntry> _criteriaEntries(SectionScore score) {
  if (score.criteria.isEmpty) return const [];

  final order = score.skill == 'speaking'
      ? const ['fluency', 'lexical', 'grammar', 'pronunciation']
      : const [
          'task_achievement',
          'task_response',
          'coherence',
          'lexical',
          'grammar',
        ];

  final entries = <_CriterionEntry>[];
  for (final key in order) {
    final value = score.criteria[key];
    if (value != null) {
      entries.add(_CriterionEntry(label: _criterionLabel(key), band: value));
    }
  }
  for (final entry in score.criteria.entries) {
    if (!order.contains(entry.key)) {
      entries.add(
        _CriterionEntry(label: _criterionLabel(entry.key), band: entry.value),
      );
    }
  }
  return entries;
}

String _criterionLabel(String key) {
  switch (key) {
    case 'task_achievement':
      return 'Task Achievement';
    case 'task_response':
      return 'Task Response';
    case 'coherence':
      return 'Coherence & Cohesion';
    case 'lexical':
      return 'Lexical Resource';
    case 'grammar':
      return 'Grammatical Range & Accuracy';
    case 'fluency':
      return 'Fluency & Coherence';
    case 'pronunciation':
      return 'Pronunciation';
    default:
      return key
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
  }
}

String _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
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
  if (date == null) return 'IELTS Mock Test';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · '
      '${two(local.hour)}:${two(local.minute)}';
}
