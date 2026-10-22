import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Notification preference state (saved locally)
  bool _dailyReminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _streakShieldEnabled = true;
  bool _soundEffectsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero Banner Card ──
                  _buildHeroBanner(context, user),
                  const SizedBox(height: 16),

                  // ── Stats Row ──
                  _buildStatsRow(context, user),
                  const SizedBox(height: 16),

                  // ── Learning Goal Card ──
                  _buildLearningGoalCard(context, user),
                  const SizedBox(height: 24),

                  // ── Tính năng nổi bật AI ──
                  _buildFeatureShortcutsSection(context),
                  const SizedBox(height: 24),

                  // ── Achievements ──
                  _buildAchievementsSection(context, user),
                  const SizedBox(height: 24),

                  // ── Settings ──
                  _buildSettingsSection(context, user, themeMode),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Hero Banner
  // ──────────────────────────────────────────────
  Widget _buildHeroBanner(BuildContext context, User? user) {
    final displayName = _formatDisplayName(user?.name);
    final avatarEmoji = user?.avatarUrl ?? '';
    final hasEmoji = avatarEmoji.isNotEmpty && avatarEmoji.runes.length <= 4;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF4A3DB8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar + Edit button
          Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => _showEditProfileDialog(context, user),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00CEC9), Color(0xFF6C5CE7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: hasEmoji
                        ? Text(
                            avatarEmoji,
                            style: const TextStyle(fontSize: 42),
                          )
                        : Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'L',
                            style: AppTextStyles.h2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 36,
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () => _showEditProfileDialog(context, user),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            displayName,
            style: AppTextStyles.h3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          // Email
          if (user?.email != null && user!.email.isNotEmpty)
            Text(
              user.email,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white70,
              ),
            ),
          const SizedBox(height: 14),

          // Level badge & Quick Edit
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.school_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cấp độ ${user?.currentLevel ?? 'A1'} — ${_levelName(user?.currentLevel ?? 'A1')}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showEditProfileDialog(context, user),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Chỉnh sửa',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Stats Row
  // ──────────────────────────────────────────────
  Widget _buildStatsRow(BuildContext context, User? user) {
    return Row(
      children: [
        _StatCard(
          value: '${user?.streak ?? 0}',
          unit: 'ngày',
          label: 'Streak',
          icon: Icons.local_fire_department_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFFA502)],
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '🔥 Chuỗi Streak: ${user?.streak ?? 0} ngày liên tiếp! Học mỗi ngày để tăng chuỗi nhé!',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        _StatCard(
          value: '${user?.totalXp ?? 0}',
          unit: 'XP',
          label: 'Tổng điểm',
          icon: Icons.bolt_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚡ Bạn đang có ${user?.totalXp ?? 0} XP tích luỹ từ các bài học và luyện tập!',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        _StatCard(
          value: '${user?.dailyLearningMinutes ?? 20}',
          unit: 'phút',
          label: 'Mục tiêu/ngày',
          icon: Icons.timer_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF2ED573), Color(0xFF00CEC9)],
          ),
          onTap: () => _showDailyGoalPicker(context, user),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Learning Goal Card
  // ──────────────────────────────────────────────
  Widget _buildLearningGoalCard(BuildContext context, User? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: AppColors.primary,
              size: 24,
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
                  user?.learningGoal ?? 'Giao tiếp hàng ngày tự tin',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Trình độ mục tiêu: ${user?.targetLevel ?? 'B2'} (${_levelName(user?.targetLevel ?? 'B2')})',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showEditProfileDialog(context, user),
            icon: Icon(
              Icons.chevron_right_rounded,
              color: context.palette.textHint,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Feature Shortcuts Section
  // ──────────────────────────────────────────────
  Widget _buildFeatureShortcutsSection(BuildContext context) {
    const features = [
      _FeatureShortcut(
        title: 'Phòng Thi IELTS Speaking',
        subtitle: 'Thi thử 3 Part với Giám khảo AI, chấm Band 1.0 - 9.0',
        icon: Icons.school_rounded,
        color: Color(0xFF6C5CE7),
        badge: 'MỚI 🏆',
        route: '/practice/ielts-speaking',
      ),
      _FeatureShortcut(
        title: 'Sổ Tay Lỗi Sai & Từ Vựng',
        subtitle: 'Ôn tập ngắt quãng SM-2 với Flashcard 3D thông minh',
        icon: Icons.menu_book_rounded,
        color: Color(0xFFFF7675),
        badge: 'SM-2 📓',
        route: '/mistake-notebook',
      ),
      _FeatureShortcut(
        title: 'Luyện Nhại Giọng (Shadowing)',
        subtitle: 'Luyện ngữ điệu, nối âm, chấm điểm nhịp điệu live',
        icon: Icons.graphic_eq_rounded,
        color: Color(0xFF00CEC9),
        badge: 'LIVE 🎙️',
        route: '/pronunciation/shadowing',
      ),
      _FeatureShortcut(
        title: 'Bảng Xếp Hạng & Danh Hiệu',
        subtitle: 'Giải đấu hàng tuần, thăng hạng Đồng → Vàng → Bạch Kim',
        icon: Icons.emoji_events_rounded,
        color: Color(0xFFFFA502),
        badge: 'TOP 🥇',
        route: '/leaderboard',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tính năng nổi bật',
              style: AppTextStyles.h4.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                ),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                '4 Đột phá AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...features.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => context.push(f.route),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.palette.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: f.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(f.icon, color: f.color, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    f.title,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: context.palette.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: f.color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    f.badge,
                                    style: TextStyle(
                                      color: f.color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              f.subtitle,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.palette.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: context.palette.textHint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Achievements Section
  // ──────────────────────────────────────────────
  Widget _buildAchievementsSection(BuildContext context, User? user) {
    final xp = user?.totalXp ?? 0;
    final streak = user?.streak ?? 0;

    final achievements = [
      _Achievement(
        icon: Icons.local_fire_department_rounded,
        label: 'Streak 3 ngày',
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
        label: 'Trò chuyện AI',
        unlocked: true,
        color: Color(0xFF00CEC9),
      ),
      _Achievement(
        icon: Icons.menu_book_rounded,
        label: 'Từ vựng đầu tiên',
        unlocked: xp > 0,
        color: const Color(0xFFFFA502),
      ),
      _Achievement(
        icon: Icons.psychology_rounded,
        label: 'Kiểm tra đầu vào',
        unlocked: user?.currentLevel != null,
        color: const Color(0xFF2ED573),
      ),
      _Achievement(
        icon: Icons.emoji_events_rounded,
        label: 'Streak 7 ngày',
        unlocked: streak >= 7,
        color: const Color(0xFFFFD700),
      ),
    ];

    final unlockedCount = achievements.where((a) => a.unlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Thành tích',
              style: AppTextStyles.h4.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            InkWell(
              onTap: () => context.push('/leaderboard'),
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$unlockedCount/${achievements.length} Đã mở',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children:
              achievements.map((a) => _AchievementBadge(achievement: a)).toList(),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Settings Section
  // ──────────────────────────────────────────────
  Widget _buildSettingsSection(
    BuildContext context,
    User? user,
    ThemeMode themeMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cài đặt',
          style: AppTextStyles.h4.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // 1. Thông tin cá nhân
        _SettingsItem(
          icon: Icons.person_outline_rounded,
          label: 'Thông tin cá nhân',
          value: _formatDisplayName(user?.name),
          iconColor: AppColors.primary,
          onTap: () => _showEditProfileDialog(context, user),
        ),

        // 2. Giao diện
        _SettingsItem(
          icon: Icons.brightness_6_outlined,
          label: 'Giao diện',
          value: _themeLabel(themeMode),
          iconColor: AppColors.primary,
          onTap: () => _showThemePicker(context, themeMode),
        ),

        // 3. Thông báo & nhắc nhở
        _SettingsItem(
          icon: Icons.notifications_outlined,
          label: 'Thông báo & nhắc nhở',
          value: _dailyReminderEnabled
              ? '${_reminderTime.format(context)}'
              : 'Tắt',
          iconColor: AppColors.speaking,
          onTap: () => _showNotificationsDialog(context),
        ),

        // 4. Mục tiêu học hàng ngày
        _SettingsItem(
          icon: Icons.timer_outlined,
          label: 'Mục tiêu học hàng ngày',
          value: '${user?.dailyLearningMinutes ?? 20} phút',
          iconColor: AppColors.success,
          onTap: () => _showDailyGoalPicker(context, user),
        ),

        // 5. Làm lại bài kiểm tra đầu vào
        _SettingsItem(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Làm lại bài kiểm tra đầu vào',
          iconColor: AppColors.secondary,
          onTap: () async {
            await context.push('/placement');
            ref.read(authStateProvider.notifier).refreshUser();
          },
        ),

        // 6. Trợ giúp & Hỗ trợ
        _SettingsItem(
          icon: Icons.help_outline_rounded,
          label: 'Trợ giúp & Hỗ trợ',
          iconColor: AppColors.info,
          onTap: () => _showHelpSupportDialog(context),
        ),
        const SizedBox(height: 10),

        // 7. Đăng xuất
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: AppColors.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _showLogoutDialog(context),
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
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Modals & Dialogs
  // ──────────────────────────────────────────────

  /// 1. Edit Profile Dialog
  void _showEditProfileDialog(BuildContext context, User? user) {
    final nameController = TextEditingController(
      text: _formatDisplayName(user?.name),
    );
    String selectedAvatar = user?.avatarUrl ?? '👤';
    String currentLevel = user?.currentLevel ?? 'A1';
    String targetLevel = user?.targetLevel ?? 'B2';
    String learningGoal = user?.learningGoal ?? 'Giao tiếp hàng ngày tự tin';

    final presetAvatars = ['👤', '👨‍🎓', '👩‍🎓', '🤖', '🦊', '🦁', '🚀', '⭐'];
    final cefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    final goals = [
      'Giao tiếp hàng ngày tự tin',
      'Luyện thi IELTS / TOEIC',
      'Tiếng Anh công việc & đàm phán',
      'Du lịch & định cư nước ngoài',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Thông tin cá nhân',
                          style: AppTextStyles.h4.copyWith(
                            color: context.palette.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Avatar Picker
                    Text(
                      'Chọn hình đại diện',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: context.palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: presetAvatars.map((emoji) {
                          final isSelected = selectedAvatar == emoji;
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() => selectedAvatar = emoji);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.2)
                                    : context.palette.card,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : context.palette.divider,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Display Name
                    Text(
                      'Họ và tên hiển thị',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: context.palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: context.palette.textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.palette.card,
                        hintText: 'Nhập họ và tên',
                        hintStyle: TextStyle(color: context.palette.textHint),
                        prefixIcon: const Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                        ),
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
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Current CEFR Level
                    Text(
                      'Trình độ hiện tại (CEFR)',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: context.palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: cefrLevels.map((lvl) {
                        final isSel = currentLevel == lvl;
                        return ChoiceChip(
                          label: Text(lvl),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setSheetState(() => currentLevel = lvl);
                          },
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : context.palette.textPrimary,
                            fontWeight:
                                isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: context.palette.card,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Target Level
                    Text(
                      'Trình độ mục tiêu',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: context.palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: cefrLevels.map((lvl) {
                        final isSel = targetLevel == lvl;
                        return ChoiceChip(
                          label: Text(lvl),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setSheetState(() => targetLevel = lvl);
                          },
                          selectedColor: AppColors.secondary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : context.palette.textPrimary,
                            fontWeight:
                                isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: context.palette.card,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Learning Goal
                    Text(
                      'Mục tiêu học tập chính',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: context.palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: goals.contains(learningGoal)
                          ? learningGoal
                          : goals.first,
                      dropdownColor: context.palette.card,
                      style: TextStyle(color: context.palette.textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.palette.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: context.palette.divider),
                        ),
                      ),
                      items: goals.map((g) {
                        return DropdownMenuItem(value: g, child: Text(g));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => learningGoal = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final newName = nameController.text.trim();
                          if (newName.isEmpty) return;

                          Navigator.pop(sheetContext);

                          try {
                            await ref
                                .read(authStateProvider.notifier)
                                .updateProfile(
                                  name: newName,
                                  avatarUrl: selectedAvatar,
                                  currentLevel: currentLevel,
                                  targetLevel: targetLevel,
                                  learningGoal: learningGoal,
                                );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Đã cập nhật thông tin cá nhân!'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Lỗi cập nhật: $e'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Lưu thay đổi',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 2. Daily Goal Picker
  void _showDailyGoalPicker(BuildContext context, User? user) {
    final currentMinutes = user?.dailyLearningMinutes ?? 20;
    final options = [
      (10, '10 phút / ngày', 'Nhẹ nhàng — 5 từ vựng + 1 đoạn hội thoại'),
      (15, '15 phút / ngày', 'Vừa sức — 10 từ vựng + 1 bài học'),
      (20, '20 phút / ngày', 'Tiêu chuẩn — Khuyên dùng cho người bận rộn'),
      (30, '30 phút / ngày', 'Tăng tốc — Phản xạ giao tiếp nhanh chóng'),
      (45, '45 phút / ngày', 'Chuyên sâu — Cường độ cao cho chứng chỉ'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mục tiêu học hàng ngày',
                          style: AppTextStyles.h4.copyWith(
                            color: context.palette.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final opt in options)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: opt.$1 == currentMinutes
                              ? AppColors.primary.withOpacity(0.18)
                              : context.palette.card,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.timer_rounded,
                          color: opt.$1 == currentMinutes
                              ? AppColors.primary
                              : context.palette.textSecondary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        opt.$2,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: opt.$1 == currentMinutes
                              ? AppColors.primary
                              : context.palette.textPrimary,
                          fontWeight: opt.$1 == currentMinutes
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        opt.$3,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.palette.textHint,
                        ),
                      ),
                      trailing: opt.$1 == currentMinutes
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            )
                          : null,
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        try {
                          await ref
                              .read(authStateProvider.notifier)
                              .updateProfile(dailyLearningMinutes: opt.$1);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⏱️ Đã đặt mục tiêu: ${opt.$2}'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Lỗi cập nhật: $e'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 3. Notifications Dialog
  void _showNotificationsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Thông báo & nhắc nhở',
                            style: AppTextStyles.h4.copyWith(
                              color: context.palette.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Daily reminder switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Nhắc nhở học tập hàng ngày',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.palette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Nhận thông báo để không quên luyện tập',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.palette.textHint,
                          ),
                        ),
                        value: _dailyReminderEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setDialogState(() => _dailyReminderEnabled = val);
                          setState(() => _dailyReminderEnabled = val);
                        },
                      ),

                      // Time Picker
                      if (_dailyReminderEnabled) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.alarm_rounded, color: AppColors.primary),
                          title: Text(
                            'Giờ nhắc học',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: context.palette.textPrimary,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _reminderTime.format(context),
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _reminderTime,
                            );
                            if (picked != null) {
                              setDialogState(() => _reminderTime = picked);
                              setState(() => _reminderTime = picked);
                            }
                          },
                        ),
                      ],

                      // Streak Shield
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Bảo vệ chuỗi Streak',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.palette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Cảnh báo khi sắp hết ngày mà chưa học bài',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.palette.textHint,
                          ),
                        ),
                        value: _streakShieldEnabled,
                        activeColor: AppColors.accent,
                        onChanged: (val) {
                          setDialogState(() => _streakShieldEnabled = val);
                          setState(() => _streakShieldEnabled = val);
                        },
                      ),

                      // Sound Effects
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Âm thanh & Hiệu ứng phát âm',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.palette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Phát âm thanh phản hồi và thưởng điểm XP',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.palette.textHint,
                          ),
                        ),
                        value: _soundEffectsEnabled,
                        activeColor: AppColors.success,
                        onChanged: (val) {
                          setDialogState(() => _soundEffectsEnabled = val);
                          setState(() => _soundEffectsEnabled = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🔔 Đã lưu cài đặt thông báo!'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Xong'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 4. Theme Picker
  void _showThemePicker(BuildContext context, ThemeMode current) {
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
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Giao diện',
                        style: AppTextStyles.h4.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 5. Help & Support Dialog
  void _showHelpSupportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trợ giúp & Hỗ trợ',
                        style: AppTextStyles.h4.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Quick AI Tutor Call Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cần giải đáp ngay?',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Trò chuyện hoặc gọi điện trực tiếp với AI Tutor',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            context.go('/ai-tutor');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Hỏi AI'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // FAQs
                  Text(
                    'Câu hỏi thường gặp (FAQ)',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: context.palette.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildFaqItem(
                    context,
                    'Làm sao để duy trì chuỗi Streak?',
                    'Mỗi ngày bạn chỉ cần hoàn thành tối thiểu 1 hoạt động (học từ vựng, làm bài ngữ pháp hoặc trò chuyện 1 lượt với AI) trước 23:59.',
                  ),
                  _buildFaqItem(
                    context,
                    'Cách tính điểm kinh nghiệm (XP)?',
                    'Bạn nhận được 10-20 XP cho mỗi bài học từ vựng, 30 XP cho bài tập ngữ pháp, và 50 XP khi hoàn thành bài đánh giá trình độ.',
                  ),
                  _buildFaqItem(
                    context,
                    'AI Tutor sửa phát âm thế nào?',
                    'AI sử dụng mô hình nhận diện giọng nói và đối chiếu với giọng bản xứ chuẩn Mỹ (Neural Voices) để chấm điểm và chỉ ra âm tiết phát âm chưa chính xác.',
                  ),
                  const SizedBox(height: 16),

                  // App Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.palette.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'EnglishAI Pro • Phiên bản 1.0.0',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: context.palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AI Engine: Google Gemini 2.5 Flash & Edge Neural Voices',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.palette.textHint,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.divider),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          question,
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Text(
            answer,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.palette.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  /// 6. Logout Dialog
  void _showLogoutDialog(BuildContext context) {
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

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────
  String _formatDisplayName(String? name) {
    if (name == null || name.isEmpty) return 'Learner';
    // If name looks like "Hoàng_0731" or email prefix, trim suffixes cleanly
    final parts = name.split(RegExp(r'[_@\.]'));
    if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
      return parts[0].trim();
    }
    return name;
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
      case 'C2':
        return 'Proficient';
      default:
        return level;
    }
  }
}

// ──────────────────────────────────────────────
// Custom Reusable Subwidgets
// ──────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _StatCard({
    required this.value,
    required this.unit,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.divider),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: AppTextStyles.h3.copyWith(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      unit,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: context.palette.textHint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: context.palette.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                      fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: achievement.unlocked
            ? achievement.color.withOpacity(0.12)
            : context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: achievement.unlocked
              ? achievement.color.withOpacity(0.35)
              : context.palette.divider,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            achievement.icon,
            size: 24,
            color: achievement.unlocked
                ? achievement.color
                : context.palette.textHint,
          ),
          const SizedBox(height: 4),
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

class _FeatureShortcut {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String badge;
  final String route;

  const _FeatureShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.badge,
    required this.route,
  });
}
