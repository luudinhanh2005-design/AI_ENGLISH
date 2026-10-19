import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header / Hero Banner ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF4A3DB8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00CEC9), Color(0xFF6C5CE7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              (user?.name.isNotEmpty == true)
                                  ? user!.name[0].toUpperCase()
                                  : 'L',
                              style: AppTextStyles.h2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.palette.background,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user?.name ?? 'Learner',
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Level badge
                    if (user?.currentLevel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.school_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cấp độ ${user!.currentLevel!} — ${_levelName(user.currentLevel!)}',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── Stats Row ──
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _StatCard(
                      value: '${user?.streak ?? 0}',
                      label: 'Streak',
                      icon: Icons.local_fire_department_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFFA502)],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      value: '${user?.totalXp ?? 0}',
                      label: 'XP',
                      icon: Icons.bolt_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      value: '${user?.dailyLearningMinutes ?? 20}',
                      label: 'min/ngày',
                      icon: Icons.timer_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2ED573), Color(0xFF00CEC9)],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Learning Goal ──
              if (user?.learningGoal != null || user?.targetLevel != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.palette.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.flag_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mục tiêu học tập',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: context.palette.textHint,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.learningGoal ?? 'Chưa đặt mục tiêu',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: context.palette.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (user?.targetLevel != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Mục tiêu: ${user!.targetLevel!} — ${_levelName(user.targetLevel!)}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Achievements ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thành tích',
                      style: AppTextStyles.h4.copyWith(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAchievements(user?.totalXp ?? 0, user?.streak ?? 0),
                    const SizedBox(height: 24),

                    // ── Settings Section ──
                    Text(
                      'Cài đặt',
                      style: AppTextStyles.h4.copyWith(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SettingsItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Thông tin cá nhân',
                      iconColor: AppColors.primary,
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.brightness_6_outlined,
                      label: 'Giao diện',
                      value: _themeLabel(themeMode),
                      iconColor: AppColors.primary,
                      onTap: () => _showThemePicker(context, ref, themeMode),
                    ),
                    _SettingsItem(
                      icon: Icons.notifications_outlined,
                      label: 'Thông báo & nhắc nhở',
                      iconColor: AppColors.speaking,
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.timer_outlined,
                      label: 'Mục tiêu học hàng ngày',
                      value: '${user?.dailyLearningMinutes ?? 20} phút',
                      iconColor: AppColors.success,
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.assignment_turned_in_outlined,
                      label: 'Làm lại bài kiểm tra đầu vào',
                      iconColor: AppColors.secondary,
                      onTap: () => context.push('/placement'),
                    ),
                    _SettingsItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Trợ giúp & Hỗ trợ',
                      iconColor: AppColors.info,
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),

                    // ── Logout ──
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => _showLogoutDialog(context, ref),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  'Đăng xuất',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievements(int xp, int streak) {
    final achievements = [
      _Achievement(
        icon: Icons.local_fire_department_rounded,
        label: 'Học liên tục 3 ngày',
        unlocked: streak >= 3,
        color: const Color(0xFFFF6B6B),
      ),
      _Achievement(
        icon: Icons.bolt_rounded,
        label: '100 XP đầu tiên',
        unlocked: xp >= 100,
        color: const Color(0xFF6C5CE7),
      ),
      const _Achievement(
        icon: Icons.chat_bubble_rounded,
        label: 'Trò chuyện với AI',
        unlocked: true,
        color: Color(0xFF00CEC9),
      ),
      _Achievement(
        icon: Icons.menu_book_rounded,
        label: 'Học từ vựng đầu tiên',
        unlocked: xp > 0,
        color: const Color(0xFFFFA502),
      ),
      _Achievement(
        icon: Icons.psychology_rounded,
        label: 'Bài kiểm tra đầu vào',
        unlocked: xp >= 50,
        color: const Color(0xFF2ED573),
      ),
      _Achievement(
        icon: Icons.emoji_events_rounded,
        label: 'Streak 7 ngày',
        unlocked: streak >= 7,
        color: const Color(0xFFFFD700),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.9,
      children:
          achievements.map((a) => _AchievementBadge(achievement: a)).toList(),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Sáng';
      case ThemeMode.system:
        return 'Hệ thống';
      case ThemeMode.dark:
        return 'Tối';
    }
  }

  void _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) {
    final options = <({ThemeMode mode, String label, IconData icon})>[
      (mode: ThemeMode.light, label: 'Sáng', icon: Icons.light_mode_rounded),
      (mode: ThemeMode.dark, label: 'Tối', icon: Icons.dark_mode_rounded),
      (
        mode: ThemeMode.system,
        label: 'Hệ thống',
        icon: Icons.brightness_auto_rounded
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Giao diện',
                      style: AppTextStyles.h4.copyWith(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              for (final option in options)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: Icon(
                    option.icon,
                    color: option.mode == current
                        ? AppColors.primary
                        : context.palette.textSecondary,
                  ),
                  title: Text(
                    option.label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: option.mode == current
                          ? AppColors.primary
                          : context.palette.textPrimary,
                      fontWeight: option.mode == current
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: option.mode == current
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    ref.read(themeModeProvider.notifier).setMode(option.mode);
                    Navigator.pop(sheetContext);
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.palette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Đăng xuất',
          style: AppTextStyles.h4.copyWith(color: context.palette.textPrimary),
        ),
        content: Text(
          'Bạn có chắc muốn đăng xuất khỏi tài khoản không?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Hủy',
              style: TextStyle(color: context.palette.textHint),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authStateProvider.notifier).logout();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
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

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final LinearGradient gradient;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.palette.divider),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: context.palette.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color iconColor;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.value,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.divider),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
                if (value != null) ...[
                  Text(
                    value!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.palette.textHint,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Achievement {
  final IconData icon;
  final String label;
  final bool unlocked;
  final Color color;

  const _Achievement({
    required this.icon,
    required this.label,
    required this.unlocked,
    required this.color,
  });
}

class _AchievementBadge extends StatelessWidget {
  final _Achievement achievement;

  const _AchievementBadge({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: achievement.unlocked
            ? achievement.color.withOpacity(0.12)
            : context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: achievement.unlocked
              ? achievement.color.withOpacity(0.3)
              : context.palette.divider,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            achievement.icon,
            size: 28,
            color: achievement.unlocked
                ? achievement.color
                : context.palette.textHint,
          ),
          const SizedBox(height: 6),
          Text(
            achievement.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              color: achievement.unlocked
                  ? context.palette.textPrimary
                  : context.palette.textHint,
              fontWeight:
                  achievement.unlocked ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
