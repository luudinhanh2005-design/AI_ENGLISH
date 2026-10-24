// Examiner TTS for the IELTS Mock Test Speaking section.
//
// The backend exposes `POST /speech/tts` and returns an `audio_url`. Playback
// goes through `audioplayers`; when the request (or the audio backend) fails we
// fall back to the platform speech synthesiser, which is a no-op on desktop but
// keeps the test flowing instead of blocking the candidate.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/utils/speech_service.dart';

/// Plays the examiner's lines with a consistent voice and caches the generated
/// audio URLs so repeated lines never hit the TTS endpoint twice.
class ExaminerVoice {
  ExaminerVoice(this._dio) {
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      _speaking = false;
    });
  }

  static const String _voice = 'emma';
  static const double _speed = 0.95;

  final Dio _dio;
  final AudioPlayer _player = AudioPlayer();
  final Map<String, String> _urlCache = {};

  StreamSubscription<void>? _completeSubscription;
  bool _disposed = false;
  bool _speaking = false;

  /// Incremented on every call to [speak]/[stop] so a slow TTS request cannot
  /// start playing after a newer line has already begun.
  int _generation = 0;

  /// Whether examiner audio is currently being played. Best-effort: it also
  /// turns false when playback fails.
  bool get isSpeaking => _speaking;

  /// Speaks [text] in English, replacing any line that is still playing.
  ///
  /// Never throws: a TTS failure degrades to `SpeechService.speak` and then to
  /// silence so the exam flow is never blocked.
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _disposed) return;

    await stop();
    if (_disposed) return;
    final generation = _generation;

    var url = _urlCache[trimmed];
    if (url == null) {
      url = await _fetchAudioUrl(trimmed);
      if (url != null) _urlCache[trimmed] = url;
    }
    if (_disposed || generation != _generation) return;

    if (url != null) {
      try {
        _speaking = true;
        await _player.play(UrlSource(url));
        return;
      } catch (error) {
        debugPrint('ExaminerVoice playback error: $error');
        _speaking = false;
      }
    }

    // Network/audio fallback — the browser speech synthesiser is the only
    // implementation available on web, and a silent no-op elsewhere.
    try {
      _speaking = true;
      await SpeechService.speak(trimmed, rate: _speed);
    } catch (error) {
      debugPrint('ExaminerVoice fallback error: $error');
    } finally {
      _speaking = false;
    }
  }

  /// Stops examiner audio and cancels any pending fallback speech.
  Future<void> stop() async {
    _generation++;
    _speaking = false;
    try {
      await _player.stop();
    } catch (error) {
      debugPrint('ExaminerVoice stop error: $error');
    }
    SpeechService.stop();
  }

  Future<String?> _fetchAudioUrl(String text) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.speechTts,
        data: <String, dynamic>{
          'text': text,
          'voice': _voice,
          'speed': _speed,
        },
      );
      final data = response.data;
      if (data is! Map) return null;
      final raw = data['audio_url'];
      if (raw is! String || raw.trim().isEmpty) return null;
      return AppConfig.resolveMediaUrl(raw);
    } catch (error) {
      debugPrint('ExaminerVoice TTS request error: $error');
      return null;
    }
  }

  void dispose() {
    _disposed = true;
    _speaking = false;
    _completeSubscription?.cancel();
    _completeSubscription = null;
    _player.dispose();
    SpeechService.stop();
  }
}
