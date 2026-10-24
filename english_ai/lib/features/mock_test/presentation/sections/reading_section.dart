import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/mock_test_models.dart';
import '../widgets/passage_panel.dart';
import '../widgets/question_renderer.dart';

/// Computer-delivered IELTS Reading UI.
///
/// Wide layouts show the passage and the questions side by side with
/// independent scroll areas; narrow layouts switch between the two with a
/// segmented control so the section stays usable on a phone.
class ReadingSectionView extends StatefulWidget {
  final ReadingSection section;
  final Map<String, String> answers;
  final Set<String> flagged;

  /// Called with the question id and its new value.
  final void Function(String questionId, String value) onAnswer;
  final ValueChanged<String> onToggleFlag;
  final VoidCallback onRequestSubmit;

  const ReadingSectionView({
    super.key,
    required this.section,
    required this.answers,
    required this.flagged,
    required this.onAnswer,
    required this.onToggleFlag,
    required this.onRequestSubmit,
  });

  @override
  State<ReadingSectionView> createState() => _ReadingSectionViewState();
}

class _ReadingSectionViewState extends State<ReadingSectionView> {
  int _passageIndex = 0;

  /// Narrow layout: `true` shows the passage, `false` shows the questions.
  bool _showPassage = true;

  static const double _wideBreakpoint = 900;

  List<ExamQuestion> _questionsOf(ReadingPassage passage) => [
        for (final group in passage.groups) ...group.questions,
      ];

  ReadingPassage? get _currentPassage {
    if (widget.section.passages.isEmpty) return null;
    final index = _passageIndex.clamp(0, widget.section.passages.length - 1);
    return widget.section.passages[index];
  }

  List<ExamQuestion> get _allQuestions => [
        for (final passage in widget.section.passages) ..._questionsOf(passage),
      ];

  int get _answeredCount => _allQuestions
      .where(
        (question) => (widget.answers[question.id] ?? '').trim().isNotEmpty,
      )
      .length;

  int _answeredIn(ReadingPassage passage) {
    return _questionsOf(passage)
        .where(
          (question) => (widget.answers[question.id] ?? '').trim().isNotEmpty,
        )
        .length;
  }

  bool _isPassageComplete(ReadingPassage passage) {
    final questions = _questionsOf(passage);
    if (questions.isEmpty) return false;
    return questions.every(
      (question) => (widget.answers[question.id] ?? '').trim().isNotEmpty,
    );
  }

  void _setAnswer(String questionId, String value) {
    widget.onAnswer(questionId, value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final passage = _currentPassage;

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: Container(
            color: palette.background,
            child: passage == null
                ? Center(
                    child: Text(
                      'Chưa có dữ liệu bài đọc.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > _wideBreakpoint) {
                        return _buildWideLayout(context, passage);
                      }
                      return _buildNarrowLayout(context, passage);
                    },
                  ),
          ),
        ),
        _buildBottomBar(context),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final palette = context.palette;
    final passages = widget.section.passages;
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
                Icons.menu_book_rounded,
                size: 16,
                color: AppColors.reading,
              ),
              const SizedBox(width: 6),
              Text(
                'Bài đọc',
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
                for (var i = 0; i < passages.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _SectionTab(
                    label: passages[i].title.trim().isEmpty
                        ? 'Passage ${i + 1}'
                        : passages[i].title,
                    selected: i == _passageIndex,
                    complete: _isPassageComplete(passages[i]),
                    onTap: () => setState(() => _passageIndex = i),
                  ),
                ],
              ],
            ),
          ),
          if (_currentPassage != null &&
              _currentPassage!.instructions.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: palette.textHint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _currentPassage!.instructions.trim(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: palette.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Wide layout ─────────────────────────────────────────

  Widget _buildWideLayout(BuildContext context, ReadingPassage passage) {
    final questions = _questionsOf(passage);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _PanelCard(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  PassagePanel(
                    title: passage.title.trim().isEmpty
                        ? 'Passage'
                        : passage.title,
                    text: passage.text,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 6,
            child: _PanelCard(
              icon: Icons.quiz_rounded,
              header: 'Câu hỏi',
              trailing:
                  'Đã trả lời ${_answeredIn(passage)}/${questions.length}',
              child: _buildQuestionsList(passage),
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow layout ───────────────────────────────────────

  Widget _buildNarrowLayout(BuildContext context, ReadingPassage passage) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _ViewToggle(
            showPassage: _showPassage,
            answeredLabel:
                '${_answeredIn(passage)}/${_questionsOf(passage).length}',
            onChanged: (showPassage) {
              setState(() => _showPassage = showPassage);
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _showPassage ? 0 : 1,
            children: [
              ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  PassagePanel(
                    title: passage.title.trim().isEmpty
                        ? 'Passage'
                        : passage.title,
                    text: passage.text,
                  ),
                ],
              ),
              _buildQuestionsList(passage, topPadding: 12),
            ],
          ),
        ),
      ],
    );
  }

  // ── Questions ───────────────────────────────────────────

  Widget _buildQuestionsList(
    ReadingPassage passage, {
    double topPadding = 14,
  }) {
    final questions = _questionsOf(passage);
    final answers = widget.answers;
    final first = questions.isEmpty ? 0 : questions.first.number;
    final last = questions.isEmpty ? 0 : questions.last.number;

    return ListView(
      padding: EdgeInsets.fromLTRB(14, topPadding, 14, 24),
      children: [
        Row(
          children: [
            Text(
              'Câu $first–$last',
              style: AppTextStyles.labelSmall.copyWith(
                color: context.palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'Đã trả lời ${_answeredIn(passage)}/${questions.length}',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < passage.groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          QuestionGroupCard(
            group: passage.groups[i],
            answers: answers,
            flagged: widget.flagged,
            onAnswer: _setAnswer,
            onToggleFlag: widget.onToggleFlag,
            strict: false,
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
      label: const Text('Nộp bài Reading'),
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
// Layout pieces
// ─────────────────────────────────────────────────────────

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.child,
    this.icon,
    this.header,
    this.trailing,
  });

  final IconData? icon;
  final String? header;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.divider.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 10),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: AppColors.primary),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    header!,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        trailing!,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: palette.textHint,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(
              height: 1,
              color: palette.divider.withValues(alpha: 0.7),
            ),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.showPassage,
    required this.answeredLabel,
    required this.onChanged,
  });

  final bool showPassage;
  final String answeredLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.divider.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleSegment(
              label: 'Bài đọc',
              icon: Icons.menu_book_rounded,
              selected: showPassage,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ToggleSegment(
              label: 'Câu hỏi',
              icon: Icons.quiz_rounded,
              badge: answeredLabel,
              selected: !showPassage,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

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
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    badge!,
                    style: AppTextStyles.caption.copyWith(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : palette.textHint,
                    ),
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
