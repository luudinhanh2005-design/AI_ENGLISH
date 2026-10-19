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
        child: Stack(
          children: [
            // Ambient glowing background
            Positioned(
              top: MediaQuery.of(context).size.height * 0.15,
              left: MediaQuery.of(context).size.width * 0.2,
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

            Column(
              children: [
                // ── Top Bar ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            color: context.palette.textSecondary, size: 32),
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
                                          color:
                                              context.palette.textSecondary)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF4757),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _onEndCall();
                                  },
                                  child: Text('Kết thúc',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      // Duration Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.palette.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.palette.divider),
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
                                fontSize: 14,
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
                        ),
                        tooltip: 'Bật/Tắt phụ đề',
                        onPressed: () => ref
                            .read(voiceCallProvider.notifier)
                            .toggleSubtitles(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Persona Name & Title
                Text(
                  _getPersonaTitle(state.persona),
                  style: AppTextStyles.h4.copyWith(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
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
                    width: 220,
                    height: 220,
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
                                isActive:
                                    state.status == CallStateEnum.speaking ||
                                        state.status == CallStateEnum.listening,
                              ),
                              size: const Size(220, 220),
                            );
                          },
                        ),

                        // Center Avatar Box
                        Container(
                          width: 120,
                          height: 120,
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
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                            border: Border.all(
                              color: context.palette.textSecondary,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            _getPersonaIcon(state.persona),
                            size: 54,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Status Badge ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
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
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                if (state.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                          color: Color(0xFFFF6B81), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const Spacer(flex: 1),

                // ── Live Subtitles & Grammar Toast ──
                if (state.showSubtitles) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
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
                              Icon(Icons.chat_bubble_outline_rounded,
                                  size: 14, color: AppColors.primary),
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
                                      .read(voiceCallProvider.notifier)
                                      .translateCurrentSubtitle(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: context.palette.divider,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.translate_rounded,
                                          size: 12,
                                          color: state.currentAiTranslation !=
                                                  null
                                              ? AppColors.secondary
                                              : context.palette.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          state.currentAiTranslation != null
                                              ? 'Ẩn dịch'
                                              : 'Dịch TV',
                                          style: TextStyle(
                                            color: state.currentAiTranslation !=
                                                    null
                                                ? AppColors.secondary
                                                : context.palette.textSecondary,
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
                              fontSize: 15,
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
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],

                          // Grammar/vocabulary tips for the latest turn
                          if (latestCorrections.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color:
                                        AppColors.warning.withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var i = 0;
                                      i < latestCorrections.length;
                                      i++) ...[
                                    if (i > 0) const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(
                                            Icons.lightbulb_outline_rounded,
                                            size: 16,
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
                                              fontSize: 12,
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
                ],

                const Spacer(flex: 1),

                // ── Bottom Call Actions ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute button
                      _CallActionButton(
                        icon: state.isMuted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: state.isMuted ? 'Đã tắt mic' : 'Mic bật',
                        bgColor: state.isMuted
                            ? const Color(0xFFFF4757).withOpacity(0.2)
                            : context.palette.cardLight,
                        iconColor: state.isMuted
                            ? const Color(0xFFFF4757)
                            : context.palette.textPrimary,
                        onTap: () =>
                            ref.read(voiceCallProvider.notifier).toggleMute(),
                      ),

                      // Center Speaking Toggle Button (Large)
                      GestureDetector(
                        onTap: () async {
                          if (state.status == CallStateEnum.listening) {
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
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: state.status == CallStateEnum.listening
                                  ? [
                                      const Color(0xFF2ED573),
                                      const Color(0xFF10AC84)
                                    ]
                                  : [
                                      AppColors.primary,
                                      AppColors.primary.withOpacity(0.7)
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (state.status == CallStateEnum.listening
                                        ? const Color(0xFF2ED573)
                                        : AppColors.primary)
                                    .withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            state.status == CallStateEnum.listening
                                ? Icons.check_rounded
                                : Icons.mic_rounded,
                            size: 40,
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
                        onTap: _onEndCall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
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
    final baseRadius = 60.0;
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
