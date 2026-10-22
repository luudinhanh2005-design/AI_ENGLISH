import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/speech_web.dart';
import '../providers/mistake_notebook_provider.dart';

class MistakeNotebookScreen extends ConsumerStatefulWidget {
  const MistakeNotebookScreen({super.key});

  @override
  ConsumerState<MistakeNotebookScreen> createState() =>
      _MistakeNotebookScreenState();
}

class _MistakeNotebookScreenState extends ConsumerState<MistakeNotebookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Flashcard review mode state
  int _cardIndex = 0;
  bool _isFlipped = false;
  int _reviewedSessionCount = 0;
  bool _sessionComplete = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _isFlipped = false;
        _cardIndex = 0;
        _sessionComplete = false;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _speakSentence(String text) {
    webSpeak(text, 0.95);
  }

  void _showAddMistakeDialog(BuildContext context) {
    final origController = TextEditingController();
    final corrController = TextEditingController();
    final explController = TextEditingController();
    String selectedType = 'grammar';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenHeight = MediaQuery.of(context).size.height;
            return Container(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.palette.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Thêm Lỗi Sai Mới ✍️',
                      style: AppTextStyles.h3.copyWith(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ghi chú lại câu bạn từng nói hoặc viết sai để ôn tập lại thường xuyên',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Type Selector
                    Row(
                      children: [
                        _buildTypeChip('Ngữ pháp', 'grammar', selectedType,
                            (t) => setModalState(() => selectedType = t)),
                        const SizedBox(width: 8),
                        _buildTypeChip('Từ vựng', 'vocabulary', selectedType,
                            (t) => setModalState(() => selectedType = t)),
                        const SizedBox(width: 8),
                        _buildTypeChip('Phát âm', 'pronunciation', selectedType,
                            (t) => setModalState(() => selectedType = t)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: origController,
                      style: TextStyle(color: context.palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Câu gốc có lỗi (Ví dụ: She don\'t like)',
                        prefixIcon: const Icon(Icons.close_rounded,
                            color: Color(0xFFFF6B6B)),
                        filled: true,
                        fillColor: context.palette.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: context.palette.divider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: corrController,
                      style: TextStyle(color: context.palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Câu sửa đúng (Ví dụ: She doesn\'t like)',
                        prefixIcon: const Icon(Icons.check_circle_outline_rounded,
                            color: Color(0xFF2ED573)),
                        filled: true,
                        fillColor: context.palette.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: context.palette.divider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: explController,
                      maxLines: 2,
                      style: TextStyle(color: context.palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Giải thích / Quy tắc ngữ pháp',
                        prefixIcon: const Icon(Icons.lightbulb_outline_rounded,
                            color: Color(0xFFFFA502)),
                        filled: true,
                        fillColor: context.palette.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: context.palette.divider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          if (origController.text.trim().isEmpty ||
                              corrController.text.trim().isEmpty) {
                            return;
                          }
                          ref.read(mistakeNotebookProvider.notifier).addMistake(
                                originalText: origController.text.trim(),
                                correctedText: corrController.text.trim(),
                                explanation: explController.text.trim().isEmpty
                                    ? 'Cần ghi nhớ dạng đúng của câu này.'
                                    : explController.text.trim(),
                                type: selectedType,
                                source: 'custom',
                              );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Đã thêm lỗi vào sổ tay ôn tập!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Text(
                          'Lưu Vào Sổ Tay',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
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

  Widget _buildTypeChip(
      String label, String value, String current, Function(String) onSelect) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.18)
              : context.palette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.palette.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.primary
                : context.palette.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mistakeNotebookProvider);
    final allItems = state.filteredItems.where((m) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return m.originalText.toLowerCase().contains(q) ||
          m.correctedText.toLowerCase().contains(q) ||
          m.explanation.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                // ── Top Bar ──
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
                              'Sổ Tay Lỗi Sai & Từ Vựng 📓',
                              style: AppTextStyles.h3.copyWith(
                                color: context.palette.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Ghi nhớ triệt để bằng phương pháp Lặp Lại Ngắt Quãng (SM-2)',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.palette.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showAddMistakeDialog(context),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.12),
                        ),
                        icon: const Icon(Icons.add_rounded,
                            color: AppColors.primary),
                        tooltip: 'Thêm lỗi thủ công',
                      ),
                    ],
                  ),
                ),

                // ── Stats Summary Banner ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C5CE7).withOpacity(0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox(
                          icon: Icons.bookmark_added_rounded,
                          label: 'Tổng lỗi lưu',
                          value: '${state.totalCount}',
                        ),
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withOpacity(0.3)),
                        _buildStatBox(
                          icon: Icons.alarm_rounded,
                          label: 'Cần ôn hôm nay',
                          value: '${state.dueCount}',
                          highlight: state.dueCount > 0,
                        ),
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withOpacity(0.3)),
                        _buildStatBox(
                          icon: Icons.verified_rounded,
                          label: 'Đã thành thạo',
                          value: '${state.masteredCount}',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

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
                        Tab(text: 'Danh Sách Lỗi Sai 📋'),
                        Tab(text: 'Ôn Tập Flashcard SM-2 ⚡'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Tab Views ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: LIST VIEW
                      _buildListView(context, state, allItems),
                      // TAB 2: FLASHCARD SM-2 REVIEW
                      _buildFlashcardView(context, state, allItems),
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

  Widget _buildStatBox({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: highlight ? const Color(0xFFFFEAA7) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // TAB 1: LIST VIEW
  // ──────────────────────────────────────────────
  Widget _buildListView(
      BuildContext context, MistakeNotebookState state, List<MistakeItem> items) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Filter Chips
          Row(
            children: [
              _buildFilterChip('Tất cả', null, state.filterType),
              const SizedBox(width: 6),
              _buildFilterChip('Ngữ pháp 📝', 'grammar', state.filterType),
              const SizedBox(width: 6),
              _buildFilterChip('Từ vựng 💡', 'vocabulary', state.filterType),
              const SizedBox(width: 6),
              _buildFilterChip('Phát âm 🎙️', 'pronunciation', state.filterType),
            ],
          ),
          const SizedBox(height: 12),

          // Search Box
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: context.palette.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm lỗi sai, từ vựng hoặc giải thích...',
              hintStyle: TextStyle(
                  color: context.palette.textSecondary.withOpacity(0.6),
                  fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  color: context.palette.textSecondary, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: context.palette.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.palette.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.palette.divider),
              ),
            ),
          ),
          const SizedBox(height: 14),

          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 54, color: Color(0xFF2ED573)),
                  const SizedBox(height: 12),
                  Text(
                    'Không tìm thấy lỗi sai nào!',
                    style: AppTextStyles.h4.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Các lỗi trong hội thoại AI hoặc bài viết sẽ tự động lưu vào đây.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.map((item) => _buildMistakeCard(context, item)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, String? current) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: () => ref.read(mistakeNotebookProvider.notifier).setFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : context.palette.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.palette.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.palette.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildMistakeCard(BuildContext context, MistakeItem item) {
    Color typeColor = const Color(0xFF6C5CE7);
    if (item.type == 'vocabulary') typeColor = const Color(0xFF00CEC9);
    if (item.type == 'pronunciation') typeColor = const Color(0xFFFFA502);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isDue
              ? const Color(0xFFFF6B6B).withOpacity(0.5)
              : context.palette.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Type badge, Due badge, audio, delete
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.type.toUpperCase(),
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.isDue)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alarm_rounded,
                          size: 11, color: Color(0xFFFF6B6B)),
                      SizedBox(width: 3),
                      Text(
                        'Cần ôn hôm nay',
                        style: TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (item.status == 'mastered')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ED573).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Đã thành thạo ⭐',
                    style: TextStyle(
                      color: Color(0xFF2ED573),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
              // Source
              Text(
                item.source == 'voice_call'
                    ? '🗣️ Hội thoại'
                    : item.source == 'writing'
                        ? '✍️ Bài viết'
                        : item.source == 'ielts'
                            ? '🏆 IELTS'
                            : '⚡ Rèn luyện',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _speakSentence(item.correctedText),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.volume_up_rounded,
                      color: AppColors.primary, size: 20),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  ref
                      .read(mistakeNotebookProvider.notifier)
                      .deleteMistake(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xoá lỗi khỏi sổ tay.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded,
                      color: context.palette.textSecondary.withOpacity(0.5),
                      size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Original (Wrong) sentence
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFFF6B6B).withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.close_rounded,
                    color: Color(0xFFFF6B6B), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.originalText,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Corrected sentence
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2ED573).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF2ED573).withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_rounded,
                    color: Color(0xFF2ED573), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.correctedText,
                    style: const TextStyle(
                      color: Color(0xFF2ED573),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Explanation
          Text(
            '💡 ${item.explanation}',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 2: FLASHCARD SM-2 REVIEW
  // ──────────────────────────────────────────────
  Widget _buildFlashcardView(
      BuildContext context, MistakeNotebookState state, List<MistakeItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Không có thẻ nào cần ôn tập hôm nay! 🎉',
          style: TextStyle(color: context.palette.textSecondary),
        ),
      );
    }

    if (_sessionComplete || _cardIndex >= items.length) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00CEC9), Color(0xFF6C5CE7)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00CEC9).withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    size: 48, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                'Hoàn Thành Phiên Ôn Tập! 🎉',
                style: AppTextStyles.h2.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn đã củng cố thành công $_reviewedSessionCount lỗi sai với thuật toán Spaced Repetition.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA502).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFFFA502).withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded,
                        color: Color(0xFFFFA502), size: 20),
                    SizedBox(width: 6),
                    Text(
                      '+30 XP Rèn Luyện Tích Lũy',
                      style: TextStyle(
                        color: Color(0xFFFFA502),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  setState(() {
                    _cardIndex = 0;
                    _isFlipped = false;
                    _sessionComplete = false;
                    _reviewedSessionCount = 0;
                  });
                },
                icon: const Icon(Icons.replay_rounded, color: Colors.white),
                label: const Text(
                  'Ôn Tập Lại Từ Đầu',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentItem = items[_cardIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thẻ ${_cardIndex + 1}/${items.length}',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'Khoảng lặp: ${currentItem.intervalDays} ngày',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_cardIndex + 1) / items.length,
              minHeight: 6,
              backgroundColor: context.palette.divider,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 18),

          // Interactive 3D Flip Card
          GestureDetector(
            onTap: () => setState(() => _isFlipped = !_isFlipped),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 280),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isFlipped
                      ? const Color(0xFF2ED573).withOpacity(0.6)
                      : const Color(0xFF6C5CE7).withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isFlipped
                            ? const Color(0xFF2ED573)
                            : const Color(0xFF6C5CE7))
                        .withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Badge tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_isFlipped
                              ? const Color(0xFF2ED573)
                              : const Color(0xFFFF6B6B))
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isFlipped
                          ? 'DẠNG ĐÚNG CHUẨN BẢN XỨ ✅'
                          : 'LỖI CẦN SỬA ❌',
                      style: TextStyle(
                        color: _isFlipped
                            ? const Color(0xFF2ED573)
                            : const Color(0xFFFF6B6B),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (!_isFlipped) ...[
                    Text(
                      currentItem.originalText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.palette.background,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: context.palette.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Chạm thẻ để lật đáp án & phát âm',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            currentItem.correctedText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF2ED573),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () =>
                              _speakSentence(currentItem.correctedText),
                          icon: const Icon(Icons.volume_up_rounded,
                              color: Color(0xFF2ED573), size: 24),
                          tooltip: 'Nghe phát âm chuẩn',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.palette.background,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: context.palette.divider),
                      ),
                      child: Text(
                        '💡 ${currentItem.explanation}',
                        style: TextStyle(
                          color: context.palette.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // SM-2 Review Rating Buttons
          if (_isFlipped) ...[
            Text(
              'Bạn nhớ câu này thế nào? (Thuật toán SM-2)',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSM2Button(
                    label: 'Quên hẳn',
                    sub: 'Lặp lại',
                    color: const Color(0xFFFF6B6B),
                    rating: 0,
                    item: currentItem,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSM2Button(
                    label: 'Khó',
                    sub: '+1 ngày',
                    color: const Color(0xFFFFA502),
                    rating: 2,
                    item: currentItem,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSM2Button(
                    label: 'Tốt',
                    sub: '+3 ngày',
                    color: const Color(0xFF00CEC9),
                    rating: 4,
                    item: currentItem,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSM2Button(
                    label: 'Rất dễ',
                    sub: '+7 ngày',
                    color: const Color(0xFF2ED573),
                    rating: 5,
                    item: currentItem,
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => setState(() => _isFlipped = true),
                icon: const Icon(Icons.flip_rounded, color: AppColors.primary),
                label: const Text(
                  'Xem Câu Sửa Đúng & Giải Thích',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSM2Button({
    required String label,
    required String sub,
    required Color color,
    required int rating,
    required MistakeItem item,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.14),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
      onPressed: () {
        ref
            .read(mistakeNotebookProvider.notifier)
            .reviewMistake(item.id, rating);
        setState(() {
          _reviewedSessionCount++;
          _isFlipped = false;
          _cardIndex++;
        });
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
