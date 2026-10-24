import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

import 'package:flutter/foundation.dart';

Completer<void>? _current;

void _finishCurrent() {
  final c = _current;
  _current = null;
  if (c != null && !c.isCompleted) c.complete();
}

void _complete(Completer<void> completer) {
  if (!completer.isCompleted) completer.complete();
  if (identical(_current, completer)) _current = null;
}

Future<void> webSpeak(String text, double rate) {
  _finishCurrent();
  final completer = Completer<void>();
  _current = completer;

  try {
    final literal = jsonEncode(text.replaceAll(RegExp(r'\s+'), ' ').trim());

    js.context.callMethod('eval', [
      '''
      (function() {
        if (!('speechSynthesis' in window)) { window._flutterTtsActive = false; return; }
        clearTimeout(window._flutterTtsTimer);
        window._flutterTtsTimer = null;
        window.speechSynthesis.cancel();
        if (window.speechSynthesis.paused) {
          window.speechSynthesis.resume();
        }
        var u = new SpeechSynthesisUtterance($literal);
        var timerId = null;
        u.lang = 'en-US';
        u.rate = $rate;
        u.onend = function() {
          if (window._flutterTtsTimer === timerId) window._flutterTtsTimer = null;
          window._flutterTtsActive = false;
        };
        u.onerror = function() {
          if (window._flutterTtsTimer === timerId) window._flutterTtsTimer = null;
          window._flutterTtsActive = false;
        };
        window._flutterTtsUtterance = u;
        window._flutterTtsActive = true;
        timerId = setTimeout(function() {
          if (window._flutterTtsTimer === timerId) window._flutterTtsTimer = null;
          window.speechSynthesis.speak(u);
        }, 60);
        window._flutterTtsTimer = timerId;
      })()
      '''
    ]);
  } catch (e) {
    debugPrint('Web TTS Error: $e');
    _finishCurrent();
    return Future<void>.value();
  }

  final safetyMs = (text.length * 150 / rate).round() + 4000;
  _pollUntilDone(completer, safetyMs);
  return completer.future;
}

void _pollUntilDone(Completer<void> completer, int safetyMs) {
  final deadline = DateTime.now().add(Duration(milliseconds: safetyMs));

  void poll() {
    if (completer.isCompleted) return;
    if (DateTime.now().isAfter(deadline)) {
      _complete(completer);
      return;
    }

    bool speaking = false;
    try {
      final result = js.context.callMethod('eval', [
        "window._flutterTtsActive === true && window.speechSynthesis.speaking === true",
      ]);
      speaking = result == true;
    } catch (_) {
      speaking = false;
    }

    if (!speaking) {
      _complete(completer);
      return;
    }
    Future.delayed(const Duration(milliseconds: 200), poll);
  }

  Future.delayed(const Duration(milliseconds: 200), poll);
}

void webStop() {
  _finishCurrent();
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        clearTimeout(window._flutterTtsTimer);
        window._flutterTtsTimer = null;
        if ('speechSynthesis' in window) {
          window._flutterTtsActive = false;
          window.speechSynthesis.cancel();
        }
      })()
      '''
    ]);
  } catch (e) {
    debugPrint('Web TTS Stop Error: $e');
  }
}
