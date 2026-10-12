// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

void webSpeak(String text, double rate) {
  try {
    final sanitized = text
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('"', r'\"')
        .replaceAll('\n', ' ');
    js.context.callMethod('eval', [
      '''
      (function() {
        if ('speechSynthesis' in window) {
          window.speechSynthesis.cancel();
          var u = new SpeechSynthesisUtterance("$sanitized");
          u.lang = 'en-US';
          u.rate = $rate;
          window.speechSynthesis.speak(u);
        }
      })()
      '''
    ]);
  } catch (e) {
    debugPrint('Web TTS Error: $e');
  }
}

void webStop() {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        if ('speechSynthesis' in window) {
          window.speechSynthesis.cancel();
        }
      })()
      '''
    ]);
  } catch (e) {
    debugPrint('Web TTS Stop Error: $e');
  }
}
