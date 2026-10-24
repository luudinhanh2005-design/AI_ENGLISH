import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/speech_service.dart';
import '../../data/models/pronunciation_models.dart';
import '../providers/pronunciation_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PRACTICE SCREEN  (4 giai đoạn: ready → recording → analyzing → result)
// ─────────────────────────────────────────────────────────────────────────────
class PronunciationPracticeScreen extends ConsumerStatefulWidget {
  const PronunciationPracticeScreen({super.key});

  @override
  ConsumerState<PronunciationPracticeScreen> createState() =>
      _PronunciationPracticeScreenState();
}

class _PronunciationPracticeScreenState
    extends ConsumerState<PronunciationPracticeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _scoreCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _scoreAnim;

  Timer? _recordTimer;
  static const int _maxRecordSeconds = 15;

  // Reference audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, String> _ttsCache = {};
  bool _isPlayingReference = false;
  bool _referenceFailed = false;
  bool _isStartingRecording = false;
  bool _isStoppingRecording = false;
  int _playSession = 0;
  int _referenceRepeatTotal = 0;
  int _referenceRepeatIndex = 0;
  String? _referenceUrl;
  StreamSubscription<void>? _referenceCompleteSub;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _scoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _scoreAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOutCubic),
    );

    // Warm the TTS URL cache so choosing a listen count can start playback
    // immediately, without a network round-trip after the tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prefetchReference());
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _scoreCtrl.dispose();
    _recordTimer?.cancel();
    _playSession++;
    _referenceCompleteSub?.cancel();
    _referenceCompleteSub = null;
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    _recordTimer?.cancel();
    unawaited(_audioPlayer.stop());
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(pronunciationProvider.notifier).tickRecordDuration();
      final dur = ref.read(pronunciationProvider).recordDuration;
      if (dur >= _maxRecordSeconds) {
        _stopAndAssess();
      }
    });
  }

  void _stopTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
  }

  Future<void> _startRecording() async {
    if (_isStartingRecording) return;
    _isStartingRecording = true;
    try {
      await _stopReference();
      await ref.read(pronunciationProvider.notifier).startRecording();
      if (!mounted) return;
      if (ref.read(pronunciationProvider).phase ==
          PronunciationPhase.recording) {
        _startTimer();
      }
    } finally {
      _isStartingRecording = false;
    }
  }

  Future<void> _stopAndAssess() async {
    if (_isStoppingRecording) return;
    _isStoppingRecording = true;
    try {
      _stopTimer();
      await ref.read(pronunciationProvider.notifier).stopAndAssess();
      if (!mounted) return;
      if (ref.read(pronunciationProvider).phase == PronunciationPhase.result) {
        _scoreCtrl.forward(from: 0);
      }
    } finally {
      _isStoppingRecording = false;
    }
  }

  Future<void> _cancelRecording() async {
    _stopTimer();
    await ref.read(pronunciationProvider.notifier).cancelRecording();
  }

  Future<void> _stopReference() async {
    _playSession++;
    final sub = _referenceCompleteSub;
    _referenceCompleteSub = null;
    _referenceRepeatTotal = 0;
    _referenceRepeatIndex = 0;
    _referenceUrl = null;
    try {
      await sub?.cancel();
    } catch (_) {}
    SpeechService.stop();
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isPlayingReference = false;
      _referenceFailed = false;
    });
  }

  Future<void> _playReference() async {
    if (_isPlayingReference) {
      await _stopReference();
      return;
    }

    final provider = ref.read(pronunciationProvider);
    final sentence = provider.currentSentence;
    if (sentence == null || provider.isPlayingTTS) return;

    final notifier = ref.read(pronunciationProvider.notifier);
    final cacheKey =
        '${sentence.text}|${provider.voiceId}|${provider.speechSpeed}';
    final session = ++_playSession;

    // Stop any previous sample and any browser speech before starting.
    final previousSub = _referenceCompleteSub;
    _referenceCompleteSub = null;
    try {
      await previousSub?.cancel();
    } catch (_) {}
    SpeechService.stop();
    try {
      await _audioPlayer.stop();
    } catch (_) {}

    if (!mounted || session != _playSession) return;
    setState(() {
      _isPlayingReference = true;
      _referenceFailed = false;
      _referenceRepeatTotal = provider.listenCount;
      _referenceRepeatIndex = 1;
    });

    String? url;
    try {
      url = _ttsCache[cacheKey];
      url ??= await notifier.getReferenceTTSUrl(
        sentence.text,
        voice: provider.voiceId,
        speed: provider.speechSpeed,
      );
    } catch (_) {
      _ttsCache.remove(cacheKey);
      url = null;
    }

    if (!mounted || session != _playSession) return;

    if (url == null || url.isEmpty) {
      await _handleReferenceFailure(session);
      return;
    }

    _ttsCache[cacheKey] = url;
    _referenceUrl = url;

    // Subscribe before play so a very short sample cannot finish first.
    _referenceCompleteSub = _audioPlayer.onPlayerComplete.listen(
      (_) => _handleReferenceCompleted(session),
      onError: (_) => unawaited(_handleReferenceFailure(session)),
      cancelOnError: true,
    );

    try {
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {
      _ttsCache.remove(cacheKey);
      await _handleReferenceFailure(session);
    }
  }

  void _handleReferenceCompleted(int session) {
    if (session != _playSession || !mounted) return;

    if (_referenceRepeatIndex < _referenceRepeatTotal) {
      setState(() => _referenceRepeatIndex++);
      unawaited(_playNextReference(session));
      return;
    }

    final sub = _referenceCompleteSub;
    _referenceCompleteSub = null;
    if (sub != null) unawaited(sub.cancel());
    _referenceRepeatTotal = 0;
    _referenceRepeatIndex = 0;
    _referenceUrl = null;
    if (!mounted) return;
    setState(() {
      _isPlayingReference = false;
      _referenceFailed = false;
    });
  }

  Future<void> _playNextReference(int session) async {
    final url = _referenceUrl;
    if (url == null || session != _playSession) return;
    try {
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {
      await _handleReferenceFailure(session);
    }
  }

  Future<void> _prefetchReference() async {
    final provider = ref.read(pronunciationProvider);
    final sentence = provider.currentSentence;
    if (sentence == null) return;

    final cacheKey =
        '${sentence.text}|${provider.voiceId}|${provider.speechSpeed}';
    if (_ttsCache.containsKey(cacheKey)) return;

    final url =
        await ref.read(pronunciationProvider.notifier).getReferenceTTSUrl(
              sentence.text,
              voice: provider.voiceId,
              speed: provider.speechSpeed,
              showLoading: false,
            );
    if (!mounted || url == null || url.isEmpty) return;

    // The user may have changed sentence/voice/speed while we were waiting.
    final latest = ref.read(pronunciationProvider);
    final latestSentence = latest.currentSentence;
    final latestKey = latestSentence == null
        ? null
        : '${latestSentence.text}|${latest.voiceId}|${latest.speechSpeed}';
    if (latestKey == cacheKey) {
      _ttsCache[cacheKey] = url;
    }
  }

  Future<void> _handleReferenceFailure(int session) async {
    if (session != _playSession) return;
    final failureSession = ++_playSession;
    final sub = _referenceCompleteSub;
    _referenceCompleteSub = null;
    _referenceRepeatTotal = 0;
    _referenceRepeatIndex = 0;
    _referenceUrl = null;
    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    if (!mounted || failureSession != _playSession) return;
    setState(() {
      _isPlayingReference = false;
      _referenceFailed = true;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Không phát được audio mẫu. Kiểm tra backend rồi bấm Nghe lại.',
          ),
        ),
      );
  }

  Future<void> _selectVoice(String voiceId) async {
    await _stopReference();
    if (!mounted) return;
    ref.read(pronunciationProvider.notifier).setVoice(voiceId);
    unawaited(_prefetchReference());
  }

  Future<void> _selectSpeed(double speed) async {
    await _stopReference();
    if (!mounted) return;
    ref.read(pronunciationProvider.notifier).setSpeechSpeed(speed);
    unawaited(_prefetchReference());
  }

  Future<void> _selectListenCount(int count) async {
    await _stopReference();
    if (!mounted) return;
    ref.read(pronunciationProvider.notifier).setListenCount(count);
    await _playReference();
  }

  Future<void> _restartSession() async {
    await _stopReference();
    if (!mounted) return;
    _scoreCtrl.reset();
    ref.read(pronunciationProvider.notifier).restartSession();
  }

  Future<void> _goToNextSentence() async {
    await _stopReference();
    if (!mounted) return;
    _scoreCtrl.reset();
    _ttsCache.clear();
    ref.read(pronunciationProvider.notifier).nextRandomSentence();
    unawaited(_prefetchReference());
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ───────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pronunciationProvider);
    final sentence = state.currentSentence;

    if (sentence == null) {
      return Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(
          backgroundColor: context.palette.surface,
          foregroundColor: context.palette.textPrimary,
          title: const Text('Luyện phát âm'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_off_rounded,
                  size: 64, color: context.palette.textSecondary),
              const SizedBox(height: 16),
              Text(
                'Chưa chọn câu luyện tập.\nVui lòng quay lại và chọn câu.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: context.palette.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(sentence, state),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _buildPhaseContent(state, sentence),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── TOP BAR ─────────
  Widget _buildTopBar(
      PracticeSentenceModel sentence, PronunciationState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(bottom: BorderSide(color: context.palette.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: context.palette.textPrimary),
            onPressed: () async {
              _stopTimer();
              if (ref.read(pronunciationProvider).phase ==
                  PronunciationPhase.recording) {
                await ref
                    .read(pronunciationProvider.notifier)
                    .cancelRecording();
              }
              await _stopReference();
              if (mounted) context.pop();
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Luyện phát âm',
                  style: AppTextStyles.labelLarge.copyWith(
                      color: context.palette.textPrimary,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  '${sentence.level} • ${sentence.topic}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
          // Phase indicator
          _buildPhaseChip(state.phase),
        ],
      ),
    );
  }

  Widget _buildPhaseChip(PronunciationPhase phase) {
    final labels = {
      PronunciationPhase.ready: ('Sẵn sàng', AppColors.secondary),
      PronunciationPhase.recording: ('Đang ghi', AppColors.error),
      PronunciationPhase.analyzing: ('Phân tích', AppColors.warning),
      PronunciationPhase.result: ('Kết quả', AppColors.success),
    };
    final (label, color) = labels[phase]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(label,
          style: AppTextStyles.labelSmall
              .copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }

  // ───────── PHASE CONTENT ─────────
  Widget _buildPhaseContent(
      PronunciationState state, PracticeSentenceModel sentence) {
    switch (state.phase) {
      case PronunciationPhase.ready:
        return _buildReadyPhase(sentence, state, key: const ValueKey('ready'));
      case PronunciationPhase.recording:
        return _buildRecordingPhase(state, sentence,
            key: const ValueKey('recording'));
      case PronunciationPhase.analyzing:
        return _buildAnalyzingPhase(key: const ValueKey('analyzing'));
      case PronunciationPhase.result:
        return _buildResultPhase(state, sentence,
            key: const ValueKey('result'));
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // GIAI ĐOẠN 1: READY
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildReadyPhase(
    PracticeSentenceModel sentence,
    PronunciationState state, {
    required Key key,
  }) {
    final needsRetry = state.errorMessage?.contains('Chưa nghe rõ') ?? false;
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // Sentence card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.palette.card, context.palette.cardLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Câu cần đọc',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Main sentence
                Text(
                  sentence.text,
                  style: AppTextStyles.h3.copyWith(
                    color: context.palette.textPrimary,
                    height: 1.5,
                    letterSpacing: 0.3,
                  ),
                ),

                // IPA
                if (sentence.ipaTranscription.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    sentence.ipaTranscription,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.secondary,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],

                // Tip
                if (sentence.tipVi != null && sentence.tipVi!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_rounded,
                            color: AppColors.warning, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sentence.tipVi!,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: context.palette.textSecondary,
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
          ),

          const SizedBox(height: 20),

          // Speech settings
          _buildSpeechSettings(state),

          const SizedBox(height: 16),

          // Error message
          if (state.errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),

          // Buttons
          Row(
            children: [
              // Nghe phát âm chuẩn
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('btn_listen_reference'),
                  onPressed: state.isPlayingTTS ? null : _playReference,
                  icon: Icon(
                    state.isPlayingTTS
                        ? Icons.hourglass_top_rounded
                        : _isPlayingReference
                            ? Icons.stop_circle_outlined
                            : _referenceFailed
                                ? Icons.replay_rounded
                                : Icons.volume_up_rounded,
                    size: 20,
                  ),
                  label: Text(
                    state.isPlayingTTS
                        ? 'Đang tải...'
                        : _isPlayingReference
                            ? 'Dừng'
                            : _referenceFailed
                                ? 'Nghe lại'
                                : state.listenCount > 1
                                    ? 'Nghe mẫu ×${state.listenCount}'
                                    : 'Nghe mẫu',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bắt đầu đọc (không còn animation pulse)
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  key: const Key('btn_start_recording'),
                  onPressed: _startRecording,
                  icon: const Icon(Icons.mic_rounded, size: 22),
                  label: Text(
                    needsRetry ? 'Đọc lại' : 'Bắt đầu đọc',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),

          if (_isPlayingReference && !state.isPlayingTTS) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                _referenceRepeatTotal > 1
                    ? 'Đang phát mẫu $_referenceRepeatIndex/$_referenceRepeatTotal'
                    : 'Đang phát mẫu...',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Center(
            child: Text(
              '🎯 Đọc to, rõ ràng và tự nhiên nhất có thể',
              style: AppTextStyles.labelSmall
                  .copyWith(color: context.palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechSettings(PronunciationState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  size: 19, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Tùy chỉnh giọng đọc',
                style: AppTextStyles.labelMedium.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Giọng đọc',
            style: AppTextStyles.labelSmall
                .copyWith(color: context.palette.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSettingChip(
                'Sarah • US nữ',
                state.voiceId == 'sarah',
                () => _selectVoice('sarah'),
              ),
              _buildSettingChip(
                'Harrison • US nam',
                state.voiceId == 'harrison',
                () => _selectVoice('harrison'),
              ),
              _buildSettingChip(
                'Emma • UK nữ',
                state.voiceId == 'emma',
                () => _selectVoice('emma'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Tốc độ đọc',
            style: AppTextStyles.labelSmall
                .copyWith(color: context.palette.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final speed in const [0.75, 1.0, 1.25])
                _buildSettingChip(
                  '${speed}x',
                  (state.speechSpeed - speed).abs() < 0.001,
                  () => _selectSpeed(speed),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Số lần nghe',
            style: AppTextStyles.labelSmall
                .copyWith(color: context.palette.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final count in const [1, 2, 3])
                _buildSettingChip(
                  '$count lần',
                  state.listenCount == count,
                  () => _selectListenCount(count),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn số lần, mẫu sẽ tự phát ngay.',
            style: AppTextStyles.labelSmall
                .copyWith(color: context.palette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: AppTextStyles.labelSmall.copyWith(
        color:
            selected ? AppColors.primaryLight : context.palette.textSecondary,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      ),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      backgroundColor: context.palette.card,
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.6)
            : context.palette.divider,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // GIAI ĐOẠN 2: RECORDING
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildRecordingPhase(
    PronunciationState state,
    PracticeSentenceModel sentence, {
    required Key key,
  }) {
    final remaining = _maxRecordSeconds - state.recordDuration;
    final progress = state.recordDuration / _maxRecordSeconds;

    return LayoutBuilder(
      key: key,
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 40),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Câu cần đọc vẫn hiển thị trong lúc ghi âm
              _buildRecordingSentenceCard(sentence, state),
              const SizedBox(height: 24),

              // Waveform animation
              SizedBox(
                height: 64,
                child: AnimatedBuilder(
                  animation: _waveCtrl,
                  builder: (context, _) => CustomPaint(
                    size: const Size(double.infinity, 64),
                    painter: _WaveformPainter(_waveCtrl.value),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Mic pulse ring
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 104 * _pulseAnim.value,
                      height: 104 * _pulseAnim.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error.withValues(alpha: 0.15),
                      ),
                    ),
                    child!,
                  ],
                ),
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4757), Color(0xFFFF6B81)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.5),
                        blurRadius: 22,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mic_rounded,
                      color: Colors.white, size: 34),
                ),
              ),

              const SizedBox(height: 18),
              Text(
                'Đang thu âm...',
                style: AppTextStyles.h4.copyWith(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Còn lại $remaining giây',
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.palette.textSecondary),
              ),
              const SizedBox(height: 14),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: context.palette.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0.8 ? AppColors.error : AppColors.success,
                  ),
                  minHeight: 6,
                ),
              ),

              const SizedBox(height: 24),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  // Hủy
                  OutlinedButton.icon(
                    key: const Key('btn_cancel_recording'),
                    onPressed: _cancelRecording,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Hủy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.palette.textSecondary,
                      side: BorderSide(color: context.palette.divider),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  // Xong
                  ElevatedButton.icon(
                    key: const Key('btn_stop_recording'),
                    onPressed: _stopAndAssess,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Xong & Chấm điểm',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingSentenceCard(
      PracticeSentenceModel sentence, PronunciationState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Câu cần đọc',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sentence.text,
            style: AppTextStyles.h4.copyWith(
              color: context.palette.textPrimary,
              height: 1.45,
            ),
          ),
          if (sentence.ipaTranscription.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              sentence.ipaTranscription,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.secondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // GIAI ĐOẠN 3: ANALYZING
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildAnalyzingPhase({required Key key}) {
    return Center(
      key: key,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _waveCtrl,
            builder: (context, child) => Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                Transform.rotate(
                  angle: _waveCtrl.value * 2 * math.pi,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 3,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                  ),
                ),
                // Inner ring
                Transform.rotate(
                  angle: -_waveCtrl.value * 2 * math.pi * 0.7,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Icon
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 30),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'AI đang phân tích phát âm...',
            style: AppTextStyles.h4.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đánh giá từng âm tiết, độ lưu loát và ngữ điệu',
            style: AppTextStyles.bodySmall
                .copyWith(color: context.palette.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // GIAI ĐOẠN 4: RESULT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildResultPhase(
    PronunciationState state,
    PracticeSentenceModel sentence, {
    required Key key,
  }) {
    final result = state.result;
    if (result == null)
      return const SizedBox.shrink(key: ValueKey('no_result'));

    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: AnimatedBuilder(
        animation: _scoreAnim,
        builder: (context, child) => Opacity(
          opacity: _scoreAnim.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _scoreAnim.value)),
            child: child,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── A. Overall Score Ring ──
            _buildOverallScoreCard(result),
            const SizedBox(height: 16),

            // ── B. 4 Sub-scores ──
            _buildSubscoresCard(result),
            const SizedBox(height: 16),

            // ── C. Word-level highlights ──
            _buildWordHighlightsCard(result, sentence),
            const SizedBox(height: 16),

            // ── D. AI Feedback ──
            if (result.feedbackVi.isNotEmpty) _buildFeedbackCard(result),

            if (result.feedbackVi.isNotEmpty) const SizedBox(height: 16),

            // ── E. Actions ──
            _buildResultActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallScoreCard(PronunciationResultModel result) {
    final score = result.overallScore;
    final color = score >= 80
        ? AppColors.success
        : score >= 60
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // Score ring
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: context.palette.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: AppTextStyles.h3.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '/100',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: context.palette.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.gradeLabel,
                  style: AppTextStyles.h4.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Điểm phát âm tổng thể',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.palette.textSecondary),
                ),
                const SizedBox(height: 8),
                // Star rating
                Row(
                  children: List.generate(5, (i) {
                    final filled = i < (score / 20).ceil();
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color:
                          filled ? AppColors.warning : context.palette.divider,
                      size: 20,
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscoresCard(PronunciationResultModel result) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phân tích chi tiết',
            style: AppTextStyles.labelMedium.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          // Chỉ vẽ thanh khi backend thật sự đo được chỉ số tương ứng.
          if (result.fluencyMeasured)
            _buildScoreBar(
              'Fluency',
              result.fluencyScore,
              Icons.water_rounded,
              AppColors.secondary,
            )
          else
            _buildNotMeasuredRow(
              'Độ trôi chảy: chưa đo',
              Icons.water_rounded,
              AppColors.secondary,
            ),
          _buildScoreBar(
            'Accuracy',
            result.accuracyScore,
            Icons.gps_fixed_rounded,
            AppColors.primary,
          ),
          _buildScoreBar(
            'Completeness',
            result.completenessScore,
            Icons.check_circle_outline_rounded,
            AppColors.success,
          ),
          if (result.prosodyMeasured)
            _buildScoreBar(
              'Prosody',
              result.prosodyScore,
              Icons.music_note_rounded,
              AppColors.speaking,
            )
          else
            _buildNotMeasuredRow(
              'Ngữ điệu: chưa phân tích',
              Icons.music_note_rounded,
              AppColors.speaking,
            ),
        ],
      ),
    );
  }

  /// Dòng thay thế thanh điểm khi backend không đo được chỉ số này.
  Widget _buildNotMeasuredRow(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: context.palette.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(
      String label, double score, IconData icon, Color color) {
    final displayColor = score >= 80
        ? AppColors.success
        : score >= 60
            ? AppColors.warning
            : AppColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: context.palette.textSecondary),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: context.palette.divider,
                valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                minHeight: 7,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              score.toStringAsFixed(0),
              style: AppTextStyles.labelSmall.copyWith(
                color: displayColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordHighlightsCard(
      PronunciationResultModel result, PracticeSentenceModel sentence) {
    if (result.wordScores.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.abc_rounded,
                  size: 20, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                'Phân tích từng từ',
                style: AppTextStyles.labelMedium.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap vào từ màu đỏ để xem hướng dẫn phát âm',
            style: AppTextStyles.labelSmall
                .copyWith(color: context.palette.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children:
                result.wordScores.map((ws) => _buildWordChip(ws)).toList(),
          ),
          const SizedBox(height: 14),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(AppColors.success, 'Đúng (≥80)'),
              const SizedBox(width: 16),
              _buildLegendItem(AppColors.warning, 'Tạm (60-79)'),
              const SizedBox(width: 16),
              _buildLegendItem(AppColors.error, 'Sai (<60)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordChip(WordScoreModel ws) {
    final Color color;
    final Color bg;
    if (ws.isCorrect) {
      color = AppColors.success;
      bg = AppColors.success.withValues(alpha: 0.15);
    } else if (ws.isPartial) {
      color = AppColors.warning;
      bg = AppColors.warning.withValues(alpha: 0.15);
    } else {
      color = AppColors.error;
      bg = AppColors.error.withValues(alpha: 0.15);
    }

    return GestureDetector(
      onTap: ws.isWrong ? () => _showWordTip(ws) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ws.word,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${ws.score.toStringAsFixed(0)}%',
              style: AppTextStyles.labelSmall.copyWith(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall
              .copyWith(color: context.palette.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  void _showWordTip(WordScoreModel ws) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 20),
              Text(
                '"${ws.word}"',
                style: AppTextStyles.h3.copyWith(
                    color: AppColors.error, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Điểm phát âm: ${ws.score.toStringAsFixed(0)}/100',
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.palette.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded,
                            color: AppColors.warning, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Mẹo phát âm',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ws.errorType == 'Omission'
                          ? 'Bạn đã bỏ qua từ này. Hãy đọc lại toàn bộ câu, chú ý phát âm từng từ một.'
                          : ws.errorType == 'Insertion'
                              ? 'Bạn đọc thêm từ không có trong câu. Hãy đọc sát theo văn bản.'
                              : 'Hãy tập trung vào từng âm tiết của từ này, đọc chậm rồi tăng dần tốc độ.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.palette.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(PronunciationResultModel result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.secondary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: AppColors.primaryLight, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Nhận xét của AI',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.feedbackVi,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.palette.textPrimary,
              height: 1.5,
            ),
          ),
          if (result.improvementTips.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...result.improvementTips.take(3).map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            tip,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: context.palette.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('btn_retry_pronunciation'),
                onPressed: _restartSession,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Đọc lại'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.palette.textSecondary,
                  side: BorderSide(color: context.palette.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                key: const Key('btn_next_sentence'),
                onPressed: _goToNextSentence,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Câu tiếp theo',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildHomeButton(),
      ],
    );
  }

  Widget _buildHomeButton() {
    return TextButton.icon(
      key: const Key('btn_back_to_pronunciation_home'),
      onPressed: () async {
        await _stopReference();
        if (mounted) context.pop();
      },
      icon: const Icon(Icons.home_rounded, size: 18),
      label: const Text('Về trang luyện phát âm'),
      style: TextButton.styleFrom(
        foregroundColor: context.palette.textSecondary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Waveform CustomPainter
// ─────────────────────────────────────────────────────────────────────────────
class _WaveformPainter extends CustomPainter {
  final double animValue;

  _WaveformPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const barCount = 24;
    final barWidth = size.width / (barCount * 2.0);

    for (int i = 0; i < barCount; i++) {
      final phase = (i / barCount) + animValue;
      final height = (0.2 + 0.8 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi))) *
          size.height;
      final x = i * barWidth * 2 + barWidth;

      // Color gradient from red to orange
      final t = i / barCount;
      paint.color = Color.lerp(AppColors.error, AppColors.warning, t)!
          .withValues(alpha: 0.85);

      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.animValue != animValue;
}
