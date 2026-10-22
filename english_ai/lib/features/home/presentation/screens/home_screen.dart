import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final userName = user?.name ?? 'Learner';
    final greeting = _getgreeting();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.screenPaddingH,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // ── Header â”€â”€
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting 👋',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userName,
                          style: AppTextStyles.h2.copyWith(
                            color: context.palette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Streak badge (Clickable to Leaderboard)
                  GestureDetector(
                    onTap: () => context.push('/leaderboard'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.streakGradient,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${user?.streak ?? 0}',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // XP badge (Clickable to Leaderboard)
                  GestureDetector(
                    onTap: () => context.push('/leaderboard'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.xpGradient,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${user?.totalXp ?? 0}',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ── Daily Goal Card â”€â”€
              AppCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF8E7CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Today's Goal",
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusFull,
                            ),
                          ),
                          child: Text(
                            '${user?.dailyLearningMinutes ?? 20} min',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ((user?.totalXp ?? 15) % 100 / 60.0)
                            .clamp(0.15, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(((user?.totalXp ?? 15) % 100 / 60.0).clamp(0.15, 1.0) * 100).toInt()}% — ${_getGoalMessage((user?.totalXp ?? 0))}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Quick Actions â”€â”€
              Text(
                'Quick Actions',
                style: AppTextStyles.h4.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.record_voice_over_rounded,
                      label: 'Phát âm\nAI',
                      color: AppColors.speaking,
                      onTap: () => context.push('/pronunciation'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.menu_book_rounded,
                      label: 'Từ vựng\nFlashcards',
                      color: AppColors.secondary,
                      onTap: () => context.push('/vocabulary'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.smart_toy_rounded,
                      label: 'AI\nTutor',
                      color: AppColors.primary,
                      onTap: () => context.go('/ai-tutor'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.assignment_turned_in_rounded,
                      label: 'Đầu vào\nTest',
                      color: AppColors.accent,
                      onTap: () => context.push('/placement'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ── Level Card or Placement Test Prompt â”€â”€
              if (user?.currentLevel == null) ...[
                InkWell(
                  onTap: () => context.push('/placement'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.psychology_rounded,
                            color: Colors.white, size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Làm bài kiểm tra năng lực',
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Được AI xếp lớp và cá nhân hóa lộ trình học',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color:
                              _levelColor(user!.currentLevel!).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            user.currentLevel!,
                            style: AppTextStyles.h3.copyWith(
                              color: _levelColor(user.currentLevel!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Level',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.palette.textHint,
                              ),
                            ),
                            Text(
                              _levelName(user.currentLevel!),
                              style: AppTextStyles.labelLarge.copyWith(
                                color: context.palette.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: context.palette.textHint,
                        size: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // ── Recommended Section â”€â”€
              Text(
                'Recommended for You',
                style: AppTextStyles.h4.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _RecommendationCard(
                icon: Icons.record_voice_over_rounded,
                title: 'Luyện Phát Âm AI',
                subtitle: 'Chấm điểm phát âm & nhận phản hồi chi tiết',
                color: AppColors.speaking,
                onTap: () => context.push('/pronunciation'),
              ),
              const SizedBox(height: 8),
              _RecommendationCard(
                icon: Icons.phone_in_talk_rounded,
                title: 'Gọi Thoại Với AI',
                subtitle: 'Đàm thoại 2 chiều thời gian thực cùng Sarah',
                color: const Color(0xFF2ED573),
                onTap: () => context.push('/ai-tutor/call'),
              ),
              const SizedBox(height: 8),
              _RecommendationCard(
                icon: Icons.military_tech_rounded,
                title: 'Thi Thử IELTS Speaking (Emma) 🏆',
                subtitle: 'Phòng thi chuẩn 3 phần, giám khảo Emma chấm điểm Band 1.0 - 9.0',
                color: const Color(0xFFF39C12),
                onTap: () => context.push('/practice/ielts-speaking'),
              ),
              const SizedBox(height: 8),
              _RecommendationCard(
                icon: Icons.auto_stories_rounded,
                title: 'Sổ Tay Lỗi Sai & Từ Vựng 📓',
                subtitle: 'Ghi nhớ triệt để bằng phương pháp Lặp Lại Ngắt Quãng SM-2',
                color: const Color(0xFF6C5CE7),
                onTap: () => context.push('/mistake-notebook'),
              ),
              const SizedBox(height: 8),
              _RecommendationCard(
                icon: Icons.mic_external_on_rounded,
                title: 'Luyện Nhại Giọng (Shadowing) 🎙️',
                subtitle: 'Làm chủ ngữ điệu & phản xạ tự nhiên như người bản ngữ',
                color: const Color(0xFF00CEC9),
                onTap: () => context.push('/pronunciation/shadowing'),
              ),
              const SizedBox(height: 8),
              _RecommendationCard(
                icon: Icons.leaderboard_rounded,
                title: 'Bảng Xếp Hạng & Danh Hiệu 🥇',
                subtitle: 'Giải đấu hàng tuần, thăng hạng & nhận thưởng huy hiệu',
                color: const Color(0xFFE84393),
                onTap: () => context.push('/leaderboard'),
              ),
              const SizedBox(height: 8),
              _RecommendationCard(
                icon: Icons.headphones_rounded,
                title: 'Listening Practice',
                subtitle: 'Daily Conversation & AI Tutor',
                color: AppColors.listening,
                onTap: () => context.go('/ai-tutor'),
              ),
              const SizedBox(height: 8),
              _RecommendationCard(
                icon: Icons.book_rounded,
                title: 'Vocabulary Flashcards',
                subtitle: 'Học từ vựng qua thẻ ghi nhớ SM-2',
                color: AppColors.vocabulary,
                onTap: () => context.push('/vocabulary'),
              ),
              const SizedBox(height: 8),
              _RecommendationCard(
                icon: Icons.edit_note_rounded,
                title: 'Grammar Review & Practice',
                subtitle: 'Ngữ pháp & Trắc nghiệm mini quiz',
                color: AppColors.grammar,
                onTap: () => context.go('/practice'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _getGoalMessage(int xp) {
    if (xp > 80) return 'Tuyệt vời, bạn sắp hoàn thành mục tiêu!';
    if (xp > 30) return 'Đang học rất tốt, tiếp tục phát huy!';
    return 'Bắt đầu bài học đầu tiên hôm nay nào!';
  }

  String _getgreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Color _levelColor(String level) {
    switch (level) {
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
      default:
        return AppColors.primary;
    }
  }

  String _levelName(String level) {
    switch (level) {
      case 'A1':
        return 'Beginner';
      case 'A2':
        return 'Elementary';
      case 'B1':
        return 'Intermediate';
      case 'B2':
        return 'Upper Intermediate';
      case 'C1':
        return 'Advanced';
      default:
        return level;
    }
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _RecommendationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: context.palette.divider.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.palette.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_filled_rounded,
              color: color,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}
