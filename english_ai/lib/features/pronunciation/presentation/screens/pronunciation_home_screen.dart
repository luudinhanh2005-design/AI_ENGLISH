import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/pronunciation_models.dart';
import '../providers/pronunciation_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HOME SCREEN: Chọn cấp độ, danh sách câu, lịch sử, thống kê
// ─────────────────────────────────────────────────────────────────────────────
class PronunciationHomeScreen extends ConsumerStatefulWidget {
  const PronunciationHomeScreen({super.key});

  @override
  ConsumerState<PronunciationHomeScreen> createState() =>
      _PronunciationHomeScreenState();
}

class _PronunciationHomeScreenState
    extends ConsumerState<PronunciationHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pronunciationProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _heroFade,
          child: SlideTransition(
            position: _heroSlide,
            child: CustomScrollView(
              slivers: [
                // ── App Bar ──
                SliverAppBar(
                  backgroundColor: context.palette.background,
                  elevation: 0,
                  pinned: true,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_rounded,
                        color: context.palette.textPrimary),
                    onPressed: () => context.pop(),
                  ),
                  title: Text(
                    'Luyện phát âm',
                    style: AppTextStyles.h4.copyWith(
                      color: context.palette.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.refresh_rounded,
                          color: context.palette.textSecondary),
                      tooltip: 'Tải lại',
                      onPressed: () {
                        ref
                            .read(pronunciationProvider.notifier)
                            .loadSentences(state.selectedLevel);
                        ref.read(pronunciationProvider.notifier).loadHistory();
                        ref.read(pronunciationProvider.notifier).loadStats();
                      },
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Hero stats card ──
                        _buildHeroCard(state),
                        const SizedBox(height: 24),

                        // ── Level filter ──
                        _buildLevelFilter(state),
                        const SizedBox(height: 16),

                        // ── Sentence list ──
                        _buildSentenceList(state),
                        const SizedBox(height: 24),

                        // ── Recent history ──
                        _buildHistorySection(state),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // HERO CARD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildHeroCard(PronunciationState state) {
    final stats = state.stats;
    final avgScore = stats.averageOverall;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1040), Color(0xFF0D2137)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.speaking.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.speaking.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.speaking.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.record_voice_over_rounded,
                    color: AppColors.speaking, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pronunciation Lab',
                      style: AppTextStyles.h4.copyWith(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Luyện giọng bản xứ cùng AI',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: context.palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _buildStatItem(
                avgScore > 0 ? '${avgScore.toStringAsFixed(0)}' : '--',
                'Điểm TB',
                Icons.equalizer_rounded,
                AppColors.speaking,
              ),
              _buildStatDivider(),
              _buildStatItem(
                '${stats.totalSessions}',
                'Lần luyện',
                Icons.repeat_rounded,
                AppColors.secondary,
              ),
              _buildStatDivider(),
              _buildStatItem(
                stats.bestScore > 0
                    ? '${stats.bestScore.toStringAsFixed(0)}'
                    : '--',
                'Điểm cao nhất',
                Icons.emoji_events_rounded,
                AppColors.warning,
              ),
              _buildStatDivider(),
              _buildStatItem(
                '${stats.currentStreak}',
                'Streak ngày',
                Icons.local_fire_department_rounded,
                AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick start button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('btn_quick_start_pronunciation'),
              onPressed: () {
                final sentences = ref.read(pronunciationProvider).sentences;
                if (sentences.isEmpty) return;
                sentences.shuffle();
                ref
                    .read(pronunciationProvider.notifier)
                    .selectSentence(sentences.first);
                context.push('/pronunciation/practice');
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Bắt đầu luyện ngay',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.speaking,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/pronunciation/shadowing'),
              icon: const Icon(Icons.mic_external_on_rounded,
                  size: 20, color: Color(0xFF00CEC9)),
              label: const Text(
                'Chế độ Luyện Nhại Giọng (Shadowing) 🎙️',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF00CEC9),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00CEC9), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.labelLarge.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: context.palette.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: context.palette.divider,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // LEVEL FILTER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildLevelFilter(PronunciationState state) {
    const levels = ['A1', 'A2', 'B1', 'B2', 'C1'];
    final levelColors = {
      'A1': AppColors.levelA1,
      'A2': AppColors.levelA2,
      'B1': AppColors.levelB1,
      'B2': AppColors.levelB2,
      'C1': AppColors.levelC1,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chọn cấp độ',
          style: AppTextStyles.labelMedium.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: levels.map((level) {
              final isSelected = state.selectedLevel == level;
              final color = levelColors[level]!;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => ref
                      .read(pronunciationProvider.notifier)
                      .loadSentences(level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.2)
                          : context.palette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : context.palette.divider,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 8)
                            ]
                          : [],
                    ),
                    child: Text(
                      level,
                      style: AppTextStyles.labelMedium.copyWith(
                        color:
                            isSelected ? color : context.palette.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SENTENCE LIST
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildSentenceList(PronunciationState state) {
    if (state.isLoadingSentences) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.speaking),
        ),
      );
    }

    if (state.sentences.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Không có câu luyện tập cho cấp độ này.',
            style: AppTextStyles.bodySmall
                .copyWith(color: context.palette.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Câu luyện tập (${state.sentences.length})',
              style: AppTextStyles.labelMedium.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              state.selectedLevel,
              style: AppTextStyles.labelSmall
                  .copyWith(color: context.palette.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...state.sentences.asMap().entries.map(
              (entry) => _buildSentenceCard(entry.value, entry.key),
            ),
      ],
    );
  }

  Widget _buildSentenceCard(PracticeSentenceModel sentence, int index) {
    return GestureDetector(
      onTap: () {
        ref.read(pronunciationProvider.notifier).selectSentence(sentence);
        context.push('/pronunciation/practice');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.palette.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.speaking.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.speaking,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sentence.text,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.palette.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  if (sentence.ipaTranscription.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      sentence.ipaTranscription,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.secondary.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.palette.cardLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      sentence.topic,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: context.palette.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: context.palette.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // HISTORY
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildHistorySection(PronunciationState state) {
    if (state.isLoadingHistory) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.speaking));
    }

    if (state.history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.palette.divider),
        ),
        child: Row(
          children: [
            Icon(Icons.history_rounded,
                color: context.palette.textSecondary, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chưa có lịch sử',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: context.palette.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Hoàn thành buổi luyện đầu tiên để xem kết quả tại đây!',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: context.palette.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lịch sử luyện tập',
              style: AppTextStyles.labelMedium.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Icon(Icons.history_rounded,
                color: context.palette.textSecondary, size: 18),
          ],
        ),
        const SizedBox(height: 12),
        ...state.history.take(5).map((item) => _buildHistoryItem(item)),
      ],
    );
  }

  Widget _buildHistoryItem(PronunciationHistoryModel item) {
    final score = item.overallScore;
    final color = score >= 80
        ? AppColors.success
        : score >= 60
            ? AppColors.warning
            : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              score.toStringAsFixed(0),
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.sentence.isNotEmpty ? item.sentence : '(Câu không rõ)',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.palette.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(item.createdAt),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: context.palette.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            score >= 80
                ? Icons.star_rounded
                : score >= 60
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            color: color,
            size: 20,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
