import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/speech_io.dart';
import '../../data/models/reflex_model.dart';
import '../../data/services/reflex_coach_service.dart';

class ReflexCoachScreen extends StatefulWidget {
  const ReflexCoachScreen({super.key});

  @override
  State<ReflexCoachScreen> createState() => _ReflexCoachScreenState();
}

class _ReflexCoachScreenState extends State<ReflexCoachScreen>
    with SingleTickerProviderStateMixin {
  final ReflexCoachService _service = ReflexCoachService.instance;
  final TextEditingController _textController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<ReflexTopic> _topics = [];
  int _selectedTopicIndex = 0;
  int _currentChallengeIndex = 0;

  bool _isLoadingTopics = true;
  bool _isAssessing = false;
  bool _isListening = false;
  bool _showHints = false;
  bool _isManualTextMode = false;

  ReflexEvaluation? _lastEvaluation;
  int _sessionXp = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadTopics();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _speech.stop();
    webStop();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoadingTopics = true);
    final topics = await _service.getReflexTopics();
    if (mounted) {
      setState(() {
        _topics = topics;
        _isLoadingTopics = false;
      });
    }
  }

  ReflexTopic? get _currentTopic =>
      _topics.isNotEmpty && _selectedTopicIndex < _topics.length
          ? _topics[_selectedTopicIndex]
          : null;

  ReflexChallenge? get _currentChallenge {
    final topic = _currentTopic;
    if (topic != null &&
        topic.challenges.isNotEmpty &&
        _currentChallengeIndex < topic.challenges.length) {
      return topic.challenges[_currentChallengeIndex];
    }
    return null;
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize(
      onError: (val) => setState(() => _isListening = false),
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _lastEvaluation = null;
      });
      _speech.listen(
        onResult: (val) {
          setState(() {
            _textController.text = val.recognizedWords;
          });
        },
        localeId: 'en_US',
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không mở được micro hoặc trình duyệt chưa cấp quyền. Hãy gõ câu trả lời vào ô text bên dưới nhé!'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isManualTextMode = true);
      }
    }
  }

  Future<void> _submitEvaluation() async {
    final challenge = _currentChallenge;
    final userText = _textController.text.trim();
    if (challenge == null || userText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nói hoặc nhập câu tiếng Anh của bạn trước.')),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    setState(() => _isAssessing = true);

    final eval = await _service.assessReflex(
      promptVi: challenge.promptVi,
      userEn: userText,
      topic: _currentTopic?.title ?? 'General',
      level: challenge.level,
    );

    if (mounted) {
      setState(() {
        _lastEvaluation = eval;
        _isAssessing = false;
        if (eval.score >= 60) {
          _sessionXp += 20;
        }
      });
    }
  }

  void _nextChallenge() {
    final topic = _currentTopic;
    if (topic == null) return;

    setState(() {
      _lastEvaluation = null;
      _textController.clear();
      _showHints = false;
      if (_currentChallengeIndex < topic.challenges.length - 1) {
        _currentChallengeIndex++;
      } else {
        // Move to next topic or loop
        _currentChallengeIndex = 0;
        _selectedTopicIndex = (_selectedTopicIndex + 1) % _topics.length;
      }
    });
  }

  void _retryChallenge() {
    setState(() {
      _lastEvaluation = null;
      _textController.clear();
      _showHints = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final challenge = _currentChallenge;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12141C) : const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Phản Xạ Giao Tiếp AI 🤖'),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFA000), Color(0xFFFF6F00)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  '+$_sessionXp XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoadingTopics
          ? const Center(child: CircularProgressIndicator())
          : _topics.isEmpty
              ? const Center(child: Text('Không tải được danh sách câu hỏi.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopicSelector(isDark),
                      const SizedBox(height: 12),
                      if (challenge != null) ...[
                        _buildProgressBar(),
                        const SizedBox(height: 14),
                        _buildPromptCard(challenge, isDark),
                        const SizedBox(height: 16),
                        _buildInputSection(isDark),
                        const SizedBox(height: 16),
                        if (_lastEvaluation != null)
                          _buildEvaluationResultCard(_lastEvaluation!, isDark),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildTopicSelector(bool isDark) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _topics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final isSelected = idx == _selectedTopicIndex;
          final topic = _topics[idx];
          return ChoiceChip(
            label: Text(topic.title),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: isDark ? const Color(0xFF222638) : Colors.white,
            labelStyle: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
            ),
            onSelected: (val) {
              if (val) {
                setState(() {
                  _selectedTopicIndex = idx;
                  _currentChallengeIndex = 0;
                  _lastEvaluation = null;
                  _textController.clear();
                  _showHints = false;
                });
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() {
    final topic = _currentTopic;
    if (topic == null || topic.challenges.isEmpty) return const SizedBox.shrink();

    final current = _currentChallengeIndex + 1;
    final total = topic.challenges.length;
    final progress = current / total;

    return Row(
      children: [
        Text(
          'Tình huống $current / $total',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptCard(ReflexChallenge ch, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2235) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Huấn Luyện Viên Phản Xạ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ch.contextDesc,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ch.level,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Hãy nói câu tiếng Anh tương ứng:',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '“${ch.promptVi}”',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary),
                tooltip: 'Nghe đọc câu tiếng Việt',
                onPressed: () => speakWithLang(ch.promptVi, 'vi-VN', 0.5),
              ),
            ],
          ),
          if (ch.hints.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _showHints = !_showHints),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showHints ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showHints ? 'Ẩn gợi ý' : 'Gợi ý từ khóa',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
            if (_showHints) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: ch.hints
                    .map(
                      (h) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C324B) : const Color(0xFFEDF2F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          h,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInputSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2235) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isListening ? AppColors.primary : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: _isListening ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Câu nói tiếng Anh của bạn:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isManualTextMode ? Icons.mic_rounded : Icons.keyboard_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                tooltip: _isManualTextMode ? 'Chuyển sang nói Micro' : 'Chuyển sang gõ bàn phím',
                onPressed: () => setState(() => _isManualTextMode = !_isManualTextMode),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 2,
            readOnly: _isListening,
            decoration: InputDecoration(
              hintText: _isListening
                  ? 'Đang lắng nghe bạn nói... (Hãy nói bằng tiếng Anh)'
                  : 'Bấm micro bên dưới để nói hoặc nhập câu tiếng Anh...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: _isListening ? AppColors.primary : (isDark ? Colors.white38 : Colors.black38),
                fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF141724) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Large Microphone Control Center
          Center(
            child: Column(
              children: [
                ScaleTransition(
                  scale: _isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                  child: InkWell(
                    onTap: _toggleListening,
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isListening
                              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                              : [AppColors.primary, const Color(0xFF8B5CF6)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.red : AppColors.primary).withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: _isListening ? 4 : 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isListening ? 'Bấm để dừng nói' : 'Bấm micro để nói tiếng Anh',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isListening ? Colors.redAccent : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _isAssessing ? null : _submitEvaluation,
            icon: _isAssessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 20),
            label: Text(_isAssessing ? 'AI Đang Phân Tích & Chấm Điểm...' : 'Gửi AI Đánh Giá & Gợi Ý ✨'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationResultCard(ReflexEvaluation eval, bool isDark) {
    Color scoreColor;
    String scoreTitle;
    IconData scoreIcon;

    if (eval.score >= 85) {
      scoreColor = const Color(0xFF10B981);
      scoreTitle = '🌟 Xuất Sắc & Chuẩn Bản Xứ!';
      scoreIcon = Icons.check_circle_rounded;
    } else if (eval.score >= 60) {
      scoreColor = const Color(0xFFF59E0B);
      scoreTitle = '💡 Khá Tốt Nhưng Hơi Lủng Củng';
      scoreIcon = Icons.info_rounded;
    } else {
      scoreColor = const Color(0xFFEF4444);
      scoreTitle = '⚠️ Cần Cải Thiện Ngữ Pháp & Từ Vựng';
      scoreIcon = Icons.warning_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F30) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scoreColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header score
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${eval.score}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: scoreColor,
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
                      scoreTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thang điểm phản xạ: ${eval.score}/100',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Feedback paragraph
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141724) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(scoreIcon, size: 20, color: scoreColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    eval.feedbackVi,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (eval.betterOptions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '🎯 Cách Người Bản Xứ Sẽ Nói (Bấm loa để nghe):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...eval.betterOptions.map((opt) => _buildOptionTile(opt, isDark)),
          ],

          if (eval.grammarNote.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.school_rounded, size: 20, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      eval.grammarNote,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retryChallenge,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Nói lại câu này'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _nextChallenge,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Tình huống kế ➔'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(ReflexOption opt, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141724) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 22),
            tooltip: 'Nghe phát âm chuẩn',
            onPressed: () => webSpeak(opt.english, 0.45),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opt.english,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
                Text(
                  opt.vietnamese,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                if (opt.contextNote.isNotEmpty)
                  Text(
                    '• ${opt.contextNote}',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
            tooltip: 'Sao chép để luyện nói câu này',
            onPressed: () {
              setState(() {
                _textController.text = opt.english;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã chọn câu này vào ô luyện nói!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
