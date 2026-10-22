import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../data/models/pronunciation_models.dart';

// -----------------------------------------------------------------------------
// State
// -----------------------------------------------------------------------------
enum PronunciationPhase { ready, recording, analyzing, result }

class PronunciationState {
  final PronunciationPhase phase;
  final String selectedLevel;
  final List<PracticeSentenceModel> sentences;
  final PracticeSentenceModel? currentSentence;
  final PronunciationResultModel? result;
  final PronunciationStatsModel stats;
  final List<PronunciationHistoryModel> history;
  final bool isLoadingSentences;
  final bool isLoadingHistory;
  final bool isPlayingTTS;
  final String? errorMessage;
  final int recordDuration; // seconds elapsed while recording

  // Speech settings (persisted between sessions)
  final String voiceId;
  final double speechSpeed;
  final int requiredReads;

  // Multi-read session progress
  final int attemptsDone;
  final List<PronunciationResultModel> attemptResults;

  const PronunciationState({
    this.phase = PronunciationPhase.ready,
    this.selectedLevel = 'B1',
    this.sentences = const [],
    this.currentSentence,
    this.result,
    this.stats = const PronunciationStatsModel(),
    this.history = const [],
    this.isLoadingSentences = false,
    this.isLoadingHistory = false,
    this.isPlayingTTS = false,
    this.errorMessage,
    this.recordDuration = 0,
    this.voiceId = 'sarah',
    this.speechSpeed = 1.0,
    this.requiredReads = 1,
    this.attemptsDone = 0,
    this.attemptResults = const [],
  });

  bool get isSessionComplete => attemptsDone >= requiredReads;

  int get nextAttemptNumber =>
      attemptsDone >= requiredReads ? requiredReads : attemptsDone + 1;

  double get averageAttemptScore {
    if (attemptResults.isEmpty) return 0;
    final total = attemptResults.fold<double>(
      0,
      (sum, result) => sum + result.overallScore,
    );
    return total / attemptResults.length;
  }

  double get bestAttemptScore {
    if (attemptResults.isEmpty) return 0;
    return attemptResults
        .map((result) => result.overallScore)
        .reduce((a, b) => a > b ? a : b);
  }

  PronunciationState copyWith({
    PronunciationPhase? phase,
    String? selectedLevel,
    List<PracticeSentenceModel>? sentences,
    PracticeSentenceModel? currentSentence,
    PronunciationResultModel? result,
    PronunciationStatsModel? stats,
    List<PronunciationHistoryModel>? history,
    bool? isLoadingSentences,
    bool? isLoadingHistory,
    bool? isPlayingTTS,
    String? errorMessage,
    int? recordDuration,
    String? voiceId,
    double? speechSpeed,
    int? requiredReads,
    int? attemptsDone,
    List<PronunciationResultModel>? attemptResults,
    bool clearError = false,
    bool clearResult = false,
    bool clearCurrentSentence = false,
  }) {
    return PronunciationState(
      phase: phase ?? this.phase,
      selectedLevel: selectedLevel ?? this.selectedLevel,
      sentences: sentences ?? this.sentences,
      currentSentence: clearCurrentSentence
          ? null
          : (currentSentence ?? this.currentSentence),
      result: clearResult ? null : (result ?? this.result),
      stats: stats ?? this.stats,
      history: history ?? this.history,
      isLoadingSentences: isLoadingSentences ?? this.isLoadingSentences,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isPlayingTTS: isPlayingTTS ?? this.isPlayingTTS,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      recordDuration: recordDuration ?? this.recordDuration,
      voiceId: voiceId ?? this.voiceId,
      speechSpeed: speechSpeed ?? this.speechSpeed,
      requiredReads: requiredReads ?? this.requiredReads,
      attemptsDone: attemptsDone ?? this.attemptsDone,
      attemptResults: attemptResults ?? this.attemptResults,
    );
  }
}

// -----------------------------------------------------------------------------
// Provider
// -----------------------------------------------------------------------------
final pronunciationProvider =
    StateNotifierProvider<PronunciationNotifier, PronunciationState>((ref) {
  return PronunciationNotifier(ref.watch(dioProvider));
});

// -----------------------------------------------------------------------------
// Notifier
// -----------------------------------------------------------------------------
class PronunciationNotifier extends StateNotifier<PronunciationState> {
  final dynamic _dio;
  final AudioRecordingService _recorder;

  static const String _prefsVoice = 'pronunciation_voice';
  static const String _prefsSpeed = 'pronunciation_speed';
  static const String _prefsReads = 'pronunciation_required_reads';
  static const List<String> _voiceOptions = ['sarah', 'harrison', 'emma'];
  static const List<double> _speedOptions = [0.75, 1.0, 1.25];

  PronunciationNotifier(this._dio, {AudioRecordingService? recorder})
      : _recorder = recorder ?? AudioRecordingService(),
        super(const PronunciationState()) {
    _loadSpeechSettings();
    loadSentences('B1');
    loadStats();
    loadHistory();
  }

  // ---------------------------------------------------------------------------
  // Persisted speech settings
  // ---------------------------------------------------------------------------
  Future<void> _loadSpeechSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final savedVoice = prefs.getString(_prefsVoice);
      final savedSpeed = prefs.getDouble(_prefsSpeed);
      final savedReads = prefs.getInt(_prefsReads);

      final voice = _voiceOptions.contains(savedVoice) ? savedVoice! : 'sarah';
      final speed = savedSpeed != null && _speedOptions.contains(savedSpeed)
          ? savedSpeed
          : 1.0;
      final reads = (savedReads ?? 1).clamp(1, 3).toInt();

      state = state.copyWith(
        voiceId: voice,
        speechSpeed: speed,
        requiredReads: reads,
      );
    } catch (_) {
      // Keep defaults if preferences are unavailable.
    }
  }

  Future<void> _persistSpeechSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsVoice, state.voiceId);
      await prefs.setDouble(_prefsSpeed, state.speechSpeed);
      await prefs.setInt(_prefsReads, state.requiredReads);
    } catch (_) {
      // Settings are best-effort; keep the in-memory values.
    }
  }

  void setVoice(String voiceId) {
    if (!_voiceOptions.contains(voiceId) || voiceId == state.voiceId) return;
    state = state.copyWith(voiceId: voiceId);
    _persistSpeechSettings();
  }

  void setSpeechSpeed(double speed) {
    final supported = _speedOptions.any(
      (option) => (option - speed).abs() < 0.001,
    );
    if (!supported || (state.speechSpeed - speed).abs() < 0.001) return;
    state = state.copyWith(speechSpeed: speed);
    _persistSpeechSettings();
  }

  void setRequiredReads(int reads) {
    final clamped = reads.clamp(1, 3).toInt();
    if (clamped == state.requiredReads) return;
    state = state.copyWith(
      requiredReads: clamped,
      attemptsDone: 0,
      attemptResults: const [],
      phase: PronunciationPhase.ready,
      recordDuration: 0,
      clearResult: true,
      clearError: true,
    );
    _persistSpeechSettings();
  }

  // ---------------------------------------------------------------------------
  // Load practice sentences by level
  // ---------------------------------------------------------------------------
  Future<void> loadSentences(String level) async {
    state = state.copyWith(
      selectedLevel: level,
      isLoadingSentences: true,
      clearError: true,
    );
    try {
      final response = await _dio.get(
        '/speech/practice',
        queryParameters: {'level': level},
      );
      final data = response.data as Map<String, dynamic>;
      final rawList = data['sentences'] as List<dynamic>? ?? [];
      final sentences = rawList
          .map((s) => PracticeSentenceModel.fromJson(s as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        sentences: sentences,
        isLoadingSentences: false,
      );
    } catch (_) {
      // Fallback sentences khi không có internet / backend đang tắt
      state = state.copyWith(
        sentences: _fallbackSentences(level),
        isLoadingSentences: false,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Pick a sentence to practice
  // ---------------------------------------------------------------------------
  void selectSentence(PracticeSentenceModel sentence) {
    state = state.copyWith(
      currentSentence: sentence,
      phase: PronunciationPhase.ready,
      attemptsDone: 0,
      attemptResults: const [],
      clearResult: true,
      clearError: true,
      recordDuration: 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Play TTS (reference pronunciation)
  // ---------------------------------------------------------------------------
  Future<String?> getReferenceTTSUrl(
    String text, {
    String? voice,
    double? speed,
  }) async {
    if (mounted) state = state.copyWith(isPlayingTTS: true);
    try {
      final response = await _dio.post(
        '/speech/tts',
        data: {
          'text': text,
          'voice': voice ?? state.voiceId,
          'speed': speed ?? state.speechSpeed,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final path = data['audio_url'] as String? ?? '';
      if (path.isEmpty) return null;
      return AppConfig.resolveMediaUrl(path);
    } catch (_) {
      return null;
    } finally {
      if (mounted) state = state.copyWith(isPlayingTTS: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Recording lifecycle
  // ---------------------------------------------------------------------------
  Future<void> startRecording() async {
    try {
      await _recorder.startRecording();
      state = state.copyWith(
        phase: PronunciationPhase.recording,
        recordDuration: 0,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage:
            'Không thể truy cập micro. Hãy cho phép quyền microphone.',
      );
    }
  }

  void tickRecordDuration() {
    if (state.phase == PronunciationPhase.recording) {
      state = state.copyWith(recordDuration: state.recordDuration + 1);
    }
  }

  Future<void> cancelRecording() async {
    await _recorder.cancelRecording();
    state = state.copyWith(
      phase: PronunciationPhase.ready,
      recordDuration: 0,
      clearError: true,
    );
  }

  Future<void> stopAndAssess() async {
    final sentence = state.currentSentence;
    if (sentence == null) return;

    state = state.copyWith(phase: PronunciationPhase.analyzing);

    try {
      final audioBytes = await _recorder.stopRecording();
      if (audioBytes == null || audioBytes.isEmpty) {
        state = state.copyWith(
          phase: PronunciationPhase.ready,
          recordDuration: 0,
          clearResult: true,
          errorMessage: 'Không thu được âm thanh. Hãy thử lại!',
        );
        return;
      }

      // ĐOẠN CODE ĐƯỢC SỬA LỖI Ở ĐÂY:
      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(
          audioBytes,
          filename: kIsWeb ? 'pronunciation.webm' : 'pronunciation.wav',
          // Ép trình duyệt Web gửi file dưới dạng audio thay vì video
          contentType: MediaType('audio', kIsWeb ? 'webm' : 'wav'),
        ),
        'reference_text': sentence.text,
        'session_type': 'read_aloud',
      });

      final response = await _dio.post('/speech/assess', data: formData);
      final result = PronunciationResultModel.fromJson(
        response.data as Map<String, dynamic>,
      );

      // Backend không nhận diện được giọng đọc: không chấm điểm ảo,
      // giữ nguyên số lần đã hoàn thành và yêu cầu người đọc đọc lại.
      if (result.recognizedText.trim().isEmpty) {
        state = state.copyWith(
          phase: PronunciationPhase.ready,
          recordDuration: 0,
          clearResult: true,
          errorMessage:
              'Chưa nghe rõ giọng đọc. Hãy đọc to, rõ hơn và thử lại.',
        );
        return;
      }

      final updatedResults = [...state.attemptResults, result];
      final updatedAttempts =
          (state.attemptsDone + 1).clamp(0, state.requiredReads).toInt();

      state = state.copyWith(
        phase: PronunciationPhase.result,
        result: result,
        attemptsDone: updatedAttempts,
        attemptResults: updatedResults,
        recordDuration: 0,
        clearError: true,
      );

      // Refresh history sau khi hoàn thành
      loadHistory();
    } catch (e) {
      state = state.copyWith(
        phase: PronunciationPhase.ready,
        recordDuration: 0,
        clearResult: true,
        errorMessage: 'Lỗi phân tích phát âm. Vui lòng thử lại.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Load history & stats
  // ---------------------------------------------------------------------------
  Future<void> loadHistory() async {
    state = state.copyWith(isLoadingHistory: true);
    try {
      final response = await _dio.get('/speech/history');
      final data = response.data as Map<String, dynamic>;
      final rawList = data['sessions'] as List<dynamic>? ?? [];
      final history = rawList
          .map((h) =>
              PronunciationHistoryModel.fromJson(h as Map<String, dynamic>))
          .toList();
      state = state.copyWith(history: history, isLoadingHistory: false);
    } catch (_) {
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  Future<void> loadStats() async {
    try {
      final response = await _dio.get('/speech/stats');
      final stats = PronunciationStatsModel.fromJson(
        response.data as Map<String, dynamic>,
      );
      state = state.copyWith(stats: stats);
    } catch (_) {
      // Keep defaults
    }
  }

  // ---------------------------------------------------------------------------
  // Reset về ready để luyện lại câu
  // ---------------------------------------------------------------------------
  /// Quay về màn hình sẵn sàng cho lần đọc kế tiếp, giữ các kết quả cũ.
  void startNextAttempt() {
    state = state.copyWith(
      phase: PronunciationPhase.ready,
      recordDuration: 0,
      clearResult: true,
      clearError: true,
    );
  }

  /// Bỏ kết quả của lần vừa đọc và cho phép đọc lại đúng lần đó.
  void retryLastAttempt() {
    final results = [...state.attemptResults];
    if (results.isNotEmpty) results.removeLast();
    final attempts =
        (state.attemptsDone - 1).clamp(0, state.requiredReads).toInt();
    state = state.copyWith(
      phase: PronunciationPhase.ready,
      attemptsDone: attempts,
      attemptResults: results,
      recordDuration: 0,
      clearResult: true,
      clearError: true,
    );
  }

  /// Bắt đầu lại toàn bộ phiên đọc (xóa tất cả kết quả của câu hiện tại).
  void restartSession() {
    state = state.copyWith(
      phase: PronunciationPhase.ready,
      attemptsDone: 0,
      attemptResults: const [],
      recordDuration: 0,
      clearResult: true,
      clearError: true,
    );
  }

  void retryCurrentSentence() => restartSession();

  // ---------------------------------------------------------------------------
  // Chọn câu ngẫu nhiên kế tiếp cùng level
  // ---------------------------------------------------------------------------
  void nextRandomSentence() {
    final list = state.sentences;
    if (list.isEmpty) return;
    final current = state.currentSentence;
    final candidates = list.where((s) => s.text != current?.text).toList();
    if (candidates.isEmpty) return;
    candidates.shuffle();
    selectSentence(candidates.first);
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Fallback sentences khi không có backend
  // ---------------------------------------------------------------------------
  List<PracticeSentenceModel> _fallbackSentences(String level) {
    final map = {
      'A1': [
        PracticeSentenceModel(
            text: 'Hello, my name is Sarah.',
            level: 'A1',
            topic: 'Greeting',
            ipaTranscription: '/həˈloʊ maɪ neɪm ɪz ˈsærə/'),
        PracticeSentenceModel(
            text: 'I am happy to meet you.',
            level: 'A1',
            topic: 'Greeting',
            ipaTranscription: '/aɪ æm ˈhæpi tuː miːt juː/'),
        PracticeSentenceModel(
            text: 'The weather is nice today.',
            level: 'A1',
            topic: 'Weather',
            ipaTranscription: '/ðə ˈwɛðər ɪz naɪs təˈdeɪ/'),
      ],
      'A2': [
        PracticeSentenceModel(
            text: 'I usually wake up at seven in the morning.',
            level: 'A2',
            topic: 'Daily Routine',
            ipaTranscription: '/aɪ ˈjuːʒuəli weɪk ʌp æt ˈsɛvən/'),
        PracticeSentenceModel(
            text: 'Can you tell me the way to the nearest station?',
            level: 'A2',
            topic: 'Directions',
            ipaTranscription: '/kæn juː tɛl miː ðə weɪ/'),
      ],
      'B1': [
        PracticeSentenceModel(
            text: 'Yesterday, I went to school with my friend.',
            level: 'B1',
            topic: 'Daily Life',
            ipaTranscription: '/ˈjɛstərdeɪ aɪ wɛnt tuː skuːl/'),
        PracticeSentenceModel(
            text: 'She has been learning English for three years.',
            level: 'B1',
            topic: 'Education',
            ipaTranscription: '/ʃiː hæz bɪn ˈlɜːrnɪŋ ˈɪŋɡlɪʃ/'),
        PracticeSentenceModel(
            text: 'I would rather stay home than go out tonight.',
            level: 'B1',
            topic: 'Preference',
            ipaTranscription: '/aɪ wʊd ˈræðər steɪ hoʊm/'),
      ],
      'B2': [
        PracticeSentenceModel(
            text:
                'Despite the challenges, she managed to finish the project on time.',
            level: 'B2',
            topic: 'Work',
            ipaTranscription: '/dɪˈspaɪt ðə ˈtʃælɪndʒɪz/'),
        PracticeSentenceModel(
            text:
                'The government should invest more in renewable energy sources.',
            level: 'B2',
            topic: 'Environment',
            ipaTranscription: '/ðə ˈɡʌvərnmənt ʃʊd ɪnˈvɛst/'),
      ],
      'C1': [
        PracticeSentenceModel(
            text:
                'The ramifications of climate change are far more pervasive than previously anticipated.',
            level: 'C1',
            topic: 'Environment',
            ipaTranscription: '/ðə ˌræmɪfɪˈkeɪʃənz əv ˈklaɪmɪt/'),
        PracticeSentenceModel(
            text:
                'Notwithstanding the economic downturn, the company maintained its competitive edge.',
            level: 'C1',
            topic: 'Business',
            ipaTranscription: '/ˌnɒtwɪθˈstændɪŋ ðə ˌiːkəˈnɒmɪk/'),
      ],
    };
    return map[level] ?? map['B1']!;
  }
}
