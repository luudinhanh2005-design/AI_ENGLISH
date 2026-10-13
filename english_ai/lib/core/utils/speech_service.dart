import 'speech_web.dart' if (dart.library.io) 'speech_io.dart';

class SpeechService {
  SpeechService._();

  static Future<void> speak(String text, {double rate = 0.95}) {
    if (text.trim().isEmpty) return Future<void>.value();
    return webSpeak(text, rate);
  }

  static void stop() {
    webStop();
  }
}