import 'speech_web.dart' if (dart.library.io) 'speech_io.dart';

class SpeechService {
  SpeechService._();

  static void speak(String text, {double rate = 0.95}) {
    if (text.trim().isEmpty) return;
    webSpeak(text, rate);
  }

  static void stop() {
    webStop();
  }
}
