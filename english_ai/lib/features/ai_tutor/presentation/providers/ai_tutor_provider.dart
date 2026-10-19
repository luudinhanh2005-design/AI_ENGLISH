import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/ai_tutor_models.dart';

class AiTutorState {
  final bool isLoading;
  final bool isTranscribing;
  final String? errorMessage;
  final String currentPersona; // 'sarah', 'harrison', 'emma'
  final String? sessionId;
  final List<ChatMessageModel> messages;
  final List<String> currentSuggestions;

  const AiTutorState({
    this.isLoading = false,
    this.isTranscribing = false,
    this.errorMessage,
    this.currentPersona = 'sarah',
    this.sessionId,
    this.messages = const [],
    this.currentSuggestions = const [],
  });

  AiTutorState copyWith({
    bool? isLoading,
    bool? isTranscribing,
    String? errorMessage,
    String? currentPersona,
    String? sessionId,
    List<ChatMessageModel>? messages,
    List<String>? currentSuggestions,
  }) {
    return AiTutorState(
      isLoading: isLoading ?? this.isLoading,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      errorMessage: errorMessage,
      currentPersona: currentPersona ?? this.currentPersona,
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      currentSuggestions: currentSuggestions ?? this.currentSuggestions,
    );
  }
}

final aiTutorProvider =
    StateNotifierProvider<AiTutorNotifier, AiTutorState>((ref) {
  return AiTutorNotifier(ref.watch(dioProvider));
});

class AiTutorNotifier extends StateNotifier<AiTutorState> {
  final dynamic _dio;

  AiTutorNotifier(this._dio) : super(const AiTutorState()) {
    _sendWelcomeMessage('sarah');
  }

  void _sendWelcomeMessage(String persona) {
    String welcome;
    List<String> suggestions;

    if (persona == 'harrison') {
      welcome =
          'Good day! I am Mr. Harrison, your Business English Coach. How can I assist you with your professional communications today?';
      suggestions = [
        'How can I prepare for an executive presentation?',
        'Teach me phrases for formal email negotiations.',
        'Review my business elevator pitch.',
      ];
    } else if (persona == 'emma') {
      welcome =
          'Hello! I am Emma, your IELTS Academic Examiner. Let us work on expanding your vocabulary and grammatical complexity.';
      suggestions = [
        'Let us practice an IELTS Part 2 speaking topic.',
        'How can I use more idiomatic expressions?',
        'Test my academic vocabulary.',
      ];
    } else {
      welcome =
          'Hi there! I am Sarah, your AI English Tutor 👋 Let us chat and practice speaking English naturally. What is on your mind today?';
      suggestions = [
        'Tell me about your favorite travel destination.',
        'I want to practice ordering food at a restaurant.',
        'Can you check my sentence grammar?',
      ];
    }

    state = state.copyWith(
      currentPersona: persona,
      messages: [
        ChatMessageModel(
          id: 'welcome_$persona',
          role: 'assistant',
          content: welcome,
          suggestedReplies: suggestions,
          createdAt: DateTime.now(),
        ),
      ],
      currentSuggestions: suggestions,
    );
  }

  void setPersona(String persona) {
    if (state.currentPersona == persona) return;
    state = state.copyWith(sessionId: null);
    _sendWelcomeMessage(persona);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessageModel(
      id: 'msg_user_${DateTime.now().microsecondsSinceEpoch}',
      role: 'user',
      content: trimmed,
      createdAt: DateTime.now(),
    );

    // Optimistically add user message to list
    final updated = List<ChatMessageModel>.from(state.messages)..add(userMsg);
    state = state.copyWith(
      messages: updated,
      isLoading: true,
      errorMessage: null,
      currentSuggestions: [],
    );

    try {
      final response = await _dio.post(
        '/ai/chat',
        data: {
          'session_id': state.sessionId,
          'persona': state.currentPersona,
          'message': trimmed,
          'topic': 'General Conversation',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final sessionId = data['session_id'] as String?;
      final replyText = data['reply'] as String? ?? '';
      final rawCorrections = data['corrections'] as List<dynamic>? ?? [];
      final rawSuggestions = data['suggested_replies'] as List<dynamic>? ?? [];

      final corrections = rawCorrections
          .whereType<Map<String, dynamic>>()
          .map(AICorrectionModel.fromJson)
          .toList();
      final suggestions = rawSuggestions.map((s) => s.toString()).toList();

      final assistantMsg = ChatMessageModel(
        id: 'msg_ai_${DateTime.now().microsecondsSinceEpoch}',
        role: 'assistant',
        content: replyText,
        corrections: corrections,
        suggestedReplies: suggestions,
        createdAt: DateTime.now(),
      );

      final newMessages = List<ChatMessageModel>.from(state.messages)..add(assistantMsg);

      state = state.copyWith(
        isLoading: false,
        sessionId: sessionId,
        messages: newMessages,
        currentSuggestions: suggestions,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể kết nối với AI Tutor. Vui lòng thử lại.',
      );
    }
  }

  Future<String?> transcribeAudio(Uint8List audioBytes, {String filename = 'audio.wav'}) async {
    try {
      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(audioBytes, filename: filename),
        'language': 'en',
      });
      final response = await _dio.post(
        '/speech/transcribe',
        data: formData,
      );
      if (response.data != null && response.data['transcript'] != null) {
        return (response.data['transcript'] as String).trim();
      }
    } catch (e) {
      // Transcription error
    }
    return null;
  }

  Future<void> sendAudioMessage(Uint8List audioBytes, {String filename = 'audio.wav'}) async {
    state = state.copyWith(isTranscribing: true, errorMessage: null);
    try {
      final transcript = await transcribeAudio(audioBytes, filename: filename);
      state = state.copyWith(isTranscribing: false);
      if (transcript != null && transcript.isNotEmpty) {
        await sendMessage(transcript);
      } else {
        state = state.copyWith(
          errorMessage: 'Không nhận diện được âm thanh. Hãy thử nói to và rõ hơn nhé!',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isTranscribing: false,
        errorMessage: 'Lỗi nhận diện âm thanh. Vui lòng thử lại.',
      );
    }
  }

  Future<String?> getAudioUrlForText(String text, String persona) async {
    try {
      final response = await _dio.post(
        '/speech/tts',
        data: {
          'text': text,
          'voice': persona,
        },
      );
      if (response.data != null && response.data['audio_url'] != null) {
        final audioPath = (response.data['audio_url'] as String).trim();
        if (audioPath.isEmpty) return null;
        return AppConfig.resolveMediaUrl(audioPath);
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }

  Future<String?> translateText(String text) async {
    try {
      final response = await _dio.post(
        '/ai/translate',
        data: {
          'text': text,
          'target_lang': 'vi',
        },
      );
      if (response.data != null && response.data['translated_text'] != null) {
        return response.data['translated_text'] as String;
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }
}
