import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/mock_test_provider.dart';
import '../sections/listening_section.dart';
import '../sections/reading_section.dart';
import '../sections/speaking_section.dart';
import '../sections/writing_section.dart';
import '../widgets/exam_timer_bar.dart';
import '../widgets/section_bridge.dart';

/// The exam runner. It renders whichever section the provider says is active
/// and owns the submit confirmation, pause overlay and exit guard.
class MockTestRunnerScreen extends ConsumerStatefulWidget {
  const MockTestRunnerScreen({super.key});

  @override
  ConsumerState<MockTestRunnerScreen> createState() =>
      _MockTestRunnerScreenState();
}

class _MockTestRunnerScreenState extends ConsumerState<MockTestRunnerScreen> {
  bool _navigatedToResult = false;
  bool _busyNext = false;
  bool _confirmingSubmit = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockTestProvider);
    final palette = context.palette;

    if (state.phase == MockTestPhase.result) {
      _scheduleResultRedirect();
      return _buildWaiting(context, 'Đang mở kết quả bài thi...');
    }

    final inExam = state.phase == MockTestPhase.running ||
        state.phase == MockTestPhase.sectionDone ||
        state.phase == MockTestPhase.evaluating;

    return PopScope(
      canPop: !inExam,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExit(state);
      },
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, state, inExam),
                  if (state.phase == MockTestPhase.running) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: ExamTimerBar(
                        remainingSeconds: state.remainingSeconds,
                        totalSeconds: _sectionDuration(state),
                        paused: state.paused,
                        onPause: state.isPractice
                            ? () => ref.read(mockTestProvider.notifier).pause()
                            : null,
                        onResume: state.isPractice
                            ? () => ref.read(mockTestProvider.notifier).resume()
                            : null,
                      ),
                    ),
                    if (state.error != null)
                      _buildSaveErrorBanner(context, state.error!),
                  ],
                  Expanded(child: _buildBody(context, state)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    MockTestState state,
    bool inExam,
  ) {
    final palette = context.palette;
    final skill = state.currentSkill;
    final isPractice = state.isPractice;
    final planned = state.plannedSkills;
    final currentIndex =
        skill == null ? -1 : planned.indexOf(skill);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            tooltip: inExam ? 'Thoát bài thi' : 'Đóng',
            onPressed: () {
              if (inExam) {
                _handleExit(state);
              } else {
                context.go('/mock-test');
              }
            },
            icon: const Icon(Icons.close_rounded),
            color: palette.textSecondary,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill == null
                      ? 'IELTS Mock Test'
                      : _skillLabel(skill),
                  style: AppTextStyles.h4.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  state.phase == MockTestPhase.sectionDone
                      ? 'Đã nộp phần thi'
                      : _sectionSubtitle(state),
                  style: AppTextStyles.caption.copyWith(
                    color: palette.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ModeChip(isPractice: isPractice),
              if (currentIndex >= 0 && planned.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Phần ${currentIndex + 1}/${planned.length}',
                  style: AppTextStyles.caption.copyWith(
                    color: palette.textHint,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _sectionSubtitle(MockTestState state) {
    final skill = state.currentSkill;
    final set = state.set;
    if (skill == null || set == null) return '';

    switch (skill) {
      case 'listening':
        final section = set.listening;
        if (section == null) return 'Listening';
        return '${section.parts.length} parts · ${section.totalQuestions} câu';
      case 'reading':
        final section = set.reading;
        if (section == null) return 'Reading';
        return '${section.passages.length} passages · ${section.totalQuestions} câu';
      case 'writing':
        final section = set.writing;
        if (section == null) return 'Writing';
        return '${section.tasks.length} tasks · 60 phút';
      case 'speaking':
        return '3 parts · 11–14 phút';
      default:
        return '';
    }
  }

  // ── Body switch ─────────────────────────────────────────

  Widget _buildBody(BuildContext context, MockTestState state) {
    switch (state.phase) {
      case MockTestPhase.running:
        return _buildRunning(context, state);
      case MockTestPhase.sectionDone:
        return _buildSectionDone(context, state);
      case MockTestPhase.evaluating:
        return const _EvaluatingView();
      case MockTestPhase.error:
        return _buildError(context, state);
      case MockTestPhase.loading:
        return _buildWaiting(context, 'Đang chuẩn bị bài thi...');
      default:
        return _buildNoAttempt(context);
    }
  }

  Widget _buildRunning(BuildContext context, MockTestState state) {
    if (state.remainingSeconds <= 0 &&
        !state.paused &&
        !state.submitting &&
        state.phase == MockTestPhase.running) {
      return _buildMessage(
        context,
        icon: Icons.timer_off_rounded,
        color: AppColors.error,
        title: 'Đã hết giờ',
        message:
            'Hệ thống chưa nộp được phần thi do lỗi kết nối. Hãy nộp lại ngay để '
            'giữ câu trả lời của bạn.',
        actionLabel: 'Nộp phần thi',
        onAction: _retrySubmit,
      );
    }

    final section = _buildSection(state);
    if (section == null) {
      return _buildMessage(
        context,
        icon: Icons.inbox_rounded,
        color: AppColors.warning,
        title: 'Phần thi chưa sẵn sàng',
        message:
            'Bộ đề này không có dữ liệu cho phần ${_skillLabel(state.currentSkill ?? '')}. '
            'Hãy quay lại phòng thi và chọn bộ đề khác.',
        actionLabel: 'Về phòng thi',
        onAction: () => context.go('/mock-test'),
      );
    }

    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: section,
    );

    if (!state.paused) return padded;

    return Stack(
      children: [
        Positioned.fill(child: AbsorbPointer(child: padded)),
        Positioned.fill(
          child: _PausedOverlay(
            onResume: () => ref.read(mockTestProvider.notifier).resume(),
          ),
        ),
      ],
    );
  }

  Widget? _buildSection(MockTestState state) {
    final skill = state.currentSkill;
    final set = state.set;
    if (skill == null || set == null) return null;

    final notifier = ref.read(mockTestProvider.notifier);

    switch (skill) {
      case 'listening':
        final section = set.listening;
        if (section == null) return null;
        return ListeningSectionView(
          key: const ValueKey<String>('mock-listening'),
          section: section,
          answers: state.currentAnswers,
          flagged: state.currentFlagged,
          onAnswer: notifier.setAnswer,
          onToggleFlag: notifier.toggleFlag,
          onRequestSubmit: _confirmSubmit,
          strict: state.isStrict,
        );
      case 'reading':
        final section = set.reading;
        if (section == null) return null;
        return ReadingSectionView(
          key: const ValueKey<String>('mock-reading'),
          section: section,
          answers: state.currentAnswers,
          flagged: state.currentFlagged,
          onAnswer: notifier.setAnswer,
          onToggleFlag: notifier.toggleFlag,
          onRequestSubmit: _confirmSubmit,
        );
      case 'writing':
        final section = set.writing;
        if (section == null) return null;
        return WritingSectionView(
          key: const ValueKey<String>('mock-writing'),
          section: section,
          answers: state.currentAnswers,
          onAnswer: (taskId, text) => notifier.setAnswer(taskId, text),
          onRequestSubmit: _confirmSubmit,
          strict: state.isStrict,
        );
      case 'speaking':
        final section = set.speaking;
        if (section == null) return null;
        return SpeakingSectionView(
          key: const ValueKey<String>('mock-speaking'),
          section: section,
          strict: state.isStrict,
          onCompleted: (part1Qa, part2Answer, part3Qa, followUpQa) {
            _submitSpeaking(part1Qa, part2Answer, part3Qa, followUpQa);
          },
          onPayloadChanged: (payload) {
            ref
                .read(mockTestProvider.notifier)
                .setSpeakingAutoBody(payload);
          },
        );
      default:
        return null;
    }
  }

  Widget _buildSectionDone(BuildContext context, MockTestState state) {
    final score = state.currentScore;
    if (score == null) {
      return _buildMessage(
        context,
        icon: Icons.hourglass_empty_rounded,
        color: AppColors.warning,
        title: 'Chưa có kết quả phần thi',
        message: 'Không tìm thấy điểm của phần thi vừa nộp.',
        actionLabel: 'Về phòng thi',
        onAction: () => context.go('/mock-test'),
      );
    }

    final remaining = state.plannedSkills
        .where((skill) => !state.scores.containsKey(skill))
        .length;
    final isLast = remaining == 0;

    return SectionBridge(
      skillLabel: _skillLabel(score.skill),
      band: score.band,
      rawScore: score.rawScore,
      total: score.total,
      comment: score.comment,
      isLast: isLast,
      loading: _busyNext,
      onNext: _handleNext,
    );
  }

  Widget _buildError(BuildContext context, MockTestState state) {
    return _buildMessage(
      context,
      icon: Icons.error_outline_rounded,
      color: AppColors.error,
      title: 'Không thể tiếp tục bài thi',
      message: state.error ??
          'Đã xảy ra lỗi khi kết nối máy chủ. Tiến độ của bạn vẫn được lưu.',
      actionLabel: state.attempt == null ? 'Về phòng thi' : 'Thử lại',
      onAction: state.attempt == null ? () => context.go('/mock-test') : _retry,
      secondaryLabel: state.attempt == null ? null : 'Về phòng thi',
      onSecondary: state.attempt == null ? null : () => context.go('/mock-test'),
    );
  }

  Widget _buildNoAttempt(BuildContext context) {
    return _buildMessage(
      context,
      icon: Icons.play_circle_outline_rounded,
      color: AppColors.primary,
      title: 'Chưa có bài thi nào đang diễn ra',
      message:
          'Hãy chọn một bộ đề trong phòng thi để bắt đầu. Bài thi đang làm dở sẽ '
          'được khôi phục tự động.',
      actionLabel: 'Về phòng thi',
      onAction: () => context.go('/mock-test'),
    );
  }

  Widget _buildWaiting(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveErrorBanner(BuildContext context, String message) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.warning,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                color: palette.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => ref.read(mockTestProvider.notifier).saveNow(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Lưu lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    final palette = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 8),
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────

  Future<void> _confirmSubmit() async {
    if (_confirmingSubmit) return;
    final state = ref.read(mockTestProvider);
    if (state.phase != MockTestPhase.running) return;
    if (state.currentSkill == 'speaking') return;

    final skill = state.currentSkill ?? '';
    final total = _questionTotal(state);
    final answered = _answeredCount(state);
    final unit = skill == 'writing' ? 'bài' : 'câu';

    _confirmingSubmit = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.palette;
        return AlertDialog(
          backgroundColor: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Nộp phần ${_skillLabel(skill)}?',
            style: AppTextStyles.h4.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn đã trả lời $answered/$total $unit.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              if (total > 0 && answered < total) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Còn ${total - answered} $unit chưa trả lời. '
                          'Sau khi nộp, bạn không thể sửa lại phần này.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: palette.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Sau khi nộp, bạn không thể sửa lại phần này.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Tiếp tục làm'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Nộp section'),
            ),
          ],
        );
      },
    );
    _confirmingSubmit = false;

    if (confirmed != true || !mounted) return;

    final notifier = ref.read(mockTestProvider.notifier);
    await notifier.saveNow();
    if (!mounted) return;

    final ok = await notifier.submitCurrentSection();
    if (!ok && mounted) {
      final error = ref.read(mockTestProvider).error;
      _showSnack(error ?? 'Không thể nộp phần thi. Vui lòng thử lại.');
    }
  }

  Future<void> _submitSpeaking(
    List<Map<String, String>> part1Qa,
    String part2Answer,
    List<Map<String, String>> part3Qa,
    List<Map<String, String>> followUpQa,
  ) async {
    final ok = await ref.read(mockTestProvider.notifier).submitCurrentSection(
      extraBody: <String, dynamic>{
        'part1_qa': part1Qa,
        'part2_answer': part2Answer,
        'part3_qa': part3Qa,
        'follow_up_qa': followUpQa,
      },
    );
    if (!ok && mounted) {
      final error = ref.read(mockTestProvider).error;
      _showSnack(error ?? 'Không thể nộp phần Speaking. Vui lòng thử lại.');
    }
  }

  Future<void> _retrySubmit() async {
    final ok = await ref.read(mockTestProvider.notifier).submitCurrentSection();
    if (!ok && mounted) {
      final error = ref.read(mockTestProvider).error;
      _showSnack(error ?? 'Vẫn chưa thể nộp bài. Vui lòng kiểm tra kết nối.');
    }
  }

  Future<void> _handleNext() async {
    if (_busyNext) return;
    setState(() => _busyNext = true);

    final ok = await ref.read(mockTestProvider.notifier).nextSection();
    if (!mounted) return;
    setState(() => _busyNext = false);

    if (!ok) {
      final error = ref.read(mockTestProvider).error;
      _showSnack(error ?? 'Không thể chuyển phần thi. Vui lòng thử lại.');
      return;
    }
    if (ref.read(mockTestProvider).phase == MockTestPhase.result) {
      _scheduleResultRedirect();
    }
  }

  Future<void> _retry() async {
    final state = ref.read(mockTestProvider);
    if (state.attempt == null) {
      if (mounted) context.go('/mock-test');
      return;
    }
    final completed = await ref.read(mockTestProvider.notifier).complete();
    if (!mounted) return;
    if (completed) {
      _scheduleResultRedirect();
    } else {
      final error = ref.read(mockTestProvider).error;
      _showSnack(error ?? 'Vẫn chưa thể hoàn tất bài thi. Vui lòng thử lại.');
    }
  }

  Future<void> _handleExit(MockTestState state) async {
    if (state.phase == MockTestPhase.evaluating) {
      _showSnack('Hệ thống đang chấm bài. Vui lòng chờ trong giây lát.');
      return;
    }

    if (state.isStrict) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final palette = dialogContext.palette;
          return AlertDialog(
            backgroundColor: palette.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            icon: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.warning,
              size: 32,
            ),
            title: Text(
              'Không thể thoát giữa bài thi',
              style: AppTextStyles.h4.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              'Chế độ thi thật không cho phép thoát hoặc tạm dừng. '
              'Hãy hoàn thành bài thi để nhận kết quả.',
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ở lại bài thi'),
              ),
            ],
          );
        },
      );
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.palette;
        return AlertDialog(
          backgroundColor: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Thoát bài thi?',
            style: AppTextStyles.h4.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Bài thi luyện tập sẽ được tạm dừng. Bạn có thể tiếp tục từ phòng thi '
            'bất cứ lúc nào.',
            style: AppTextStyles.bodySmall.copyWith(
              color: palette.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Ở lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tạm dừng & thoát'),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true || !mounted) return;
    if (state.phase == MockTestPhase.running) {
      ref.read(mockTestProvider.notifier).pause();
    }
    context.go('/mock-test');
  }

  void _scheduleResultRedirect() {
    if (_navigatedToResult) return;
    _navigatedToResult = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.pushReplacement('/mock-test/result');
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ── Data helpers ────────────────────────────────────────

  int? _sectionDuration(MockTestState state) {
    final skill = state.currentSkill;
    if (skill == null) return null;

    final attempt = state.attempt;
    if (attempt != null) {
      for (final section in attempt.sections) {
        if (section.skill == skill && section.durationSeconds > 0) {
          return section.durationSeconds;
        }
      }
    }

    final set = state.set;
    if (set == null) return null;
    switch (skill) {
      case 'listening':
        return set.listening?.durationSeconds;
      case 'reading':
        return set.reading?.durationSeconds;
      case 'writing':
        return set.writing?.durationSeconds;
      case 'speaking':
        return set.speaking?.durationSeconds;
      default:
        return null;
    }
  }

  int _questionTotal(MockTestState state) {
    final set = state.set;
    final skill = state.currentSkill;
    if (set == null || skill == null) return 0;
    switch (skill) {
      case 'listening':
        return set.listening?.totalQuestions ?? 0;
      case 'reading':
        return set.reading?.totalQuestions ?? 0;
      case 'writing':
        return set.writing?.tasks.length ?? 0;
      default:
        return 0;
    }
  }

  int _answeredCount(MockTestState state) {
    final answers = state.currentAnswers;
    return answers.values.where((value) => value.trim().isNotEmpty).length;
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-views
// ─────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final bool isPractice;

  const _ModeChip({required this.isPractice});

  @override
  Widget build(BuildContext context) {
    final color = isPractice ? AppColors.secondary : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        isPractice ? 'Luyện tập' : 'Thi thật',
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  final VoidCallback onResume;

  const _PausedOverlay({required this.onResume});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      color: palette.background.withOpacity(0.97),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pause_rounded,
                color: AppColors.secondary,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Bài thi đang tạm dừng',
              style: AppTextStyles.h3.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Đồng hồ đã dừng. Bạn có thể tiếp tục khi đã sẵn sàng.',
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Tiếp tục làm bài'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluatingView extends StatefulWidget {
  const _EvaluatingView();

  @override
  State<_EvaluatingView> createState() => _EvaluatingViewState();
}

class _EvaluatingViewState extends State<_EvaluatingView> {
  static const List<String> _messages = <String>[
    'Đang chấm phần thi vừa nộp...',
    'AI đang phân tích câu trả lời của bạn...',
    'Đang đối chiếu đáp án và tính band...',
    'Sắp xong rồi, vui lòng chờ thêm một chút...',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 22),
            Text(
              'Đang tổng hợp kết quả',
              style: AppTextStyles.h3.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(
                _messages[_index],
                key: ValueKey<int>(_index),
                style: AppTextStyles.bodySmall.copyWith(
                  color: palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

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
          ? 'Bài thi'
          : skill[0].toUpperCase() + skill.substring(1);
  }
}
