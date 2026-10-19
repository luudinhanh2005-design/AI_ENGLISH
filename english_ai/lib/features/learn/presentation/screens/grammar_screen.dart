import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/speech_service.dart';
import '../../data/grammar_data.dart';

class GrammarScreen extends StatefulWidget {
  final String? initialLessonId;

  const GrammarScreen({super.key, this.initialLessonId});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  String _selectedLevel = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  GrammarLesson? _activeLesson;

  @override
  void initState() {
    super.initState();
    if (widget.initialLessonId != null) {
      final found = grammarLessonsData.firstWhere(
        (l) => l.id == widget.initialLessonId,
        orElse: () => grammarLessonsData.first,
      );
      _activeLesson = found;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openLesson(GrammarLesson lesson) {
    setState(() {
      _activeLesson = lesson;
    });
  }

  void _closeLesson() {
    setState(() {
      _activeLesson = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeLesson != null) {
      return _GrammarLessonDetailView(
        lesson: _activeLesson!,
        onBack: _closeLesson,
      );
    }

    final filteredLessons = grammarLessonsData.where((l) {
      final matchesLevel = _selectedLevel == 'All' || l.level == _selectedLevel;
      final matchesQuery = _searchQuery.isEmpty ||
          l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.titleVi.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesLevel && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.palette.textPrimary),
          tooltip: 'Thoát',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/learn');
            }
          },
        ),
        title: Text(
          'Ngữ Pháp Toàn Diện (Grammar)',
          style: AppTextStyles.titleMedium.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero Banner ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C5CE7).withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_stories_rounded,
                              color: Colors.white, size: 36),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hệ thống ngữ pháp chuẩn CEFR 📚',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Lý thuyết cô đọng, công thức dễ nhớ, ví dụ thực tế và bài tập kiểm tra tức thì',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Search Bar ──
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: context.palette.textPrimary),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm thì, cấu trúc, mệnh đề...',
                      hintStyle: TextStyle(
                          color: context.palette.textHint, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: context.palette.card,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Level Filter Chips ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                            'All', 'Tất cả (${grammarLessonsData.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('A1', 'A1 Căn bản'),
                        const SizedBox(width: 8),
                        _buildFilterChip('A2', 'A2 Sơ cấp'),
                        const SizedBox(width: 8),
                        _buildFilterChip('B1', 'B1 Trung cấp'),
                        const SizedBox(width: 8),
                        _buildFilterChip('B2', 'B2 Nâng cao'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Lesson List ──
                  if (filteredLessons.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 48, color: context.palette.textHint),
                          const SizedBox(height: 12),
                          Text(
                            'Không tìm thấy bài học ngữ pháp phù hợp',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: context.palette.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredLessons
                        .map((lesson) => _buildLessonItem(lesson)),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String level, String label) {
    final isSelected = _selectedLevel == level;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedLevel = level),
      backgroundColor: context.palette.card,
      selectedColor: AppColors.primary.withOpacity(0.25),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : context.palette.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : context.palette.divider,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildLessonItem(GrammarLesson lesson) {
    Color levelColor = Colors.green;
    if (lesson.level == 'A2') levelColor = const Color(0xFF00CEC9);
    if (lesson.level == 'B1') levelColor = const Color(0xFFFFA502);
    if (lesson.level == 'B2') levelColor = const Color(0xFFFF4757);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openLesson(lesson),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.menu_book_rounded,
                      color: levelColor, size: 24),
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
                              lesson.title,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: context.palette.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: levelColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lesson.level,
                              style: TextStyle(
                                color: levelColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        lesson.titleVi,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lesson.description,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 2. DETAILED LESSON VIEW WITH TABS
// ─────────────────────────────────────────────────────────────
class _GrammarLessonDetailView extends StatefulWidget {
  final GrammarLesson lesson;
  final VoidCallback onBack;

  const _GrammarLessonDetailView({
    required this.lesson,
    required this.onBack,
  });

  @override
  State<_GrammarLessonDetailView> createState() =>
      _GrammarLessonDetailViewState();
}

class _GrammarLessonDetailViewState extends State<_GrammarLessonDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Quiz state
  final Map<int, int> _selectedAnswers = {};
  int _score = 0;
  bool _quizCompleted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectQuizOption(int qIndex, int optIndex) {
    if (_selectedAnswers.containsKey(qIndex)) return;
    setState(() {
      _selectedAnswers[qIndex] = optIndex;
      if (optIndex == widget.lesson.quiz[qIndex].correctIndex) {
        _score++;
      }
      if (_selectedAnswers.length == widget.lesson.quiz.length) {
        _quizCompleted = true;
      }
    });
  }

  void _resetQuiz() {
    setState(() {
      _selectedAnswers.clear();
      _score = 0;
      _quizCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color levelColor = Colors.green;
    if (widget.lesson.level == 'A2') levelColor = const Color(0xFF00CEC9);
    if (widget.lesson.level == 'B1') levelColor = const Color(0xFFFFA502);
    if (widget.lesson.level == 'B2') levelColor = const Color(0xFFFF4757);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.palette.textPrimary),
          onPressed: widget.onBack,
        ),
        title: Column(
          children: [
            Text(
              widget.lesson.title,
              style: AppTextStyles.titleSmall.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.lesson.titleVi,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.secondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: levelColor.withOpacity(0.5)),
            ),
            child: Text(
              widget.lesson.level,
              style: TextStyle(
                color: levelColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.palette.textSecondary,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            const Tab(
                icon: Icon(Icons.menu_book_rounded, size: 18),
                text: 'Lý thuyết'),
            const Tab(
                icon: Icon(Icons.lightbulb_outline_rounded, size: 18),
                text: 'Ví dụ & Lỗi'),
            Tab(
              icon: const Icon(Icons.quiz_rounded, size: 18),
              text: 'Kiểm tra (${widget.lesson.quiz.length})',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTheoryTab(levelColor),
                  _buildExamplesTab(),
                  _buildQuizTab(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab 1: Theory & Formulas ──
  Widget _buildTheoryTab(Color levelColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
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
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.secondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Định nghĩa & Ý nghĩa',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: context.palette.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.lesson.description,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.palette.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Formula Cards
        Text(
          'Công thức cốt lõi 📐',
          style: AppTextStyles.labelLarge.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        _buildFormulaRow(
          symbol: '+',
          title: 'Khẳng định (Affirmative)',
          formula: widget.lesson.formulaAffirmative,
          color: Colors.green,
        ),
        const SizedBox(height: 8),
        _buildFormulaRow(
          symbol: '-',
          title: 'Phủ định (Negative)',
          formula: widget.lesson.formulaNegative,
          color: Colors.redAccent,
        ),
        const SizedBox(height: 8),
        _buildFormulaRow(
          symbol: '?',
          title: 'Nghi vấn (Question)',
          formula: widget.lesson.formulaQuestion,
          color: Colors.blueAccent,
        ),

        const SizedBox(height: 20),

        // Time markers
        Text(
          'Dấu hiệu nhận biết & Từ then chốt ⚡',
          style: AppTextStyles.labelLarge.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.lesson.timeMarkers.map((marker) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                marker,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Usage Rules
        Text(
          'Cách sử dụng chi tiết 📋',
          style: AppTextStyles.labelLarge.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...widget.lesson.usageRules.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final rule = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$idx',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rule,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.palette.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFormulaRow({
    required String symbol,
    required String title,
    required String formula,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              symbol,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formula,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Examples & Common Mistakes ──
  Widget _buildExamplesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Ví dụ thực tế & Phát âm 🎙️',
          style: AppTextStyles.labelLarge.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...widget.lesson.examples.map((ex) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.palette.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded,
                      color: AppColors.secondary),
                  tooltip: 'Nghe phát âm',
                  onPressed: () => SpeechService.speak(ex.english),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.english,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ex.vietnamese,
                        style: TextStyle(
                          color: AppColors.secondary.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                      if (ex.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '💡 ${ex.note}',
                          style: TextStyle(
                            color: context.palette.textSecondary,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        Text(
          'Lỗi sai người học hay mắc phải ⚠️',
          style: AppTextStyles.labelLarge.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...widget.lesson.commonMistakes.map((mistake) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE74C3C).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFFE74C3C).withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFE74C3C), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    mistake,
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Tab 3: Interactive Quiz ──
  Widget _buildQuizTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_quizCompleted)
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2ED573), Color(0xFF1ABC9C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech_rounded,
                    color: Colors.white, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hoàn thành: $_score/${widget.lesson.quiz.length} câu đúng! 🎉',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _score == widget.lesson.quiz.length
                            ? 'Xuất sắc! Bạn đã nắm vững điểm ngữ pháp này.'
                            : 'Tốt lắm! Hãy xem lại các câu giải thích bên dưới.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _resetQuiz,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Làm lại'),
                ),
              ],
            ),
          ),
        ...widget.lesson.quiz.asMap().entries.map((entry) {
          final qIndex = entry.key;
          final q = entry.value;
          final userSelected = _selectedAnswers[qIndex];
          final isAnswered = userSelected != null;

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Câu ${qIndex + 1}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        q.question,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Options
                ...q.options.asMap().entries.map((optEntry) {
                  final optIndex = optEntry.key;
                  final optText = optEntry.value;
                  final isThisOptionSelected = userSelected == optIndex;
                  final isThisCorrect = optIndex == q.correctIndex;

                  Color optBg = context.palette.surface;
                  Color optBorder = context.palette.divider;
                  Color textColor = context.palette.textPrimary;

                  if (isAnswered) {
                    if (isThisCorrect) {
                      optBg = Colors.green.withOpacity(0.15);
                      optBorder = Colors.green;
                      textColor = Colors.greenAccent;
                    } else if (isThisOptionSelected) {
                      optBg = Colors.red.withOpacity(0.15);
                      optBorder = Colors.red;
                      textColor = Colors.redAccent;
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: optBg,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: isAnswered
                            ? null
                            : () => _selectQuizOption(qIndex, optIndex),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: optBorder),
                          ),
                          child: Row(
                            children: [
                              Text(
                                String.fromCharCode(65 + optIndex),
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  optText,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (isAnswered && isThisCorrect)
                                const Icon(Icons.check_circle_rounded,
                                    color: Colors.green, size: 18),
                              if (isAnswered &&
                                  isThisOptionSelected &&
                                  !isThisCorrect)
                                const Icon(Icons.cancel_rounded,
                                    color: Colors.red, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Explanation
                if (isAnswered) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.secondary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Giải thích: ${q.explanation}',
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}
