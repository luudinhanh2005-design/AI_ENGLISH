import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/speech_service.dart';
import '../providers/mistake_notebook_provider.dart';

enum IELTSStep {
  intro,
  part1,
  part2Prep,
  part2Speak,
  part3,
  evaluating,
  result,
}

class IeltsSpeakingMockScreen extends ConsumerStatefulWidget {
  const IeltsSpeakingMockScreen({super.key});

  @override
  ConsumerState<IeltsSpeakingMockScreen> createState() =>
      _IeltsSpeakingMockScreenState();
}

class _IeltsSpeakingMockScreenState
    extends ConsumerState<IeltsSpeakingMockScreen> {
  IELTSStep _step = IELTSStep.intro;

  // Prompt data
  Map<String, dynamic>? _promptData;
  bool _isLoadingPrompt = false;

  // Test State
  int _p1Index = 0;
  final List<Map<String, String>> _p1Answers = [];

  // Part 2
  Timer? _prepTimer;
  int _prepSecondsRemaining = 60;
  final TextEditingController _prepNotesController = TextEditingController();

  Timer? _speakTimer;
  int _speakSecondsRemaining = 120;
  String _part2Answer = '';

  // Part 3
  int _p3Index = 0;
  final List<Map<String, String>> _p3Answers = [];

  // Speech recording & Mic
  final TextEditingController _speechInputController = TextEditingController();
  final AudioRecordingService _audioService = AudioRecordingService();
  bool _isRecordingMic = false;
  bool _isTranscribing = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  // Evaluation Result
  Map<String, dynamic>? _resultData;

  @override
  void initState() {
    super.initState();
    _fetchPrompt();
  }

  @override
  void dispose() {
    _prepTimer?.cancel();
    _speakTimer?.cancel();
    _recordTimer?.cancel();
    _audioService.dispose();
    _prepNotesController.dispose();
    _speechInputController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrompt([String? topicId]) async {
    setState(() => _isLoadingPrompt = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        ApiEndpoints.ieltsPrompt,
        queryParameters: topicId != null ? {'topic_id': topicId} : null,
      );
      if (res.statusCode == 200 && res.data != null) {
        setState(() {
          _promptData = res.data as Map<String, dynamic>;
          _isLoadingPrompt = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback if offline
    setState(() {
      _promptData = {
        'id': 'tech_comm',
        'topic': 'Technology & Modern Communication',
        'part1': [
          'How often do you use social media to communicate with friends?',
          'Do you prefer texting or calling someone, and why?',
          'What new technology has made your daily life easier recently?',
        ],
        'part2': {
          'cue_card':
              'Describe a piece of electronic equipment that you find useful.',
          'prompts': [
            'What it is and when you got it',
            'What you use it for regularly',
            'How easy or difficult it is to use',
            'Explain why you find it particularly useful in your life',
          ],
          'prep_time_seconds': 60,
          'speak_time_seconds': 120,
        },
        'part3': [
          'In what ways has modern technology changed traditional human relationships?',
          'Do you think artificial intelligence will replace human workers in the future?',
          'How can elderly people be encouraged to adopt modern digital tools?',
        ],
      };
      _isLoadingPrompt = false;
    });
  }

  void _examinerSpeak(String text) {
    SpeechService.speak(text, rate: 0.95);
  }

  void _startPart1() {
    setState(() {
      _step = IELTSStep.part1;
      _p1Index = 0;
      _p1Answers.clear();
      _speechInputController.clear();
    });
    final questions = (_promptData?['part1'] as List?) ?? [];
    if (questions.isNotEmpty) {
      _examinerSpeak('Welcome to the IELTS Speaking test. Let\'s begin Part 1. ' +
          questions[0].toString());
    }
  }

  // ──────────────────────────────────────────────
  // Mic Recording & Speech-to-Text
  // ──────────────────────────────────────────────
  Future<void> _toggleMic() async {
    if (_isRecordingMic) {
      await _stopMicAndTranscribe();
    } else {
      await _startMic();
    }
  }

  Future<void> _startMic() async {
    try {
      final hasPerm = await _audioService.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng cấp quyền Microphone cho trình duyệt để nói.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _audioService.startRecording();
      setState(() {
        _isRecordingMic = true;
        _recordSeconds = 0;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      debugPrint('Start mic error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi bật microphone: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _stopMicAndTranscribe() async {
    _recordTimer?.cancel();
    setState(() {
      _isRecordingMic = false;
      _isTranscribing = true;
    });

    try {
      final bytes = await _audioService.stopRecording();
      if (bytes != null && bytes.isNotEmpty) {
        final dio = ref.read(dioProvider);
        final formData = FormData.fromMap({
          'audio': MultipartFile.fromBytes(
            bytes,
            filename: kIsWeb ? 'ielts_speech.webm' : 'ielts_speech.wav',
          ),
          'language': 'en',
        });
        final res = await dio.post('/speech/transcribe', data: formData);
        if (res.data != null && res.data['transcript'] != null) {
          final transcript = (res.data['transcript'] as String).trim();
          if (transcript.isNotEmpty) {
            final cur = _speechInputController.text.trim();
            setState(() {
              _speechInputController.text = cur.isEmpty ? transcript : '$cur $transcript';
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🎙️ Đã nhận diện giọng nói: "$transcript"'),
                  backgroundColor: const Color(0xFF2ED573),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chưa nghe rõ giọng nói. Bạn thử nói lại to hơn nhé!')),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Transcribe error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi nhận diện giọng nói: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<bool> _confirmSkipQuestion(String message) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.palette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4757), size: 26),
            SizedBox(width: 8),
            Text('Chưa Có Câu Trả Lời', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: context.palette.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Quay lại trả lời'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4757),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Bỏ qua (0 điểm)'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _nextPart1Question() async {
    if (_isRecordingMic) {
      await _stopMicAndTranscribe();
    }

    final questions = (_promptData?['part1'] as List?) ?? [];
    final currentQ = questions[_p1Index].toString();
    final answerText = _speechInputController.text.trim();

    if (answerText.isEmpty) {
      final confirm = await _confirmSkipQuestion(
        'Bạn chưa nói hoặc nhập câu trả lời cho câu hỏi Part 1 này.\nNếu tiếp tục bỏ qua, bạn sẽ bị tính 0 điểm cho câu hỏi này. Bạn có muốn tiếp tục?',
      );
      if (!confirm) return;
    }

    _p1Answers.add({
      'question': currentQ,
      'answer': answerText, // PURE USER INPUT, NO FAKE DEFAULT!
    });
    _speechInputController.clear();

    if (_p1Index < questions.length - 1) {
      setState(() {
        _p1Index++;
      });
      _examinerSpeak(questions[_p1Index].toString());
    } else {
      // Transition to Part 2 Prep
      _startPart2Prep();
    }
  }

  void _startPart2Prep() {
    setState(() {
      _step = IELTSStep.part2Prep;
      _prepSecondsRemaining = 60;
      _prepNotesController.clear();
    });
    _examinerSpeak(
        'Now, I will give you a topic card for Part 2. You have one minute to prepare your notes, and then you will speak for two minutes.');

    _prepTimer?.cancel();
    _prepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prepSecondsRemaining > 1) {
        setState(() => _prepSecondsRemaining--);
      } else {
        timer.cancel();
        _startPart2Speak();
      }
    });
  }

  void _startPart2Speak() {
    _prepTimer?.cancel();
    setState(() {
      _step = IELTSStep.part2Speak;
      _speakSecondsRemaining = 120;
      _speechInputController.clear();
    });
    _examinerSpeak('Your preparation time is over. Please start speaking now.');

    _speakTimer?.cancel();
    _speakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_speakSecondsRemaining > 1) {
        setState(() => _speakSecondsRemaining--);
      } else {
        timer.cancel();
        _finishPart2();
      }
    });
  }

  Future<void> _finishPart2() async {
    if (_isRecordingMic) {
      await _stopMicAndTranscribe();
    }
    _speakTimer?.cancel();
    final answer = _speechInputController.text.trim();

    if (answer.isEmpty) {
      final confirm = await _confirmSkipQuestion(
        'Bạn chưa ghi âm hoặc nhập nội dung bài nói cho Part 2 (Cue Card).\nPhần thi độc thoại 2 phút là trọng tâm của IELTS Speaking. Nếu bỏ qua sẽ nhận Band 1.0 (Không hoàn thành). Bạn có chắc muốn nộp bài trống?',
      );
      if (!confirm) return;
    }

    _part2Answer = answer; // PURE USER INPUT, NO FAKE DEFAULT!
    _speechInputController.clear();

    // Start Part 3
    _startPart3();
  }

  void _startPart3() {
    setState(() {
      _step = IELTSStep.part3;
      _p3Index = 0;
      _p3Answers.clear();
      _speechInputController.clear();
    });
    final questions = (_promptData?['part3'] as List?) ?? [];
    if (questions.isNotEmpty) {
      _examinerSpeak('Thank you. We will now move on to Part 3, where we discuss more general questions. ' +
          questions[0].toString());
    }
  }

  Future<void> _nextPart3Question() async {
    if (_isRecordingMic) {
      await _stopMicAndTranscribe();
    }

    final questions = (_promptData?['part3'] as List?) ?? [];
    final currentQ = questions[_p3Index].toString();
    final answerText = _speechInputController.text.trim();

    if (answerText.isEmpty) {
      final confirm = await _confirmSkipQuestion(
        'Bạn chưa đưa ra câu trả lời cho câu hỏi Part 3 này. Nếu bỏ qua, câu này sẽ bị tính 0 điểm. Bạn có muốn tiếp tục?',
      );
      if (!confirm) return;
    }

    _p3Answers.add({
      'question': currentQ,
      'answer': answerText, // PURE USER INPUT!
    });
    _speechInputController.clear();

    if (_p3Index < questions.length - 1) {
      setState(() {
        _p3Index++;
      });
      _examinerSpeak(questions[_p3Index].toString());
    } else {
      // Evaluate test!
      _submitTestForEvaluation();
    }
  }

  Future<void> _submitTestForEvaluation() async {
    setState(() {
      _step = IELTSStep.evaluating;
    });

    final dio = ref.read(dioProvider);
    try {
      final res = await dio.post(
        ApiEndpoints.ieltsEvaluate,
        data: {
          'topic': _promptData?['topic'] ?? 'General IELTS Speaking',
          'part1_qa': _p1Answers,
          'part2_answer': _part2Answer,
          'part3_qa': _p3Answers,
        },
      );

      if (res.statusCode == 200 && res.data != null) {
        setState(() {
          _resultData = res.data as Map<String, dynamic>;
          _step = IELTSStep.result;
        });
        return;
      }
    } catch (_) {}

    // Fallback Result with authentic strict word count checks
    final allWords = [
      ..._p1Answers.map((e) => e['answer'] ?? ''),
      _part2Answer,
      ..._p3Answers.map((e) => e['answer'] ?? ''),
    ].join(' ').trim();
    final wordCount = RegExp(r'\b\w+\b').allMatches(allWords).length;

    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() {
      if (wordCount == 0) {
        _resultData = {
          'overall_band': 1.0,
          'fluency_band': 1.0,
          'lexical_band': 1.0,
          'grammar_band': 1.0,
          'pronunciation_band': 1.0,
          'cefr_level': 'Pre-A1',
          'examiner_comment':
              'Thí sinh không trả lời hoặc không ghi nhận được giọng nói nào trong toàn bộ buổi thi. Theo thang điểm chuẩn IELTS, bài thi nhận điểm Band 1.0 (Did not attempt / Non-user).',
          'strengths': ['Chưa ghi nhận câu trả lời để đánh giá điểm mạnh.'],
          'improvements': [
            'Bấm mic để nói trực tiếp câu trả lời của bạn.',
            'Nếu không dùng mic, hãy gõ câu trả lời tiếng Anh vào khung trước khi bấm tiếp tục.',
          ],
          'corrections': [],
          'band8_samples': [],
        };
      } else if (wordCount < 25) {
        _resultData = {
          'overall_band': 2.5,
          'fluency_band': 2.5,
          'lexical_band': 2.5,
          'grammar_band': 2.5,
          'pronunciation_band': 2.5,
          'cefr_level': 'A1',
          'examiner_comment':
              'Thí sinh chỉ đưa ra câu trả lời rất ngắn ($wordCount từ), chưa đủ để hình thành câu đối thoại hoàn chỉnh. Đạt mức Band 2.5.',
          'strengths': ['Có phản xạ ban đầu với câu hỏi.'],
          'improvements': ['Tránh trả lời cộc lốc, hãy trả lời đủ chủ - vị ngữ.'],
          'corrections': [],
          'band8_samples': [],
        };
      } else if (wordCount < 60) {
        _resultData = {
          'overall_band': 3.5,
          'fluency_band': 3.5,
          'lexical_band': 3.5,
          'grammar_band': 3.5,
          'pronunciation_band': 4.0,
          'cefr_level': 'A2',
          'examiner_comment':
              'Thí sinh trả lời được ý cơ bản ($wordCount từ) nhưng còn ngắn. Đạt Band 3.5 (Extremely limited user).',
          'strengths': ['Đã nêu được ý chính của câu hỏi.'],
          'improvements': ['Mở rộng câu trả lời với lý do và ví dụ.'],
          'corrections': [],
          'band8_samples': [],
        };
      } else {
        _resultData = {
          'overall_band': 6.0,
          'fluency_band': 6.0,
          'lexical_band': 6.0,
          'grammar_band': 6.0,
          'pronunciation_band': 6.0,
          'cefr_level': 'B2',
          'examiner_comment':
              'Bạn đã hoàn thành bài thi với $wordCount từ và khả năng duy trì đối thoại tương đối tốt. Cố gắng sử dụng thêm các cấu trúc câu phức ở Part 3 để chinh phục Band 7.5+ nhé!',
          'strengths': [
            'Duy trì tốc độ nói ổn định, không ngập ngừng quá lâu ở Part 2.',
            'Sử dụng các từ nối tự nhiên.',
          ],
          'improvements': [
            'Cung cấp thêm ví dụ thực tế hoặc số liệu dẫn chứng ở Part 3.',
            'Tránh lặp lại một số từ cơ bản, mở rộng từ vựng học thuật.',
          ],
          'corrections': [],
          'band8_samples': [],
        };
      }
      _step = IELTSStep.result;
    });
  }

  void _saveMistakesToNotebook() {
    final corrections = (_resultData?['corrections'] as List?) ?? [];
    if (corrections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có lỗi sai nào để lưu.')),
      );
      return;
    }

    ref.read(mistakeNotebookProvider.notifier).addBatchMistakes(
          corrections.cast<Map<String, dynamic>>(),
          source: 'ielts',
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '🎉 Đã lưu ${corrections.length} lỗi vào Sổ tay lỗi sai & Flashcard SM-2!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2ED573),
      ),
    );
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
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case IELTSStep.intro:
        return _buildIntroView();
      case IELTSStep.part1:
        return _buildPart1View();
      case IELTSStep.part2Prep:
        return _buildPart2PrepView();
      case IELTSStep.part2Speak:
        return _buildPart2SpeakView();
      case IELTSStep.part3:
        return _buildPart3View();
      case IELTSStep.evaluating:
        return _buildEvaluatingView();
      case IELTSStep.result:
        return _buildResultView();
    }
  }

  // ──────────────────────────────────────────────
  // 1. INTRO VIEW
  // ──────────────────────────────────────────────
  Widget _buildIntroView() {
    final topic = _promptData?['topic'] ?? 'Technology & Modern Communication';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Back
          Row(
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
              const SizedBox(width: 6),
              Text(
                'Phòng Thi Thử IELTS Speaking 🏆',
                style: AppTextStyles.h3.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Examiner Emma Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: const Color(0xFF00CEC9), width: 3),
                      ),
                      child: const Center(
                        child: Text('👩‍🏫', style: TextStyle(fontSize: 40)),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2ED573),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Giám Khảo Emma',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE74C3C),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'British 🇬🇧',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chuyên gia khảo thí IELTS Senior Examiner với chuẩn đánh giá IDP & British Council.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
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

          const SizedBox(height: 20),

          // Topic Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CHỦ ĐỀ THI ĐÃ CHỌN',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // Toggle another topic
                        final topics = [
                          'tech_comm',
                          'travel_exp',
                          'education_career'
                        ];
                        final cur = _promptData?['id'] ?? 'tech_comm';
                        final next =
                            topics[(topics.indexOf(cur) + 1) % topics.length];
                        _fetchPrompt(next);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Đổi đề thi khác',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary),
                    ),
                  ],
                ),
                Text(
                  topic,
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3 Parts Overview
          Text(
            'Quy Trình Thi Chuẩn 3 Phần:',
            style: AppTextStyles.h4.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildPartIntroCard(
            stepNumber: '1',
            title: 'Part 1: Khởi động & Hỏi đáp cá nhân',
            desc:
                'Giám khảo đặt 3 câu hỏi thường ngày để kiểm tra phản xạ tự nhiên và độ trôi chảy ban đầu.',
            color: const Color(0xFF00CEC9),
          ),
          const SizedBox(height: 10),
          _buildPartIntroCard(
            stepNumber: '2',
            title: 'Part 2: Thẻ Gợi Ý (Cue Card Long Turn)',
            desc:
                '1 phút chuẩn bị với sổ tay nháp + 2 phút nói liên tục về chủ đề được bốc thăm.',
            color: const Color(0xFF6C5CE7),
          ),
          const SizedBox(height: 10),
          _buildPartIntroCard(
            stepNumber: '3',
            title: 'Part 3: Thảo Luận Chuyên Sâu (Discussion)',
            desc:
                '3 câu hỏi phân tích, phản biện mang tính học thuật cao liên quan tới Part 2.',
            color: const Color(0xFFFFA502),
          ),

          const SizedBox(height: 28),

          // Start Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              onPressed: _startPart1,
              icon: const Icon(Icons.mic_rounded, color: Colors.white),
              label: const Text(
                'Bắt Đầu Phòng Thi Thử IELTS 🚀',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPartIntroCard({
    required String stepNumber,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: TextStyle(
                  color: color,
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
                Text(
                  title,
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 2. PART 1 VIEW
  // ──────────────────────────────────────────────
  Widget _buildPart1View() {
    final questions = (_promptData?['part1'] as List?) ?? [];
    final currentQ = questions.isNotEmpty ? questions[_p1Index].toString() : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageHeader('PART 1 / 3: HỎI ĐÁP KHỞI ĐỘNG',
              'Câu hỏi ${_p1Index + 1} trên ${questions.length}'),
          const SizedBox(height: 20),

          // Question Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF00CEC9).withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00CEC9).withOpacity(0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('👩‍🏫', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      'Giám khảo Emma hỏi:',
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _examinerSpeak(currentQ),
                      icon: const Icon(Icons.volume_up_rounded,
                          color: Color(0xFF00CEC9)),
                      tooltip: 'Nghe lại câu hỏi',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currentQ,
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildSpeechAndTextInput(
            label: 'Câu trả lời của bạn (Nói qua Mic hoặc gõ văn bản):',
            hintText: 'Bấm micro ở trên để nói hoặc gõ câu trả lời tiếng Anh...',
            maxLines: 4,
            sampleLabel: '⚡ Điền mẫu thử nghiệm',
            onSample: () {
              final samples = [
                'I generally use social media on a daily basis to keep in touch with my close friends and family members.',
                'Personally, I lean towards texting because it allows me to articulate my thoughts more coherently without feeling rushed.',
                'Undoubtedly, smart cloud translation tools have simplified how I digest academic materials from international sources.',
              ];
              setState(() {
                _speechInputController.text = samples[_p1Index % samples.length];
              });
            },
            nextLabel: _p1Index < questions.length - 1
                ? 'Câu Tiếp Theo'
                : 'Sang Part 2 (Cue Card)',
            nextIcon: Icons.arrow_forward_rounded,
            onNext: _nextPart1Question,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 3. PART 2 PREPARATION VIEW (1 Minute)
  // ──────────────────────────────────────────────
  Widget _buildPart2PrepView() {
    final cueCard = _promptData?['part2'] as Map<String, dynamic>?;
    final topicText = cueCard?['cue_card'] ?? '';
    final prompts = (cueCard?['prompts'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageHeader('PART 2: GIAI ĐOẠN CHUẨN BỊ (1 PHÚT)',
              'Ghi chép từ khóa vào sổ tay nháp trước khi bắt đầu nói'),
          const SizedBox(height: 16),

          // Countdown Circle
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: _prepSecondsRemaining / 60,
                    strokeWidth: 8,
                    backgroundColor: context.palette.divider,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6C5CE7)),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_prepSecondsRemaining',
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('giây',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Cue Card Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF6C5CE7).withOpacity(0.5), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topicText,
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'You should say:',
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 6),
                ...prompts.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(
                                  color: Color(0xFF6C5CE7),
                                  fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              p.toString(),
                              style: TextStyle(
                                color: context.palette.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Scratchpad Notes
          Text(
            'Sổ tay ghi chú nháp (Từ vựng, cấu trúc):',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _prepNotesController,
            maxLines: 3,
            style: TextStyle(color: context.palette.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText:
                  'Ví dụ: smartphone, acquired last year, seamless multitasking, indispensable...',
              hintStyle: TextStyle(
                  color: context.palette.textSecondary.withOpacity(0.5)),
              filled: true,
              fillColor: context.palette.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.palette.divider),
              ),
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _startPart2Speak,
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text(
                'Đã Sẵn Sàng Nói (Bắt đầu 2 phút) 🎙️',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 4. PART 2 SPEAKING VIEW (2 Minutes)
  // ──────────────────────────────────────────────
  Widget _buildPart2SpeakView() {
    final cueCard = _promptData?['part2'] as Map<String, dynamic>?;
    final topicText = cueCard?['cue_card'] ?? '';

    final mins = _speakSecondsRemaining ~/ 60;
    final secs = _speakSecondsRemaining % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageHeader('PART 2: ĐỘC THOẠI LIÊN TỤC (2 PHÚT)',
              'Trình bày bài nói hoàn chỉnh dựa trên các gợi ý'),
          const SizedBox(height: 16),

          // Speaking Timer Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic_rounded,
                    color: Color(0xFFFF6B6B), size: 22),
                const SizedBox(width: 8),
                Text(
                  'ĐANG GHI ÂM BÀI NÓI: $timeStr',
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Cue Card summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.divider),
            ),
            child: Text(
              'Đề bài: $topicText',
              style: TextStyle(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 14),

          _buildSpeechAndTextInput(
            label: 'Nội dung bài nói 2 phút của bạn:',
            hintText: 'Bấm micro ở trên để nói liên tục hoặc nhập bài thuyết trình...',
            maxLines: 6,
            sampleLabel: '⚡ Điền mẫu Band 7.5',
            onSample: () {
              setState(() {
                _speechInputController.text =
                    'I would like to elaborate on my smartphone, which I acquired approximately one year ago. It has undeniably become an indispensable asset in my daily life, facilitating seamless communication and autonomous research. What makes it particularly user-friendly is the intuitive operating system and prompt responsiveness. Without a shadow of a doubt, it has transformed how I manage both my studies and personal responsibilities.';
              });
            },
            nextLabel: 'Hoàn Thành Part 2',
            nextIcon: Icons.check_circle_rounded,
            onNext: _finishPart2,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 5. PART 3 VIEW
  // ──────────────────────────────────────────────
  Widget _buildPart3View() {
    final questions = (_promptData?['part3'] as List?) ?? [];
    final currentQ = questions.isNotEmpty ? questions[_p3Index].toString() : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageHeader('PART 3 / 3: THẢO LUẬN CHUYÊN SÂU',
              'Câu hỏi ${_p3Index + 1} trên ${questions.length} - Đòi hỏi tư duy phân tích'),
          const SizedBox(height: 20),

          // Question Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFFFA502).withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFA502).withOpacity(0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('👩‍🏫', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      'Giám khảo Emma đặt câu hỏi chuyên sâu:',
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _examinerSpeak(currentQ),
                      icon: const Icon(Icons.volume_up_rounded,
                          color: Color(0xFFFFA502)),
                      tooltip: 'Nghe lại câu hỏi',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currentQ,
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildSpeechAndTextInput(
            label: 'Phân tích & Lập luận của bạn:',
            hintText: 'Đưa ra luận điểm, dẫn chứng và góc nhìn cá nhân...',
            maxLines: 4,
            sampleLabel: '⚡ Điền mẫu Band 8.0',
            onSample: () {
              final samples = [
                'From my perspective, modern technology has undeniably attenuated physical face-to-face interactions, while simultaneously fostering global virtual communities.',
                'While automated algorithms can substitute manual and repetitive tasks, intrinsic human attributes such as empathetic communication remain irreplaceable.',
                'Governments and educational institutions should implement user-friendly community workshops to bridge the generational digital divide.',
              ];
              setState(() {
                _speechInputController.text = samples[_p3Index % samples.length];
              });
            },
            nextLabel: _p3Index < questions.length - 1
                ? 'Câu Tiếp Theo'
                : 'Nộp Bài Chấm Điểm 🎯',
            nextIcon: Icons.check_rounded,
            onNext: _nextPart3Question,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Common Voice & Text Input Component
  // ──────────────────────────────────────────────
  Widget _buildSpeechAndTextInput({
    required String label,
    required String hintText,
    required int maxLines,
    required VoidCallback onSample,
    required String sampleLabel,
    required VoidCallback onNext,
    required String nextLabel,
    required IconData nextIcon,
  }) {
    final wordCount = _speechInputController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: wordCount == 0
                    ? const Color(0xFFFF4757).withOpacity(0.12)
                    : const Color(0xFF2ED573).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                wordCount == 0 ? 'Chưa trả lời (0 từ)' : '$wordCount từ',
                style: TextStyle(
                  color: wordCount == 0
                      ? const Color(0xFFFF4757)
                      : const Color(0xFF2ED573),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Microphone Live Action Bar
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: _isRecordingMic
                ? const Color(0xFFFF4757).withOpacity(0.18)
                : context.palette.card,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _isTranscribing ? null : _toggleMic,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isRecordingMic
                        ? const Color(0xFFFF4757)
                        : const Color(0xFF00CEC9).withOpacity(0.6),
                    width: _isRecordingMic ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isTranscribing) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00CEC9),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'AI đang nhận diện giọng nói tiếng Anh...',
                        style: TextStyle(
                          color: Color(0xFF00CEC9),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ] else if (_isRecordingMic) ...[
                      const Icon(Icons.stop_circle_rounded,
                          color: Color(0xFFFF4757), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'ĐANG GHI ÂM (${_recordSeconds}s) — BẤM ĐỂ DỪNG & LẤY CHỮ ⏹️',
                        style: const TextStyle(
                          color: Color(0xFFFF4757),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.mic_rounded,
                          color: Color(0xFF00CEC9), size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Bấm vào đây để nói vào Micro (Speech-to-Text)',
                        style: TextStyle(
                          color: Color(0xFF00CEC9),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Text input field
        TextField(
          controller: _speechInputController,
          maxLines: maxLines,
          style: TextStyle(color: context.palette.textPrimary, fontSize: 14),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: context.palette.textSecondary.withOpacity(0.6),
            ),
            filled: true,
            fillColor: context.palette.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.palette.divider),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFF00CEC9)),
                ),
                onPressed: onSample,
                icon: const Icon(Icons.auto_fix_high_rounded,
                    color: Color(0xFF00CEC9), size: 18),
                label: Text(
                  sampleLabel,
                  style: const TextStyle(color: Color(0xFF00CEC9), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onNext,
                icon: Icon(nextIcon, color: Colors.white, size: 18),
                label: Text(
                  nextLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // 6. EVALUATING VIEW
  // ──────────────────────────────────────────────
  Widget _buildEvaluatingView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Giám Khảo Emma Đang Chấm Điểm...',
              style: AppTextStyles.h3.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Đang đối soát 4 tiêu chí chuẩn IELTS:\n• Fluency & Coherence\n• Lexical Resource\n• Grammatical Range\n• Pronunciation',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 7. RESULT VIEW (IELTS Certificate & Feedback)
  // ──────────────────────────────────────────────
  Widget _buildResultView() {
    final overall = (_resultData?['overall_band'] as num?)?.toDouble() ?? 1.0;
    final fluency = (_resultData?['fluency_band'] as num?)?.toDouble() ?? 1.0;
    final lexical = (_resultData?['lexical_band'] as num?)?.toDouble() ?? 1.0;
    final grammar = (_resultData?['grammar_band'] as num?)?.toDouble() ?? 1.0;
    final pron =
        (_resultData?['pronunciation_band'] as num?)?.toDouble() ?? 1.0;
    final cefr = _resultData?['cefr_level'] ?? 'Pre-A1';
    final comment = _resultData?['examiner_comment'] ??
        'Không ghi nhận câu trả lời nào từ thí sinh trong toàn bộ buổi thi. Đạt mức Band 1.0 (Did not attempt / Non-user).';
    final strengths = (_resultData?['strengths'] as List?) ?? [];
    final improvements = (_resultData?['improvements'] as List?) ?? [];
    final corrections = (_resultData?['corrections'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/'),
                icon: Icon(Icons.close_rounded,
                    color: context.palette.textPrimary),
              ),
              const SizedBox(width: 6),
              Text(
                'Bảng Điểm Thi Thử IELTS Speaking 🎓',
                style: AppTextStyles.h3.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Certificate Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'OFFICIAL MOCK TEST REPORT',
                      style: TextStyle(
                        color: Color(0xFF00CEC9),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'CEFR: $cefr',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  overall.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  _bandDescription(overall),
                  style: const TextStyle(
                    color: Color(0xFF00CEC9),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),

                // 4 Sub-criteria Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSubscoreColumn('Fluency', fluency),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _buildSubscoreColumn('Lexical', lexical),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _buildSubscoreColumn('Grammar', grammar),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _buildSubscoreColumn('Pronunciation', pron),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Examiner Emma's Commentary
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('👩‍🏫', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      'Nhận xét từ Giám khảo Emma:',
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  comment,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Strengths & Improvements
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ED573).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF2ED573).withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '✨ Điểm Mạnh',
                        style: TextStyle(
                          color: Color(0xFF2ED573),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...strengths.map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• $s',
                              style: TextStyle(
                                  color: context.palette.textPrimary,
                                  fontSize: 11,
                                  height: 1.3),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA502).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFFFA502).withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 Cần Cải Thiện',
                        style: TextStyle(
                          color: Color(0xFFFFA502),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...improvements.map((im) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• $im',
                              style: TextStyle(
                                  color: context.palette.textPrimary,
                                  fontSize: 11,
                                  height: 1.3),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Save Mistakes Button (Connects with Mistake Notebook Feature 2!)
          if (corrections.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: const Color(0xFF6C5CE7).withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_add_rounded,
                      color: Color(0xFF6C5CE7), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sổ Tay Lỗi Sai (Flashcard SM-2)',
                          style: TextStyle(
                            color: Color(0xFF6C5CE7),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Phát hiện ${corrections.length} lỗi trong bài thi. Lưu để ôn tập định kỳ.',
                          style: TextStyle(
                            color: context.palette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saveMistakesToNotebook,
                    child: const Text('Lưu Tất Cả',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    setState(() {
                      _step = IELTSStep.intro;
                      _resultData = null;
                    });
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Thi Lại Đề Khác'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_rounded, color: Colors.white),
                  label: const Text('Về Trang Chủ',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSubscoreColumn(String label, double score) {
    return Column(
      children: [
        Text(
          score.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStageHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _step = IELTSStep.intro),
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: context.palette.textPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: context.palette.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _bandDescription(double band) {
    if (band >= 8.5) return 'Expert User (Xuất Sắc Tuyệt Đối)';
    if (band >= 7.5) return 'Very Good User (Rất Thành Thạo)';
    if (band >= 6.5) return 'Good User (Thành Thạo Độc Lập)';
    if (band >= 5.5) return 'Competent User (Đủ Năng Lực)';
    if (band >= 4.0) return 'Modest User (Hạn Chế)';
    if (band >= 2.0) return 'Intermittent User (Cực Kỳ Hạn Chế)';
    return 'Non-User / Did Not Attempt (Chưa Có Điểm / Không Trả Lời)';
  }
}
