import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/speech_service.dart';
import '../../data/listening_data.dart';

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with SingleTickerProviderStateMixin {
  ListeningLesson? _activeLesson;
  int _activeTabIndex = 0; // 0: Dialogue, 1: Vocab, 2: Quiz

  // Audio Playback State
  bool _isPlayingAll = false;
  int _currentPlayingLineIndex = -1;
  double _playbackRate = 1.0;
  bool _showTranslation = true;

  // Mỗi lần phát/dừng/đổi bài tăng số này; vòng lặp phát cũ thấy số khác sẽ tự thoát.
  int _playSession = 0;

  // Quiz State
  final Map<int, int> _userAnswers = {}; // questionIndex -> selectedOptionIndex

  void _selectLesson(ListeningLesson lesson) {
    _playSession++;
    SpeechService.stop();
    setState(() {
      _activeLesson = lesson;
      _activeTabIndex = 0;
      _isPlayingAll = false;
      _currentPlayingLineIndex = -1;
      _userAnswers.clear();
    });
  }

  void _backToLessonList() {
    _playSession++;
    SpeechService.stop();
    setState(() {
      _activeLesson = null;
      _isPlayingAll = false;
      _currentPlayingLineIndex = -1;
      _userAnswers.clear();
    });
  }

  Future<void> _playSingleLine(String text, int lineIndex) async {
    final session = ++_playSession;
    setState(() {
      _isPlayingAll = false;
      _currentPlayingLineIndex = lineIndex;
    });

    // Chờ đọc xong thật sự (không dùng timer đoán thời gian).
    await SpeechService.speak(text, rate: _playbackRate);

    if (mounted && session == _playSession) {
      setState(() {
        _currentPlayingLineIndex = -1;
      });
    }
  }

  Future<void> _playEntireDialogue() async {
    if (_activeLesson == null) return;

    // Đang phát -> bấm lần nữa là dừng.
    if (_isPlayingAll) {
      _playSession++;
      SpeechService.stop();
      setState(() {
        _isPlayingAll = false;
        _currentPlayingLineIndex = -1;
      });
      return;
    }

    final session = ++_playSession;
    final dialogue = _activeLesson!.dialogue;
    setState(() {
      _isPlayingAll = true;
    });

    for (int i = 0; i < dialogue.length; i++) {
      if (!mounted || session != _playSession) return;
      setState(() {
        _currentPlayingLineIndex = i;
      });

      await SpeechService.speak(dialogue[i].text, rate: _playbackRate);

      if (!mounted || session != _playSession) return;
      // Nghỉ ngắn giữa các lượt thoại cho tự nhiên.
      await Future.delayed(const Duration(milliseconds: 350));
    }

    if (mounted && session == _playSession) {
      setState(() {
        _isPlayingAll = false;
        _currentPlayingLineIndex = -1;
      });
    }
  }

  void _cyclePlaybackRate() {
    setState(() {
      if (_playbackRate == 1.0) {
        _playbackRate = 0.8;
      } else if (_playbackRate == 0.8) {
        _playbackRate = 1.2;
      } else {
        _playbackRate = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _playSession++;
    SpeechService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeLesson == null) {
      return _buildLessonSelector(context);
    }
    return _buildActiveLesson(context, _activeLesson!);
  }

  // ─────────────────────────────────────────────────────────────
  // 1. LESSON SELECTOR SCREEN
  // ─────────────────────────────────────────────────────────────
  Widget _buildLessonSelector(BuildContext context) {
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
          'Luyện Nghe Hiểu (Listening)',
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
                        colors: [Color(0xFF2E86DE), Color(0xFF0984E3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E86DE).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.headphones_rounded,
                            color: Colors.white, size: 40),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hội thoại tiếng Anh thực tế 🎧',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Luyện nghe đa giọng điệu, kiểm tra phản xạ và mở rộng vốn từ',
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
                    'Danh sách bài học (${listeningLessonsData.length} chủ đề)',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...listeningLessonsData.map((lesson) {
                    return _buildLessonCard(context, lesson);
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

  Widget _buildLessonCard(BuildContext context, ListeningLesson lesson) {
    Color levelColor = Colors.green;
    if (lesson.level == 'A2') levelColor = const Color(0xFF00CEC9);
    if (lesson.level == 'B1') levelColor = const Color(0xFFFFA502);
    if (lesson.level == 'B2') levelColor = const Color(0xFFFF4757);

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
          onTap: () => _selectLesson(lesson),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.listening.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppColors.listening,
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
                              lesson.title,
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
                              lesson.level,
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
                        lesson.titleVi,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.listening,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        lesson.scenarioVi,
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
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 13, color: AppColors.textSecondaryDark),
                          const SizedBox(width: 4),
                          Text(
                            '${lesson.dialogue.length} câu thoại',
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
                            '${lesson.questions.length} câu hỏi',
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
  // 2. ACTIVE LESSON SCREEN
  // ─────────────────────────────────────────────────────────────
  Widget _buildActiveLesson(BuildContext context, ListeningLesson lesson) {
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
          onPressed: _backToLessonList,
        ),
        title: Column(
          children: [
            Text(
              lesson.title,
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${lesson.titleVi} • ${lesson.level}',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.listening,
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _cyclePlaybackRate,
            icon: const Icon(Icons.speed_rounded,
                size: 16, color: AppColors.secondary),
            label: Text(
              '${_playbackRate}x',
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
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
                  // Audio control bar
                  _buildAudioPlayerBar(lesson),

                  // Tab Switcher
                  _buildTabSwitcher(),

                  // Tab Content
                  Expanded(
                    child: _activeTabIndex == 0
                        ? _buildDialogueTab(lesson)
                        : _activeTabIndex == 1
                            ? _buildVocabTab(lesson)
                            : _buildQuizTab(lesson),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayerBar(ListeningLesson lesson) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkDivider),
      ),
      child: Row(
        children: [
          // Play / Pause button
          ElevatedButton.icon(
            onPressed: _playEntireDialogue,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isPlayingAll ? Colors.orange : AppColors.listening,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(0, 44),
            ),
            icon: Icon(
              _isPlayingAll ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 20,
            ),
            label: Text(
              _isPlayingAll ? 'Dừng phát' : 'Nghe toàn bài',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isPlayingAll
                  ? 'Đang phát câu ${_currentPlayingLineIndex + 1}/${lesson.dialogue.length}...'
                  : 'Bấm câu thoại để nghe riêng',
              style: TextStyle(
                color: _isPlayingAll
                    ? AppColors.listening
                    : AppColors.textSecondaryDark,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: _showTranslation ? 'Ẩn bản dịch' : 'Hiện bản dịch',
            icon: Icon(
              _showTranslation
                  ? Icons.translate_rounded
                  : Icons.translate_outlined,
              color: _showTranslation
                  ? AppColors.secondary
                  : AppColors.textSecondaryDark,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _showTranslation = !_showTranslation;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          _buildTabItem(0, 'Hội thoại', Icons.forum_rounded),
          const SizedBox(width: 8),
          _buildTabItem(1, 'Từ vựng', Icons.book_rounded),
          const SizedBox(width: 8),
          _buildTabItem(2, 'Bài kiểm tra', Icons.quiz_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _activeTabIndex == index;
    return Expanded(
      child: Material(
        color: isSelected
            ? AppColors.listening.withOpacity(0.2)
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
                color: isSelected ? AppColors.listening : AppColors.darkDivider,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.listening
                      : AppColors.textSecondaryDark,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.listening
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
  // TAB 1: DIALOGUE
  // ─────────────────────────────────────────────────────────────
  Widget _buildDialogueTab(ListeningLesson lesson) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: lesson.dialogue.length,
      itemBuilder: (context, index) {
        final line = lesson.dialogue[index];
        final isCurrent = _currentPlayingLineIndex == index;
        final isSpeaker1 = index % 2 == 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.listening.withOpacity(0.15)
                : AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent ? AppColors.listening : AppColors.darkDivider,
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSpeaker1
                      ? const Color(0xFF2E86DE).withOpacity(0.2)
                      : const Color(0xFF10AC84).withOpacity(0.2),
                ),
                child: Center(
                  child: Text(
                    line.speaker.isNotEmpty ? line.speaker[0] : '?',
                    style: TextStyle(
                      color: isSpeaker1
                          ? const Color(0xFF2E86DE)
                          : const Color(0xFF10AC84),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.speaker,
                      style: TextStyle(
                        color: isSpeaker1
                            ? const Color(0xFF2E86DE)
                            : const Color(0xFF10AC84),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      line.text,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (_showTranslation) ...[
                      const SizedBox(height: 4),
                      Text(
                        line.textVi,
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isCurrent
                      ? Icons.volume_up_rounded
                      : Icons.play_circle_outline_rounded,
                  color: isCurrent
                      ? AppColors.listening
                      : AppColors.textSecondaryDark,
                  size: 24,
                ),
                tooltip: 'Nghe câu này',
                onPressed: () => _playSingleLine(line.text, index),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: VOCABULARY
  // ─────────────────────────────────────────────────────────────
  Widget _buildVocabTab(ListeningLesson lesson) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: lesson.keyVocab.length,
      itemBuilder: (context, index) {
        final vocab = lesson.keyVocab[index];
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
                            color: AppColors.listening,
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
                        color: AppColors.listening),
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
                'Ví dụ: "${vocab.example}"',
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
  Widget _buildQuizTab(ListeningLesson lesson) {
    int totalQuestions = lesson.questions.length;
    int answeredCount = _userAnswers.length;
    int correctCount = 0;
    _userAnswers.forEach((qIdx, optIdx) {
      if (optIdx == lesson.questions[qIdx].correctIndex) {
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
                      ? '🎉 Xuất sắc! Bạn đúng 100%'
                      : 'Hoàn thành bài kiểm tra! Điểm: $correctCount/$totalQuestions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Xem lại giải thích chi tiết cho từng câu hỏi bên dưới',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...List.generate(lesson.questions.length, (qIdx) {
          final q = lesson.questions[qIdx];
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
                      border: Border.all(
                          color: AppColors.listening.withOpacity(0.3)),
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
