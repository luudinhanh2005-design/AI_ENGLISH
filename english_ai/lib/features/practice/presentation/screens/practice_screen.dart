import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/practice_progress_store.dart';
import '../providers/practice_progress_provider.dart';
import '../providers/practice_quiz_provider.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final quiz = ref.read(practiceQuizProvider);
      if (quiz.lessons.isEmpty && quiz.phase == PracticeQuizPhase.loading) {
        final level = ref.read(authStateProvider).valueOrNull?.currentLevel;
        unawaited(
          ref.read(practiceQuizProvider.notifier).load(userLevel: level),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final progress = ref.watch(practiceProgressProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(streak: user?.streak ?? 0),
                  const SizedBox(height: 20),
                  _buildStats(
                    xp: user == null ? '—' : '${user.totalXp} XP',
                    accuracy: progress.accuracyPercent == null
                        ? '—'
                        : '${progress.accuracyPercent}%',
                    daily:
                        '${progress.dailyDone}/${PracticeProgress.dailyGoal}',
                    dailyMet: progress.dailyGoalMet,
                  ),
                  const SizedBox(height: 26),
                  _buildQuizSection(),
                  const SizedBox(height: 28),
                  _buildSkillsSection(),
                  const SizedBox(height: 28),
                  _buildAdvancedSection(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader({required int streak}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đấu Trường Luyện Tập ⚡',
                style: AppTextStyles.h2.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rèn phản xạ nhanh, làm chủ ngữ pháp & viết câu thông minh',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.palette.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFA502).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFA502).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFFA502),
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                'Chuỗi $streak',
                style: const TextStyle(
                  color: Color(0xFFFFA502),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Widget _buildStats({
    required String xp,
    required String accuracy,
    required String daily,
    required bool dailyMet,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.palette.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatColumn(
              icon: Icons.military_tech_rounded,
              color: const Color(0xFF00CEC9),
              value: xp,
              label: 'Điểm rèn luyện',
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatColumn(
              icon: Icons.track_changes_rounded,
              color: const Color(0xFF2ED573),
              value: accuracy,
              label: 'Độ chính xác',
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatColumn(
              icon: dailyMet ? Icons.check_circle_rounded : Icons.bolt_rounded,
              color: const Color(0xFFFFA502),
              value: daily,
              label: 'Mục tiêu',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 44,
      color: context.palette.divider,
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.palette.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ── Grammar quiz ──────────────────────────────────────────────────────────

  Widget _buildQuizSection() {
    final quiz = ref.watch(practiceQuizProvider);
    final notifier = ref.read(practiceQuizProvider.notifier);
    final canShowCounter =
        quiz.phase == PracticeQuizPhase.ready && quiz.totalQuestions > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.auto_awesome_rounded,
          title: 'Thử Thách Ngữ Pháp',
          color: AppColors.grammar,
          trailing: canShowCounter
              ? _buildPill(
                  '${quiz.questionIndex + 1}/${quiz.totalQuestions} câu',
                )
              : null,
        ),
        const SizedBox(height: 14),
        _buildQuizCard(quiz, notifier),
      ],
    );
  }

  Widget _buildQuizCard(
    PracticeQuizState quiz,
    PracticeQuizNotifier notifier,
  ) {
    switch (quiz.phase) {
      case PracticeQuizPhase.loading:
        return _buildPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 14),
              Text(
                'Đang chuẩn bị bài luyện...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
        );
      case PracticeQuizPhase.error:
        return _buildPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.warning,
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                quiz.errorMessage ?? 'Không tải được bài luyện.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: notifier.retry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        );
      case PracticeQuizPhase.submitting:
        return _buildPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 14),
              Text(
                'Đang chấm điểm và cập nhật XP...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
        );
      case PracticeQuizPhase.finished:
        return _buildQuizResult(quiz, notifier);
      case PracticeQuizPhase.ready:
        return _buildQuizQuestion(quiz, notifier);
    }
  }

  Widget _buildQuizQuestion(
    PracticeQuizState quiz,
    PracticeQuizNotifier notifier,
  ) {
    final lesson = quiz.lesson;
    final question = quiz.question;
    if (lesson == null || question == null) {
      return _buildPanel(
        child: Text(
          'Chưa có câu hỏi. Thử tải lại nhé!',
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      );
    }

    final explanation = question.explanation.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLevelBadge(lesson.level),
              if (lesson.isBeta) ...[
                const SizedBox(width: 6),
                _buildBetaBadge(),
              ],
              const Spacer(),
              if (quiz.combo > 1) _buildComboChip(quiz.combo),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lesson.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h4.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            question.question,
            style: AppTextStyles.labelLarge.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...question.options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;
            final isCorrect = idx == question.correctIndex;
            final isSelected = quiz.selectedOption == idx;

            Color borderColor = context.palette.divider;
            Color bgColor = context.palette.surface;
            Color textColor = context.palette.textPrimary;

            if (quiz.revealed) {
              if (isCorrect) {
                borderColor = AppColors.success;
                bgColor = AppColors.success.withValues(alpha: 0.12);
                textColor = AppColors.success;
              } else if (isSelected) {
                borderColor = AppColors.error;
                bgColor = AppColors.error.withValues(alpha: 0.12);
                textColor = AppColors.error;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: quiz.revealed
                      ? null
                      : () => _selectAnswer(quiz, notifier, idx),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? borderColor
                                : context.palette.divider
                                    .withValues(alpha: 0.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            String.fromCharCode(65 + idx),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : context.palette.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: textColor,
                            ),
                          ),
                        ),
                        if (quiz.revealed && isCorrect)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 20,
                          ),
                        if (quiz.revealed && isSelected && !isCorrect)
                          const Icon(
                            Icons.cancel_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (quiz.revealed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.secondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      explanation.isNotEmpty
                          ? explanation
                          : 'Đáp án đúng: ${question.options[question.correctIndex]}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final wasLast = quiz.isLastQuestion;
                  await notifier.next();
                  if (!wasLast) return;
                  final next = ref.read(practiceQuizProvider);
                  final outcome = next.outcome;
                  if (outcome != null &&
                      outcome.synced &&
                      outcome.xpEarned > 0) {
                    await ref.read(authStateProvider.notifier).refreshUser();
                  }
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  quiz.isLastQuestion ? 'Nộp bài & nhận XP' : 'Câu tiếp theo',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _selectAnswer(
    PracticeQuizState quiz,
    PracticeQuizNotifier notifier,
    int index,
  ) {
    if (quiz.revealed) return;
    if (!notifier.selectAnswer(index)) return;
    final next = ref.read(practiceQuizProvider);
    if (!next.revealed) return;
    unawaited(
      ref.read(practiceProgressProvider.notifier).recordAnswer(
            correct: next.isCorrect,
          ),
    );
  }

  Widget _buildQuizResult(
    PracticeQuizState quiz,
    PracticeQuizNotifier notifier,
  ) {
    final lesson = quiz.lesson;
    final attempt = quiz.outcome?.attempt;
    final percent = (attempt?.score ?? quiz.percent.toDouble()).round();
    final correct = attempt?.correct ?? quiz.correctCount;
    final total = attempt?.total ?? quiz.totalQuestions;
    final xp = attempt?.xpEarned ?? 0;
    final queued = quiz.outcome?.queued ?? false;
    final duplicate = attempt?.duplicate ?? false;

    final colors = percent >= 80
        ? [const Color(0xFF2ED573), const Color(0xFF00CEC9)]
        : percent >= 60
            ? [AppColors.primary, AppColors.secondary]
            : [const Color(0xFFFF6B6B), const Color(0xFFFFA502)];

    final title = percent >= 80
        ? 'Xuất sắc! $percent%'
        : percent >= 60
            ? 'Khá lắm! $percent%'
            : 'Cố lên! $percent%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Colors.white,
            size: 44,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Đúng $correct/$total câu',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
          ),
          if (lesson != null) ...[
            const SizedBox(height: 6),
            Text(
              '${lesson.title} • ${lesson.level}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 12),
          _buildResultChip(
            xp > 0
                ? '+$xp XP'
                : queued
                    ? 'Đã lưu offline'
                    : duplicate
                        ? 'Đã ghi nhận trước đó'
                        : 'XP đã tối đa',
          ),
          if (duplicate) ...[
            const SizedBox(height: 6),
            Text(
              'Bài làm này đã được ghi nhận trước đó.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
            ),
          ],
          if (quiz.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              quiz.errorMessage!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: notifier.restart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Làm lại'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await notifier.nextLesson();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: colors.first,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Bài tiếp theo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (lesson != null)
                TextButton(
                  onPressed: () => context.push('/grammar?id=${lesson.id}'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Học lý thuyết'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Skill grid ────────────────────────────────────────────────────────────

  Widget _buildSkillsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.grid_view_rounded,
          title: 'Luyện Kỹ Năng',
          color: AppColors.secondary,
        ),
        const SizedBox(height: 14),
        _buildSkillRow(
          left: _buildSkillCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Writing AI',
            subtitle: 'Chấm bài & gợi ý sửa lỗi',
            color: AppColors.writing,
            onTap: () => context.push('/writing'),
          ),
          right: _buildSkillCard(
            icon: Icons.edit_note_rounded,
            title: 'Viết câu',
            subtitle: '30 bài • 3 cấp độ',
            color: AppColors.secondary,
            onTap: () => context.push('/writing-practice'),
          ),
        ),
        const SizedBox(height: 10),
        _buildSkillRow(
          left: _buildSkillCard(
            icon: Icons.mic_rounded,
            title: 'Luyện nói',
            subtitle: 'Gọi thoại 1-1 với Sarah',
            color: AppColors.speaking,
            onTap: () => context.push('/ai-tutor/call'),
          ),
          right: _buildSkillCard(
            icon: Icons.flip_to_front_rounded,
            title: 'Flashcards',
            subtitle: 'Ôn 15 từ sắp quên',
            color: AppColors.primary,
            onTap: () => context.push('/vocabulary/review'),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillRow({required Widget left, required Widget right}) {
    return SizedBox(
      height: 138,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }

  Widget _buildSkillCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.palette.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Advanced ──────────────────────────────────────────────────────────────

  Widget _buildAdvancedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.rocket_launch_rounded,
          title: 'Nâng Cao',
          color: AppColors.speaking,
        ),
        const SizedBox(height: 14),
        _buildAdvancedCard(
          emoji: '🏆',
          title: 'Thi Thử IELTS 4 Kỹ Năng',
          subtitle: 'Bản beta – đang hoàn thiện • Band 1-9',
          badge: 'BETA',
          colors: const [Color(0xFF2C3E50), Color(0xFF3498DB)],
          shadowColor: const Color(0xFF3498DB),
          onTap: () => context.push('/mock-test'),
        ),
        const SizedBox(height: 12),
        _buildAdvancedCard(
          emoji: '📓',
          title: 'Sổ Tay Lỗi Sai & Từ Vựng',
          subtitle: 'Ôn tập ngắt quãng SM-2',
          badge: 'SM-2',
          colors: const [Color(0xFF6C5CE7), Color(0xFF8E7CF8)],
          shadowColor: const Color(0xFF6C5CE7),
          onTap: () => context.push('/mistake-notebook'),
        ),
      ],
    );
  }

  Widget _buildAdvancedCard({
    required String emoji,
    required String title,
    required String subtitle,
    required String badge,
    required List<Color> colors,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h4.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  Widget _buildPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.palette.divider),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.palette.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLevelBadge(String level) {
    final color = _levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBetaBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'BETA',
        style: TextStyle(
          color: AppColors.warning,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildComboChip(int combo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA502).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: Color(0xFFFFA502),
            size: 14,
          ),
          const SizedBox(width: 3),
          Text(
            'Combo x$combo',
            style: const TextStyle(
              color: Color(0xFFFFA502),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.divider),
      ),
      child: child,
    );
  }

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
}
