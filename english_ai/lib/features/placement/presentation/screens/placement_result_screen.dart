import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/placement_models.dart';
import '../providers/placement_provider.dart';

class PlacementResultScreen extends ConsumerWidget {
  final PlacementResultModel result;

  const PlacementResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overall = result.overall;
    final levelColor = _levelColor(overall.level);
    final range = overall.levelRange.toSet().toList();
    final rangeText = range.length <= 1
        ? overall.level
        : '${range.first} – ${range.last}';

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Đóng',
          icon: Icon(Icons.close_rounded, color: context.palette.textSecondary),
          onPressed: () {
            ref.read(placementProvider.notifier).dismissResult();
          },
        ),
        title: Text(
          'Kết quả trình độ',
          style: AppTextStyles.titleMedium.copyWith(
            color: context.palette.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Làm lại bài kiểm tra',
            icon: Icon(Icons.refresh_rounded,
                color: context.palette.textSecondary),
            onPressed: () {
              ref.read(placementProvider.notifier).dismissResult();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenPaddingH,
            4,
            AppDimensions.screenPaddingH,
            32,
          ),
          children: [
            _LevelHero(
              result: result,
              color: levelColor,
              rangeText: rangeText,
            ),
            const SizedBox(height: 16),
            _ExamMappingCard(result: result),
            const SizedBox(height: 16),
            _SectionTitle(
              title: 'Năng lực theo kỹ năng',
              subtitle: result.profileConsistency == 'uneven'
                  ? 'Các kỹ năng đang lệch nhau; ưu tiên kỹ năng thấp nhất.'
                  : 'Điểm từng kỹ năng được quy về cùng thang CEFR.',
            ),
            const SizedBox(height: 10),
            ...result.skills.values.map(
              (skill) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SkillCard(skill: skill),
              ),
            ),
            const SizedBox(height: 6),
            _SectionTitle(
              title: 'Điểm mạnh & cần cải thiện',
              subtitle: 'Dựa trên độ khó câu làm đúng và rubric bài viết/nói.',
            ),
            const SizedBox(height: 10),
            _StrengthPair(
              strengths: result.strengths,
              weaknesses: result.weaknesses,
            ),
            const SizedBox(height: 16),
            if (result.recommendation.isNotEmpty) ...[
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.accent,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nhận xét tổng quan',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: context.palette.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            result.recommendation,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.palette.textPrimary,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            _SectionTitle(
              title: 'Lộ trình 4 tuần',
              subtitle: 'Ưu tiên kỹ năng yếu, duy trì kỹ năng mạnh.',
            ),
            const SizedBox(height: 10),
            ...result.roadmap.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RoadmapTile(step: step),
              ),
            ),
            const SizedBox(height: 10),
            _CanDoCard(result: result),
            const SizedBox(height: 16),
            _ReviewCard(result: result),
            const SizedBox(height: 22),
            AppButton(
              text: 'Bắt đầu lộ trình học',
              icon: Icons.route_rounded,
              onPressed: () => context.goNamed(RouteNames.home),
            ),
            const SizedBox(height: 10),
            AppButton(
              text: 'Kiểm tra lại',
              isOutlined: true,
              onPressed: () {
                ref.read(placementProvider.notifier).dismissResult();
              },
            ),
            const SizedBox(height: 14),
            Text(
              'Kết quả dựa trên mô hình IRT 3 tham số và rubric CEFR. '
              'Quy đổi chứng chỉ chỉ mang tính tham khảo, không thay thế '
              'bài thi chính thức của IELTS/TOEIC/TOEFL/Cambridge.',
              style: AppTextStyles.caption.copyWith(
                color: context.palette.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelHero extends StatelessWidget {
  final PlacementResultModel result;
  final Color color;
  final String rangeText;

  const _LevelHero({
    required this.result,
    required this.color,
    required this.rangeText,
  });

  @override
  Widget build(BuildContext context) {
    final overall = result.overall;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, AppColors.secondary, 0.45)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                'TRÌNH ĐỘ CEFR CỦA BẠN',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            overall.level,
            style: AppTextStyles.score.copyWith(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          Text(
            overall.levelLabel,
            style: AppTextStyles.labelLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            overall.descriptionVi,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.92),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _HeroBadge(
                icon: Icons.straighten_rounded,
                text: 'Khoảng $rangeText',
              ),
              _HeroBadge(
                icon: Icons.verified_rounded,
                text: 'Tin cậy: ${overall.confidenceVi}',
              ),
              _HeroBadge(
                icon: Icons.bolt_rounded,
                text: '+${result.xpAwarded} XP',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
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

class _ExamMappingCard extends StatelessWidget {
  final PlacementResultModel result;

  const _ExamMappingCard({required this.result});

  static const _labels = <String, String>{
    'ielts': 'IELTS',
    'toeic': 'TOEIC',
    'toefl': 'TOEFL iBT',
    'cambridge': 'Cambridge',
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 7),
              Text(
                'Quy đổi tham khảo',
                style: AppTextStyles.labelLarge.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _labels.entries.map((entry) {
              final value = result.examEquivalents[entry.key] ?? '—';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Text(
                        entry.value,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: context.palette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Chỉ mang tính tham khảo, không phải chứng chỉ chính thức.',
            style: AppTextStyles.caption.copyWith(
              color: context.palette.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SkillCard extends StatelessWidget {
  final PlacementSkillResultModel skill;

  const _SkillCard({required this.skill});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(skill.level);
    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_skillIcon(skill.key), color: color, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.label,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      skill.isProductive
                          ? 'Rubric CEFR · ${skill.rubricAverage?.toStringAsFixed(1) ?? '0.0'}/5'
                          : '${skill.correct}/${skill.total} câu đúng',
                      style: AppTextStyles.caption.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.28)),
                ),
                child: Text(
                  skill.level,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: LinearProgressIndicator(
              value: (skill.isProductive
                      ? (skill.rubricAverage ?? 0) / 5
                      : skill.percent / 100)
                  .clamp(0.0, 1.0),
              backgroundColor: context.palette.cardLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 7,
            ),
          ),
          if (skill.isProductive && skill.tasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...skill.tasks.map(
              (task) => _ProductiveFeedback(task: task),
            ),
          ],
          if (skill.canDo.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Có thể: ${skill.canDo.take(2).join(' · ')}',
              style: AppTextStyles.caption.copyWith(
                color: context.palette.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductiveFeedback extends StatelessWidget {
  final PlacementProductiveTaskModel task;

  const _ProductiveFeedback({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.palette.cardLight.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.feedback.isNotEmpty)
            Text(
              task.feedback,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.palette.textPrimary,
                height: 1.45,
              ),
            ),
          if (task.improvements.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...task.improvements.take(3).map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppColors.accent)),
                        Expanded(
                          child: Text(
                            tip,
                            style: AppTextStyles.caption.copyWith(
                              color: context.palette.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          if (task.transcript != null && task.transcript!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Bản ghi: ${task.transcript}',
              style: AppTextStyles.caption.copyWith(
                color: context.palette.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StrengthPair extends StatelessWidget {
  final List<PlacementStrengthModel> strengths;
  final List<PlacementStrengthModel> weaknesses;

  const _StrengthPair({required this.strengths, required this.weaknesses});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MiniListCard(
            title: 'Điểm mạnh',
            icon: Icons.trending_up_rounded,
            color: AppColors.success,
            items: strengths,
            emptyText: 'Sẽ rõ hơn sau thêm bài luyện.',
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _MiniListCard(
            title: 'Cần cải thiện',
            icon: Icons.trending_down_rounded,
            color: AppColors.accent,
            items: weaknesses,
            emptyText: 'Các kỹ năng khá đồng đều.',
          ),
        ),
      ],
    );
  }
}

class _MiniListCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<PlacementStrengthModel> items;
  final String emptyText;

  const _MiniListCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              emptyText,
              style: AppTextStyles.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            )
          else
            ...items.take(3).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            item.level,
                            style: AppTextStyles.caption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.label,
                            style: AppTextStyles.caption.copyWith(
                              color: context.palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _RoadmapTile extends StatelessWidget {
  final PlacementRoadmapStepModel step;

  const _RoadmapTile({required this.step});

  @override
  Widget build(BuildContext context) {
    final color = step.isHighPriority ? AppColors.accent : AppColors.primary;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      onTap: () => context.push(step.route),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_skillIcon(step.skill), color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      step.label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      step.level,
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  step.action,
                  style: AppTextStyles.caption.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (step.isHighPriority)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Ưu tiên',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: context.palette.textSecondary),
        ],
      ),
    );
  }
}

class _CanDoCard extends StatelessWidget {
  final PlacementResultModel result;

  const _CanDoCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, List<String>>>[];
    if (result.canDo.isNotEmpty) {
      entries.addAll(result.canDo.entries.where((e) => e.value.isNotEmpty));
    } else {
      for (final skill in result.skills.values) {
        if (skill.canDo.isNotEmpty) {
          entries.add(MapEntry(skill.key, skill.canDo));
        }
      }
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.checklist_rounded,
            color: AppColors.primary, size: 21),
        title: Text(
          'Bạn có thể làm được gì ở trình độ ${result.overall.level}?',
          style: AppTextStyles.labelLarge.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: entries.map((entry) {
          final label = result.skills[entry.key]?.label ??
              _skillLabel(entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                ...entry.value.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(color: AppColors.primary)),
                        Expanded(
                          child: Text(
                            line,
                            style: AppTextStyles.caption.copyWith(
                              color: context.palette.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final PlacementResultModel result;

  const _ReviewCard({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.review.isEmpty) return const SizedBox.shrink();
    final correct = result.review.where((item) => item.isCorrect).length;
    return AppCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.fact_check_rounded,
            color: AppColors.secondary, size: 21),
        title: Text(
          'Xem lại đáp án',
          style: AppTextStyles.labelLarge.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '$correct/${result.review.length} câu đúng',
          style: AppTextStyles.caption.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        children: result.review.map((item) {
          final color = item.isCorrect ? AppColors.success : AppColors.error;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.palette.cardLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      item.isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_skillLabel(item.skill)} · ${item.level}',
                      style: AppTextStyles.caption.copyWith(
                        color: context.palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.stem,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.palette.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Bạn chọn: ${item.selected.isEmpty ? '—' : item.selected.join(', ')}'
                  '  ·  Đáp án: ${item.correct.join(', ')}',
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.explanationVi.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.explanationVi,
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────

Color _levelColor(String level) {
  switch (level.toUpperCase()) {
    case 'A1':
      return AppColors.levelA1;
    case 'A2':
      return AppColors.levelA2;
    case 'B1':
      return AppColors.levelB1;
    case 'B2':
      return AppColors.levelB2;
    case 'C1':
      return AppColors.levelC1;
    case 'C2':
      return AppColors.levelC2;
    default:
      return AppColors.primary;
  }
}

IconData _skillIcon(String skill) {
  switch (skill) {
    case 'listening':
      return Icons.headphones_rounded;
    case 'reading':
      return Icons.menu_book_rounded;
    case 'use_of_english':
      return Icons.spellcheck_rounded;
    case 'writing':
      return Icons.edit_note_rounded;
    case 'speaking':
      return Icons.mic_rounded;
    default:
      return Icons.school_rounded;
  }
}

String _skillLabel(String skill) {
  switch (skill) {
    case 'listening':
      return 'Nghe';
    case 'reading':
      return 'Đọc';
    case 'use_of_english':
      return 'Ngữ pháp & Từ vựng';
    case 'writing':
      return 'Viết';
    case 'speaking':
      return 'Nói';
    default:
      return skill;
  }
}
