import '../../../../core/utils/speech_service.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/vocabulary_list_provider.dart';

class VocabularyListScreen extends ConsumerStatefulWidget {
  const VocabularyListScreen({super.key});

  @override
  ConsumerState<VocabularyListScreen> createState() =>
      _VocabularyListScreenState();
}

class _VocabularyListScreenState extends ConsumerState<VocabularyListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedLevel = 'All Levels';
  bool _flashcardMode = false;

  final List<String> _levels = [
    'All Levels',
    'A1',
    'A2',
    'B1',
    'B2',
    'C1',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(allVocabularyWordsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimaryDark),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/vocabulary');
            }
          },
        ),
        title: Text(
          'Kho Từ Vựng',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: wordsAsync.maybeWhen(
              data: (words) => Chip(
                label: Text('${words.length} từ',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.primary)),
                backgroundColor: AppColors.primary.withOpacity(0.15),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
              ),
              orElse: () => const SizedBox(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            width: double.infinity,
            height: double.infinity,
            child: Column(
              children: [
          // ── Search & Filter Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textPrimaryDark),
                    decoration: InputDecoration(
                      hintText: 'Search word...',
                      hintStyle: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondaryDark),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textSecondaryDark, size: 20),
                      filled: true,
                      fillColor: AppColors.surfaceDark,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLevel,
                      dropdownColor: AppColors.surfaceDark,
                      style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textPrimaryDark),
                      icon: const Icon(Icons.expand_more,
                          color: AppColors.textSecondaryDark, size: 18),
                      items: _levels
                          .map((l) => DropdownMenuItem(
                              value: l,
                              child: Text(l,
                                  style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textPrimaryDark))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedLevel = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Action Buttons ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    label: 'Search',
                    color: AppColors.primary,
                    icon: Icons.search_rounded,
                    onTap: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    label: _flashcardMode ? 'List Mode' : 'Flashcard Mode',
                    color: const Color(0xFFFFA502),
                    icon: _flashcardMode ? Icons.grid_view : Icons.style_rounded,
                    onTap: () => setState(() => _flashcardMode = !_flashcardMode),
                  ),
                ),
              ],
            ),
          ),

          // ── Word Grid / Flashcard Grid ──
          Expanded(
            child: wordsAsync.when(
              data: (allWords) {
                final query = _searchController.text.toLowerCase().trim();
                final filtered = allWords.where((w) {
                  final matchesQuery = query.isEmpty ||
                      w.word.toLowerCase().contains(query) ||
                      w.meaningVi.toLowerCase().contains(query);
                  final matchesLevel = _selectedLevel == 'All Levels' ||
                      w.level == _selectedLevel;
                  return matchesQuery && matchesLevel;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off,
                            color: AppColors.textSecondaryDark, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Không tìm thấy từ nào',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondaryDark),
                        ),
                      ],
                    ),
                  );
                }

                if (_flashcardMode) {
                  return _FlashcardGrid(words: filtered);
                }
                return _WordGrid(words: filtered);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Không thể tải từ vựng',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textPrimaryDark),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          ref.refresh(allVocabularyWordsProvider),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
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
}

// ── Word Grid (vocabulary list style like screenshot 3) ──
class _WordGrid extends StatelessWidget {
  final List<dynamic> words;
  const _WordGrid({required this.words});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 750
            ? (constraints.maxWidth > 1000 ? 4 : 3)
            : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemCount: words.length,
          itemBuilder: (context, i) => _WordCard(word: words[i]),
        );
      },
    );
  }
}

class _WordCard extends StatelessWidget {
  final dynamic word;
  const _WordCard({required this.word});

  Color _levelColor(String level) {
    switch (level) {
      case 'A1':
      case 'A2':
        return const Color(0xFF2ED573);
      case 'B1':
      case 'B2':
        return const Color(0xFF1E90FF);
      default:
        return const Color(0xFFFF6B6B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lvlColor = _levelColor(word.level as String);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            word.word as String,
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            word.meaningVi as String,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            word.exampleSentence as String,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondaryDark,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: lvlColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              word.level as String,
              style: AppTextStyles.labelSmall.copyWith(
                color: lvlColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              SpeechService.speak(word.word as String);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.volume_up_rounded,
                      color: AppColors.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Pronounce',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Flashcard Grid (flip EN → VI) like screenshot 2 ──
class _FlashcardGrid extends StatelessWidget {
  final List<dynamic> words;
  const _FlashcardGrid({required this.words});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 750
            ? (constraints.maxWidth > 1000 ? 4 : 3)
            : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: words.length,
          itemBuilder: (context, i) => _FlipCard(word: words[i]),
        );
      },
    );
  }
}

class _FlipCard extends StatefulWidget {
  final dynamic word;
  const _FlipCard({required this.word});

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _anim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _flip() {
    HapticFeedback.selectionClick();
    if (_flipped) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    setState(() => _flipped = !_flipped);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (ctx, child) {
          final angle = _anim.value * pi;
          final isBack = angle > (pi / 2);
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _CardBack(word: widget.word),
                  )
                : _CardFront(word: widget.word),
          );
        },
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  final dynamic word;
  const _CardFront({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word.word as String,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            word.phonetic as String,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF636E72)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            '👆 Nhấn để lật',
            style: TextStyle(
                fontSize: 10,
                color: Color(0xFFB2BEC3)),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final dynamic word;
  const _CardBack({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word.word as String,
            style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            word.meaningVi as String,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            word.exampleSentence as String,
            style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
