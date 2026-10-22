import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic>? _leaderboardData;
  List<dynamic> _badges = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final dio = ref.read(dioProvider);

    try {
      final resLeader = await dio.get(ApiEndpoints.userLeaderboard);
      if (resLeader.statusCode == 200) {
        _leaderboardData = resLeader.data as Map<String, dynamic>;
      }
    } catch (_) {}

    try {
      final resBadges = await dio.get(ApiEndpoints.userBadges);
      if (resBadges.statusCode == 200 && resBadges.data is List) {
        _badges = resBadges.data as List;
      }
    } catch (_) {}

    // Fallback if offline
    _leaderboardData ??= {
      'league_name': 'Giải Đấu Vàng 🥇',
      'league_tier': 'gold',
      'time_remaining': '2 ngày 14 giờ',
      'top_users': [
        {
          'rank': 1,
          'name': 'Minh Anh',
          'avatar': '👩‍🎓',
          'weekly_xp': 1280,
          'streak': 14,
          'title': 'Bậc Thầy Giao Tiếp'
        },
        {
          'rank': 2,
          'name': 'Tuấn Kiệt',
          'avatar': '🚀',
          'weekly_xp': 960,
          'streak': 9,
          'title': 'Chiến Binh IELTS'
        },
        {
          'rank': 3,
          'name': 'Thuỳ Linh',
          'avatar': '✨',
          'weekly_xp': 820,
          'streak': 12,
          'title': 'Thợ Săn Phát Âm'
        },
        {
          'rank': 4,
          'name': 'Bạn (Học viên)',
          'avatar': '👑',
          'weekly_xp': 560,
          'streak': 4,
          'title': 'Tân Binh Tiềm Năng',
          'is_current_user': true,
        },
        {
          'rank': 5,
          'name': 'Đức Huy',
          'avatar': '⚡',
          'weekly_xp': 540,
          'streak': 6,
          'title': 'Học Viên Chăm Chỉ'
        },
        {
          'rank': 6,
          'name': 'Bảo Ngọc',
          'avatar': '🌟',
          'weekly_xp': 480,
          'streak': 4,
          'title': 'Người Kiên Trì'
        },
        {
          'rank': 7,
          'name': 'Hoàng Nam',
          'avatar': '🎯',
          'weekly_xp': 390,
          'streak': 5,
          'title': 'Yêu Thích Tiếng Anh'
        },
        {
          'rank': 8,
          'name': 'Khánh Vy',
          'avatar': '🌸',
          'weekly_xp': 310,
          'streak': 3,
          'title': 'Khám Phá Từ Mới'
        },
      ],
      'current_user_rank': 4,
      'current_user_xp': 560,
      'promotion_zone_cutoff': 3,
    };

    if (_badges.isEmpty) {
      _badges = [
        {
          'id': 'badge_voice_first',
          'title': 'Bước Đầu Tự Tin',
          'description': 'Thực hiện cuộc gọi thoại đầu tiên với gia sư AI',
          'category': 'Giao tiếp',
          'reward_xp': 50,
          'current_progress': 1,
          'target_progress': 1,
          'is_unlocked': true,
          'is_claimed': false,
        },
        {
          'id': 'badge_streak_3',
          'title': 'Chiến Binh Kiên Trì',
          'description': 'Giữ chuỗi học tập ít nhất 3 ngày liên tiếp',
          'category': 'Kỷ luật',
          'reward_xp': 50,
          'current_progress': 3,
          'target_progress': 3,
          'is_unlocked': true,
          'is_claimed': false,
        },
        {
          'id': 'badge_ielts_first',
          'title': 'Thử Thách IELTS Speaking',
          'description': 'Hoàn thành một bài thi thử IELTS Speaking 3 phần',
          'category': 'IELTS',
          'reward_xp': 100,
          'current_progress': 1,
          'target_progress': 1,
          'is_unlocked': true,
          'is_claimed': false,
        },
        {
          'id': 'badge_shadowing_pro',
          'title': 'Bậc Thầy Nhại Giọng',
          'description': 'Đạt điểm Shadowing trên 80% với một bài luyện nói',
          'category': 'Phát âm',
          'reward_xp': 75,
          'current_progress': 1,
          'target_progress': 1,
          'is_unlocked': true,
          'is_claimed': false,
        },
        {
          'id': 'badge_mistake_collector',
          'title': 'Thợ Săn Lỗi Sai',
          'description': 'Lưu và ôn tập ít nhất 3 lỗi trong Sổ tay lỗi sai',
          'category': 'Học tập',
          'reward_xp': 60,
          'current_progress': 3,
          'target_progress': 3,
          'is_unlocked': true,
          'is_claimed': false,
        },
        {
          'id': 'badge_xp_500',
          'title': 'Ngôi Sao Tích Lũy',
          'description': 'Tích lũy đạt mốc 500 XP rèn luyện',
          'category': 'Danh dự',
          'reward_xp': 100,
          'current_progress': 450,
          'target_progress': 500,
          'is_unlocked': false,
          'is_claimed': false,
        },
      ];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _claimBadge(Map<String, dynamic> badge) async {
    final badgeId = badge['id'] as String;
    final rewardXp = badge['reward_xp'] as int? ?? 50;

    try {
      final dio = ref.read(dioProvider);
      await dio.post(ApiEndpoints.userBadgeClaim(badgeId));
    } catch (_) {}

    setState(() {
      badge['is_claimed'] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '🎉 Chúc mừng bạn đã nhận +$rewardXp XP từ danh hiệu "${badge['title']}"!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2ED573),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.palette.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // ── Top Navigation Bar ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: context.palette.textPrimary, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đấu Trường Xếp Hạng & Danh Hiệu 🏆',
                              style: AppTextStyles.h3.copyWith(
                                color: context.palette.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Thi đua rèn luyện hàng tuần & mở khóa huy hiệu vinh danh',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.palette.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Tab Bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.palette.divider),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: context.palette.textSecondary,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [
                        Tab(text: 'Bảng Xếp Hạng Tuần 🥇'),
                        Tab(text: 'Bộ Sưu Tập Huy Hiệu 🎖️'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Tab Views ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: WEEKLY LEADERBOARD
                      _buildLeaderboardTab(context),
                      // TAB 2: BADGES & ACHIEVEMENTS
                      _buildBadgesTab(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 1: WEEKLY LEADERBOARD
  // ──────────────────────────────────────────────
  Widget _buildLeaderboardTab(BuildContext context) {
    final leagueName = _leaderboardData?['league_name'] ?? 'Giải Đấu Vàng 🥇';
    final timeRemaining =
        _leaderboardData?['time_remaining'] ?? '2 ngày 14 giờ';
    final topUsers =
        (_leaderboardData?['top_users'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final userRank = _leaderboardData?['current_user_rank'] ?? 4;
    final userXp = _leaderboardData?['current_user_xp'] ?? 560;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // League Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF39C12), Color(0xFFF1C40F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF39C12).withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leagueName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Top 3 người dẫn đầu sẽ thăng hạng Bạch Kim 💎',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              timeRemaining,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Top 3 Podium Cards
                if (topUsers.length >= 3) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Rank 2 (Silver)
                      _buildPodiumItem(
                        rank: 2,
                        user: topUsers[1],
                        height: 120,
                        ringColor: const Color(0xFFBDC3C7),
                        crown: '🥈',
                      ),
                      const SizedBox(width: 10),
                      // Rank 1 (Gold)
                      _buildPodiumItem(
                        rank: 1,
                        user: topUsers[0],
                        height: 145,
                        ringColor: const Color(0xFFF1C40F),
                        crown: '👑',
                        isFirst: true,
                      ),
                      const SizedBox(width: 10),
                      // Rank 3 (Bronze)
                      _buildPodiumItem(
                        rank: 3,
                        user: topUsers[2],
                        height: 105,
                        ringColor: const Color(0xFFE67E22),
                        crown: '🥉',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // Ranks 4 to 10 list
                ...topUsers.skip(3).map((u) => _buildRankRow(context, u)),
              ],
            ),
          ),
        ),

        // Sticky Bottom User Rank Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: context.palette.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$userRank',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vị Trí Của Bạn Trong Giải Đấu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      userRank <= 3
                          ? '🔥 Bạn đang ở trong nhóm THĂNG HẠNG!'
                          : 'Cần thêm 160 XP để vào Top 3 Thăng Hạng 🚀',
                      style: TextStyle(
                        color: userRank <= 3
                            ? const Color(0xFF2ED573)
                            : const Color(0xFFFFA502),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.xpGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$userXp XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumItem({
    required int rank,
    required Map<String, dynamic> user,
    required double height,
    required Color ringColor,
    required String crown,
    bool isFirst = false,
  }) {
    return Column(
      children: [
        Text(crown, style: TextStyle(fontSize: isFirst ? 24 : 18)),
        const SizedBox(height: 2),
        Container(
          width: isFirst ? 60 : 50,
          height: isFirst ? 60 : 50,
          decoration: BoxDecoration(
            color: context.palette.card,
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: isFirst ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: ringColor.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Text(
              user['avatar']?.toString() ?? '👤',
              style: TextStyle(fontSize: isFirst ? 28 : 22),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          user['name']?.toString() ?? '',
          style: TextStyle(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: isFirst ? 13 : 11,
          ),
        ),
        Text(
          '${user['weekly_xp']} XP',
          style: TextStyle(
            color: ringColor,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: isFirst ? 84 : 74,
          height: height * 0.45,
          decoration: BoxDecoration(
            color: ringColor.withOpacity(0.18),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: ringColor.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                color: ringColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankRow(BuildContext context, Map<String, dynamic> user) {
    final isMe = user['is_current_user'] == true;
    final rank = user['rank'] ?? 4;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withOpacity(0.14)
            : context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? AppColors.primary : context.palette.divider,
          width: isMe ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                color: isMe ? AppColors.primary : context.palette.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.palette.background,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user['avatar']?.toString() ?? '👤',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user['name']?.toString() ?? '',
                      style: TextStyle(
                        color: isMe
                            ? AppColors.primary
                            : context.palette.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'BẠN',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  user['title']?.toString() ?? '',
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Color(0xFFFFA502), size: 14),
              const SizedBox(width: 2),
              Text(
                '${user['streak'] ?? 1}',
                style: const TextStyle(
                  color: Color(0xFFFFA502),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Text(
            '${user['weekly_xp']} XP',
            style: TextStyle(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 2: BADGES & ACHIEVEMENTS
  // ──────────────────────────────────────────────
  Widget _buildBadgesTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF8E7CF8)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Text('🎖️', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bộ Sưu Tập Huy Hiệu Vinh Danh',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hoàn thành thử thách để nhận điểm XP thưởng và huy hiệu độc quyền!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Danh Hiệu Đã Mở Khóa & Đang Chinh Phục:',
            style: TextStyle(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          ..._badges.map((b) => _buildBadgeCard(context, b as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(BuildContext context, Map<String, dynamic> badge) {
    final isUnlocked = badge['is_unlocked'] == true;
    final isClaimed = badge['is_claimed'] == true;
    final rewardXp = badge['reward_xp'] ?? 50;
    final currentProg = (badge['current_progress'] as num?)?.toInt() ?? 0;
    final targetProg = (badge['target_progress'] as num?)?.toInt() ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked
              ? const Color(0xFF2ED573).withOpacity(0.5)
              : context.palette.divider,
          width: isUnlocked ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Badge Icon Circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? const Color(0xFF2ED573).withOpacity(0.16)
                  : context.palette.divider.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isUnlocked ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
                color: isUnlocked
                    ? const Color(0xFF2ED573)
                    : context.palette.textSecondary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      badge['title']?.toString() ?? '',
                      style: TextStyle(
                        color: isUnlocked
                            ? context.palette.textPrimary
                            : context.palette.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA502).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+$rewardXp XP',
                        style: const TextStyle(
                          color: Color(0xFFFFA502),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  badge['description']?.toString() ?? '',
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                // Progress
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (currentProg / targetProg).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: context.palette.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUnlocked
                          ? const Color(0xFF2ED573)
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Action button
          if (isUnlocked && !isClaimed)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ED573),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _claimBadge(badge),
              child: const Text(
                'Nhận',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          else if (isClaimed)
            const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2ED573), size: 16),
                SizedBox(width: 3),
                Text(
                  'Đã nhận',
                  style: TextStyle(
                    color: Color(0xFF2ED573),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else
            Text(
              '$currentProg/$targetProg',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
