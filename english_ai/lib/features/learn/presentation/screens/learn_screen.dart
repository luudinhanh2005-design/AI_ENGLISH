import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ── Header ──
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lộ Trình Học Tập 🧭',
                              style: AppTextStyles.h2.copyWith(
                                color: context.palette.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Học bài bản theo chuẩn CEFR quốc tế (A1 → B2)',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              user?.currentLevel ?? 'B1',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Resume Learning Hero Card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A00E0).withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '⚡ BÀI HỌC TIẾP THEO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'Tiến độ: 60%',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Thì Hiện Tại Hoàn Thành (Present Perfect)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Nắm vững cấu trúc S + have/has + V3, phân biệt since/for & làm bài kiểm tra.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: 0.6,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF2ED573)),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () => context
                                .push('/grammar?id=present_perfect_experience'),
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Học ngay ➔'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF4A00E0),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Section 1: 4 Core Skills ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kỹ Năng Cốt Lõi 🎯',
                        style: AppTextStyles.h4.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '4 học phần',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 550;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isWide ? 4 : 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: isWide ? 1.25 : 1.3,
                        children: [
                          _SkillCard(
                            icon: Icons.menu_book_rounded,
                            title: 'Từ vựng',
                            subtitle: '5 chủ đề • SM-2',
                            color: AppColors.vocabulary,
                            badgeText: 'HOT',
                            onTap: () => context.push('/vocabulary'),
                          ),
                          _SkillCard(
                            icon: Icons.edit_note_rounded,
                            title: 'Ngữ pháp',
                            subtitle: 'A1-B2 • Có Trắc Nghiệm',
                            color: AppColors.grammar,
                            badgeText: 'MỚI',
                            onTap: () => context.push('/grammar'),
                          ),
                          _SkillCard(
                            icon: Icons.headphones_rounded,
                            title: 'Nghe hiểu',
                            subtitle: 'Hội thoại có phát âm',
                            color: AppColors.listening,
                            badgeText: 'AUDIO',
                            onTap: () => context.push('/listening'),
                          ),
                          _SkillCard(
                            icon: Icons.chrome_reader_mode_rounded,
                            title: 'Đọc hiểu',
                            subtitle: 'Bài đọc đa cấp độ',
                            color: AppColors.reading,
                            badgeText: 'BÀI ĐỌC',
                            onTap: () => context.push('/reading'),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── Placement Banner (if needed) ──
                  if (user?.currentLevel == null) ...[
                    _PlacementBanner(onTap: () => context.push('/placement')),
                    const SizedBox(height: 28),
                  ],

                  // ── Section 2: CEFR Learning Journey ──
                  Text(
                    'Lộ Trình Cấp Độ CEFR 📈',
                    style: AppTextStyles.h4.copyWith(
                      color: context.palette.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lựa chọn trình độ để mở danh sách bài học và bài tập trắc nghiệm',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildCefrTrack(context),

                  const SizedBox(height: 28),

                  // ── Section 3: Featured Lessons ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bài Học Ngữ Pháp Trọng Tâm 📖',
                        style: AppTextStyles.h4.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/grammar'),
                        child: const Text('Xem tất cả ➔',
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _FeaturedLessonCard(
                    title: 'Thì Quá Khứ Đơn',
                    subtitle: 'Past Simple Tense',
                    description:
                        'Diễn đạt hành động đã xảy ra và hoàn thành trong quá khứ • Cấu trúc did/didn\'t',
                    color: const Color(0xFF00CEC9),
                    icon: Icons.history_edu_rounded,
                    level: 'A1',
                    onTap: () => context
                        .push('/grammar?id=past_simple_regular_irregular'),
                  ),
                  const SizedBox(height: 10),
                  _FeaturedLessonCard(
                    title: 'Hiện Tại Hoàn Thành',
                    subtitle: 'Present Perfect Tense',
                    description:
                        'Hành động xảy ra trong quá khứ có liên quan đến hiện tại • Dấu hiệu since, for, already',
                    color: const Color(0xFFFFA502),
                    icon: Icons.auto_stories_rounded,
                    level: 'B1',
                    onTap: () => context.push(
                        '/grammar?id=present_perfect_simple_vs_continuous'),
                  ),
                  const SizedBox(height: 10),
                  _FeaturedLessonCard(
                    title: 'Câu Điều Kiện Loại 2',
                    subtitle: 'Second Conditional',
                    description:
                        'Điều kiện không có thật ở hiện tại hoặc tương lai • If + V2/were, S + would + V',
                    color: const Color(0xFFFF4757),
                    icon: Icons.psychology_rounded,
                    level: 'B1',
                    onTap: () => context.push('/grammar?id=second_conditional'),
                  ),
                  const SizedBox(height: 10),
                  _FeaturedLessonCard(
                    title: 'Câu Bị Động',
                    subtitle: 'Passive Voice',
                    description:
                        'Nhấn mạnh đối tượng chịu tác động • Cấu trúc S + be + V3/ed (+ by O)',
                    color: const Color(0xFF6C5CE7),
                    icon: Icons.swap_horiz_rounded,
                    level: 'B1',
                    onTap: () =>
                        context.push('/grammar?id=passive_present_past'),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCefrTrack(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _CefrCard(
            level: 'A1',
            title: 'Khởi Động',
            description: 'Thì Hiện Tại Đơn & Danh từ',
            color: Colors.green,
            onTap: () => context.push('/grammar?id=present_simple'),
          ),
          const SizedBox(width: 12),
          _CefrCard(
            level: 'A2',
            title: 'Sơ Cấp',
            description: 'Quá Khứ Đơn & Tiếp Diễn',
            color: const Color(0xFF00CEC9),
            onTap: () => context.push('/grammar?id=past_simple_vs_continuous'),
          ),
          const SizedBox(width: 12),
          _CefrCard(
            level: 'B1',
            title: 'Trung Cấp',
            description: 'Hiện Tại Hoàn Thành & Tiếp Diễn',
            color: const Color(0xFFFFA502),
            onTap: () => context
                .push('/grammar?id=present_perfect_simple_vs_continuous'),
          ),
          const SizedBox(width: 12),
          _CefrCard(
            level: 'B2',
            title: 'Nâng Cao',
            description: 'Câu Điều Kiện Nâng Cao & Mệnh Đề',
            color: const Color(0xFFFF4757),
            onTap: () => context.push('/grammar?id=advanced_conditionals'),
          ),
        ],
      ),
    );
  }
}

class _CefrCard extends StatelessWidget {
  final String level;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _CefrCard({
    required this.level,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                level,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.labelMedium.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.palette.textSecondary,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? badgeText;
  final VoidCallback onTap;

  const _SkillCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (badgeText != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: context.palette.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedLessonCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final IconData icon;
  final String level;
  final VoidCallback onTap;

  const _FeaturedLessonCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.icon,
    required this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.palette.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: context.palette.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            level,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.palette.textSecondary,
                      ),
                      maxLines: 2,
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
    );
  }
}

class _PlacementBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _PlacementBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFFA502)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.psychology_rounded, color: Colors.white, size: 36),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚡ Chưa xác định trình độ!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Làm bài kiểm tra để AI cá nhân hóa lộ trình học',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
