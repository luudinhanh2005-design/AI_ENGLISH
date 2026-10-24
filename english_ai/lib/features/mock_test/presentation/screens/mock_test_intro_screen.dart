import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/mock_test_models.dart';
import '../providers/mock_test_provider.dart';

/// Pre-exam briefing: rules per mode, device check, start button.
class MockTestIntroScreen extends ConsumerStatefulWidget {
  final String? setId;
  final String? mode;
  final List<String>? skills;

  const MockTestIntroScreen({
    super.key,
    this.setId,
    this.mode,
    this.skills,
  });

  @override
  ConsumerState<MockTestIntroScreen> createState() =>
      _MockTestIntroScreenState();
}

class _MockTestIntroScreenState extends ConsumerState<MockTestIntroScreen> {
  String? _setId;
  String _mode = 'strict';
  List<String>? _skills;

  bool _argsResolved = false;
  bool _starting = false;
  String? _startError;

  bool _testingAudio = false;
  String? _audioMessage;
  bool _audioFailed = false;
  AudioPlayer? _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsResolved) return;
    _argsResolved = true;
    _resolveArguments();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSetIfNeeded());
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  void _resolveArguments() {
    Object? extra;
    try {
      extra = GoRouterState.of(context).extra;
    } catch (_) {
      extra = null;
    }
    final map = _asMap(extra);

    _setId = widget.setId ??
        map['setId']?.toString() ??
        map['set_id']?.toString() ??
        map['id']?.toString();

    final rawMode = widget.mode ?? map['mode']?.toString();
    _mode = rawMode == 'practice' ? 'practice' : 'strict';

    final argumentSkills = widget.skills ?? _stringList(map['skills']);
    _skills = (argumentSkills == null || argumentSkills.isEmpty)
        ? null
        : argumentSkills;
  }

  Future<void> _loadSetIfNeeded() async {
    if (!mounted) return;
    final setId = _setId;
    if (setId == null || setId.isEmpty) return;

    final notifier = ref.read(mockTestProvider.notifier);
    final state = ref.read(mockTestProvider);

    if (state.phase == MockTestPhase.running ||
        state.phase == MockTestPhase.sectionDone ||
        state.phase == MockTestPhase.evaluating) {
      return;
    }
    if (state.set?.id == setId && state.phase != MockTestPhase.error) {
      return;
    }
    await notifier.loadSet(setId);
  }

  Future<void> _start(MockTestSet set) async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startError = null;
    });

    final ok = await ref
        .read(mockTestProvider.notifier)
        .start(set.id, _mode, skills: _skills);
    if (!mounted) return;

    if (ok) {
      context.pushReplacement('/mock-test/run');
      return;
    }

    setState(() {
      _starting = false;
      _startError = ref.read(mockTestProvider).error ??
          'Không thể bắt đầu bài thi. Vui lòng thử lại.';
    });
  }

  Future<void> _testJudgeVoice() async {
    if (_testingAudio) return;
    setState(() {
      _testingAudio = true;
      _audioMessage = null;
      _audioFailed = false;
    });

    final dio = ref.read(dioProvider);
    try {
      final response = await dio.post<dynamic>(
        ApiEndpoints.speechTts,
        data: <String, dynamic>{
          'text': 'Welcome to the IELTS mock test.',
        },
      );

      final data = response.data;
      String? audioUrl;
      if (data is Map) {
        final candidate = data['audio_url'] ?? data['url'] ?? data['audio'];
        audioUrl = candidate?.toString();
      }

      if (audioUrl == null || audioUrl.trim().isEmpty) {
        throw const FormatException('Missing audio url');
      }

      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(
        UrlSource(AppConfig.resolveMediaUrl(audioUrl.trim())),
      );

      if (!mounted) return;
      setState(() {
        _audioMessage =
            'Đang phát câu mẫu. Hãy kiểm tra âm lượng loa của bạn.';
        _audioFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _audioMessage =
            'Chưa phát được âm thanh mẫu. Hãy kiểm tra kết nối mạng và loa, '
            'hoặc bỏ qua bước này — bạn vẫn có thể làm bài bình thường.';
        _audioFailed = true;
      });
    } finally {
      if (mounted) setState(() => _testingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockTestProvider);
    final palette = context.palette;
    final set = state.set;
    final matches = set != null && (_setId == null || set.id == _setId);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 12),
                  if (_setId == null)
                    _MessageCard(
                      icon: Icons.link_off_rounded,
                      color: AppColors.error,
                      title: 'Thiếu thông tin bộ đề',
                      message:
                          'Không tìm thấy bộ đề cần thi. Hãy quay lại phòng thi và chọn lại.',
                      actionLabel: 'Về phòng thi',
                      onAction: () => context.go('/mock-test'),
                    )
                  else if (set == null || !matches)
                    _buildLoadingOrError(context, state)
                  else
                    _buildContent(context, state, set),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        IconButton(
          tooltip: 'Quay lại',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/mock-test');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          color: palette.textPrimary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHUẨN BỊ THI',
                style: AppTextStyles.overline.copyWith(
                  color: AppColors.secondary,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                'IELTS Mock Test',
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

  Widget _buildLoadingOrError(BuildContext context, MockTestState state) {
    if (state.phase == MockTestPhase.running ||
        state.phase == MockTestPhase.sectionDone ||
        state.phase == MockTestPhase.evaluating) {
      return Column(
        children: [
          _buildInProgressCard(context),
          const SizedBox(height: 12),
          _buildErrorHint(context),
        ],
      );
    }
    if (state.phase == MockTestPhase.error) {
      return _MessageCard(
        icon: Icons.cloud_off_rounded,
        color: AppColors.error,
        title: 'Không tải được bộ đề',
        message: state.error ?? 'Vui lòng kiểm tra kết nối và thử lại.',
        actionLabel: 'Thử lại',
        onAction: _loadSetIfNeeded,
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Đang tải bộ đề...'),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MockTestState state,
    MockTestSet set,
  ) {
    final palette = context.palette;
    final isPractice = _mode == 'practice';
    final inProgress = state.phase == MockTestPhase.running ||
        state.phase == MockTestPhase.sectionDone ||
        state.phase == MockTestPhase.evaluating;

    final availableSkills = _orderedSkills(set.skills);
    final selectedSkills = _skills ?? availableSkills;
    final estimatedMinutes = _estimateMinutes(set, selectedSkills);
    final errorMessage = _startError ??
        (state.phase == MockTestPhase.error ? state.error : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title card ─────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: isPractice
                ? const LinearGradient(
                    colors: [Color(0xFF0F9B8E), Color(0xFF00CEC9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BannerBadge(
                    label: isPractice ? 'Luyện tập' : 'Thi thật',
                    icon: isPractice
                        ? Icons.fitness_center_rounded
                        : Icons.verified_rounded,
                  ),
                  _BannerBadge(
                    label: set.typeLabel,
                    icon: Icons.school_rounded,
                  ),
                  if (estimatedMinutes > 0)
                    _BannerBadge(
                      label: '~${_formatMinutes(estimatedMinutes)}',
                      icon: Icons.schedule_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                set.title,
                style: AppTextStyles.h2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (set.description.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  set.description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.88),
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                isPractice
                    ? 'Band ước tính – chế độ luyện tập'
                    : 'Band thi thử – mô phỏng phòng thi thật',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        if (inProgress) ...[
          const SizedBox(height: 16),
          _buildInProgressCard(context),
        ],

        if (errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBanner(context, errorMessage),
        ],

        const SizedBox(height: 16),

        // ── Selected sections ──────────────────────────────
        _Panel(
          title: 'Các phần thi',
          icon: Icons.list_alt_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final skill in selectedSkills) _SkillPill(skill: skill),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isPractice
                    ? 'Bạn có thể dừng giữa chừng và tiếp tục sau. Kết quả dùng để tham khảo.'
                    : 'Bài thi diễn ra liên tục theo đúng thứ tự Listening → Reading → Writing → Speaking.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: palette.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Rules ─────────────────────────────────────────
        _Panel(
          title: isPractice ? 'Luật luyện tập' : 'Luật phòng thi',
          icon: isPractice
              ? Icons.fitness_center_rounded
              : Icons.gavel_rounded,
          accent: isPractice ? AppColors.secondary : AppColors.primary,
          child: Column(
            children: [
              for (final rule in _rulesFor(isPractice))
                _RuleRow(
                  icon: rule.icon,
                  text: rule.text,
                  color: isPractice ? AppColors.secondary : AppColors.primary,
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Device check ──────────────────────────────────
        _Panel(
          title: 'Kiểm tra thiết bị',
          icon: Icons.settings_voice_rounded,
          accent: AppColors.speaking,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.mic_rounded,
                    size: 18,
                    color: AppColors.speaking,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phần Speaking cần micro. Trình duyệt sẽ hỏi quyền truy cập '
                      'micro khi bạn bắt đầu nói — hãy chọn "Cho phép".',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: palette.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _testingAudio ? null : _testJudgeVoice,
                icon: _testingAudio
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.volume_up_rounded, size: 18),
                label: const Text('Nghe thử giọng giám khảo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.speaking,
                  side: BorderSide(
                    color: AppColors.speaking.withOpacity(0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              if (_audioMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_audioFailed ? AppColors.warning : AppColors.success)
                        .withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          (_audioFailed ? AppColors.warning : AppColors.success)
                              .withOpacity(0.32),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _audioFailed
                            ? Icons.info_outline_rounded
                            : Icons.graphic_eq_rounded,
                        size: 16,
                        color: _audioFailed
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _audioMessage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: palette.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Start ─────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _starting || inProgress ? null : () => _start(set),
            icon: _starting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isPractice
                        ? Icons.play_circle_fill_rounded
                        : Icons.rocket_launch_rounded,
                    size: 20,
                  ),
            label: Text(
              _starting
                  ? 'Đang bắt đầu...'
                  : isPractice
                      ? 'Bắt đầu luyện tập'
                      : 'Bắt đầu thi',
            ),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isPractice ? AppColors.secondary : AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: AppTextStyles.labelLarge,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            isPractice
                ? 'Bạn có thể tạm dừng bất cứ lúc nào trong chế độ luyện tập.'
                : 'Khi bấm bắt đầu, đồng hồ sẽ chạy và không thể tạm dừng.',
            style: AppTextStyles.caption.copyWith(color: palette.textHint),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorHint(BuildContext context) {
    return Text(
      'Bạn đang có một bài thi chưa hoàn thành. Hãy tiếp tục bài thi đó thay vì '
      'bắt đầu bài mới.',
      style: AppTextStyles.bodySmall.copyWith(
        color: context.palette.textSecondary,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildInProgressCard(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.pending_actions_rounded,
            color: AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bạn đang có một buổi thi chưa hoàn thành.',
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => context.pushReplacement('/mock-test/run'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_Rule> _rulesFor(bool isPractice) {
    if (isPractice) {
      return const [
        _Rule(
          icon: Icons.pause_circle_outline_rounded,
          text: 'Được tạm dừng và tiếp tục bất cứ lúc nào.',
        ),
        _Rule(
          icon: Icons.replay_rounded,
          text: 'Được nghe lại audio và xem lại phần thi đã làm.',
        ),
        _Rule(
          icon: Icons.school_rounded,
          text: 'Có thể luyện riêng từng kỹ năng nếu muốn.',
        ),
        _Rule(
          icon: Icons.insights_rounded,
          text: 'Kết quả là band ước tính, không phải điểm thi chính thức.',
        ),
      ];
    }
    return const [
      _Rule(
        icon: Icons.timer_off_rounded,
        text: 'Không được tạm dừng đồng hồ trong suốt bài thi.',
      ),
      _Rule(
        icon: Icons.block_rounded,
        text: 'Không thể quay lại phần thi đã nộp.',
      ),
      _Rule(
        icon: Icons.headphones_rounded,
        text: 'Audio Listening chỉ được nghe 1 lần cho mỗi part.',
      ),
      _Rule(
        icon: Icons.assignment_turned_in_rounded,
        text: 'Hết giờ, hệ thống tự động nộp phần thi hiện tại.',
      ),
    ];
  }

  int _estimateMinutes(MockTestSet set, List<String> skills) {
    var seconds = 0;
    for (final skill in skills) {
      switch (skill) {
        case 'listening':
          seconds += set.listening?.durationSeconds ?? 1800;
          break;
        case 'reading':
          seconds += set.reading?.durationSeconds ?? 3600;
          break;
        case 'writing':
          seconds += set.writing?.durationSeconds ?? 3600;
          break;
        case 'speaking':
          seconds += set.speaking?.durationSeconds ?? 840;
          break;
      }
    }
    return (seconds / 60).round();
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes phút';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '$hours giờ';
    return '$hours giờ $rest phút';
  }
}

// ─────────────────────────────────────────────────────────────
// Local widgets & helpers
// ─────────────────────────────────────────────────────────────

class _Rule {
  final IconData icon;
  final String text;

  const _Rule({required this.icon, required this.text});
}

class _BannerBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _BannerBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
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

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.h4.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _RuleRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.palette.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillPill extends StatelessWidget {
  final String skill;

  const _SkillPill({required this.skill});

  @override
  Widget build(BuildContext context) {
    final color = _skillColor(skill);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_skillIcon(skill), size: 14, color: color),
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
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
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

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<String>? _stringList(Object? value) {
  if (value is List) {
    final items = value
        .map((item) => item?.toString().trim().toLowerCase() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return items.isEmpty ? null : items;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return null;
}

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
