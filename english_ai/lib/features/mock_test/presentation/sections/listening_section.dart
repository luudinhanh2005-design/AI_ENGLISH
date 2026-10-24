import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/mock_test_models.dart';
import '../widgets/exam_audio_player.dart';
import '../widgets/question_renderer.dart';

/// Computer-delivered IELTS Listening UI.
///
/// * four part tabs with per-part completion indicator
/// * a single-play audio player in strict mode (replay + pause in practice)
/// * every question of the selected part, grouped by instruction block
/// * a bottom bar with the answered/flagged counters and the submit action
///
/// The countdown timer and the submit confirmation live in the runner.
class ListeningSectionView extends StatefulWidget {
  final ListeningSection section;
  final Map<String, String> answers;
  final Set<String> flagged;

  /// Called with the question id and its new value.
  final void Function(String questionId, String value) onAnswer;
  final ValueChanged<String> onToggleFlag;
  final VoidCallback onRequestSubmit;
  final bool strict;

  const ListeningSectionView({
    super.key,
    required this.section,
    required this.answers,
    required this.flagged,
    required this.onAnswer,
    required this.onToggleFlag,
    required this.onRequestSubmit,
    required this.strict,
  });

  @override
  State<ListeningSectionView> createState() => _ListeningSectionViewState();
}

class _ListeningSectionViewState extends State<ListeningSectionView> {
  int _partIndex = 0;

  /// Parts whose strict-mode playback has been used.
  final Set<String> _playedParts = {};

  List<ExamQuestion> _questionsOf(ListeningPart part) => [
        for (final group in part.groups) ...group.questions,
      ];

  ListeningPart? get _currentPart {
    if (widget.section.parts.isEmpty) return null;
    final index = _partIndex.clamp(0, widget.section.parts.length - 1);
    return widget.section.parts[index];
  }

  List<ExamQuestion> get _allQuestions => [
        for (final part in widget.section.parts) ..._questionsOf(part),
      ];

  int get _answeredCount => _allQuestions
      .where(
        (question) => (widget.answers[question.id] ?? '').trim().isNotEmpty,
      )
      .length;

  bool _isPartComplete(ListeningPart part) {
    final questions = _questionsOf(part);
    if (questions.isEmpty) return false;
    return questions.every(
      (question) => (widget.answers[question.id] ?? '').trim().isNotEmpty,
    );
  }

  void _setAnswer(String questionId, String value) {
    widget.onAnswer(questionId, value);
  }

  void _markPartPlayed(String partId) {
    if (!mounted) return;
    setState(() => _playedParts.add(partId));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final part = _currentPart;

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: Container(
            color: palette.background,
            child: part == null
                ? Center(
                    child: Text(
                      'Chưa có dữ liệu phần nghe.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  )
                : _buildPart(context, part),
          ),
        ),
        _buildBottomBar(context),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final palette = context.palette;
    final parts = widget.section.parts;
    final total = _allQuestions.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          bottom: BorderSide(
            color: palette.divider.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.headphones_rounded,
                size: 16,
                color: AppColors.secondaryDark,
              ),
              const SizedBox(width: 6),
              Text(
                'Bài nghe',
                style: AppTextStyles.labelMedium.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Đã trả lời $_answeredCount/$total',
                style: AppTextStyles.bodySmall.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < parts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _SectionTab(
                    label: parts[i].title.trim().isEmpty
                        ? 'Part ${i + 1}'
                        : parts[i].title,
                    selected: i == _partIndex,
                    complete: _isPartComplete(parts[i]),
                    onTap: () => setState(() => _partIndex = i),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────

  Widget _buildPart(BuildContext context, ListeningPart part) {
    final palette = context.palette;
    final questions = _questionsOf(part);
    final answers = widget.answers;
    final answered = questions
        .where((question) => (answers[question.id] ?? '').trim().isNotEmpty)
        .length;
    final first = questions.isEmpty ? 0 : questions.first.number;
    final last = questions.isEmpty ? 0 : questions.last.number;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _HeadphoneHint(strict: widget.strict),
        const SizedBox(height: 12),
        if (part.instructions.trim().isNotEmpty) ...[
          _InstructionsBanner(text: part.instructions.trim()),
          const SizedBox(height: 12),
        ],
        ExamAudioPlayer(
          key: ValueKey('listening-audio-${part.id}'),
          audioUrl: part.audioUrl,
          strict: widget.strict,
          playedBefore: _playedParts.contains(part.id),
          onConsumed: () => _markPartPlayed(part.id),
          label: '${part.title} audio',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Câu $first–$last',
              style: AppTextStyles.labelSmall.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'Đã trả lời $answered/${questions.length}',
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < part.groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          QuestionGroupCard(
            group: part.groups[i],
            answers: answers,
            flagged: widget.flagged,
            onAnswer: _setAnswer,
            onToggleFlag: widget.onToggleFlag,
            strict: widget.strict,
          ),
        ],
      ],
    );
  }

  // ── Bottom bar ──────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    final palette = context.palette;
    final total = _allQuestions.length;

    final stats = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Đã trả lời $_answeredCount/$total',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_rounded,
              size: 12,
              color: palette.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.flagged.length} câu đã đánh dấu',
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );

    final submitButton = FilledButton.icon(
      onPressed: widget.onRequestSubmit,
      icon: const Icon(Icons.send_rounded, size: 18),
      label: const Text('Nộp bài Listening'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.divider.withValues(alpha: 0.7)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 430) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  stats,
                  const SizedBox(height: 10),
                  submitButton,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: stats),
                const SizedBox(width: 12),
                submitButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Header pieces
// ─────────────────────────────────────────────────────────

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.selected,
    required this.complete,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = selected ? Colors.white : palette.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : palette.cardLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : palette.divider.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (complete) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: selected ? Colors.white : AppColors.success,
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

// ─────────────────────────────────────────────────────────
// Body pieces
// ─────────────────────────────────────────────────────────

class _HeadphoneHint extends StatelessWidget {
  const _HeadphoneHint({required this.strict});

  final bool strict;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.headphones_rounded,
            size: 18,
            color: AppColors.secondaryDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strict
                  ? 'Đeo tai nghe trước khi bắt đầu. Mỗi phần audio chỉ được phát một lần '
                      'và bạn vẫn có thể xem câu hỏi trong khi nghe.'
                  : 'Đeo tai nghe để nghe rõ hơn. Ở chế độ luyện tập bạn có thể tạm dừng '
                      'và nghe lại audio.',
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionsBanner extends StatelessWidget {
  const _InstructionsBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
