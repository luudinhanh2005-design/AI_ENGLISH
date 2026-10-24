import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/mock_test_models.dart';

/// Writing section of the IELTS mock test.
///
/// Two tasks (Task 1 / Task 2) are edited in memory; the parent [answers] map
/// stays the source of truth and receives the drafts through [onAnswer] with a
/// short debounce. In strict mode the guidance bullets are hidden because they
/// are hints (see contract §4).
class WritingSectionView extends StatefulWidget {
  final WritingSection section;
  final Map<String, String> answers;
  final void Function(String taskId, String text) onAnswer;
  final VoidCallback onRequestSubmit;
  final bool strict;

  const WritingSectionView({
    super.key,
    required this.section,
    required this.answers,
    required this.onAnswer,
    required this.onRequestSubmit,
    required this.strict,
  });

  @override
  State<WritingSectionView> createState() => _WritingSectionViewState();
}

class _WritingSectionViewState extends State<WritingSectionView> {
  static const Duration _saveDebounce = Duration(milliseconds: 400);

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, Timer> _saveTimers = {};
  final FocusNode _editorFocus = FocusNode();
  int _taskIndex = 0;

  List<WritingTask> get _tasks => widget.section.tasks;

  @override
  void initState() {
    super.initState();
    for (final task in _tasks) {
      _controllers[task.id] = TextEditingController(
        text: widget.answers[task.id] ?? '',
      );
    }
    _editorFocus.addListener(_onEditorFocusChanged);
  }

  @override
  void dispose() {
    _editorFocus.removeListener(_onEditorFocusChanged);
    _editorFocus.dispose();
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Flushes the draft on blur so leaving the editor (tab switch, submit,
  /// section change) never drops the last debounce window.
  void _onEditorFocusChanged() {
    if (_editorFocus.hasFocus || _tasks.isEmpty) return;
    final index = _taskIndex.clamp(0, _tasks.length - 1);
    _flushTask(_tasks[index]);
  }

  TextEditingController? get _activeController {
    if (_tasks.isEmpty) return null;
    final index = _taskIndex.clamp(0, _tasks.length - 1);
    return _controllers[_tasks[index].id];
  }

  @override
  void didUpdateWidget(covariant WritingSectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pull external changes (e.g. a resumed attempt) into the controllers, but
    // never rewrite the field the candidate is currently typing in.
    for (final task in _tasks) {
      final controller = _controllers[task.id];
      if (controller == null) continue;
      if (identical(controller, _activeController) && _editorFocus.hasFocus) {
        continue;
      }
      final external = widget.answers[task.id] ?? '';
      if (external == controller.text) continue;
      if (controller.value.composing.isValid) continue;
      controller.value = TextEditingValue(
        text: external,
        selection: TextSelection.collapsed(offset: external.length),
      );
    }
  }

  // ── Draft persistence ───────────────────────────────────

  void _onTextChanged(WritingTask task, String text) {
    setState(() {});
    _saveTimers[task.id]?.cancel();
    _saveTimers[task.id] = Timer(_saveDebounce, () {
      widget.onAnswer(task.id, text);
    });
  }

  void _flushTask(WritingTask task) {
    _saveTimers.remove(task.id)?.cancel();
    final controller = _controllers[task.id];
    if (controller != null) widget.onAnswer(task.id, controller.text);
  }

  void _flushAll() {
    for (final task in _tasks) {
      _flushTask(task);
    }
  }

  void _selectTask(int index) {
    if (index == _taskIndex || index < 0 || index >= _tasks.length) return;
    _flushTask(_tasks[_taskIndex]);
    setState(() => _taskIndex = index);
  }

  Future<void> _clearTask(WritingTask task) async {
    if ((_controllers[task.id]?.text ?? '').trim().isEmpty) return;
    final palette = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Xoá bài Task ${task.task}?',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Toàn bộ nội dung bạn đã viết cho Task ${task.task} sẽ bị xoá và '
          'không thể khôi phục.',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Giữ bài'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Xoá bài',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _saveTimers.remove(task.id)?.cancel();
    _controllers[task.id]?.clear();
    widget.onAnswer(task.id, '');
    setState(() {});
  }

  static int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  // ── Submit ──────────────────────────────────────────────

  Future<void> _requestSubmit() async {
    _flushAll();

    final short = <String>[];
    for (final task in _tasks) {
      final words = _countWords(_controllers[task.id]?.text ?? '');
      if (words < task.minWords) {
        short.add(
          'Task ${task.task}: $words/${task.minWords} từ '
          '(còn thiếu ${task.minWords - words} từ)',
        );
      }
    }

    if (short.isNotEmpty) {
      final palette = context.palette;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 26,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bài viết chưa đủ độ dài',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bài thi Writing bị trừ điểm nếu viết dưới số từ tối thiểu. '
                'Bạn vẫn muốn nộp bài?',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              for (final line in short)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(color: AppColors.warning),
                      ),
                      Expanded(
                        child: Text(
                          line,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Viết tiếp'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Vẫn nộp bài',
                style: TextStyle(color: AppColors.warning),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    widget.onRequestSubmit();
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (_tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Đề Writing chưa có bài nào.',
            style: TextStyle(color: palette.textSecondary),
          ),
        ),
      );
    }

    final safeIndex = _taskIndex.clamp(0, _tasks.length - 1);
    final task = _tasks[safeIndex];
    final controller = _controllers[task.id]!;
    final words = _countWords(controller.text);

    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The runner caps the section at 900px, so use the viewport width
            // to decide the desktop split rather than the local constraint.
            final wide = MediaQuery.sizeOf(context).width > 900;
            final editorHeight = (MediaQuery.sizeOf(context).height * 0.62)
                .clamp(480.0, 860.0)
                .toDouble();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1360),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 14),
                      _buildTaskTabs(context, safeIndex),
                      const SizedBox(height: 16),
                      if (wide)
                        SizedBox(
                          height: editorHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 11,
                                child: SingleChildScrollView(
                                  child: _buildPromptCard(context, task),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 10,
                                child: SingleChildScrollView(
                                  child: _buildEditorCard(
                                    context,
                                    task,
                                    controller,
                                    words,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        _buildPromptCard(context, task),
                        const SizedBox(height: 14),
                        _buildEditorCard(context, task, controller, words),
                      ],
                      const SizedBox(height: 18),
                      _buildSubmitBar(context),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final palette = context.palette;
    final totalMinutes = widget.section.durationSeconds ~/ 60;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.writing.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.edit_note_rounded,
            color: AppColors.writing,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Writing',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                totalMinutes > 0
                    ? 'IELTS Writing · $totalMinutes phút cho 2 bài'
                    : 'IELTS Writing · 2 bài viết',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (widget.strict ? AppColors.error : AppColors.success)
                .withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.strict ? 'Thi thật' : 'Luyện tập',
            style: TextStyle(
              color: widget.strict ? AppColors.error : AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskTabs(BuildContext context, int safeIndex) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tasks.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == _tasks.length - 1 ? 0 : 6,
                ),
                child: _buildTab(context, _tasks[i], i == safeIndex, i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    WritingTask task,
    bool selected,
    int index,
  ) {
    final palette = context.palette;
    final words = _countWords(_controllers[task.id]?.text ?? '');
    final done = words >= task.minWords;
    return InkWell(
      onTap: () => _selectTask(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.writing.withOpacity(0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.writing.withOpacity(0.6)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? AppColors.writing : palette.textHint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Task ${task.task}',
                        style: TextStyle(
                          color: selected
                              ? palette.textPrimary
                              : palette.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: palette.cardLight,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          "${task.recommendedMinutes}'",
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.minWords} từ · $words từ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: done ? AppColors.success : palette.textHint,
                      fontSize: 10.5,
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

  // ── Prompt ──────────────────────────────────────────────

  Widget _buildPromptCard(BuildContext context, WritingTask task) {
    final palette = context.palette;
    final visual = task.visual;
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
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.writing.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'TASK ${task.task}',
                  style: const TextStyle(
                    color: AppColors.writing,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: palette.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${task.recommendedMinutes} phút',
                    style: TextStyle(color: palette.textHint, fontSize: 11.5),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 14,
                    color: palette.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'tối thiểu ${task.minWords} từ',
                    style: TextStyle(color: palette.textHint, fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            task.prompt,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14.5,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (visual != null) ...[
            const SizedBox(height: 16),
            _buildVisual(context, visual),
          ],
          if (!widget.strict && task.guidance.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildGuidance(context, task.guidance),
          ],
        ],
      ),
    );
  }

  Widget _buildVisual(BuildContext context, WritingVisual visual) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _visualIcon(visual.type),
                size: 20,
                color: AppColors.writing,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visual.title.isEmpty
                          ? 'Dữ liệu của đề bài'
                          : visual.title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _visualTypeLabel(visual.type),
                      style: TextStyle(
                        color: palette.textHint,
                        fontSize: 10.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (visual.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              visual.description,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          if (visual.data.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDataTable(context, visual),
          ],
        ],
      ),
    );
  }

  Widget _buildDataTable(BuildContext context, WritingVisual visual) {
    final palette = context.palette;
    final border = BorderSide(color: palette.divider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.4),
          1: FlexColumnWidth(1),
        },
        border: TableBorder(
          top: border,
          bottom: border,
          left: border,
          right: border,
          horizontalInside: border,
          verticalInside: border,
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.writing.withOpacity(0.10),
            ),
            children: [
              _tableCell(context, 'Hạng mục', header: true),
              _tableCell(context, 'Giá trị', header: true, alignRight: true),
            ],
          ),
          for (final datum in visual.data)
            TableRow(
              children: [
                _tableCell(context, datum.label),
                _tableCell(context, datum.value, alignRight: true),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tableCell(
    BuildContext context,
    String text, {
    bool header = false,
    bool alignRight = false,
  }) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: header ? palette.textPrimary : palette.textSecondary,
          fontSize: 12,
          fontWeight: header ? FontWeight.w700 : FontWeight.w400,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildGuidance(BuildContext context, List<String> guidance) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Gợi ý triển khai (chế độ luyện tập)',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in guidance)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        height: 1.45,
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

  // ── Editor ──────────────────────────────────────────────

  Widget _buildEditorCard(
    BuildContext context,
    WritingTask task,
    TextEditingController controller,
    int words,
  ) {
    final palette = context.palette;
    final remaining = task.minWords - words;
    final done = remaining <= 0;
    final counterColor = done ? AppColors.success : AppColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Text(
                'Bài làm Task ${task.task}',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: counterColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: counterColor.withOpacity(0.4)),
                ),
                child: Text(
                  '$words / ${task.minWords} từ',
                  style: TextStyle(
                    color: counterColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            done
                ? 'Đã đủ độ dài tối thiểu. Hãy dành thời gian soát lỗi ngữ pháp và từ vựng.'
                : 'Còn thiếu $remaining từ để đạt mức tối thiểu ${task.minWords} từ.',
            style: TextStyle(
              color: done ? palette.textSecondary : counterColor,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            focusNode: _editorFocus,
            onChanged: (value) => _onTextChanged(task, value),
            minLines: 18,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14.5,
              height: 1.7,
            ),
            decoration: InputDecoration(
              hintText:
                  'Viết bài của bạn bằng tiếng Anh tại đây. Bài viết được lưu '
                  'tự động khi bạn chuyển tab hoặc nộp bài.',
              hintStyle: TextStyle(
                color: palette.textHint,
                fontSize: 13,
                height: 1.6,
              ),
              filled: true,
              fillColor: palette.background,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.writing,
                  width: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.cloud_done_outlined,
                size: 14,
                color: palette.textHint,
              ),
              const SizedBox(width: 5),
              Text(
                'Tự động lưu',
                style: TextStyle(color: palette.textHint, fontSize: 11),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => unawaited(_clearTask(task)),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: palette.textSecondary,
                ),
                label: Text(
                  'Xoá bài',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar(BuildContext context) {
    final palette = context.palette;
    var underLength = false;
    var empty = true;
    for (final task in _tasks) {
      final text = _controllers[task.id]?.text ?? '';
      final words = _countWords(text);
      if (text.trim().isNotEmpty) empty = false;
      if (words < task.minWords) underLength = true;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nộp bài Writing',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                empty
                    ? 'Bạn chưa viết nội dung nào. Bài nộp trống sẽ nhận điểm rất thấp.'
                    : underLength
                        ? 'Một số bài chưa đạt số từ tối thiểu — bạn vẫn có thể nộp.'
                        : 'Cả hai bài đã đạt độ dài tối thiểu. Sẵn sàng nộp bài.',
                style: TextStyle(
                  color: empty || underLength
                      ? AppColors.warning
                      : palette.textSecondary,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          );

          final button = SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _requestSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.writing,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text(
                'Nộp bài Writing',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 10),
                button,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }

  static IconData _visualIcon(String type) {
    switch (type) {
      case 'bar_chart':
        return Icons.bar_chart_rounded;
      case 'line_graph':
      case 'line_chart':
        return Icons.show_chart_rounded;
      case 'pie_chart':
        return Icons.pie_chart_outline_rounded;
      case 'table':
        return Icons.table_chart_outlined;
      case 'process':
      case 'flow_chart':
        return Icons.account_tree_outlined;
      case 'map':
        return Icons.map_outlined;
      case 'diagram':
        return Icons.insights_rounded;
      case 'letter':
        return Icons.mail_outline_rounded;
      default:
        return Icons.insert_chart_outlined_rounded;
    }
  }

  static String _visualTypeLabel(String type) {
    switch (type) {
      case 'bar_chart':
        return 'BIỂU ĐỒ CỘT';
      case 'line_graph':
      case 'line_chart':
        return 'BIỂU ĐỒ ĐƯỜNG';
      case 'pie_chart':
        return 'BIỂU ĐỒ TRÒN';
      case 'table':
        return 'BẢNG SỐ LIỆU';
      case 'process':
      case 'flow_chart':
        return 'QUY TRÌNH';
      case 'map':
        return 'BẢN ĐỒ';
      case 'diagram':
        return 'SƠ ĐỒ';
      case 'letter':
        return 'THƯ';
      default:
        return type.isEmpty ? 'DỮ LIỆU' : type.toUpperCase();
    }
  }
}
