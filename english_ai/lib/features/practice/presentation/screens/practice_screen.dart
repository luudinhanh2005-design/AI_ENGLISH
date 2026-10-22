import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class PracticeQuizItem {
  final String question;
  final List<String> options;
  final int correct;
  final String explanation;

  const PracticeQuizItem({
    required this.question,
    required this.options,
    required this.correct,
    required this.explanation,
  });
}

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  // ── Mini Grammar Quiz State ──
  int _quizIndex = 0;
  int? _selectedAnswer;
  bool _showResult = false;
  int _correctCount = 0;
  bool _quizFinished = false;
  int _streak = 1;

  // ── Writing Evaluator State ──
  final TextEditingController _writingController = TextEditingController();
  bool _isEvaluating = false;
  Map<String, dynamic>? _writingResult;

  final List<String> _promptSuggestions = [
    'Describe your favorite holiday destination and why you love it.',
    'Do you agree that AI will replace language teachers in the future?',
    'Write about a memorable achievement in your life.',
    'Explain why regular physical exercise is crucial for mental health.',
  ];

  static const List<PracticeQuizItem> _quizQuestions = [
    PracticeQuizItem(
      question:
          'Choose the correct verb form: "She _______ to school every day."',
      options: ['go', 'goes', 'going', 'gone'],
      correct: 1,
      explanation:
          'Chủ ngữ "she" (ngôi 3 số ít) trong thì Hiện tại đơn → thêm "s": goes.',
    ),
    PracticeQuizItem(
      question: 'Which sentence uses the Present Perfect correctly?',
      options: [
        'I have seen that movie yesterday.',
        'I have already seen that movie.',
        'I am seeing that movie since 2020.',
        'I see that movie last week.',
      ],
      correct: 1,
      explanation:
          '"Already" đi với Hiện tại hoàn thành → "have + V3 (seen)" là đúng.',
    ),
    PracticeQuizItem(
      question:
          'Complete the sentence: "If I _______ rich, I would travel the world."',
      options: ['am', 'will be', 'were', 'had been'],
      correct: 2,
      explanation:
          'Câu điều kiện loại 2 (unreal present): If + S + were/V2, S + would + V.',
    ),
    PracticeQuizItem(
      question: '"The report _______ by the manager tomorrow." (Passive)',
      options: [
        'will written',
        'will be written',
        'will write',
        'is writing',
      ],
      correct: 1,
      explanation: 'Câu bị động tương lai: will be + V3 → "will be written".',
    ),
    PracticeQuizItem(
      question:
          'Choose the correct preposition: "I\'m interested _______ learning English."',
      options: ['on', 'at', 'in', 'for'],
      correct: 2,
      explanation:
          'Cụm cố định "be interested in + V-ing": hứng thú với việc gì.',
    ),
  ];

  @override
  void dispose() {
    _writingController.dispose();
    super.dispose();
  }

  void _selectAnswer(int index) {
    if (_showResult) return;
    setState(() {
      _selectedAnswer = index;
      _showResult = true;
      if (index == _quizQuestions[_quizIndex].correct) {
        _correctCount++;
        _streak++;
      } else {
        _streak = 1;
      }
    });
  }

  void _nextQuestion() {
    if (_quizIndex < _quizQuestions.length - 1) {
      setState(() {
        _quizIndex++;
        _selectedAnswer = null;
        _showResult = false;
      });
    } else {
      setState(() {
        _quizFinished = true;
      });
    }
  }

  void _resetQuiz() {
    setState(() {
      _quizIndex = 0;
      _selectedAnswer = null;
      _showResult = false;
      _correctCount = 0;
      _quizFinished = false;
      _streak = 1;
    });
  }

  void _insertRandomPrompt() {
    final next = (_promptSuggestions..shuffle()).first;
    _writingController.text = next;
  }

  Future<void> _evaluateWriting() async {
    final text = _writingController.text.trim();
    if (text.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng nhập ít nhất 20 ký tự để đánh giá!'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isEvaluating = true;
      _writingResult = null;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final sentences =
        text.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).length;
    final avgWordsPerSentence = sentences > 0 ? words / sentences : words;

    // Scoring
    double score = 65.0;
    if (words >= 40) score += 10;
    if (words >= 80) score += 10;
    if (avgWordsPerSentence >= 8 && avgWordsPerSentence <= 20) score += 8;
    if (text.contains(RegExp(
        r'\b(however|furthermore|nevertheless|consequently|moreover)\b',
        caseSensitive: false))) score += 5;
    if (text.contains(RegExp(r'\b(although|despite|whereas|whilst|because)\b',
        caseSensitive: false))) score += 5;
    score = score.clamp(50.0, 96.0);

    final ielts = (score / 100 * 9).clamp(4.5, 8.5);
    final cefr = score >= 80
        ? 'B2'
        : score >= 65
            ? 'B1'
            : 'A2';

    setState(() {
      _isEvaluating = false;
      _writingResult = {
        'score': score.round(),
        'ielts': ielts.toStringAsFixed(1),
        'cefr': cefr,
        'word_count': words,
        'sentence_count': sentences,
        'tips': [
          if (words < 50)
            '✍️ Hãy viết thêm khoảng ${50 - words} từ nữa để phát triển ý đầy đủ hơn.',
          if (!text.contains(
              RegExp(r'\b(however|furthermore)\b', caseSensitive: false)))
            '💡 Thêm liên từ học thuật: however, furthermore, consequently.',
          if (avgWordsPerSentence < 8)
            '📝 Câu quá ngắn - thử kết hợp các câu đơn thành câu ghép (compound sentence).',
          '🎯 Từ vựng phong phú và cấu trúc mạch lạc!',
        ],
      };
    });
  }

  @override
  Widget build(BuildContext context) {
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

                  // ── Arena Header ──
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đấu Trường Luyện Tập ⚡',
                              style: AppTextStyles.h2.copyWith(
                                color: context.palette.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rèn phản xạ nhanh, làm chủ ngữ pháp & viết câu thông minh',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA502).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFFFA502).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded,
                                color: Color(0xFFFFA502), size: 18),
                            const SizedBox(width: 4),
                            Text(
                              'Chuỗi $_streak',
                              style: const TextStyle(
                                color: Color(0xFFFFA502),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Gamified Stats Dashboard ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.palette.divider),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          icon: Icons.military_tech_rounded,
                          color: const Color(0xFF00CEC9),
                          value: '450 XP',
                          label: 'Điểm rèn luyện',
                        ),
                        Container(
                            width: 1,
                            height: 40,
                            color: context.palette.divider),
                        _buildStatColumn(
                          icon: Icons.check_circle_outline_rounded,
                          color: const Color(0xFF2ED573),
                          value:
                              '${_quizQuestions.isNotEmpty ? (_correctCount / _quizQuestions.length * 100).round() : 85}%',
                          label: 'Độ chính xác',
                        ),
                        Container(
                            width: 1,
                            height: 40,
                            color: context.palette.divider),
                        _buildStatColumn(
                          icon: Icons.flash_on_rounded,
                          color: const Color(0xFFFFA502),
                          value: '5/5',
                          label: 'Mục tiêu hôm nay',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 2 Advanced Feature Launchers ──
                  Row(
                    children: [
                      // IELTS Speaking Mock
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/practice/ielts-speaking'),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3498DB).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('🏆',
                                        style: TextStyle(fontSize: 24)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Text('Band 1-9',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Thi Thử IELTS\nSpeaking',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '3 phần thi chuẩn IDP',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Mistake Notebook & SM-2
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/mistake-notebook'),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C5CE7), Color(0xFF8E7CF8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C5CE7).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('📓',
                                        style: TextStyle(fontSize: 24)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Text('SM-2 Review',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Sổ Tay Lỗi Sai &\nTừ Vựng',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Flashcard ngắt quãng',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Featured Arena Station: Smart Sentence Writing ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00B894).withOpacity(0.35),
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
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '✍️ TRỌNG TÂM LUYỆN TẬP',
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
                              '30 Bài • 3 Cấp Độ',
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
                          'Xưởng Luyện Viết Câu Thông Minh 🖊️',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Thực hành ghép câu từ từ vựng gợi ý, kiểm tra ngữ pháp tức thì và nâng cấp từ dễ đến khó.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildFeatureTag('Dễ (A1-A2)'),
                            const SizedBox(width: 8),
                            _buildFeatureTag('Vừa (B1)'),
                            const SizedBox(width: 8),
                            _buildFeatureTag('Khó (B2)'),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () =>
                                  context.push('/writing-practice'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF00B894),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              child: const Text('Vào luyện ➔',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Split Practice Stations (Speaking & Flashcard Drill) ──
                  Row(
                    children: [
                      Expanded(
                        child: _buildStationTile(
                          icon: Icons.mic_rounded,
                          title: 'Luyện Nói AI',
                          subtitle: 'Hội thoại giao tiếp phản xạ',
                          color: const Color(0xFFE17055),
                          onTap: () => context.go('/ai-tutor'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStationTile(
                          icon: Icons.flip_to_front_rounded,
                          title: 'Lật Thẻ SM-2',
                          subtitle: 'Ôn tập 15 từ sắp quên',
                          color: const Color(0xFF6C5CE7),
                          onTap: () => context.push('/vocabulary/review'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Arena Section: Speed Grammar Quiz ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.grammar.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.flash_on_rounded,
                                color: AppColors.grammar, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Trắc Nghiệm Tốc Độ ⚡',
                            style: AppTextStyles.h4.copyWith(
                              color: context.palette.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.palette.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.palette.divider),
                        ),
                        child: Text(
                          '${_quizIndex + 1}/${_quizQuestions.length} câu',
                          style: TextStyle(
                            color: context.palette.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildQuizCard(),

                  const SizedBox(height: 28),

                  // ── Arena Section: Writing Lab & AI Evaluator ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFA502).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.rate_review_rounded,
                                color: Color(0xFFFFA502), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Phòng Thử Nghiệm Viết AI 📝',
                            style: AppTextStyles.h4.copyWith(
                              color: context.palette.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _insertRandomPrompt,
                        icon: const Icon(Icons.casino_outlined, size: 16),
                        label: const Text('Gợi ý đề',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildWritingEvaluator(),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: context.palette.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: context.palette.textSecondary,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  // ── Quiz Card ──
  Widget _buildQuizCard() {
    if (_quizFinished) {
      final percent = (_correctCount / _quizQuestions.length * 100).round();
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: percent >= 80
                ? [const Color(0xFF2ED573), const Color(0xFF00CEC9)]
                : percent >= 60
                    ? [AppColors.primary, AppColors.secondary]
                    : [const Color(0xFFFF6B6B), const Color(0xFFFFA502)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              percent >= 80
                  ? 'Xuất sắc! $percent%'
                  : percent >= 60
                      ? 'Khá lắm! $percent%'
                      : 'Cố lên! $percent%',
              style: AppTextStyles.h3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Đúng $_correctCount/${_quizQuestions.length} câu',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: context.palette.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text('Luyện lại lần nữa',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final q = _quizQuestions[_quizIndex];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.question,
            style: AppTextStyles.labelLarge.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...q.options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;
            final isCorrect = idx == q.correct;
            final isSelected = _selectedAnswer == idx;

            Color borderColor = context.palette.divider;
            Color bgColor = context.palette.surface;
            Color textColor = context.palette.textPrimary;

            if (_showResult) {
              if (isCorrect) {
                borderColor = AppColors.success;
                bgColor = AppColors.success.withOpacity(0.12);
                textColor = AppColors.success;
              } else if (isSelected) {
                borderColor = AppColors.error;
                bgColor = AppColors.error.withOpacity(0.12);
                textColor = AppColors.error;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _selectAnswer(idx),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? borderColor
                                : context.palette.divider.withOpacity(0.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            String.fromCharCode(65 + idx),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : context.palette.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: textColor),
                          ),
                        ),
                        if (_showResult && isCorrect)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 20),
                        if (_showResult && isSelected && !isCorrect)
                          const Icon(Icons.cancel_rounded,
                              color: AppColors.error, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (_showResult) ...[
            const SizedBox(height: 12),
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
                      q.explanation,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _nextQuestion,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  _quizIndex < _quizQuestions.length - 1
                      ? 'Câu tiếp theo'
                      : 'Xem kết quả',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Writing Evaluator ──
  Widget _buildWritingEvaluator() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _writingController,
            maxLines: 4,
            style: TextStyle(color: context.palette.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText:
                  'Nhập hoặc dán câu tiếng Anh của bạn tại đây để AI đánh giá...',
              hintStyle:
                  TextStyle(color: context.palette.textHint, fontSize: 13),
              filled: true,
              fillColor: context.palette.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isEvaluating ? null : _evaluateWriting,
              icon: _isEvaluating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 16),
              label: Text(
                  _isEvaluating ? 'AI đang chấm điểm...' : 'Đánh giá với AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ),
          if (_writingResult != null) ...[
            const SizedBox(height: 16),
            Divider(color: context.palette.divider),
            const SizedBox(height: 12),
            Row(
              children: [
                _ScoreBadge(
                  label: 'Điểm tổng',
                  value: '${_writingResult!['score']}/100',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _ScoreBadge(
                  label: 'CEFR',
                  value: _writingResult!['cefr'] as String,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                _ScoreBadge(
                  label: 'IELTS Band',
                  value: _writingResult!['ielts'] as String,
                  color: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _WritingStat(
                  label: 'Số từ',
                  value: '${_writingResult!['word_count']}',
                ),
                _WritingStat(
                  label: 'Số câu',
                  value: '${_writingResult!['sentence_count']}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Gợi ý cải thiện:',
              style: AppTextStyles.labelMedium.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...((_writingResult!['tips'] as List<dynamic>?)
                        ?.map((e) => e.toString()) ??
                    const <String>[])
                .map(
              (tip) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  tip,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ScoreBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.h3.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
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

class _WritingStat extends StatelessWidget {
  final String label;
  final String value;

  const _WritingStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.h4.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: context.palette.textHint,
          ),
        ),
      ],
    );
  }
}
