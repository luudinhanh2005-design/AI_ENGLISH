import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/voice_call_models.dart';
import '../providers/voice_call_provider.dart';

class VoiceCallSummaryScreen extends ConsumerWidget {
  const VoiceCallSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceCallProvider);
    final summary = state.summary ??
        VoiceCallSummaryModel(
          persona: state.persona,
          durationSeconds: state.durationSeconds,
          totalTurns: state.turns.length,
          allCorrections: state.turns.expand((t) => t.corrections).toList(),
          turns: state.turns,
          fluencyScore: state.calculatedFluencyScore,
          feedbackVi: 'Hoàn thành cuộc gọi thoại luyện giao tiếp tiếng Anh!',
        );

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.palette.textPrimary),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          'Tổng kết cuộc gọi thoại',
          style: AppTextStyles.h4.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero Congratulations Card ──
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      const Color(0xFF3B82F6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: const Icon(
                        Icons.phone_in_talk_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Đàm thoại thành công!',
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cùng ${summary.personaDisplayName}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Điểm lưu loát: ${summary.fluencyScore}/100 • ${summary.fluencyRating}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 3 Metric Cards ──
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.timer_outlined,
                      label: 'Thời gian',
                      value: summary.formattedDuration,
                      color: const Color(0xFF00D2D3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.forum_outlined,
                      label: 'Lượt nói',
                      value: '${summary.totalTurns} lượt',
                      color: const Color(0xFFFFA502),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.spellcheck_rounded,
                      label: 'Ngữ pháp',
                      value: '${summary.allCorrections.length} lưu ý',
                      color: summary.allCorrections.isEmpty
                          ? const Color(0xFF2ED573)
                          : const Color(0xFFFF4757),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── AI Feedback ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.palette.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.palette.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.psychology_rounded,
                        color: Color(0xFFFFA502), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nhận xét từ giáo viên AI',
                            style: TextStyle(
                              color: context.palette.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary.feedbackVi,
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Grammar Review Section ──
              Text(
                'Ngữ pháp cần chú ý (${summary.allCorrections.length})',
                style: AppTextStyles.h4.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              if (summary.allCorrections.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ED573).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF2ED573).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Color(0xFF2ED573), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Xuất sắc! Bạn không mắc lỗi ngữ pháp nào trong cuộc gọi này.',
                          style: TextStyle(
                            color: Color(0xFF2ED573),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...summary.allCorrections.map(
                  (c) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.palette.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.close_rounded,
                                color: Color(0xFFFF4757), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c.original,
                                style: const TextStyle(
                                  color: Color(0xFFFF4757),
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Color(0xFFFF4757),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.check_rounded,
                                color: Color(0xFF2ED573), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c.correction,
                                style: const TextStyle(
                                  color: Color(0xFF2ED573),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (c.explanationVi.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '💡 ${c.explanationVi}',
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // ── Action Buttons ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.palette.textPrimary,
                        side: BorderSide(color: context.palette.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Nhắn tin chat'),
                      onPressed: () => context.go('/ai-tutor'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: context.palette.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.phone_in_talk_rounded),
                      label: const Text(
                        'Gọi lại',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        context.pushReplacement('/ai-tutor/call',
                            extra: summary.persona);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(
                  'Về trang chủ',
                  style: TextStyle(color: context.palette.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.palette.textHint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
