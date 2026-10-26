import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/speech_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/subtitle_line.dart';
import '../../data/models/video_lesson.dart';

enum ReflexMode { shadowing, qna }

class ReflexPracticeScreen extends ConsumerStatefulWidget {
  final VideoLesson lesson;
  final String? initialSubtitleId;

  const ReflexPracticeScreen({
    super.key,
    required this.lesson,
    this.initialSubtitleId,
  });

  @override
  ConsumerState<ReflexPracticeScreen> createState() =>
      _ReflexPracticeScreenState();
}

class _ReflexPracticeScreenState extends ConsumerState<ReflexPracticeScreen> {
  late List<SubtitleLine> _sentences;
  int _currentIndex = 0;
  ReflexMode _mode = ReflexMode.shadowing;

  // Audio services
  final AudioRecordingService _recordingService = AudioRecordingService();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;

  bool _isPlayingSample = false;
  bool _isRecording = false;
  bool _isEvaluating = false;

  String _spokenText = '';
  Map<String, dynamic>? _assessmentResult;

  int _earnedXp = 0;

  @override
  void initState() {
    super.initState();
    _sentences = widget.lesson.subtitles;
    if (widget.initialSubtitleId != null) {
      final idx =
          _sentences.indexWhere((s) => s.id == widget.initialSubtitleId);
      if (idx != -1) _currentIndex = idx;
    }
    _initSpeechRecognizer();
  }

  Future<void> _initSpeechRecognizer() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (err) => debugPrint('STT Error: $err'),
        onStatus: (status) => debugPrint('STT Status: $status'),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to initialize STT: $e');
    }
  }

  SubtitleLine get _currentSubtitle => _sentences[_currentIndex];

  String get _targetReferenceText {
    if (_mode == ReflexMode.qna &&
        _currentSubtitle.suggestedResponse != null &&
        _currentSubtitle.suggestedResponse!.isNotEmpty) {
      return _currentSubtitle.suggestedResponse!;
    }
    return _currentSubtitle.englishText;
  }

  Future<void> _playSampleAudio({double rate = 0.9}) async {
    if (_isPlayingSample) return;
    setState(() => _isPlayingSample = true);
    try {
      final text = _mode == ReflexMode.qna && _currentSubtitle.reflexQuestion != null
          ? _currentSubtitle.reflexQuestion!
          : _currentSubtitle.englishText;
      await SpeechService.speak(text, rate: rate);
    } catch (_) {}
    if (mounted) {
      setState(() => _isPlayingSample = false);
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _spokenText = '';
      _assessmentResult = null;
    });

    try {
      // 1. Start audio recorder for backend assess
      await _recordingService.startRecording();

      // 2. Start STT for live on-device speech feedback
      if (_speechEnabled) {
        await _speechToText.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _spokenText = result.recognizedWords;
              });
            }
          },
          localeId: 'en_US',
        );
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecordingAndEvaluate() async {
    if (!_isRecording) return;
    setState(() {
      _isRecording = false;
      _isEvaluating = true;
    });

    Uint8List? audioBytes;
    try {
      if (_speechEnabled && _speechToText.isListening) {
        await _speechToText.stop();
      }
      audioBytes = await _recordingService.stopRecording();
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }

    await _evaluateSpokenSpeech(audioBytes);
  }

  Future<void> _evaluateSpokenSpeech(Uint8List? audioBytes) async {
    final refText = _targetReferenceText;

    // 1. Try Backend Speech AI Assessment if audio was captured
    if (audioBytes != null && audioBytes.isNotEmpty) {
      try {
        final dio = ref.read(dioProvider);
        final formData = FormData.fromMap({
          'audio': MultipartFile.fromBytes(
            audioBytes,
            filename: 'practice_speech.wav',
          ),
          'reference_text': refText,
          'session_type': 'video_reflex',
        });

        final res = await dio.post(
          ApiEndpoints.speechAssess,
          data: formData,
          options: Options(receiveTimeout: const Duration(seconds: 15)),
        );

        if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
          final data = res.data as Map<String, dynamic>;
          _applyAssessmentResult(
            overallScore: (data['overall_score'] as num?)?.toDouble() ?? 80.0,
            accuracyScore: (data['accuracy_score'] as num?)?.toDouble() ?? 80.0,
            fluencyScore: (data['fluency_score'] as num?)?.toDouble() ?? 75.0,
            recognisedText: (data['recognised_text'] as String?) ?? _spokenText,
            feedback: (data['feedback'] as String?) ?? 'Phát âm rất tự nhiên!',
            wordScores: data['word_scores'] as List<dynamic>?,
          );
          return;
        }
      } catch (e) {
        debugPrint('Backend speech assess failed, using local similarity: $e');
      }
    }

    // 2. Intelligent local fallback evaluation based on recognized text
    _evaluateLocally(refText, _spokenText);
  }

  void _evaluateLocally(String reference, String spoken) {
    final cleanRef = reference.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final cleanSpoken = spoken.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    final refWords = cleanRef.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final spokenWords = cleanSpoken.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (spokenWords.isEmpty) {
      setState(() {
        _isEvaluating = false;
        _assessmentResult = {
          'overall_score': 0.0,
          'accuracy_score': 0.0,
          'fluency_score': 0.0,
          'recognised_text': 'Chưa nghe thấy giọng đọc. Hãy bấm nói to hơn nhé.',
          'feedback': 'Hãy thử bấm nút Mic và đọc to, rõ ràng hơn.',
          'word_scores': <Map<String, dynamic>>[],
        };
      });
      return;
    }

    int matchedCount = 0;
    final List<Map<String, dynamic>> wordScores = [];

    for (final word in refWords) {
      if (spokenWords.contains(word)) {
        matchedCount++;
        wordScores.add({
          'word': word,
          'score': 95.0,
          'status': 'correct',
        });
      } else {
        wordScores.add({
          'word': word,
          'score': 40.0,
          'status': 'needs_work',
        });
      }
    }

    final double ratio = (matchedCount / (refWords.isEmpty ? 1 : refWords.length)).clamp(0.0, 1.0);
    final double overallScore = (ratio * 100).roundToDouble();
    final double accuracyScore = (ratio * 95).roundToDouble();
    final double fluencyScore = (ratio * 90 + 5).roundToDouble();

    String feedback = 'Xuất sắc! Bạn đã phản xạ rất chuẩn.';
    if (overallScore < 50) {
      feedback = 'Cần luyện tập thêm. Hãy nghe lại câu mẫu một lần nữa nhé.';
    } else if (overallScore < 80) {
      feedback = 'Rất tốt! Cố gắng phát âm chuẩn các từ được đánh dấu màu cam.';
    }

    _applyAssessmentResult(
      overallScore: overallScore,
      accuracyScore: accuracyScore,
      fluencyScore: fluencyScore,
      recognisedText: spoken,
      feedback: feedback,
      wordScores: wordScores,
    );
  }

  void _applyAssessmentResult({
    required double overallScore,
    required double accuracyScore,
    required double fluencyScore,
    required String recognisedText,
    required String feedback,
    List<dynamic>? wordScores,
  }) {
    final earned = (overallScore >= 70) ? 10 : 5;
    _earnedXp += earned;

    setState(() {
      _isEvaluating = false;
      _assessmentResult = {
        'overall_score': overallScore,
        'accuracy_score': accuracyScore,
        'fluency_score': fluencyScore,
        'recognised_text': recognisedText,
        'feedback': feedback,
        'word_scores': wordScores ?? [],
      };
    });
  }

  void _goToNextSentence() {
    if (_currentIndex < _sentences.length - 1) {
      setState(() {
        _currentIndex++;
        _spokenText = '';
        _assessmentResult = null;
      });
      // Automatically play next sentence sample
      _playSampleAudio();
    } else {
      // Completed all sentences
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Hoàn Thành Luyện Tập!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn đã hoàn thành phản xạ tất cả ${_sentences.length} câu trong bài học "${widget.lesson.title}".',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    '+$_earnedXp XP đã được cộng vào hồ sơ!',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Quay lại bài học'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentIndex = 0;
                _assessmentResult = null;
                _spokenText = '';
              });
            },
            child: const Text('Luyện tập lại', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recordingService.dispose();
    if (_speechEnabled) {
      _speechToText.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = _currentSubtitle;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13141B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Luyện Phản Xạ & Nhại Giọng',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Câu ${_currentIndex + 1} / ${_sentences.length} — ${widget.lesson.title}',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _sentences.length,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.speaking),
                ),
              ),
              const SizedBox(height: 18),

              // Mode toggle (Shadowing vs Q&A Reflex)
              _buildModeToggle(isDark),
              const SizedBox(height: 18),

              // Target Sentence Card
              _buildTargetCard(sub, isDark),
              const SizedBox(height: 20),

              // Microphone & Recording Area
              _buildRecordingActionArea(isDark),
              const SizedBox(height: 20),

              // Assessment Results
              if (_isEvaluating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.speaking),
                        SizedBox(height: 12),
                        Text('AI đang phân tích giọng nói & phản xạ của bạn...'),
                      ],
                    ),
                  ),
                )
              else if (_assessmentResult != null)
                _buildAssessmentCard(isDark),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _mode = ReflexMode.shadowing),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _mode == ReflexMode.shadowing
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '1. Nhại giọng (Shadowing)',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: _mode == ReflexMode.shadowing
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _mode = ReflexMode.qna),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _mode == ReflexMode.qna
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '2. Hỏi & Đáp phản xạ',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: _mode == ReflexMode.qna
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard(SubtitleLine sub, bool isDark) {
    final bool isQna = _mode == ReflexMode.qna;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isQna
                      ? Colors.orange.withOpacity(0.12)
                      : AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isQna ? 'CÂU HỎI TÌNH HUỐNG' : 'CÂU MẪU CẦN NÓI',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isQna ? Colors.orange.shade800 : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              // Native Audio Play Button
              IconButton(
                tooltip: 'Nghe chậm 0.8x',
                onPressed: () => _playSampleAudio(rate: 0.75),
                icon: const Icon(Icons.slow_motion_video_rounded,
                    color: AppColors.secondary, size: 22),
              ),
              IconButton(
                tooltip: 'Nghe câu mẫu',
                onPressed: () => _playSampleAudio(rate: 0.95),
                icon: Icon(
                  _isPlayingSample
                      ? Icons.volume_up_rounded
                      : Icons.play_circle_fill_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isQna) ...[
            Text(
              sub.reflexQuestion ?? 'How would you respond to this statement?',
              style: AppTextStyles.h4.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gợi ý câu trả lời:',
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub.suggestedResponse ?? sub.englishText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              sub.englishText,
              style: AppTextStyles.h4.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                height: 1.35,
              ),
            ),
            if (sub.ipa != null && sub.ipa!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                sub.ipa!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '🇻🇳 ${sub.vietnameseText}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordingActionArea(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // Live transcribed text or guide
          if (_spokenText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.speaking.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.speaking.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bạn vừa nói:',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.speaking,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"$_spokenText"',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              _isRecording
                  ? 'Đang nghe... Hãy nói to và rõ ràng'
                  : 'Bấm micro để bắt đầu luyện nói phản xạ',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _isRecording ? AppColors.speaking : Colors.grey,
                fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          const SizedBox(height: 10),

          // Big Record Button
          GestureDetector(
            onTap: () {
              if (_isRecording) {
                _stopRecordingAndEvaluate();
              } else {
                _startRecording();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isRecording
                      ? [Colors.redAccent, Colors.red]
                      : [AppColors.speaking, const Color(0xFFFF4757)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : AppColors.speaking)
                        .withOpacity(0.4),
                    blurRadius: _isRecording ? 25 : 15,
                    spreadRadius: _isRecording ? 6 : 2,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isRecording ? 'Chạm để Dừng & Chấm Điểm' : 'Chạm để Nói',
            style: AppTextStyles.labelSmall.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentCard(bool isDark) {
    final res = _assessmentResult!;
    final double overallScore = (res['overall_score'] as num?)?.toDouble() ?? 0.0;
    final double accuracyScore = (res['accuracy_score'] as num?)?.toDouble() ?? 0.0;
    final double fluencyScore = (res['fluency_score'] as num?)?.toDouble() ?? 0.0;
    final String feedback = res['feedback'] ?? '';
    final List<dynamic> words = res['word_scores'] as List<dynamic>? ?? [];

    final bool isPassed = overallScore >= 70;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPassed ? Colors.green.shade400 : Colors.orange.shade400,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPassed ? Colors.green : Colors.orange).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with score badge
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPassed
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                ),
                child: Center(
                  child: Text(
                    '${overallScore.toInt()}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isPassed ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPassed ? 'Phản Xạ Tuyệt Vời! 🎉' : 'Cố Gắng Lên Nào! 💪',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isPassed ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feedback,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Accuracy & Fluency metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Độ chính xác',
                  '${accuracyScore.toInt()}%',
                  AppColors.primary,
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  'Độ lưu loát',
                  '${fluencyScore.toInt()}%',
                  AppColors.secondary,
                  isDark,
                ),
              ),
            ],
          ),

          // Word-by-word analysis
          if (words.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Chi tiết từng từ bạn phát âm:',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: words.map((w) {
                final String word = (w['word'] ?? '').toString();
                final String status = (w['status'] ?? '').toString();
                final bool isCorrect = status == 'correct' ||
                    ((w['score'] as num?)?.toDouble() ?? 0) >= 70;

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect
                          ? Colors.green.shade300
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Text(
                    word,
                    style: TextStyle(
                      color: isCorrect ? Colors.green.shade800 : Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 22),

          // Next button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _goToNextSentence,
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              label: Text(
                _currentIndex < _sentences.length - 1
                    ? 'Câu Tiếp Theo'
                    : 'Hoàn Thành Bài Luyện',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
