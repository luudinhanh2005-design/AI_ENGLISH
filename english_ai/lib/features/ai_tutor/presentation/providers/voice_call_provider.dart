import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../data/models/ai_tutor_models.dart';
import '../../data/models/voice_call_models.dart';

class VoiceCallState {
  final CallStateEnum status;
  final String persona;
  final int durationSeconds;
  final bool isMuted;
  final bool showSubtitles;
  final String? currentAiSubtitle;
  final String? currentUserSubtitle;
  final String? currentAiTranslation;
  final AICorrectionModel? activeCorrection;
  final List<CallTurnModel> turns;
  final VoiceCallSummaryModel? summary;
  final String? errorMessage;
  final bool isTranslatingSubtitle;

  const VoiceCallState({
    this.status = CallStateEnum.connecting,
    this.persona = 'sarah',
    this.durationSeconds = 0,
    this.isMuted = false,
    this.showSubtitles = true,
    this.currentAiSubtitle,
    this.currentUserSubtitle,
    this.currentAiTranslation,
    this.activeCorrection,
    this.turns = const [],
    this.summary,
    this.errorMessage,
    this.isTranslatingSubtitle = false,
  });

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int get calculatedFluencyScore {
    if (turns.isEmpty) return 70;
    final correctionCount = turns.fold<int>(
      0,
      (total, turn) => total + turn.corrections.length,
    );
    final turnsBonus = (turns.length * 4).clamp(0, 20).toInt();
    final durationBonus =
        ((durationSeconds / 60.0) * 5).round().clamp(0, 10).toInt();
    final errorPenalty = (correctionCount * 3).clamp(0, 20).toInt();
    return (65 + turnsBonus + durationBonus - errorPenalty)
        .clamp(45, 96)
        .toInt();
  }

  VoiceCallState copyWith({
    CallStateEnum? status,
    String? persona,
    int? durationSeconds,
    bool? isMuted,
    bool? showSubtitles,
    String? currentAiSubtitle,
    String? currentUserSubtitle,
    String? currentAiTranslation,
    AICorrectionModel? activeCorrection,
    List<CallTurnModel>? turns,
    VoiceCallSummaryModel? summary,
    String? errorMessage,
    bool? isTranslatingSubtitle,
    bool clearActiveCorrection = false,
    bool clearAiTranslation = false,
    bool clearError = false,
  }) {
    return VoiceCallState(
      status: status ?? this.status,
      persona: persona ?? this.persona,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isMuted: isMuted ?? this.isMuted,
      showSubtitles: showSubtitles ?? this.showSubtitles,
      currentAiSubtitle: currentAiSubtitle ?? this.currentAiSubtitle,
      currentUserSubtitle: currentUserSubtitle ?? this.currentUserSubtitle,
      currentAiTranslation: clearAiTranslation
          ? null
          : (currentAiTranslation ?? this.currentAiTranslation),
      activeCorrection: clearActiveCorrection
          ? null
          : (activeCorrection ?? this.activeCorrection),
      turns: turns ?? this.turns,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isTranslatingSubtitle: isTranslatingSubtitle ?? this.isTranslatingSubtitle,
    );
  }
}

final voiceCallProvider =
    StateNotifierProvider.autoDispose<VoiceCallNotifier, VoiceCallState>((ref) {
  return VoiceCallNotifier(ref.watch(dioProvider));
});

class VoiceCallNotifier extends StateNotifier<VoiceCallState> {
  final dynamic _dio;
  final AudioRecordingService _recordingService = AudioRecordingService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? _durationTimer;
  String? _chatSessionId;
  StreamSubscription? _playerCompleteSubscription;

  VoiceCallNotifier(this._dio) : super(const VoiceCallState()) {
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (state.status == CallStateEnum.speaking) {
        state = state.copyWith(status: CallStateEnum.listening);
      }
    });
  }

  Future<void> startCall(String persona) async {
    state = state.copyWith(
      persona: persona,
      status: CallStateEnum.connecting,
      durationSeconds: 0,
      turns: [],
      summary: null,
      clearError: true,
    );

    _startDurationTimer();

    // Welcome sentence for call
    String welcomeText;
    if (persona.toLowerCase() == 'harrison') {
      welcomeText = "Hello! Harrison here. Ready for our business discussion today?";
    } else if (persona.toLowerCase() == 'emma') {
      welcomeText = "Good day! Emma speaking. Let's practice your IELTS fluency now.";
    } else {
      welcomeText = "Hi there! I'm Sarah! So wonderful to talk with you. How are you feeling today?";
    }

    state = state.copyWith(
      currentAiSubtitle: welcomeText,
      clearAiTranslation: true,
      status: CallStateEnum.speaking,
    );

    // Speak welcome message
    await _playAiSpeech(welcomeText, persona);
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status != CallStateEnum.ended) {
        state = state.copyWith(durationSeconds: state.durationSeconds + 1);
      }
    });
  }

  Future<void> startSpeaking() async {
    if (state.isMuted) return;
    try {
      await _audioPlayer.stop();
      await _recordingService.startRecording();
      state = state.copyWith(
        status: CallStateEnum.listening,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Không thể mở micro. Hãy kiểm tra quyền truy cập microphone.',
      );
    }
  }

  Future<void> stopSpeakingAndProcess() async {
    if (state.status != CallStateEnum.listening) return;

    state = state.copyWith(status: CallStateEnum.thinking);

    try {
      final audioBytes = await _recordingService.stopRecording();
      if (audioBytes == null || audioBytes.isEmpty) {
        state = state.copyWith(
          status: CallStateEnum.listening,
          errorMessage: 'Chưa thu được âm thanh. Hãy thử nói lại nhé!',
        );
        return;
      }

      // Step 1: STT with Whisper
      final userText = await _transcribeAudio(audioBytes);
      if (userText == null || userText.trim().isEmpty) {
        state = state.copyWith(
          status: CallStateEnum.listening,
          errorMessage: 'Không nhận diện được giọng nói. Bạn hãy nói to hơn chút nhé!',
        );
        return;
      }

      state = state.copyWith(currentUserSubtitle: userText);

      // Step 2: Send to AI Chat
      final chatResponse = await _dio.post(
        '/ai/chat',
        data: {
          'session_id': _chatSessionId,
          'persona': state.persona,
          'message': userText,
          'topic': 'Voice Call Conversation',
        },
      );

      final data = chatResponse.data as Map<String, dynamic>;
      _chatSessionId = data['session_id'] as String?;
      final replyText = data['reply'] as String? ?? 'I hear you!';
      final rawCorrections = data['corrections'] as List<dynamic>? ?? [];

      final corrections = rawCorrections
          .whereType<Map<String, dynamic>>()
          .map(AICorrectionModel.fromJson)
          .toList();

      final newTurn = CallTurnModel(
        id: 'turn_${DateTime.now().millisecondsSinceEpoch}',
        userText: userText,
        aiText: replyText,
        corrections: corrections,
        timestamp: DateTime.now(),
        turnIndex: state.turns.length + 1,
      );

      final updatedTurns = List<CallTurnModel>.from(state.turns)..add(newTurn);

      state = state.copyWith(
        currentAiSubtitle: replyText,
        clearAiTranslation: true,
        activeCorrection: corrections.isNotEmpty ? corrections.first : null,
        clearActiveCorrection: corrections.isEmpty,
        turns: updatedTurns,
        status: CallStateEnum.speaking,
      );

      // Step 3: Speak response
      await _playAiSpeech(replyText, state.persona);
    } catch (e) {
      debugPrint('Voice call process error: $e');
      state = state.copyWith(
        status: CallStateEnum.listening,
        errorMessage: 'Lỗi kết nối đàm thoại. Vui lòng thử lại.',
      );
    }
  }

  Future<String?> _transcribeAudio(Uint8List audioBytes) async {
    try {
      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(audioBytes, filename: kIsWeb ? 'call_voice.webm' : 'call_voice.wav'),
        'language': 'en',
      });
      final res = await _dio.post('/speech/transcribe', data: formData);
      if (res.data != null && res.data['transcript'] != null) {
        return (res.data['transcript'] as String).trim();
      }
    } catch (e) {
      debugPrint('Transcribe error: $e');
    }
    return null;
  }

  Future<void> _playAiSpeech(String text, String persona) async {
    try {
      final res = await _dio.post(
        '/speech/tts',
        data: {
          'text': text,
          'voice': persona,
        },
      );
      if (res.data != null && res.data['audio_url'] != null) {
        final audioUrl = AppConfig.resolveMediaUrl(res.data['audio_url'] as String);
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
        return;
      }
    } catch (e) {
      debugPrint('TTS play error: $e');
    }
    // If TTS fails, automatically switch to listening after brief simulated duration
    await Future.delayed(const Duration(seconds: 3));
    if (state.status == CallStateEnum.speaking) {
      state = state.copyWith(status: CallStateEnum.listening);
    }
  }

  void toggleMute() {
    final newMuted = !state.isMuted;
    if (newMuted && state.status == CallStateEnum.listening) {
      _recordingService.cancelRecording();
    }
    state = state.copyWith(isMuted: newMuted);
  }

  void toggleSubtitles() {
    state = state.copyWith(showSubtitles: !state.showSubtitles);
  }

  Future<void> translateCurrentSubtitle() async {
    final text = state.currentAiSubtitle;
    if (text == null || text.isEmpty || state.isTranslatingSubtitle) return;

    if (state.currentAiTranslation != null) {
      state = state.copyWith(clearAiTranslation: true);
      return;
    }

    state = state.copyWith(isTranslatingSubtitle: true);
    try {
      final res = await _dio.post(
        '/ai/translate',
        data: {'text': text, 'target_lang': 'vi'},
      );
      if (res.data != null && res.data['translated_text'] != null) {
        state = state.copyWith(
          currentAiTranslation: res.data['translated_text'] as String,
          isTranslatingSubtitle: false,
        );
      } else {
        state = state.copyWith(isTranslatingSubtitle: false);
      }
    } catch (e) {
      state = state.copyWith(isTranslatingSubtitle: false);
    }
  }

  void endCall() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _audioPlayer.stop();
    _recordingService.cancelRecording();

    final allCorrections = <AICorrectionModel>[];
    for (final turn in state.turns) {
      allCorrections.addAll(turn.corrections);
    }

    final fluency = state.calculatedFluencyScore;

    String feedback;
    if (fluency >= 85) {
      feedback = 'Cuộc đàm thoại xuất sắc! Bạn phản xạ rất nhanh và biểu đạt tự nhiên.';
    } else if (fluency >= 70) {
      feedback = 'Bạn giao tiếp rất tự tin và duy trì cuộc trò chuyện tốt. Tiếp tục phát huy nhé!';
    } else {
      feedback = 'Khởi đầu tốt! Hãy luyện thêm để giảm thời gian ngập ngừng khi nói tiếng Anh.';
    }

    final summary = VoiceCallSummaryModel(
      persona: state.persona,
      durationSeconds: state.durationSeconds,
      totalTurns: state.turns.length,
      allCorrections: allCorrections,
      turns: state.turns,
      fluencyScore: fluency,
      feedbackVi: feedback,
    );

    state = state.copyWith(
      status: CallStateEnum.ended,
      summary: summary,
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _recordingService.dispose();
    super.dispose();
  }
}
