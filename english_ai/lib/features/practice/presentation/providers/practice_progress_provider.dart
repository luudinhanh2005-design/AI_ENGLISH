import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/practice_progress_store.dart';

/// Practice accuracy + daily goal, persisted locally.
final practiceProgressProvider =
    StateNotifierProvider<PracticeProgressNotifier, PracticeProgress>((ref) {
  return PracticeProgressNotifier();
});

class PracticeProgressNotifier extends StateNotifier<PracticeProgress> {
  Future<void> _saveChain = Future<void>.value();
  bool _hasLocalMutation = false;

  PracticeProgressNotifier() : super(PracticeProgress.empty()) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final loaded = await PracticeProgressStore.load();
    // A fast first answer may finish before the initial read. Never replace it
    // with the older persisted value.
    if (mounted && !_hasLocalMutation) state = loaded;
  }

  Future<void> recordAnswer({required bool correct}) async {
    _hasLocalMutation = true;
    final next = state.recordAnswer(correct: correct);
    state = next;
    _saveChain = _saveChain.then((_) => PracticeProgressStore.save(next));
    await _saveChain;
  }

  Future<void> reload() async {
    final loaded = await PracticeProgressStore.load();
    if (mounted) state = loaded;
  }
}
