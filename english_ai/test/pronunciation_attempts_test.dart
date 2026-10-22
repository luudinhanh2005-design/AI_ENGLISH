import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:english_ai/core/services/audio_recording_service.dart';
import 'package:english_ai/features/pronunciation/data/models/pronunciation_models.dart';
import 'package:english_ai/features/pronunciation/presentation/providers/pronunciation_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRecorder implements AudioRecordingService {
  Uint8List? nextBytes = Uint8List.fromList([1, 2, 3]);

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isRecording() async => false;

  @override
  Stream<Amplitude> amplitudeStream([
    Duration interval = const Duration(milliseconds: 200),
  ]) =>
      Stream<Amplitude>.empty();

  @override
  Future<void> startRecording() async {}

  @override
  Future<Uint8List?> stopRecording() async => nextBytes;

  @override
  Future<void> cancelRecording() async {}

  @override
  void dispose() {}
}

class _FakeDio {
  final List<double> scores = [72, 86, 64];
  int _scoreIndex = 0;

  String recognizedText = 'hello world';
  Map<String, dynamic>? lastTtsData;

  Future<Response<dynamic>> post(String path, {Object? data}) async {
    if (path == '/speech/assess') {
      final score = scores[_scoreIndex % scores.length];
      _scoreIndex++;
      return Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'reference_text': 'Hello world',
          'recognised_text': recognizedText,
          'overall_score': score,
          'fluency_score': score,
          'accuracy_score': score,
          'completeness_score': score,
          'prosody_score': score,
          'feedback': 'ok',
          'word_scores': <Map<String, dynamic>>[],
        },
      );
    }

    if (path == '/speech/tts') {
      lastTtsData = data as Map<String, dynamic>?;
      return Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {'audio_url': '/audio/test.mp3'},
      );
    }

    throw Exception('Unexpected POST $path');
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    throw Exception('offline');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('multi-read session tracks attempts, retry and summary', () async {
    final recorder = _FakeRecorder();
    final dio = _FakeDio();
    final notifier = PronunciationNotifier(dio, recorder: recorder);
    addTearDown(notifier.dispose);

    // Let SharedPreferences finish loading its defaults first.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    notifier.selectSentence(
      const PracticeSentenceModel(
        text: 'Hello world',
        level: 'B1',
        topic: 'Test',
        ipaTranscription: '',
      ),
    );
    notifier.setRequiredReads(3);

    expect(notifier.state.requiredReads, 3);
    expect(notifier.state.attemptsDone, 0);

    await notifier.startRecording();
    expect(notifier.state.phase, PronunciationPhase.recording);
    await notifier.stopAndAssess();

    expect(notifier.state.phase, PronunciationPhase.result);
    expect(notifier.state.attemptsDone, 1);
    expect(notifier.state.attemptResults.single.overallScore, 72);
    expect(notifier.state.isSessionComplete, isFalse);
    expect(notifier.state.nextAttemptNumber, 2);

    notifier.startNextAttempt();
    expect(notifier.state.phase, PronunciationPhase.ready);
    await notifier.startRecording();
    await notifier.stopAndAssess();

    expect(notifier.state.attemptsDone, 2);
    expect(
      notifier.state.attemptResults.map((result) => result.overallScore),
      [72, 86],
    );
    expect(notifier.state.averageAttemptScore, 79);
    expect(notifier.state.bestAttemptScore, 86);

    notifier.retryLastAttempt();
    expect(notifier.state.attemptsDone, 1);
    expect(notifier.state.attemptResults.length, 1);

    notifier.startNextAttempt();
    await notifier.startRecording();
    await notifier.stopAndAssess();
    notifier.startNextAttempt();
    await notifier.startRecording();
    await notifier.stopAndAssess();

    expect(notifier.state.attemptsDone, 3);
    expect(notifier.state.isSessionComplete, isTrue);
    expect(notifier.state.attemptResults.length, 3);

    notifier.restartSession();
    expect(notifier.state.attemptsDone, 0);
    expect(notifier.state.attemptResults, isEmpty);
    expect(notifier.state.phase, PronunciationPhase.ready);
  });

  test('unclear transcript does not count as a completed attempt', () async {
    final recorder = _FakeRecorder();
    final dio = _FakeDio()..recognizedText = '';
    final notifier = PronunciationNotifier(dio, recorder: recorder);
    addTearDown(notifier.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    notifier.selectSentence(
      const PracticeSentenceModel(
        text: 'Hello world',
        level: 'B1',
        topic: 'Test',
        ipaTranscription: '',
      ),
    );
    notifier.setRequiredReads(2);

    await notifier.startRecording();
    await notifier.stopAndAssess();

    expect(notifier.state.phase, PronunciationPhase.ready);
    expect(notifier.state.attemptsDone, 0);
    expect(notifier.state.attemptResults, isEmpty);
    expect(notifier.state.errorMessage, contains('Chưa nghe rõ'));
  });

  test('TTS request uses the selected voice and speed', () async {
    final dio = _FakeDio();
    final notifier = PronunciationNotifier(dio, recorder: _FakeRecorder());
    addTearDown(notifier.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final url = await notifier.getReferenceTTSUrl(
      'Hello world',
      voice: 'emma',
      speed: 1.25,
    );

    expect(url, isNotNull);
    expect(dio.lastTtsData?['voice'], 'emma');
    expect(dio.lastTtsData?['speed'], 1.25);
  });
}
