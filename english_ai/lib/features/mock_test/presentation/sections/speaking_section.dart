import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/mock_test_models.dart';
import '../widgets/examiner_voice.dart';

typedef SpeakingCompleted = void Function(
  List<Map<String, String>> part1Qa,
  String part2Answer,
  List<Map<String, String>> part3Qa,
  List<Map<String, String>> followUpQa,
);

enum _SpeakingPhase {
  intro,
  part1,
  part2Prep,
  part2Speak,
  part2FollowUp,
  part3,
  finished,
}

class _SpeakingQuestion {
  final String topic;
  final String text;

  const _SpeakingQuestion({required this.topic, required this.text});
}

/// Full IELTS Speaking mock test: intro → Part 1 → Part 2 (prep + long turn +
/// follow-ups) → Part 3. The examiner asks questions through [ExaminerVoice]
/// and answers are captured with the microphone + `/speech/transcribe`.
///
/// Strict mode forbids typed answers (mic only) and hides hints; practice mode
/// allows typing and unlimited replays. Scoring is done by the backend — this
/// widget only collects the answers and hands them to [onCompleted] once.
class SpeakingSectionView extends ConsumerStatefulWidget {
  final SpeakingSection section;
  final bool strict;
  final SpeakingCompleted onCompleted;

  /// Reports the collected answers so the runner/provider can submit them if
  /// the global exam timer expires before the candidate finishes.
  final ValueChanged<Map<String, dynamic>>? onPayloadChanged;

  const SpeakingSectionView({
    super.key,
    required this.section,
    required this.strict,
    required this.onCompleted,
    this.onPayloadChanged,
  });

  @override
  ConsumerState<SpeakingSectionView> createState() =>
      _SpeakingSectionViewState();
}

class _SpeakingSectionViewState extends ConsumerState<SpeakingSectionView> {
  late final ExaminerVoice _voice;
  final AudioRecordingService _recorder = AudioRecordingService();

  late final List<_SpeakingQuestion> _part1Questions;
  late final List<String> _part3Questions;

  _SpeakingPhase _phase = _SpeakingPhase.intro;

  int _part1Index = 0;
  int _followUpIndex = 0;
  int _part3Index = 0;

  final List<Map<String, String>> _part1Qa = [];
  final List<Map<String, String>> _part3Qa = [];
  final List<Map<String, String>> _followUpQa = [];
  String _part2Answer = '';

  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Timer? _prepTimer;
  Timer? _speakTimer;
  Timer? _recordTimer;

  int _prepRemaining = 60;
  int _speakRemaining = 120;
  int _recordSeconds = 0;

  bool _isRecording = false;
  bool _isStartingMic = false;
  bool _isTranscribing = false;
  bool _finishingPart2 = false;
  bool _completedSent = false;
  String? _micError;

  Completer<void>? _transcribeDone;

  /// One replay per question is allowed in strict mode, mirroring a real
  /// examiner's willingness to repeat a question once.
  final Set<String> _replayUsed = {};

  SpeakingPart2 get _part2 => widget.section.part2;

  @override
  void initState() {
    super.initState();
    _voice = ExaminerVoice(ref.read(dioProvider));
    _part1Questions = [
      for (final topic in widget.section.part1Topics)
        for (final question in topic.questions)
          _SpeakingQuestion(topic: topic.topic, text: question),
    ];
    _part3Questions = List<String>.from(widget.section.part3Questions);
    _prepRemaining = _part2.prepSeconds > 0 ? _part2.prepSeconds : 60;
    _speakRemaining = _part2.speakSeconds > 0 ? _part2.speakSeconds : 120;
  }

  @override
  void dispose() {
    _prepTimer?.cancel();
    _speakTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    _voice.dispose();
    _answerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Flow ────────────────────────────────────────────────

  void _startTest() {
    _replayUsed.clear();
    if (_part1Questions.isEmpty) {
      _startPart2Prep();
      return;
    }
    setState(() {
      _phase = _SpeakingPhase.part1;
      _part1Index = 0;
      _micError = null;
    });
    _answerController.clear();
    _askPart1Question();
  }

  void _askPart1Question() {
    final item = _part1Questions[_part1Index];
    final intro = _part1Index == 0 ? "Let's begin with Part 1. " : '';
    unawaited(_voice.speak('$intro${item.text}'));
  }

  Future<void> _nextPart1Question() async {
    if (_isTranscribing || _isStartingMic) {
      _showSnack('Đang xử lý câu trả lời, vui lòng đợi trong giây lát.');
      return;
    }
    final item = _part1Questions[_part1Index];
    final canContinue = await _ensureAnswered(
      emptyMessage:
          'Bạn chưa trả lời câu hỏi Part 1 này. Nếu bỏ qua, câu trả lời sẽ '
          'được tính 0 điểm. Bạn vẫn muốn tiếp tục?',
    );
    if (!canContinue || !mounted) return;

    _part1Qa.add({
      'question': item.text,
      'answer': _answerController.text.trim(),
    });
    _answerController.clear();
    _notifyPayload();

    if (_part1Index < _part1Questions.length - 1) {
      setState(() {
        _part1Index++;
        _micError = null;
      });
      _askPart1Question();
    } else {
      _startPart2Prep();
    }
  }

  void _startPart2Prep() {
    _prepTimer?.cancel();
    _speakTimer?.cancel();
    _speakTimer = null;
    setState(() {
      _phase = _SpeakingPhase.part2Prep;
      _prepRemaining = _part2.prepSeconds > 0 ? _part2.prepSeconds : 60;
      _micError = null;
      _part2Answer = '';
    });
    _answerController.clear();
    _notesController.clear();
    unawaited(
      _voice.speak(
        'Now I will give you a topic card for Part 2. You have one minute to '
        'prepare your notes, and then you will speak for up to two minutes.',
      ),
    );

    _prepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_phase != _SpeakingPhase.part2Prep) {
        timer.cancel();
        return;
      }
      if (_prepRemaining <= 1) {
        timer.cancel();
        setState(() => _prepRemaining = 0);
        _startPart2Speak();
      } else {
        setState(() => _prepRemaining--);
      }
    });
  }

  void _startPart2Speak() {
    if (_phase == _SpeakingPhase.part2Speak) return;
    _prepTimer?.cancel();
    _speakTimer?.cancel();
    _speakTimer = null;
    setState(() {
      _phase = _SpeakingPhase.part2Speak;
      _speakRemaining = _part2.speakSeconds > 0 ? _part2.speakSeconds : 120;
      _micError = null;
    });
    _answerController.clear();
    unawaited(_voice.stop());
    // Start recording and the 2-minute clock together, like the real test.
    unawaited(_handleMicTap());
  }

  void _startPart2Countdown() {
    if (_speakTimer?.isActive ?? false) return;
    _speakTimer?.cancel();
    _speakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_phase != _SpeakingPhase.part2Speak) {
        timer.cancel();
        return;
      }
      if (_speakRemaining <= 1) {
        timer.cancel();
        setState(() => _speakRemaining = 0);
        unawaited(_finishPart2Speak(auto: true));
      } else {
        setState(() => _speakRemaining--);
      }
    });
  }

  Future<void> _finishPart2Speak({required bool auto}) async {
    if (_finishingPart2) return;
    _finishingPart2 = true;
    _speakTimer?.cancel();
    _speakTimer = null;

    if (_isRecording) {
      await _stopRecording();
    } else if (_isTranscribing) {
      await _transcribeDone?.future;
    }
    if (!mounted) {
      _finishingPart2 = false;
      return;
    }

    final answer = _answerController.text.trim();
    if (answer.isEmpty && !auto) {
      final skip = await _confirmSkip(
        'Bạn chưa có nội dung cho phần độc thoại Part 2. Nếu bỏ qua, phần này '
        'sẽ bị tính 0 điểm. Bạn vẫn muốn tiếp tục?',
      );
      if (!skip || !mounted) {
        _finishingPart2 = false;
        return;
      }
    }

    _part2Answer = answer;
    _answerController.clear();
    _notesController.clear();
    _notifyPayload();
    _finishingPart2 = false;
    _startPart2FollowUp();
  }

  void _startPart2FollowUp() {
    final followUps = _part2.followUps;
    if (followUps.isEmpty) {
      _startPart3();
      return;
    }
    setState(() {
      _phase = _SpeakingPhase.part2FollowUp;
      _followUpIndex = 0;
      _micError = null;
    });
    _answerController.clear();
    _askFollowUpQuestion();
  }

  void _askFollowUpQuestion() {
    final question = _part2.followUps[_followUpIndex];
    final intro = _followUpIndex == 0 ? 'Thank you. ' : '';
    unawaited(_voice.speak('$intro$question'));
  }

  Future<void> _nextFollowUpQuestion() async {
    if (_isTranscribing || _isStartingMic) {
      _showSnack('Đang xử lý câu trả lời, vui lòng đợi trong giây lát.');
      return;
    }
    final question = _part2.followUps[_followUpIndex];
    final canContinue = await _ensureAnswered(
      emptyMessage:
          'Bạn chưa trả lời câu hỏi phụ này. Nếu bỏ qua, câu trả lời sẽ được '
          'tính 0 điểm. Bạn vẫn muốn tiếp tục?',
    );
    if (!canContinue || !mounted) return;

    _followUpQa.add({
      'question': question,
      'answer': _answerController.text.trim(),
    });
    _answerController.clear();
    _notifyPayload();

    if (_followUpIndex < _part2.followUps.length - 1) {
      setState(() {
        _followUpIndex++;
        _micError = null;
      });
      _askFollowUpQuestion();
    } else {
      _startPart3();
    }
  }

  void _startPart3() {
    _prepTimer?.cancel();
    _speakTimer?.cancel();
    _speakTimer = null;
    if (_part3Questions.isEmpty) {
      _finishTest();
      return;
    }
    setState(() {
      _phase = _SpeakingPhase.part3;
      _part3Index = 0;
      _micError = null;
    });
    _answerController.clear();
    unawaited(_voice.speak(_part3Intro()));
  }

  String _part3Intro() {
    final question = _part3Questions[_part3Index];
    return 'Thank you. We will now move on to Part 3, where I will ask you a '
        'few more general questions. $question';
  }

  Future<void> _nextPart3Question() async {
    if (_isTranscribing || _isStartingMic) {
      _showSnack('Đang xử lý câu trả lời, vui lòng đợi trong giây lát.');
      return;
    }
    final question = _part3Questions[_part3Index];
    final canContinue = await _ensureAnswered(
      emptyMessage:
          'Bạn chưa trả lời câu hỏi Part 3 này. Nếu bỏ qua, câu trả lời sẽ '
          'được tính 0 điểm. Bạn vẫn muốn tiếp tục?',
    );
    if (!canContinue || !mounted) return;

    _part3Qa.add({
      'question': question,
      'answer': _answerController.text.trim(),
    });
    _answerController.clear();
    _notifyPayload();

    if (_part3Index < _part3Questions.length - 1) {
      setState(() {
        _part3Index++;
        _micError = null;
      });
      unawaited(_voice.speak(_part3Questions[_part3Index]));
    } else {
      _finishTest();
    }
  }

  void _notifyPayload() {
    widget.onPayloadChanged?.call({
      'part1_qa': List<Map<String, String>>.from(_part1Qa),
      'part2_answer': _part2Answer,
      'part3_qa': List<Map<String, String>>.from(_part3Qa),
      'follow_up_qa': List<Map<String, String>>.from(_followUpQa),
    });
  }

  void _finishTest() {
    if (_completedSent) return;
    _completedSent = true;

    _prepTimer?.cancel();
    _speakTimer?.cancel();
    _recordTimer?.cancel();
    if (_isRecording) {
      _isRecording = false;
      unawaited(_recorder.cancelRecording());
    }
    unawaited(_voice.stop());

    if (mounted) {
      setState(() => _phase = _SpeakingPhase.finished);
    }

    _notifyPayload();
    widget.onCompleted(
      List<Map<String, String>>.from(_part1Qa),
      _part2Answer,
      List<Map<String, String>>.from(_part3Qa),
      List<Map<String, String>>.from(_followUpQa),
    );
  }

  Future<bool> _ensureAnswered({required String emptyMessage}) async {
    if (_isRecording) {
      await _stopRecording();
    } else if (_isTranscribing) {
      await _transcribeDone?.future;
    }
    if (!mounted) return false;
    if (_isTranscribing) {
      _showSnack('Đang nhận diện câu trả lời, vui lòng đợi trong giây lát.');
      return false;
    }
    if (_answerController.text.trim().isEmpty) {
      return _confirmSkip(emptyMessage);
    }
    return true;
  }

  // ── Microphone & transcription ──────────────────────────

  Future<void> _handleMicTap() async {
    if (_isTranscribing || _isStartingMic) return;
    if (_isRecording) {
      await _stopRecording();
      return;
    }
    final started = await _startRecording();
    if (!mounted || !started) return;
    if (_phase == _SpeakingPhase.part2Speak) {
      _startPart2Countdown();
    }
  }

  Future<bool> _startRecording() async {
    if (_isRecording || _isTranscribing || _isStartingMic) return false;
    setState(() {
      _isStartingMic = true;
      _micError = null;
    });

    try {
      final granted = await _recorder.hasPermission();
      if (!granted) {
        _failMic(
          'Chưa được cấp quyền micro. Hãy cho phép micro trong trình duyệt hoặc '
          'cài đặt hệ thống rồi bấm "Thử lại".',
        );
        return false;
      }

      // Do not capture the examiner's voice.
      await _voice.stop();
      await _recorder.startRecording();
      if (!mounted) return false;
      // The flow may have moved on while the permission prompt was open.
      if (_completedSent ||
          _phase == _SpeakingPhase.part2FollowUp ||
          _phase == _SpeakingPhase.part3 ||
          _phase == _SpeakingPhase.finished) {
        await _recorder.cancelRecording();
        if (mounted) setState(() => _isStartingMic = false);
        return false;
      }

      setState(() {
        _isStartingMic = false;
        _isRecording = true;
        _recordSeconds = 0;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isRecording) {
          timer.cancel();
          return;
        }
        setState(() => _recordSeconds++);
      });
      return true;
    } catch (error) {
      debugPrint('Start recording error: $error');
      _failMic(
        'Không thể bật micro. Hãy kiểm tra thiết bị và quyền truy cập rồi thử lại.',
      );
      return false;
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      if (_isTranscribing) {
        await _transcribeDone?.future;
      }
      return;
    }

    _recordTimer?.cancel();
    _recordTimer = null;
    final done = Completer<void>();
    _transcribeDone = done;

    setState(() {
      _isRecording = false;
      _isTranscribing = true;
      _micError = null;
    });

    Uint8List? bytes;
    try {
      bytes = await _recorder.stopRecording();
    } catch (error) {
      debugPrint('Stop recording error: $error');
    }

    var transcript = '';
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        setState(() {
          _micError =
              'Không nhận được âm thanh từ micro. Hãy kiểm tra thiết bị và thử lại.';
        });
      }
    } else {
      try {
        final dio = ref.read(dioProvider);
        final formData = FormData.fromMap({
          'audio': MultipartFile.fromBytes(
            bytes,
            filename: kIsWeb ? 'ielts_speaking.webm' : 'ielts_speaking.wav',
          ),
          'language': 'en',
        });
        final response = await dio.post<dynamic>(
          ApiEndpoints.speechTranscribe,
          data: formData,
        );
        final data = response.data;
        if (data is Map && data['transcript'] is String) {
          transcript = (data['transcript'] as String).trim();
        }
      } catch (error) {
        debugPrint('Transcribe error: $error');
        if (mounted) {
          setState(() {
            _micError = 'Không nhận diện được giọng nói. Vui lòng thử nói lại.';
          });
        }
      }
    }

    if (mounted) {
      if (transcript.isNotEmpty) {
        final current = _answerController.text.trim();
        final merged = current.isEmpty ? transcript : '$current $transcript';
        _answerController.value = TextEditingValue(
          text: merged,
          selection: TextSelection.collapsed(offset: merged.length),
        );
        _showSnack('Đã nhận diện: "$transcript"', success: true);
      } else {
        _micError ??= 'Chưa nghe rõ câu trả lời. Hãy nói to hơn và thử lại.';
      }
      setState(() => _isTranscribing = false);
    }

    if (!done.isCompleted) done.complete();
    if (identical(_transcribeDone, done)) _transcribeDone = null;
  }

  void _failMic(String message) {
    _recordTimer?.cancel();
    _recordTimer = null;
    if (mounted) {
      setState(() {
        _isStartingMic = false;
        _isRecording = false;
        _micError = message;
      });
    }
    _showSnack(message);
  }

  // ── Helpers ─────────────────────────────────────────────

  void _replay(String key, String text) {
    if (widget.strict && _replayUsed.contains(key)) {
      _showSnack('Chế độ thi thật chỉ cho phép nghe lại câu hỏi một lần.');
      return;
    }
    if (widget.strict) _replayUsed.add(key);
    unawaited(_voice.speak(text));
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: success ? AppColors.success : null,
        ),
      );
  }

  Future<bool> _confirmSkip(String message) async {
    final palette = context.palette;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 26,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chưa có câu trả lời',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Quay lại trả lời'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Bỏ qua (0 điểm)',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static String _formatSeconds(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final rest = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')}';
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_phase != _SpeakingPhase.intro) ...[
                    _buildProgressHeader(context),
                    const SizedBox(height: 16),
                  ],
                  _buildPhaseBody(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseBody(BuildContext context) {
    switch (_phase) {
      case _SpeakingPhase.intro:
        return _buildIntro(context);
      case _SpeakingPhase.part1:
        return _buildPart1(context);
      case _SpeakingPhase.part2Prep:
        return _buildPart2Prep(context);
      case _SpeakingPhase.part2Speak:
        return _buildPart2Speak(context);
      case _SpeakingPhase.part2FollowUp:
        return _buildPart2FollowUp(context);
      case _SpeakingPhase.part3:
        return _buildPart3(context);
      case _SpeakingPhase.finished:
        return _buildFinished(context);
    }
  }

  Widget _buildProgressHeader(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.speaking.withOpacity(0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.record_voice_over_rounded,
                color: AppColors.speaking,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IELTS Speaking',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _phaseTitle,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: (widget.strict ? AppColors.error : AppColors.success)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.strict ? 'Thi thật' : 'Luyện tập',
                style: TextStyle(
                  color: widget.strict ? AppColors.error : AppColors.success,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            backgroundColor: palette.divider,
            color: AppColors.speaking,
          ),
        ),
      ],
    );
  }

  String get _phaseTitle {
    switch (_phase) {
      case _SpeakingPhase.intro:
        return 'Giới thiệu';
      case _SpeakingPhase.part1:
        return 'Part 1 · Hỏi đáp cá nhân';
      case _SpeakingPhase.part2Prep:
        return 'Part 2 · Chuẩn bị 1 phút';
      case _SpeakingPhase.part2Speak:
        return 'Part 2 · Độc thoại 2 phút';
      case _SpeakingPhase.part2FollowUp:
        return 'Part 2 · Câu hỏi phụ';
      case _SpeakingPhase.part3:
        return 'Part 3 · Thảo luận';
      case _SpeakingPhase.finished:
        return 'Hoàn thành';
    }
  }

  double get _progress {
    final part1Total = _part1Questions.isEmpty ? 1 : _part1Questions.length;
    final part3Total = _part3Questions.isEmpty ? 1 : _part3Questions.length;
    switch (_phase) {
      case _SpeakingPhase.intro:
        return 0;
      case _SpeakingPhase.part1:
        return 0.05 + 0.45 * (_part1Index / part1Total);
      case _SpeakingPhase.part2Prep:
        return 0.52;
      case _SpeakingPhase.part2Speak:
        return 0.6;
      case _SpeakingPhase.part2FollowUp:
        return 0.72;
      case _SpeakingPhase.part3:
        return 0.78 + 0.22 * (_part3Index / part3Total);
      case _SpeakingPhase.finished:
        return 1;
    }
  }

  // ── Intro ───────────────────────────────────────────────

  Widget _buildIntro(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Bài thi Speaking gồm 3 phần, kéo dài khoảng 11–14 phút. Giám khảo đọc '
          'câu hỏi bằng tiếng Anh và bạn trả lời bằng micro.',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.speaking,
                        width: 2.5,
                      ),
                    ),
                    child: const Center(
                      child: Text('👩‍🏫', style: TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Examiner Emma',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'IELTS Speaking Examiner',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Good morning. My name is Emma and I will be your examiner '
                'today. This test has three parts. In Part 1, I will ask you '
                'some questions about familiar topics. In Part 2, you will have '
                'one minute to prepare, and then you will speak for up to two '
                'minutes. In Part 3, we will discuss some more general '
                'questions. Do you understand? Let us begin.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildIntroPartCard(
          context,
          number: '1',
          title: 'Part 1 · Hỏi đáp cá nhân',
          description:
              '${_part1Questions.length} câu hỏi về các chủ đề quen thuộc. '
              'Trả lời ngắn gọn, tự nhiên.',
          color: AppColors.secondary,
        ),
        const SizedBox(height: 10),
        _buildIntroPartCard(
          context,
          number: '2',
          title: 'Part 2 · Cue Card',
          description:
              '${_part2.prepSeconds}s chuẩn bị với giấy nháp, sau đó nói liên '
              'tục ${_part2.speakSeconds}s và trả lời '
              '${_part2.followUps.length} câu hỏi phụ.',
          color: AppColors.accent,
        ),
        const SizedBox(height: 10),
        _buildIntroPartCard(
          context,
          number: '3',
          title: 'Part 3 · Thảo luận',
          description:
              '${_part3Questions.length} câu hỏi phân tích, mở rộng quan điểm '
              'liên quan đến chủ đề Part 2.',
          color: AppColors.speaking,
        ),
        const SizedBox(height: 16),
        _buildModeNotice(context),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _startTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.speaking,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.mic_rounded, size: 20),
            label: const Text(
              'Bắt đầu bài thi Speaking',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntroPartCard(
    BuildContext context, {
    required String number,
    required String title,
    required String description,
    required Color color,
  }) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeNotice(BuildContext context) {
    final palette = context.palette;
    final color = widget.strict ? AppColors.error : AppColors.success;
    final text = widget.strict
        ? 'Chế độ thi thật: bạn phải trả lời bằng micro, không được gõ văn bản. '
            'Mỗi câu hỏi chỉ được nghe lại một lần.'
        : 'Chế độ luyện tập: bạn có thể gõ câu trả lời dự phòng và nghe lại câu '
            'hỏi không giới hạn.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            widget.strict ? Icons.lock_outline_rounded : Icons.school_outlined,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Part 1 / Part 3 question views ──────────────────────

  Widget _buildPart1(BuildContext context) {
    if (_part1Questions.isEmpty) {
      return _buildEmptyState(context, 'Phần 1 chưa có câu hỏi.');
    }
    final index = _part1Index.clamp(0, _part1Questions.length - 1);
    final item = _part1Questions[index];
    return _buildOralQuestion(
      context,
      eyebrow: 'PART 1 · CÂU HỎI ${index + 1}/${_part1Questions.length}',
      topic: item.topic,
      question: item.text,
      accent: AppColors.secondary,
      helper:
          'Trả lời 2–4 câu, tập trung vào độ trôi chảy. Giám khảo đang kiểm '
          'tra phản xạ và vốn từ của bạn.',
      replayKey: 'p1-$index',
      onNext: _nextPart1Question,
      nextLabel:
          index < _part1Questions.length - 1 ? 'Câu tiếp theo' : 'Sang Part 2',
    );
  }

  Widget _buildPart3(BuildContext context) {
    if (_part3Questions.isEmpty) {
      return _buildEmptyState(context, 'Phần 3 chưa có câu hỏi.');
    }
    final index = _part3Index.clamp(0, _part3Questions.length - 1);
    return _buildOralQuestion(
      context,
      eyebrow: 'PART 3 · CÂU HỎI ${index + 1}/${_part3Questions.length}',
      question: _part3Questions[index],
      accent: AppColors.speaking,
      helper:
          'Đưa ra quan điểm, lý do và ví dụ. Đây là phần thể hiện khả năng lập '
          'luận và từ vựng học thuật.',
      replayKey: 'p3-$index',
      onNext: _nextPart3Question,
      nextLabel: index < _part3Questions.length - 1
          ? 'Câu tiếp theo'
          : 'Hoàn thành bài thi',
    );
  }

  Widget _buildPart2FollowUp(BuildContext context) {
    final followUps = _part2.followUps;
    if (followUps.isEmpty) {
      return _buildEmptyState(context, 'Part 2 chưa có câu hỏi phụ.');
    }
    final index = _followUpIndex.clamp(0, followUps.length - 1);
    return _buildOralQuestion(
      context,
      eyebrow: 'PART 2 · CÂU HỎI PHỤ ${index + 1}/${followUps.length}',
      question: followUps[index],
      accent: AppColors.accent,
      helper: 'Trả lời ngắn, nối tiếp chủ đề bạn vừa trình bày ở Part 2.',
      replayKey: 'fu-$index',
      onNext: _nextFollowUpQuestion,
      nextLabel: index < followUps.length - 1 ? 'Câu tiếp theo' : 'Sang Part 3',
    );
  }

  Widget _buildOralQuestion(
    BuildContext context, {
    required String eyebrow,
    required String question,
    required Color accent,
    required String replayKey,
    required Future<void> Function() onNext,
    required String nextLabel,
    String? topic,
    String? helper,
  }) {
    final palette = context.palette;
    final busy = _isTranscribing || _isStartingMic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStageHeader(context, eyebrow),
        const SizedBox(height: 12),
        _buildQuestionCard(
          context,
          question: question,
          accent: accent,
          topic: topic,
          replayKey: replayKey,
        ),
        if (helper != null) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 14,
                color: palette.textHint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  helper,
                  style: TextStyle(
                    color: palette.textHint,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _buildAnswerPanel(context, accent: accent),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_answerController.text.trim().isNotEmpty)
              TextButton.icon(
                onPressed: busy || _isRecording
                    ? null
                    : () {
                        _answerController.clear();
                        setState(() => _micError = null);
                      },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Làm lại',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: busy ? null : () => unawaited(onNext()),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                busy ? 'Đang xử lý...' : nextLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestionCard(
    BuildContext context, {
    required String question,
    required Color accent,
    required String replayKey,
    String? topic,
  }) {
    final palette = context.palette;
    final replayLocked = widget.strict && _replayUsed.contains(replayKey);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.45), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 16,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('👩‍🏫', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Examiner Emma',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (topic != null && topic.trim().isNotEmpty)
                      Text(
                        'Chủ đề: $topic',
                        style: TextStyle(
                          color: palette.textHint,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _replay(replayKey, question),
                tooltip:
                    replayLocked ? 'Đã dùng lượt nghe lại' : 'Nghe lại câu hỏi',
                icon: Icon(
                  Icons.volume_up_rounded,
                  color: replayLocked ? palette.textHint : accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Answer panel (mic + transcript) ─────────────────────

  Widget _buildAnswerPanel(
    BuildContext context, {
    required Color accent,
    bool showMicControls = true,
  }) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Câu trả lời của bạn',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: (widget.strict ? AppColors.error : AppColors.success)
                      .withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.strict ? 'Chỉ dùng micro' : 'Nói hoặc gõ',
                  style: TextStyle(
                    color: widget.strict ? AppColors.error : AppColors.success,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (showMicControls) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _buildMicButton(context, accent: accent),
                const SizedBox(width: 14),
                Expanded(child: _buildMicStatus(context, accent: accent)),
              ],
            ),
          ],
          if (_micError != null) ...[
            const SizedBox(height: 12),
            _buildMicError(context),
          ],
          const SizedBox(height: 12),
          _buildTranscriptField(context, accent: accent),
        ],
      ),
    );
  }

  Widget _buildMicButton(BuildContext context, {required Color accent}) {
    final palette = context.palette;
    final recording = _isRecording;
    final busy = _isTranscribing || _isStartingMic;

    return Material(
      color: recording
          ? AppColors.error
          : busy
              ? palette.divider
              : accent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : () => unawaited(_handleMicTap()),
        child: SizedBox(
          width: 62,
          height: 62,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    recording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMicStatus(BuildContext context, {required Color accent}) {
    final palette = context.palette;
    final String title;
    final String subtitle;
    final Color color;

    if (_isRecording) {
      title = 'Đang ghi âm · ${_formatSeconds(_recordSeconds)}';
      subtitle = 'Bấm nút đỏ để dừng và nhận diện câu trả lời.';
      color = AppColors.error;
    } else if (_isTranscribing) {
      title = 'Đang nhận diện giọng nói...';
      subtitle = 'Quá trình này thường mất vài giây.';
      color = accent;
    } else if (_isStartingMic) {
      title = 'Đang bật micro...';
      subtitle = 'Hãy cho phép trình duyệt sử dụng micro nếu được hỏi.';
      color = accent;
    } else {
      title = 'Bấm micro để trả lời';
      subtitle = widget.strict
          ? 'Bạn phải nói câu trả lời, không thể gõ văn bản ở chế độ thi thật.'
          : 'Bạn có thể nói qua micro hoặc gõ câu trả lời bên dưới.';
      color = palette.textPrimary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_isRecording)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            if (_isRecording) const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildMicError(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.error.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.mic_off_rounded,
              size: 16,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _micError ?? '',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            onPressed:
                _isTranscribing ? null : () => unawaited(_handleMicTap()),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Thử lại', style: TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptField(
    BuildContext context, {
    required Color accent,
  }) {
    final palette = context.palette;

    if (widget.strict) {
      final text = _answerController.text.trim();
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.divider),
        ),
        child: text.isEmpty
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 17,
                    color: palette.textHint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Câu trả lời sẽ xuất hiện ở đây sau khi bạn nói. Chế độ thi '
                      'thật không cho phép gõ văn bản.',
                      style: TextStyle(
                        color: palette.textHint,
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              )
            : SelectableText(
                text,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
      );
    }

    return TextField(
      controller: _answerController,
      onChanged: (_) => setState(() {}),
      minLines: 3,
      maxLines: 6,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: 13,
        height: 1.55,
      ),
      decoration: InputDecoration(
        hintText:
            'Bạn có thể nói qua micro hoặc gõ câu trả lời ở đây (chế độ luyện '
            'tập).',
        hintStyle: TextStyle(
          color: palette.textHint,
          fontSize: 12,
          height: 1.5,
        ),
        filled: true,
        fillColor: palette.background,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
      ),
    );
  }

  // ── Part 2 ──────────────────────────────────────────────

  Widget _buildPart2Prep(BuildContext context) {
    final palette = context.palette;
    final prepSeconds = _part2.prepSeconds > 0 ? _part2.prepSeconds : 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStageHeader(
          context,
          'PART 2 · CHUẨN BỊ ${prepSeconds}s',
          note: 'Nói ${_part2.speakSeconds}s',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.divider),
          ),
          child: Row(
            children: [
              _buildCountdownRing(
                context,
                seconds: _prepRemaining,
                total: prepSeconds,
                color: AppColors.speaking,
                caption: 'giây',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chuẩn bị ý tưởng',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ghi từ khóa vào khung bên dưới. Phần ghi chú không được '
                      'nộp và không ảnh hưởng đến điểm.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildCueCard(context),
        const SizedBox(height: 14),
        TextField(
          controller: _notesController,
          minLines: 3,
          maxLines: 5,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 12.5,
            height: 1.5,
          ),
          decoration: InputDecoration(
            labelText: 'Ghi chú nháp',
            labelStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
            hintText: 'Từ khóa, ý chính, cấu trúc câu...',
            hintStyle: TextStyle(color: palette.textHint, fontSize: 12),
            filled: true,
            fillColor: palette.card,
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.speaking,
                width: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _startPart2Speak,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text(
              'Sẵn sàng nói ngay',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Khi hết giờ chuẩn bị, hệ thống tự chuyển sang phần nói và bật micro.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textHint, fontSize: 10.5),
        ),
      ],
    );
  }

  Widget _buildPart2Speak(BuildContext context) {
    final palette = context.palette;
    final speakSeconds = _part2.speakSeconds > 0 ? _part2.speakSeconds : 120;
    final recording = _isRecording;
    final busy = _isTranscribing || _isStartingMic;

    final String status;
    final Color statusColor;
    if (recording) {
      status = 'Đang ghi âm bài nói';
      statusColor = AppColors.error;
    } else if (_isTranscribing) {
      status = 'Đang nhận diện bài nói...';
      statusColor = AppColors.speaking;
    } else if (_isStartingMic) {
      status = 'Đang bật micro...';
      statusColor = AppColors.speaking;
    } else {
      status = 'Chưa ghi âm';
      statusColor = palette.textSecondary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStageHeader(context, 'PART 2 · ĐỘC THOẠI ${speakSeconds}s'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: recording ? AppColors.error.withOpacity(0.07) : palette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: recording
                  ? AppColors.error.withOpacity(0.35)
                  : palette.divider,
            ),
          ),
          child: Row(
            children: [
              _buildCountdownRing(
                context,
                seconds: _speakRemaining,
                total: speakSeconds,
                color: recording ? AppColors.error : AppColors.speaking,
                caption: 'còn lại',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (recording)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (recording) const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      recording
                          ? 'Đã ghi ${_formatSeconds(_recordSeconds)}. Hệ thống tự '
                              'dừng và lưu khi hết giờ.'
                          : 'Nói liên tục đến khi hết giờ. Bạn có thể dừng sớm '
                              'nếu đã hoàn thành.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildCueCard(context, compact: true),
        if (_notesController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: 14,
                      color: palette.textHint,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Ghi chú của bạn',
                      style: TextStyle(
                        color: palette.textHint,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _notesController.text.trim(),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _buildAnswerPanel(
          context,
          accent: AppColors.speaking,
          showMicControls: false,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            if (recording)
              OutlinedButton.icon(
                onPressed: busy ? null : () => unawaited(_handleMicTap()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withOpacity(0.6)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text(
                  'Dừng & nhận diện',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            if (!recording && !busy)
              OutlinedButton.icon(
                onPressed: () => unawaited(_handleMicTap()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.speaking,
                  side: BorderSide(
                    color: AppColors.speaking.withOpacity(0.6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.mic_rounded, size: 18),
                label: Text(
                  _speakRemaining < speakSeconds
                      ? 'Ghi âm tiếp'
                      : 'Bắt đầu nói',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed:
                  busy ? null : () => unawaited(_finishPart2Speak(auto: false)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                'Hoàn tất Part 2',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCueCard(BuildContext context, {bool compact = false}) {
    final palette = context.palette;
    final prompts = _part2.prompts;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.45),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              const Text(
                'CUE CARD',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${_part2.prepSeconds}s chuẩn bị · ${_part2.speakSeconds}s nói',
                style: TextStyle(color: palette.textHint, fontSize: 9.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _part2.cueCard,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: compact ? 14.5 : 15.5,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (prompts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'You should say:',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            for (final prompt in prompts)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        prompt,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 12.5,
                          height: 1.4,
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
  }

  Widget _buildCountdownRing(
    BuildContext context, {
    required int seconds,
    required int total,
    required Color color,
    required String caption,
  }) {
    final palette = context.palette;
    final value = total <= 0 ? 0.0 : (seconds / total).clamp(0.0, 1.0);
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 7,
              backgroundColor: palette.divider,
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatSeconds(seconds),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                caption,
                style: TextStyle(color: palette.textHint, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shared bits ─────────────────────────────────────────

  Widget _buildStageHeader(
    BuildContext context,
    String label, {
    String? note,
  }) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 3,
          height: 15,
          decoration: BoxDecoration(
            color: AppColors.speaking,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ),
        if (note != null)
          Text(
            note,
            style: TextStyle(color: palette.textHint, fontSize: 10),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.record_voice_over_outlined,
            size: 40,
            color: palette.textHint,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFinished(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Đã hoàn thành bài Speaking',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đang nộp câu trả lời và tổng hợp kết quả...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.speaking,
            ),
          ),
        ],
      ),
    );
  }
}
