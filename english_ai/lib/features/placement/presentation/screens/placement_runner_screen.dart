import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/placement_models.dart';
import '../providers/placement_provider.dart';

class PlacementRunnerScreen extends ConsumerWidget {
  final PlacementSessionModel session;

  const PlacementRunnerScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(placementProvider);
    final current = session.current;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Thoát',
          icon: Icon(Icons.close_rounded, color: context.palette.textSecondary),
          onPressed: () => _confirmExit(context),
        ),
        title: Text(
          _stageTitle(current),
          style: AppTextStyles.titleMedium.copyWith(
            color: context.palette.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _ModeChip(mode: session.mode),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _GlobalProgress(session: session),
            if (state.errorMessage != null)
              _InlineError(
                message: state.errorMessage!,
                onDismiss: ref.read(placementProvider.notifier).clearError,
              ),
            Expanded(
              child: switch (current.section) {
                'receptive' => _ReceptiveSection(
                    key: ValueKey(
                      'receptive-${current.skill}-${current.stage}-${current.stageToken}',
                    ),
                    session: session,
                  ),
                'writing' => _WritingSection(
                    key: ValueKey(
                      'writing-${current.stageToken}-${current.submittedTaskIds.length}',
                    ),
                    session: session,
                  ),
                'speaking' => _SpeakingSection(
                    key: ValueKey(
                      'speaking-${current.stageToken}-${current.submittedTaskIds.length}',
                    ),
                    session: session,
                  ),
                _ => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thoát bài kiểm tra?'),
        content: const Text(
          'Tiến trình đã được lưu. Bạn có thể tiếp tục sau khi quay lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Tiếp tục làm'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    if (shouldExit == true && context.mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/learn');
      }
    }
  }
}

String _stageTitle(PlacementCurrentModel current) {
  switch (current.section) {
    case 'receptive':
      final label = _skillLabel(current.skill);
      return current.stageCount > 1
          ? '$label · Chặng ${current.stage}/${current.stageCount}'
          : label;
    case 'writing':
      return 'Bài viết';
    case 'speaking':
      return 'Bài nói';
    default:
      return 'Đang tổng hợp kết quả';
  }
}

class _ModeChip extends StatelessWidget {
  final String mode;

  const _ModeChip({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mode.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _GlobalProgress extends StatelessWidget {
  final PlacementSessionModel session;

  const _GlobalProgress({required this.session});

  @override
  Widget build(BuildContext context) {
    final progress = session.progress;
    final value = (progress.percent / 100).clamp(0.0, 1.0);
    final current = session.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenPaddingH,
        0,
        AppDimensions.screenPaddingH,
        8,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ tổng thể',
                style: AppTextStyles.caption.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              Text(
                current.isReceptive
                    ? '${current.skill == 'listening' ? 'Nghe' : current.skill == 'reading' ? 'Đọc' : 'Ngữ pháp'}'
                    : current.section == 'writing'
                        ? 'Viết'
                        : 'Nói',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: context.palette.cardLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _InlineError({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.screenPaddingH,
        4,
        AppDimensions.screenPaddingH,
        6,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 17, color: AppColors.error),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
          ),
          InkWell(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.close_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Receptive section
// ──────────────────────────────────────────────

class _ReceptiveSection extends ConsumerStatefulWidget {
  final PlacementSessionModel session;

  const _ReceptiveSection({super.key, required this.session});

  @override
  ConsumerState<_ReceptiveSection> createState() => _ReceptiveSectionState();
}

class _ReceptiveSectionState extends ConsumerState<_ReceptiveSection> {
  late final AudioPlayer _player;
  StreamSubscription<void>? _playerComplete;
  Timer? _timer;

  late int _index;
  late Map<String, List<String>> _answers;
  late int _remaining;
  final Map<String, int> _responseTimes = {};
  final Map<String, int> _playCounts = {};
  DateTime _itemStartedAt = DateTime.now();
  bool _isPlaying = false;
  bool _submitting = false;
  bool _autoSubmitted = false;

  PlacementCurrentModel get _current => widget.session.current;
  PlacementItemModel get _item => _current.items[_index];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _playerComplete = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    _answers = {
      for (final entry in _current.answers.entries)
        entry.key: List<String>.from(entry.value),
    };
    _index = _firstUnansweredIndex();
    _remaining = _current.timeRemainingSeconds;
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPlay());
  }

  int _firstUnansweredIndex() {
    for (var i = 0; i < _current.items.length; i++) {
      final answer = _answers[_current.items[i].id];
      if (answer == null || answer.isEmpty) return i;
    }
    return 0;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        setState(() => _remaining = 0);
        timer.cancel();
        if (!_autoSubmitted && !_submitting) {
          _autoSubmitted = true;
          _completeStage(auto: true);
        }
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  Future<void> _autoPlay() async {
    if (!mounted) return;
    final item = _item;
    if (item.skill != 'listening' || item.audioUrl == null) return;
    final played = _playCounts[item.id] ?? 0;
    if (played >= item.playLimit) return;
    await _playAudio();
  }

  Future<void> _playAudio() async {
    final item = _item;
    if (item.audioUrl == null) return;
    final played = _playCounts[item.id] ?? 0;
    if (played >= item.playLimit) {
      _showSnack('Bạn đã dùng hết ${item.playLimit} lượt nghe cho câu này.');
      return;
    }
    try {
      _playCounts[item.id] = played + 1;
      setState(() => _isPlaying = true);
      await _player.stop();
      await _player.play(UrlSource(AppConfig.resolveMediaUrl(item.audioUrl!)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPlaying = false);
      _showSnack('Không phát được audio. Kiểm tra kết nối và thử lại.');
    }
  }

  Future<void> _next() async {
    final selected = _answers[_item.id] ?? const <String>[];
    if (selected.isEmpty) {
      _showSnack('Hãy chọn một đáp án trước khi tiếp tục.');
      return;
    }
    final elapsed = DateTime.now().difference(_itemStartedAt).inMilliseconds;
    _responseTimes[_item.id] = elapsed;
    final isLast = _index == _current.items.length - 1;
    if (isLast) {
      await _completeStage();
      return;
    }
    final notifier = ref.read(placementProvider.notifier);
    final ok = await notifier.saveAnswer(
      itemId: _item.id,
      answer: selected,
      responseTimeMs: elapsed,
    );
    if (!ok || !mounted) return;
    setState(() {
      _index += 1;
      _itemStartedAt = DateTime.now();
      _isPlaying = false;
    });
    await _player.stop();
    await _autoPlay();
  }

  Future<void> _completeStage({bool auto = false}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final token = _current.stageToken;
    final notifier = ref.read(placementProvider.notifier);
    final ok = await notifier.completeStage(
      stageToken: token,
      answers: _answers,
      responseTimes: _responseTimes,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok && auto) {
      _showSnack('Hết giờ nhưng chưa thể gửi bài. Kiểm tra kết nối và thử lại.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerComplete?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final selected = _answers[item.id] ?? const <String>[];
    final isLast = _index == _current.items.length - 1;
    final isSaving = ref.watch(placementProvider).isSaving;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenPaddingH,
            2,
            AppDimensions.screenPaddingH,
            6,
          ),
          child: Row(
            children: [
              Text(
                'Câu ${_index + 1}/${_current.items.length}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _LevelChip(level: item.level),
              const Spacer(),
              _TimerPill(seconds: _remaining),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.screenPaddingH,
              4,
              AppDimensions.screenPaddingH,
              14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.skill == 'listening')
                  _ListeningCard(
                    item: item,
                    played: _playCounts[item.id] ?? 0,
                    isPlaying: _isPlaying,
                    onPlay: _playAudio,
                  ),
                if (item.passage != null && !item.passage!.isEmpty)
                  _PassageCard(passage: item.passage!),
                if (item.skill == 'use_of_english')
                  _InstructionCard(
                    icon: Icons.spellcheck_rounded,
                    text: 'Chọn đáp án đúng nhất để hoàn thành câu.',
                  ),
                Text(
                  item.stem,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: context.palette.textPrimary,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.isMultiSelect) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Có thể chọn nhiều đáp án.',
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ...item.options.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionTile(
                      option: option,
                      selected: selected.contains(option.key),
                      onTap: () {
                        setState(() {
                          if (item.isMultiSelect) {
                            final next = List<String>.from(selected);
                            if (next.contains(option.key)) {
                              next.remove(option.key);
                            } else {
                              next.add(option.key);
                            }
                            _answers[item.id] = next;
                          } else {
                            _answers[item.id] = [option.key];
                          }
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenPaddingH,
            10,
            AppDimensions.screenPaddingH,
            12,
          ),
          decoration: BoxDecoration(
            color: context.palette.background,
            border: Border(
              top: BorderSide(color: context.palette.divider),
            ),
          ),
          child: Row(
            children: [
              if (_index > 0) ...[
                Expanded(
                  child: AppButton(
                    text: 'Trước',
                    isOutlined: true,
                    onPressed: _submitting
                        ? null
                        : () {
                            setState(() {
                              _index -= 1;
                              _itemStartedAt = DateTime.now();
                            });
                          },
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: AppButton(
                  text: isLast
                      ? (_submitting ? 'Đang chuyển chặng...' : 'Hoàn thành chặng')
                      : 'Câu tiếp theo',
                  icon: isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded,
                  isLoading: _submitting || isSaving,
                  onPressed: (_submitting || isSaving) ? null : _next,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListeningCard extends StatelessWidget {
  final PlacementItemModel item;
  final int played;
  final bool isPlaying;
  final Future<void> Function() onPlay;

  const _ListeningCard({
    required this.item,
    required this.played,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final canPlay = played < item.playLimit;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.12),
            AppColors.secondary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: canPlay && !isPlaying ? onPlay : null,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: canPlay ? AppColors.primary : context.palette.divider,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying
                    ? Icons.graphic_eq_rounded
                    : canPlay
                        ? Icons.play_arrow_rounded
                        : Icons.volume_off_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPlaying ? 'Đang phát audio...' : 'Nghe đoạn ghi âm',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Còn ${item.playLimit - played} lượt nghe · '
                  'Audio tiếng Anh, có thể nghe lại trước khi chọn.',
                  style: AppTextStyles.caption.copyWith(
                    color: context.palette.textSecondary,
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

class _PassageCard extends StatelessWidget {
  final PlacementPassageModel passage;

  const _PassageCard({required this.passage});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (passage.title.isNotEmpty) ...[
            Text(
              passage.title,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: SingleChildScrollView(
              child: Text(
                passage.text,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.palette.textPrimary,
                  height: 1.65,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InstructionCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final PlacementOptionModel option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.1)
              : context.palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : context.palette.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : context.palette.cardLight,
              ),
              child: Text(
                option.key,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected ? Colors.white : context.palette.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.text,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Writing section
// ──────────────────────────────────────────────

class _WritingSection extends ConsumerStatefulWidget {
  final PlacementSessionModel session;

  const _WritingSection({super.key, required this.session});

  @override
  ConsumerState<_WritingSection> createState() => _WritingSectionState();
}

class _WritingSectionState extends ConsumerState<_WritingSection> {
  late final PlacementWritingTaskModel _task;
  late final TextEditingController _controller;
  Timer? _timer;
  late int _remaining;
  bool _submitting = false;
  bool _autoSubmitted = false;

  PlacementCurrentModel get _current => widget.session.current;

  @override
  void initState() {
    super.initState();
    _task = _current.writingTasks.firstWhere(
      (task) => !_current.submittedTaskIds.contains(task.id),
      orElse: () => _current.writingTasks.first,
    );
    _controller = TextEditingController(text: _current.drafts[_task.id] ?? '');
    _remaining = _current.timeRemainingSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        setState(() => _remaining = 0);
        timer.cancel();
        if (!_autoSubmitted && !_submitting) {
          _autoSubmitted = true;
          _submit(auto: true);
        }
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  int get _wordCount {
    final matches = RegExp(r"[\w'-]+").allMatches(_controller.text);
    return matches.length;
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (!auto) _showSnack('Hãy viết ít nhất một đoạn trước khi gửi bài.');
      return;
    }
    if (!auto && _wordCount < _task.minWords) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bài viết chưa đủ độ dài'),
          content: Text(
            'Bài viết hiện có $_wordCount từ, yêu cầu tối thiểu '
            '${_task.minWords} từ. Bạn vẫn muốn gửi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Viết thêm'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Vẫn gửi'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _submitting = true);
    final elapsed = (_task.timeMinutes * 60 - _remaining) * 1000;
    await ref.read(placementProvider.notifier).submitWriting(
          taskId: _task.id,
          text: text,
          responseTimeMs: elapsed < 0 ? 0 : elapsed,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (auto) {
      _showSnack('Đã hết thời gian. Bài viết được gửi tự động.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(placementProvider);
    final index = _current.writingTasks.indexWhere((t) => t.id == _task.id);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenPaddingH,
            2,
            AppDimensions.screenPaddingH,
            6,
          ),
          child: Row(
            children: [
              Text(
                'Bài ${index + 1}/${_current.writingTasks.length}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _LevelChip(level: _task.level),
              const Spacer(),
              _TimerPill(seconds: _remaining),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.screenPaddingH,
              4,
              AppDimensions.screenPaddingH,
              10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _task.title,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _task.prompt,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.palette.textPrimary,
                          height: 1.55,
                        ),
                      ),
                      if (_task.instructionsVi.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _task.instructionsVi,
                          style: AppTextStyles.caption.copyWith(
                            color: context.palette.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 14, color: context.palette.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${_task.timeMinutes} phút · ${_task.minWords}–${_task.maxWords} từ',
                            style: AppTextStyles.caption.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  maxLines: null,
                  minLines: 16,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.palette.textPrimary,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Viết bài của bạn bằng tiếng Anh tại đây...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: context.palette.textSecondary.withOpacity(0.7),
                    ),
                    filled: true,
                    fillColor: context.palette.surface,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.palette.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.palette.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$_wordCount từ',
                      style: AppTextStyles.caption.copyWith(
                        color: _wordCount >= _task.minWords
                            ? AppColors.success
                            : AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Tối thiểu ${_task.minWords} · tối đa ${_task.maxWords}',
                      style: AppTextStyles.caption.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenPaddingH,
            10,
            AppDimensions.screenPaddingH,
            12,
          ),
          decoration: BoxDecoration(
            color: context.palette.background,
            border: Border(top: BorderSide(color: context.palette.divider)),
          ),
          child: AppButton(
            text: 'Gửi bài viết',
            icon: Icons.send_rounded,
            isLoading: _submitting || state.isSubmitting,
            onPressed: (_submitting || state.isSubmitting) ? null : _submit,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Speaking section
// ──────────────────────────────────────────────

enum _SpeakingPhase { ready, prep, recording, analyzing, review }

class _SpeakingSection extends ConsumerStatefulWidget {
  final PlacementSessionModel session;

  const _SpeakingSection({super.key, required this.session});

  @override
  ConsumerState<_SpeakingSection> createState() => _SpeakingSectionState();
}

class _SpeakingSectionState extends ConsumerState<_SpeakingSection> {
  late final PlacementSpeakingTaskModel _task;
  final AudioRecordingService _recorder = AudioRecordingService();
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  _SpeakingPhase _phase = _SpeakingPhase.ready;
  int _seconds = 0;
  Uint8List? _audioBytes;
  bool _submitting = false;

  PlacementCurrentModel get _current => widget.session.current;

  @override
  void initState() {
    super.initState();
    _task = _current.speakingTasks.firstWhere(
      (task) => !_current.submittedTaskIds.contains(task.id),
      orElse: () => _current.speakingTasks.first,
    );
    _seconds = _task.prepSeconds;
  }

  void _startPrep() {
    if (_phase != _SpeakingPhase.ready) return;
    setState(() {
      _phase = _SpeakingPhase.prep;
      _seconds = _task.prepSeconds;
    });
    _startTimer(_onPrepTick);
  }

  void _startTimer(void Function() onTick) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      onTick();
    });
  }

  void _onPrepTick() {
    if (_seconds <= 1) {
      _timer?.cancel();
      _startRecording();
      return;
    }
    setState(() => _seconds -= 1);
  }

  Future<void> _startRecording() async {
    _timer?.cancel();
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showSnack('Cần quyền micro để làm bài nói. Hãy bật quyền trong cài đặt.');
        if (mounted) setState(() => _phase = _SpeakingPhase.ready);
        return;
      }
      await _recorder.startRecording();
      if (!mounted) return;
      setState(() {
        _phase = _SpeakingPhase.recording;
        _seconds = _task.responseSeconds;
      });
      _startTimer(_onRecordTick);
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _SpeakingPhase.ready);
      _showSnack('Không thể bắt đầu ghi âm. Kiểm tra micro và thử lại.');
    }
  }

  void _onRecordTick() {
    if (_seconds <= 1) {
      _timer?.cancel();
      _stopRecording();
      return;
    }
    setState(() => _seconds -= 1);
  }

  Future<void> _stopRecording() async {
    if (_phase != _SpeakingPhase.recording) return;
    _timer?.cancel();
    setState(() => _phase = _SpeakingPhase.analyzing);
    try {
      final bytes = await _recorder.stopRecording();
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _phase = _SpeakingPhase.ready);
        _showSnack('Không thu được âm thanh. Hãy thử ghi âm lại.');
        return;
      }
      setState(() {
        _audioBytes = bytes;
        _phase = _SpeakingPhase.review;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _SpeakingPhase.ready);
      _showSnack('Không thể lưu bản ghi âm. Hãy thử lại.');
    }
  }

  Future<void> _playRecording() async {
    final bytes = _audioBytes;
    if (bytes == null) return;
    try {
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (_) {
      _showSnack('Không phát lại được bản ghi âm.');
    }
  }

  Future<void> _submit() async {
    final bytes = _audioBytes;
    if (bytes == null) {
      _showSnack('Hãy ghi âm câu trả lời trước khi gửi.');
      return;
    }
    setState(() => _submitting = true);
    await ref.read(placementProvider.notifier).submitSpeaking(
          taskId: _task.id,
          audioBytes: bytes,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  Future<void> _skip() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bỏ qua nhiệm vụ nói?'),
        content: const Text(
          'Nhiệm vụ này sẽ được tính 0 điểm. Bạn có thể làm lại bài kiểm tra sau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Bỏ qua'),
          ),
        ],
      ),
    );
    if (proceed != true) return;
    if (!mounted) return;
    setState(() => _submitting = true);
    await ref.read(placementProvider.notifier).skipSpeaking(taskId: _task.id);
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _phase = _SpeakingPhase.ready;
      _seconds = _task.prepSeconds;
      _audioBytes = null;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.cancelRecording();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = _current.speakingTasks.indexWhere((t) => t.id == _task.id);
    final state = ref.watch(placementProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenPaddingH,
            2,
            AppDimensions.screenPaddingH,
            6,
          ),
          child: Row(
            children: [
              Text(
                'Nhiệm vụ ${index + 1}/${_current.speakingTasks.length}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _LevelChip(level: _task.level),
              const Spacer(),
              _PhaseChip(phase: _phase),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.screenPaddingH,
              4,
              AppDimensions.screenPaddingH,
              14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _taskTypeLabel(_task.type),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Chuẩn bị ${_task.prepSeconds}s · Nói ${_task.responseSeconds}s',
                            style: AppTextStyles.caption.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _task.title,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _task.prompt,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.palette.textPrimary,
                          height: 1.55,
                        ),
                      ),
                      if (_task.bullets.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        ..._task.bullets.map(
                          (bullet) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(color: AppColors.primary)),
                                Expanded(
                                  child: Text(
                                    bullet,
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
                      if (_task.referenceText.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: context.palette.cardLight.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '“${_task.referenceText}”',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.palette.textPrimary,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Center(child: _SpeakingControl(
                  phase: _phase,
                  seconds: _seconds,
                  task: _task,
                  hasRecording: _audioBytes != null,
                  onStartPrep: _startPrep,
                  onStop: _stopRecording,
                  onPlay: _playRecording,
                  onReset: _reset,
                  onSkip: _skip,
                  isSubmitting: _submitting || state.isSubmitting,
                  onSubmit: _submit,
                )),
                const SizedBox(height: 14),
                Text(
                  'Bài nói được AI chấm theo 5 tiêu chí CEFR: phát âm, trôi chảy, '
                  'từ vựng, ngữ pháp và mức độ hoàn thành nhiệm vụ.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: context.palette.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeakingControl extends StatelessWidget {
  final _SpeakingPhase phase;
  final int seconds;
  final PlacementSpeakingTaskModel task;
  final bool hasRecording;
  final VoidCallback onStartPrep;
  final VoidCallback onStop;
  final VoidCallback onPlay;
  final VoidCallback onReset;
  final VoidCallback onSkip;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  const _SpeakingControl({
    required this.phase,
    required this.seconds,
    required this.task,
    required this.hasRecording,
    required this.onStartPrep,
    required this.onStop,
    required this.onPlay,
    required this.onReset,
    required this.onSkip,
    required this.onSubmit,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    final isPrep = phase == _SpeakingPhase.prep;
    final isRecording = phase == _SpeakingPhase.recording;
    final isAnalyzing = phase == _SpeakingPhase.analyzing;
    final isReview = phase == _SpeakingPhase.review;

    return Column(
      children: [
        if (isPrep) ...[
          Text(
            'Chuẩn bị trong $seconds giây',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (isRecording) ...[
          Text(
            'Đang ghi âm · còn $seconds giây',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
        ],
        InkWell(
          onTap: () {
            if (phase == _SpeakingPhase.ready) onStartPrep();
            if (isRecording) onStop();
          },
          borderRadius: BorderRadius.circular(60),
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isRecording
                    ? [AppColors.error, AppColors.accent]
                    : [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isRecording ? AppColors.error : AppColors.primary)
                      .withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              isRecording
                  ? Icons.stop_rounded
                  : isAnalyzing
                      ? Icons.hourglass_top_rounded
                      : Icons.mic_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          switch (phase) {
            _SpeakingPhase.ready => 'Nhấn để bắt đầu chuẩn bị',
            _SpeakingPhase.prep => 'Hít thở sâu và chuẩn bị ý',
            _SpeakingPhase.recording => 'Nhấn để dừng ghi âm',
            _SpeakingPhase.analyzing => 'Đang xử lý bản ghi...',
            _SpeakingPhase.review => 'Nghe lại trước khi gửi',
          },
          style: AppTextStyles.bodySmall.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        if (isReview) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: AppButton(
                  text: 'Nghe lại',
                  icon: Icons.play_arrow_rounded,
                  isOutlined: true,
                  onPressed: hasRecording ? onPlay : null,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: AppButton(
                  text: 'Ghi lại',
                  icon: Icons.refresh_rounded,
                  isOutlined: true,
                  onPressed: isSubmitting ? null : onReset,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          AppButton(
            text: 'Gửi bài nói',
            icon: Icons.send_rounded,
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : onSubmit,
          ),
        ],
        if (phase == _SpeakingPhase.ready) ...[
          AppButton(
            text: 'Bắt đầu chuẩn bị',
            icon: Icons.timer_rounded,
            onPressed: onStartPrep,
          ),
          const SizedBox(height: 7),
          TextButton(
            onPressed: isSubmitting ? null : onSkip,
            child: Text(
              'Bỏ qua nhiệm vụ này',
              style: AppTextStyles.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Small shared widgets
// ──────────────────────────────────────────────

class _LevelChip extends StatelessWidget {
  final String level;

  const _LevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  final int seconds;

  const _TimerPill({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 60;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: (urgent ? AppColors.error : AppColors.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: urgent ? AppColors.error : AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '$minutes:${rest.toString().padLeft(2, '0')}',
            style: AppTextStyles.caption.copyWith(
              color: urgent ? AppColors.error : AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final _SpeakingPhase phase;

  const _PhaseChip({required this.phase});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      _SpeakingPhase.ready => ('Sẵn sàng', AppColors.primary),
      _SpeakingPhase.prep => ('Chuẩn bị', AppColors.secondary),
      _SpeakingPhase.recording => ('Đang ghi', AppColors.error),
      _SpeakingPhase.analyzing => ('Đang xử lý', AppColors.accent),
      _SpeakingPhase.review => ('Đã ghi', AppColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _taskTypeLabel(String type) {
  switch (type) {
    case 'read_aloud':
      return 'Đọc to';
    case 'discussion':
      return 'Thảo luận';
    default:
      return 'Độc thoại';
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
