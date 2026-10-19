import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  Future<void> startRecording() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      throw Exception('Microphone permission not granted');
    }

    // Browsers on Web (Chrome/Edge) support opus for MediaRecorder
    final config = RecordConfig(
      encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    );

    await _recorder.start(
      config,
      path: '',
    );
  }

  Future<Uint8List?> stopRecording() async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) return null;

    if (kIsWeb || path.startsWith('blob:') || path.startsWith('http')) {
      final bytes = await http.readBytes(Uri.parse(path));
      return bytes;
    } else {
      try {
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (e) {
        debugPrint('Error reading recorded file: $e');
      }
      return null;
    }
  }

  Future<void> cancelRecording() async {
    await _recorder.cancel();
  }

  void dispose() {
    _recorder.dispose();
  }
}