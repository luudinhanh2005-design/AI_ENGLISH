import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/speech_service.dart';
import '../../data/reading_data.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  ReadingArticle? _activeArticle;
  int _activeTabIndex = 0; // 0: Passage, 1: Vocab, 2: Quiz

  // Audio Playback
  bool _isPlayingPassage = false;
  int _currentPlayingParagraph = -1;

  // Quiz State
  final Map<int, int> _userAnswers = {};

  void _selectArticle(ReadingArticle article) {
    setState(() {
      _activeArticle = article;
      _activeTabIndex = 0;
      _isPlayingPassage = false;
      _currentPlayingParagraph = -1;
      _userAnswers.clear();
    });
  }

  void _backToArticleList() {
    SpeechService.stop();
    setState(() {
      _activeArticle = null;
      _isPlayingPassage = false;
      _currentPlayingParagraph = -1;
      _userAnswers.clear();
    });
  }

  void _playParagraph(String text, int paragraphIndex) {
    if (_isPlayingPassage && _currentPlayingParagraph == paragraphIndex) {
      SpeechService.stop();
      setState(() {
        _isPlayingPassage = false;
        _currentPlayingParagraph = -1;
      });
      return;
    }

    setState(() {
      _isPlayingPassage = true;
      _currentPlayingParagraph = paragraphIndex;
    });

    SpeechService.speak(text);

    final delayMs = (text.length * 60).clamp(3000, 15000);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted && _currentPlayingParagraph == paragraphIndex) {
        setState(() {
          _isPlayingPassage = false;
          _currentPlayingParagraph = -1;
        });
      }
    });
  }

  @override
  void dispose() {
    SpeechService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeArticle == null) {
      return _buildArticleSelector(context);
    }
    return _buildActiveArticle(context, _activeArticle!);
  }

  // ─────────────────────────────────────────────────────────────
  // 1. ARTICLE SELECTOR SCREEN
  // ─────────────────────────────────────────────────────────────
  Widget _buildArticleSelector(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 800 ? 800.0 : screenWidth;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimaryDark),
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
          'Luyện Đọc Hiểu (Reading)',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimaryDark,
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
                  // Banner header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10AC84), Color(0xFF1DD1A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10AC84).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.chrome_reader_mode_rounded,
                            color: Colors.white, size: 40),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đọc hiểu tiếng Anh đa chủ đề 📖',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Rèn luyện kỹ năng đọc lướt (Skimming) & tìm ý chính (Scanning)',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Kho bài đọc (${readingArticlesData.length} bài viết)',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...readingArticlesData.map((article) {
                    return _buildArticleCard(context, article);
                  }),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, ReadingArticle article) {
    Color levelColor = Colors.green;
    if (article.level == 'A2') levelColor = const Color(0xFF00CEC9);
    if (article.level == 'B1') levelColor = const Color(0xFFFFA502);
    if (article.level == 'B2') levelColor = const Color(0xFFFF4757);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkDivider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectArticle(article),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.reading.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: AppColors.reading,
                    size: 26,
                  ),
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
                              article.title,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textPrimaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: levelColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              article.level,
                              style: TextStyle(
                                color: levelColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        article.titleVi,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.reading,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        article.summaryVi,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 13, color: AppColors.textSecondaryDark),
                          const SizedBox(width: 4),
                          Text(
                            '~${article.readTimeMinutes} phút đọc',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Icon(Icons.text_fields_rounded,
                              size: 13, color: AppColors.textSecondaryDark),
                          const SizedBox(width: 4),
                          Text(
                            '${article.wordCount} từ',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Icon(Icons.quiz_outlined,
                              size: 13, color: AppColors.textSecondaryDark),
                          const SizedBox(width: 4),
                          Text(
                            '${article.questions.length} câu hỏi',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.darkTextHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. ACTIVE ARTICLE SCREEN
  // ─────────────────────────────────────────────────────────────
  Widget _buildActiveArticle(BuildContext context, ReadingArticle article) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 800 ? 800.0 : screenWidth;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimaryDark),
          tooltip: 'Quay lại',
          onPressed: _backToArticleList,
        ),
        title: Column(
          children: [
            Text(
              article.title,
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${article.titleVi} • ${article.level}',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.reading,
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondaryDark),
            tooltip: 'Thoát',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/learn');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tab Switcher
                  _buildTabSwitcher(),

                  // Tab Content
                  Expanded(
                    child: _activeTabIndex == 0
                        ? _buildPassageTab(article)
                        : _activeTabIndex == 1
                            ? _buildVocabTab(article)
                            : _buildQuizTab(article),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildTabItem(0, 'Bài đọc', Icons.article_rounded),
          const SizedBox(width: 8),
          _buildTabItem(1, 'Từ vựng', Icons.book_rounded),
          const SizedBox(width: 8),
          _buildTabItem(2, 'Câu hỏi hiểu bài', Icons.quiz_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _activeTabIndex == index;
    return Expanded(
      child: Material(
        color: isSelected
            ? AppColors.reading.withOpacity(0.2)
            : AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _activeTabIndex = index;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.reading : AppColors.darkDivider,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.reading
                      : AppColors.textSecondaryDark,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.reading
                        : AppColors.textSecondaryDark,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: PASSAGE
  // ─────────────────────────────────────────────────────────────
  Widget _buildPassageTab(ReadingArticle article) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        // Topic banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkDivider),
          ),
          child: Row(
            children: [
              const Icon(Icons.category_rounded,
                  size: 16, color: AppColors.reading),
              const SizedBox(width: 8),
              Text(
                'Chủ đề: ${article.topic}',
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${article.wordCount} words • ~${article.readTimeMinutes} min',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ...List.generate(article.paragraphs.length, (pIdx) {
          final pText = article.paragraphs[pIdx];
          final isPlayingThis =
              _isPlayingPassage && _currentPlayingParagraph == pIdx;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPlayingThis
                  ? AppColors.reading.withOpacity(0.12)
                  : AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isPlayingThis ? AppColors.reading : AppColors.darkDivider,
                width: isPlayingThis ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Đoạn ${pIdx + 1}',
                      style: TextStyle(
                        color: AppColors.reading,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        isPlayingThis
                            ? Icons.pause_circle_rounded
                            : Icons.volume_up_rounded,
                        color:
                            isPlayingThis ? Colors.orange : AppColors.reading,
                        size: 20,
                      ),
                      tooltip: 'Nghe đoạn văn này',
                      onPressed: () => _playParagraph(pText, pIdx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  pText,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontSize: 15,
                    height: 1.6,
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

  // ─────────────────────────────────────────────────────────────
  // TAB 2: VOCABULARY
  // ─────────────────────────────────────────────────────────────
  Widget _buildVocabTab(ReadingArticle article) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: article.vocabulary.length,
      itemBuilder: (context, index) {
        final vocab = article.vocabulary[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.darkDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vocab.word,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.reading,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          vocab.phonetic,
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded,
                        color: AppColors.reading),
                    tooltip: 'Phát âm từ',
                    onPressed: () => SpeechService.speak(vocab.word),
                  ),
                ],
              ),
              const Divider(color: AppColors.darkDivider, height: 16),
              Text(
                'Nghĩa: ${vocab.meaning}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ngữ cảnh: "${vocab.contextSentence}"',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: QUIZ
  // ─────────────────────────────────────────────────────────────
  Widget _buildQuizTab(ReadingArticle article) {
    int totalQuestions = article.questions.length;
    int answeredCount = _userAnswers.length;
    int correctCount = 0;
    _userAnswers.forEach((qIdx, optIdx) {
      if (optIdx == article.questions[qIdx].correctIndex) {
        correctCount++;
      }
    });

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        if (answeredCount == totalQuestions) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: correctCount == totalQuestions
                    ? [const Color(0xFF10AC84), const Color(0xFF1DD1A1)]
                    : [const Color(0xFF2E86DE), const Color(0xFF54A0FF)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  correctCount == totalQuestions
                      ? '🎉 Đỉnh cao! Đúng trọn vẹn $totalQuestions/$totalQuestions'
                      : 'Đã hoàn thành! Điểm: $correctCount/$totalQuestions câu',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Xem lại giải thích đáp án cho từng câu bên dưới',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...List.generate(article.questions.length, (qIdx) {
          final q = article.questions[qIdx];
          final selected = _userAnswers[qIdx];
          final isAnswered = selected != null;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkDivider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Câu ${qIdx + 1}: ${q.question}',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  q.questionVi,
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(q.options.length, (optIdx) {
                  final optionText = q.options[optIdx];
                  final isThisSelected = selected == optIdx;
                  final isCorrect = optIdx == q.correctIndex;

                  Color optBg = AppColors.backgroundDark;
                  Color optBorder = AppColors.darkDivider;
                  Color optTextColor = AppColors.textPrimaryDark;

                  if (isAnswered) {
                    if (isCorrect) {
                      optBg = Colors.green.withOpacity(0.15);
                      optBorder = Colors.green;
                      optTextColor = Colors.greenAccent;
                    } else if (isThisSelected) {
                      optBg = Colors.red.withOpacity(0.15);
                      optBorder = Colors.red;
                      optTextColor = Colors.redAccent;
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: optBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: optBorder),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: isAnswered
                            ? null
                            : () {
                                setState(() {
                                  _userAnswers[qIdx] = optIdx;
                                });
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Text(
                                String.fromCharCode(65 + optIdx) + '.',
                                style: TextStyle(
                                  color: optTextColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  optionText,
                                  style: TextStyle(
                                    color: optTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (isAnswered && isCorrect)
                                const Icon(Icons.check_circle_rounded,
                                    color: Colors.green, size: 18),
                              if (isAnswered && isThisSelected && !isCorrect)
                                const Icon(Icons.cancel_rounded,
                                    color: Colors.red, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (isAnswered) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.reading.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_rounded,
                            color: AppColors.secondary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Giải thích: ${q.explanation}',
                            style: const TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontSize: 12,
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
        const SizedBox(height: 32),
      ],
    );
  }
}
