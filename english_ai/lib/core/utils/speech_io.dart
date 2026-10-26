import 'package:flutter_tts/flutter_tts.dart';

FlutterTts? _tts;

FlutterTts _getTts() {
  _tts ??= FlutterTts();
  return _tts!;
}

Future<void> webSpeak(String text, double rate) async {
  await speakWithLang(text, 'en-US', rate);
}

Future<void> speakWithLang(String text, String lang, [double rate = 0.5]) async {
  try {
    final tts = _getTts();
    await tts.setLanguage(lang);
    await tts.setSpeechRate(rate.clamp(0.2, 1.0));
    await tts.setPitch(1.0);
    await tts.speak(text);
  } catch (e) {
    // Graceful fallback if TTS engine is uninitialized in test/mock environment
  }
}

void webStop() {
  try {
    _tts?.stop();
  } catch (_) {}
}
