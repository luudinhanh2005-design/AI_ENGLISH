import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/mock_test_models.dart';

/// Question types answered with a free-text input.
const Set<String> _textQuestionTypes = {
  'form_completion',
  'note_completion',
  'sentence_completion',
  'summary_completion',
  'short_answer',
};

/// Word used above a completion question's prompt.
const Map<String, String> _groupTypeLabels = {
  'mcq': 'Multiple choice',
  'matching': 'Matching',
  'matching_headings': 'Matching headings',
  'matching_information': 'Matching information',
  'map_labelling': 'Map labelling',
  'form_completion': 'Form completion',
  'note_completion': 'Note completion',
  'sentence_completion': 'Sentence completion',
  'summary_completion': 'Summary completion',
  'short_answer': 'Short answer',
  'tfng': 'True / False / Not Given',
  'ynng': 'Yes / No / Not Given',
};

String questionGroupTypeLabel(String type) =>
    _groupTypeLabels[type] ?? type.replaceAll('_', ' ');

/// A single exam question: number badge, prompt, answer control and flag.
///
/// The widget knows nothing about scoring. It never receives (and therefore
/// cannot reveal) the correct answer.
class QuestionRenderer extends StatefulWidget {
  const QuestionRenderer({
    super.key,
    required this.group,
    required this.question,
    required this.value,
    required this.onChanged,
    required this.strict,
    this.showGroupInstructions = false,
    this.flagged = false,
    this.onToggleFlag,
  });

  final QuestionGroup group;
  final ExamQuestion question;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool strict;
  final bool showGroupInstructions;
  final bool flagged;
  final VoidCallback? onToggleFlag;

  @override
  State<QuestionRenderer> createState() => _QuestionRendererState();
}

class _QuestionRendererState extends State<QuestionRenderer> {
  late final TextEditingController _controller;

  bool get _isTextType =>
      _textQuestionTypes.contains(widget.group.type) ||
      (!widget.group.isChoiceType && !widget.group.isTrueFalseType);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant QuestionRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final external = widget.value ?? '';
    if (_controller.text != external) {
      _controller.value = TextEditingValue(
        text: external,
        selection: TextSelection.collapsed(offset: external.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  QuestionOption? get _selectedOption {
    final current = (widget.value ?? '').trim();
    if (current.isEmpty) return null;
    for (final option in widget.group.options) {
      if (option.key.toLowerCase() == current.toLowerCase()) return option;
    }
    for (final option in widget.group.options) {
      if (option.text.toLowerCase() == current.toLowerCase()) return option;
    }
    return null;
  }

  String? get _selectedTriState {
    final raw = (widget.value ?? '').trim().toUpperCase();
    if (raw.isEmpty) return null;
    final isYesNo = widget.group.type == 'ynng';
    if (raw == 'TRUE' || raw == 'T' || raw == 'YES' || raw == 'Y') {
      return isYesNo ? 'YES' : 'TRUE';
    }
    if (raw == 'FALSE' || raw == 'F' || raw == 'NO' || raw == 'N') {
      return isYesNo ? 'NO' : 'FALSE';
    }
    if (raw == 'NOT GIVEN' ||
        raw == 'NOTGIVEN' ||
        raw == 'NG' ||
        raw == 'NOT-MENTIONED') {
      return 'NOT GIVEN';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showGroupInstructions &&
            widget.group.instructions.trim().isNotEmpty) ...[
          Text(
            widget.group.instructions.trim(),
            style: AppTextStyles.bodySmall.copyWith(
              color: palette.textSecondary,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NumberBadge(number: widget.question.number),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PromptText(prompt: widget.question.prompt),
                  const SizedBox(height: 10),
                  _buildAnswerControl(context),
                ],
              ),
            ),
            if (widget.onToggleFlag != null) ...[
              const SizedBox(width: 4),
              _FlagButton(
                flagged: widget.flagged,
                onPressed: widget.onToggleFlag!,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAnswerControl(BuildContext context) {
    if (_isTextType) return _buildTextField(context);
    if (widget.group.isTrueFalseType) return _buildTriState(context);
    if (widget.group.isChoiceType) {
      if (widget.group.options.isEmpty) return _buildTextField(context);
      if (widget.group.options.length <= 4) return _buildOptionTiles(context);
      return _buildDropdown(context);
    }
    return _buildTextField(context);
  }

  // ── Completion / short answer ───────────────────────────

  Widget _buildTextField(BuildContext context) {
    final palette = context.palette;
    final hasText = _controller.text.trim().isNotEmpty;

    return TextFormField(
      controller: _controller,
      maxLines: 1,
      textInputAction: TextInputAction.next,
      onChanged: widget.onChanged,
      enableSuggestions: false,
      autocorrect: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      style: AppTextStyles.bodyMedium.copyWith(
        color: palette.textPrimary,
        fontSize: 15,
      ),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: 'Your answer',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: palette.textHint,
          fontSize: 14,
        ),
        isDense: true,
        filled: true,
        fillColor: palette.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: (!widget.strict && hasText)
            ? IconButton(
                tooltip: 'Xóa câu trả lời',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: palette.textHint,
                ),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: palette.divider.withValues(alpha: 0.7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.divider),
        ),
      ),
    );
  }

  // ── True / False / Not Given & Yes / No / Not Given ─────

  Widget _buildTriState(BuildContext context) {
    final isYesNo = widget.group.type == 'ynng';
    final labels = isYesNo
        ? const ['YES', 'NO', 'NOT GIVEN']
        : const ['TRUE', 'FALSE', 'NOT GIVEN'];
    final selected = _selectedTriState;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          _TriStateChip(
            label: label,
            selected: selected == label,
            onTap: () => widget.onChanged(label),
          ),
      ],
    );
  }

  // ── Choice questions with few options ───────────────────

  Widget _buildOptionTiles(BuildContext context) {
    final selected = _selectedOption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.group.options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _OptionTile(
            option: widget.group.options[i],
            selected: selected?.key == widget.group.options[i].key,
            onTap: () => widget.onChanged(widget.group.options[i].key),
          ),
        ],
      ],
    );
  }

  // ── Choice questions with many options ──────────────────

  Widget _buildDropdown(BuildContext context) {
    final palette = context.palette;
    final selected = _selectedOption;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.divider.withValues(alpha: 0.7)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected?.key,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: palette.surface,
          hint: Text(
            'Chọn đáp án',
            style: AppTextStyles.bodyMedium.copyWith(
              color: palette.textHint,
              fontSize: 14,
            ),
          ),
          icon: Icon(Icons.expand_more_rounded, color: palette.textSecondary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          items: [
            for (final option in widget.group.options)
              DropdownMenuItem<String>(
                value: option.key,
                child: Text(
                  '${option.key}. ${option.text}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: palette.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) widget.onChanged(value);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Group card
// ─────────────────────────────────────────────────────────

/// A card wrapping one question group: type label, question range,
/// instructions and every question in the group.
class QuestionGroupCard extends StatelessWidget {
  const QuestionGroupCard({
    super.key,
    required this.group,
    required this.answers,
    required this.flagged,
    required this.onAnswer,
    required this.onToggleFlag,
    required this.strict,
    this.showInstructions = true,
  });

  final QuestionGroup group;

  /// Effective answers (already merged with local drafts by the section).
  final Map<String, String> answers;
  final Set<String> flagged;

  /// Called with the question id and the new answer value.
  final void Function(String questionId, String value) onAnswer;
  final ValueChanged<String> onToggleFlag;
  final bool strict;
  final bool showInstructions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final numbers = group.questions.map((q) => q.number).toList()..sort();
    final range = numbers.isEmpty
        ? ''
        : numbers.length == 1
            ? '${numbers.first}'
            : '${numbers.first}–${numbers.last}';

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    questionGroupTypeLabel(group.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Câu $range',
                style: AppTextStyles.labelSmall.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          if (showInstructions && group.instructions.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              group.instructions.trim(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          for (var i = 0; i < group.questions.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            QuestionRenderer(
              group: group,
              question: group.questions[i],
              value: answers[group.questions[i].id],
              onChanged: (value) => onAnswer(group.questions[i].id, value),
              strict: strict,
              showGroupInstructions: false,
              flagged: flagged.contains(group.questions[i].id),
              onToggleFlag: () => onToggleFlag(group.questions[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Small pieces
// ─────────────────────────────────────────────────────────

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Center(
        child: Text(
          '$number',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PromptText extends StatelessWidget {
  const _PromptText({required this.prompt});

  final String prompt;

  static final RegExp _blankPattern = RegExp(r'_{2,}');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final baseStyle = AppTextStyles.bodyLarge.copyWith(
      fontSize: 15.5,
      height: 1.55,
      color: palette.textPrimary,
    );

    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in _blankPattern.allMatches(prompt)) {
      if (match.start > index) {
        spans.add(TextSpan(text: prompt.substring(index, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: baseStyle.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
          ),
        ),
      );
      index = match.end;
    }
    if (index < prompt.length) {
      spans.add(TextSpan(text: prompt.substring(index)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: baseStyle,
    );
  }
}

class _FlagButton extends StatelessWidget {
  const _FlagButton({
    required this.flagged,
    required this.onPressed,
  });

  final bool flagged;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = flagged ? AppColors.warning : palette.textHint;

    return IconButton(
      onPressed: onPressed,
      tooltip: flagged ? 'Bỏ đánh dấu' : 'Đánh dấu câu hỏi',
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      iconSize: 20,
      icon: Icon(
        flagged ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: color,
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final QuestionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const accent = AppColors.primary;

    return Semantics(
      button: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color:
                selected ? accent.withValues(alpha: 0.10) : palette.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : palette.divider.withValues(alpha: 0.7),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? accent
                      : palette.cardLight.withValues(alpha: 0.9),
                  border: Border.all(
                    color: selected ? accent : palette.divider,
                  ),
                ),
                child: Center(
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : Text(
                          option.key,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '${option.key}. ${option.text}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: palette.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TriStateChip extends StatelessWidget {
  const _TriStateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const accent = AppColors.primary;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      backgroundColor: palette.background,
      selectedColor: accent.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected ? accent : palette.divider.withValues(alpha: 0.7),
        width: selected ? 1.4 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: selected ? accent : palette.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12.5,
      ),
    );
  }
}
