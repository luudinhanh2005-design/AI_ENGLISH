import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  /// Amplitude (dBFS, ~-160..0) samples while recording; used to detect speech/silence.
  Stream<Amplitude> amplitudeStream([
    Duration interval = const Duration(milliseconds: 200),
  ]) {
    return _recorder.onAmplitudeChanged(interval);
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

    // record yêu cầu đường dẫn file thật trên Android/iOS/desktop.
    // Trên web, plugin dùng MediaRecorder và bỏ qua path.
    var path = '';
    if (!kIsWeb) {
      final directory = await getTemporaryDirectory();
      path =
          '${directory.path}/pronunciation_${DateTime.now().millisecondsSinceEpoch}.wav';
    }

    await _recorder.start(
      config,
      path: path,
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
          final bytes = await file.readAsBytes();
          // Dọn file tạm sau khi đã đọc xong.
          try {
            await file.delete();
          } catch (_) {}
          return bytes;
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
