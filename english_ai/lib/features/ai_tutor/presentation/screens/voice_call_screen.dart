import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/ai_tutor_models.dart';
import '../../data/models/voice_call_models.dart';
import '../providers/voice_call_provider.dart';

class VoiceCallScreen extends ConsumerStatefulWidget {
  final String persona;

  const VoiceCallScreen({
    super.key,
    this.persona = 'sarah',
  });

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Initialize call
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceCallProvider.notifier).startCall(widget.persona);
    });
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onEndCall() {
    ref.read(voiceCallProvider.notifier).endCall();
    context.pushReplacement('/ai-tutor/call/summary');
  }

  Color _getStatusColor(CallStateEnum status) {
    switch (status) {
      case CallStateEnum.listening:
        return const Color(0xFF2ED573); // Neon Green
      case CallStateEnum.thinking:
        return const Color(0xFF9B59B6); // Neon Purple
      case CallStateEnum.speaking:
        return const Color(0xFFFFA502); // Warm Amber
      case CallStateEnum.connecting:
      default:
        return AppColors.primary;
    }
  }

  String _getStatusText(CallStateEnum status) {
    switch (status) {
      case CallStateEnum.listening:
        return 'Đang lắng nghe bạn...';
      case CallStateEnum.thinking:
        return 'AI đang suy nghĩ & phân tích...';
      case CallStateEnum.speaking:
        return 'AI đang nói...';
      case CallStateEnum.connecting:
      default:
        return 'Đang kết nối cuộc gọi...';
    }
  }

  IconData _getPersonaIcon(String persona) {
    switch (persona.toLowerCase()) {
      case 'harrison':
        return Icons.business_center_rounded;
      case 'emma':
        return Icons.school_rounded;
      default:
        return Icons.record_voice_over_rounded;
    }
  }

  String _getPersonaTitle(String persona) {
    switch (persona.toLowerCase()) {
      case 'harrison':
        return 'Mr. Harrison (Business Coach)';
      case 'emma':
        return 'Emma (IELTS Examiner)';
      default:
        return 'Sarah (Daily English Tutor)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceCallProvider);
    final statusColor = _getStatusColor(state.status);
    final latestCorrections = state.turns.isNotEmpty
        ? state.turns.last.corrections
        : (state.activeCorrection != null
            ? <AICorrectionModel>[state.activeCorrection!]
            : <AICorrectionModel>[]);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight;
            final isCompact = screenHeight < 760;
            final avatarSize = isCompact ? 140.0 : 200.0;
            final innerAvatarSize = isCompact ? 80.0 : 116.0;
            final avatarIconSize = isCompact ? 38.0 : 50.0;

            return Stack(
              children: [
                // Ambient glowing background
                Positioned(
                  top: screenHeight * 0.12,
                  left: MediaQuery.of(context).size.width * 0.2,
                  child: IgnorePointer(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withOpacity(0.12),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.2),
                            blurRadius: 100,
                            spreadRadius: 40,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // ── Top Bar ──
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isCompact ? 6 : 12,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                                      color: context.palette.textSecondary,
                                      size: isCompact ? 28 : 32),
                                  onPressed: () {
                                    // Minimize / Back confirmation
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: context.palette.surface,
                                        title: Text('Rời cuộc gọi?',
                                            style: TextStyle(
                                                color: context.palette.textPrimary)),
                                        content: Text(
                                          'Bạn có muốn kết thúc cuộc gọi thoại với AI không?',
                                          style: TextStyle(
                                              color: context.palette.textSecondary),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: Text('Ở lại',
                                                style: TextStyle(
                                                    color: context
                                                        .palette.textSecondary)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFFF4757),
                                            ),
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _onEndCall();
                                            },
                                            child: const Text('Kết thúc',
                                                style:
                                                    TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const Spacer(),
                                // Duration Pill
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isCompact ? 10 : 14,
                                      vertical: isCompact ? 4 : 6),
                                  decoration: BoxDecoration(
                                    color: context.palette.card,
                                    borderRadius: BorderRadius.circular(20),
                                    border:
                                        Border.all(color: context.palette.divider),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        state.formattedDuration,
                                        style: TextStyle(
                                          color: context.palette.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isCompact ? 13 : 14,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    state.showSubtitles
                                        ? Icons.subtitles_rounded
                                        : Icons.subtitles_off_rounded,
                                    color: state.showSubtitles
                                        ? AppColors.primary
                                        : context.palette.textHint,
                                    size: isCompact ? 22 : 24,
                                  ),
                                  tooltip: 'Bật/Tắt phụ đề',
                                  onPressed: () => ref
                                      .read(voiceCallProvider.notifier)
                                      .toggleSubtitles(),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isCompact ? 4 : 8),

                          // Persona Name & Title
                          Text(
                            _getPersonaTitle(state.persona),
                            style: (isCompact
                                    ? AppTextStyles.titleSmall
                                    : AppTextStyles.h4)
                                .copyWith(
                              color: context.palette.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cuộc gọi thoại đàm thoại 2 chiều',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.palette.textHint,
                            ),
                          ),

                          const Spacer(flex: 1),

                          // ── Animated Avatar with Ripple Rings ──
                          Center(
                            child: SizedBox(
                              width: avatarSize,
                              height: avatarSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Ripple Animation rings
                                  AnimatedBuilder(
                                    animation: _rippleController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        painter: _RippleRingsPainter(
                                          progress: _rippleController.value,
                                          color: statusColor,
                                          isActive: state.status ==
                                                  CallStateEnum.speaking ||
                                              state.status ==
                                                  CallStateEnum.listening,
                                        ),
                                        size: Size(avatarSize, avatarSize),
                                      );
                                    },
                                  ),

                                  // Center Avatar Box
                                  Container(
                                    width: innerAvatarSize,
                                    height: innerAvatarSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          statusColor.withOpacity(0.8),
                                          statusColor.withOpacity(0.3),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: statusColor.withOpacity(0.4),
                                          blurRadius: isCompact ? 20 : 30,
                                          spreadRadius: isCompact ? 3 : 5,
                                        ),
                                      ],
                                      border: Border.all(
                                        color: context.palette.textSecondary,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: Icon(
                                      _getPersonaIcon(state.persona),
                                      size: avatarIconSize,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: isCompact ? 10 : 16),

                          // ── Status Badge ──
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 12 : 16,
                                vertical: isCompact ? 6 : 8),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: statusColor.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (state.status == CallStateEnum.listening)
                                  const Icon(Icons.mic_rounded,
                                      size: 16, color: Color(0xFF2ED573))
                                else if (state.status == CallStateEnum.thinking)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF9B59B6)),
                                    ),
                                  )
                                else
                                  const Icon(Icons.volume_up_rounded,
                                      size: 16, color: Color(0xFFFFA502)),
                                const SizedBox(width: 8),
                                Text(
                                  _getStatusText(state.status),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isCompact ? 12 : 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (state.errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                state.errorMessage!,
                                style: const TextStyle(
                                    color: Color(0xFFFF6B81), fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],

                          const Spacer(flex: 1),

                          // ── Live Subtitles & Grammar Toast ──
                          if (state.showSubtitles) ...[
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: isCompact ? 16 : 20),
                              child: Container(
                                width: double.infinity,
                                constraints: BoxConstraints(
                                  maxHeight: isCompact ? 170 : 230,
                                ),
                                padding: EdgeInsets.all(isCompact ? 12 : 16),
                                decoration: BoxDecoration(
                                  color: context.palette.card,
                                  borderRadius: BorderRadius.circular(18),
                                  border:
                                      Border.all(color: context.palette.divider),
                                ),
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.chat_bubble_outline_rounded,
                                              size: 14,
                                              color: AppColors.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Phụ đề trực tiếp (Live Subtitle)',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (state.currentAiSubtitle != null &&
                                              state.currentAiSubtitle!.isNotEmpty)
                                            InkWell(
                                              onTap: () => ref
                                                  .read(
                                                      voiceCallProvider.notifier)
                                                  .translateCurrentSubtitle(),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: context.palette.divider,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.translate_rounded,
                                                      size: 12,
                                                      color: state.currentAiTranslation !=
                                                              null
                                                          ? AppColors.secondary
                                                          : context.palette
                                                              .textSecondary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      state.currentAiTranslation !=
                                                              null
                                                          ? 'Ẩn dịch'
                                                          : 'Dịch TV',
                                                      style: TextStyle(
                                                        color: state.currentAiTranslation !=
                                                                null
                                                            ? AppColors.secondary
                                                            : context.palette
                                                                .textSecondary,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // AI words
                                      Text(
                                        state.currentAiSubtitle ??
                                            'Đang đợi cuộc đối thoại bắt đầu...',
                                        style: TextStyle(
                                          color: context.palette.textPrimary,
                                          fontSize: isCompact ? 13.5 : 15,
                                          height: 1.35,
                                        ),
                                      ),

                                      // Vietnamese translation if requested
                                      if (state.currentAiTranslation != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          state.currentAiTranslation!,
                                          style: TextStyle(
                                            color: AppColors.secondary,
                                            fontSize: isCompact ? 12 : 13,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],

                                      // Grammar/vocabulary tips for the latest turn
                                      if (latestCorrections.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: AppColors.warning
                                                    .withValues(alpha: 0.4)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              for (var i = 0;
                                                  i < latestCorrections.length;
                                                  i++) ...[
                                                if (i > 0)
                                                  const SizedBox(height: 6),
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Padding(
                                                      padding:
                                                          EdgeInsets.only(top: 2),
                                                      child: Icon(
                                                        Icons
                                                            .lightbulb_outline_rounded,
                                                        size: 15,
                                                        color: AppColors.warning,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '${latestCorrections[i].type == 'vocabulary' ? 'Từ vựng' : 'Ngữ pháp'}: '
                                                        '${latestCorrections[i].correction} '
                                                        '(${latestCorrections[i].explanationVi})',
                                                        style: const TextStyle(
                                                          color: AppColors.warning,
                                                          fontSize: 11.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const Spacer(flex: 1),

                          // ── Bottom Call Actions ──
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              isCompact ? 6 : 8,
                              24,
                              isCompact ? 14 : 26,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Mute button
                                _CallActionButton(
                                  icon: state.isMuted
                                      ? Icons.mic_off_rounded
                                      : Icons.mic_rounded,
                                  label: state.isMuted
                                      ? 'Đã tắt mic'
                                      : 'Mic bật',
                                  bgColor: state.isMuted
                                      ? const Color(0xFFFF4757).withOpacity(0.2)
                                      : context.palette.cardLight,
                                  iconColor: state.isMuted
                                      ? const Color(0xFFFF4757)
                                      : context.palette.textPrimary,
                                  size: isCompact ? 50 : 58,
                                  iconSize: isCompact ? 24 : 28,
                                  onTap: () => ref
                                      .read(voiceCallProvider.notifier)
                                      .toggleMute(),
                                ),

                                // Center Speaking Toggle Button (Large)
                                GestureDetector(
                                  onTap: () async {
                                    if (state.status ==
                                        CallStateEnum.listening) {
                                      // User finished speaking, send to AI
                                      await ref
                                          .read(voiceCallProvider.notifier)
                                          .stopSpeakingAndProcess();
                                    } else {
                                      // Interrupt or start speaking
                                      await ref
                                          .read(voiceCallProvider.notifier)
                                          .startSpeaking();
                                    }
                                  },
                                  child: Container(
                                    width: isCompact ? 66 : 80,
                                    height: isCompact ? 66 : 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: state.status ==
                                                CallStateEnum.listening
                                            ? [
                                                const Color(0xFF2ED573),
                                                const Color(0xFF10AC84)
                                              ]
                                            : [
                                                AppColors.primary,
                                                AppColors.primary
                                                    .withOpacity(0.7)
                                              ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (state.status ==
                                                      CallStateEnum.listening
                                                  ? const Color(0xFF2ED573)
                                                  : AppColors.primary)
                                              .withOpacity(0.4),
                                          blurRadius: isCompact ? 14 : 20,
                                          spreadRadius: isCompact ? 3 : 4,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      state.status == CallStateEnum.listening
                                          ? Icons.check_rounded
                                          : Icons.mic_rounded,
                                      size: isCompact ? 34 : 40,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),

                                // End Call Button (Red)
                                _CallActionButton(
                                  icon: Icons.call_end_rounded,
                                  label: 'Kết thúc',
                                  bgColor: const Color(0xFFFF4757),
                                  iconColor: Colors.white,
                                  size: isCompact ? 50 : 58,
                                  iconSize: isCompact ? 24 : 28,
                                  onTap: _onEndCall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Action Button Helper ──
class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
    this.size = 58,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: context.palette.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Ripple Rings Painter ──
class _RippleRingsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isActive;

  _RippleRingsPainter({
    required this.progress,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.28;
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i * 0.33)) % 1.0;
      final radius = baseRadius + (maxRadius - baseRadius) * ringProgress;
      final opacity = (1.0 - ringProgress).clamp(0.0, 0.7);

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RippleRingsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.isActive != isActive;
  }
}

