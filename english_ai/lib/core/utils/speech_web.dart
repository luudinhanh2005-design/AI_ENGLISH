import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

import 'package:flutter/foundation.dart';

Completer<void>? _current;
int _seq = 0;

void _finishCurrent() {
  final c = _current;
  _current = null;
  if (c != null && !c.isCompleted) c.complete();
}

Future<void> webSpeak(String text, double rate) {
  _finishCurrent();
  final completer = Completer<void>();
  _current = completer;
  final id = ++_seq;

  try {
    js.context['__flutterTtsDone'] = js.allowInterop((dynamic doneId) {
      if (doneId == id && identical(_current, completer)) {
        _current = null;
        if (!completer.isCompleted) completer.complete();
      }
    });

    final literal = jsonEncode(text.replaceAll(RegExp(r'\s+'), ' ').trim());

    js.context.callMethod('eval', [
      '''
      (function() {
        if (!('speechSynthesis' in window)) { window.__flutterTtsDone($id); return; }
        window.speechSynthesis.cancel();
        var u = new SpeechSynthesisUtterance($literal);
        u.lang = 'en-US';
        u.rate = $rate;
        u.onend = function() { window.__flutterTtsDone($id); };
        u.onerror = function() { window.__flutterTtsDone($id); };
        window._flutterTtsUtterance = u;
        setTimeout(function() { window.speechSynthesis.speak(u); }, 60);
      })()
      '''
    ]);
  } catch (e) {
    debugPrint('Web TTS Error: $e');
    _finishCurrent();
    return Future<void>.value();
  }

  final safetyMs = (text.length * 150 / rate).round() + 4000;
  return completer.future.timeout(
    Duration(milliseconds: safetyMs),
    onTimeout: () {
      if (identical(_current, completer)) _current = null;
    },
  );
}

void webStop() {
  _finishCurrent();
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