// Presentation state for the IELTS Mock Test runner.
//
// The notifier owns the exam clock, local answers/flags, and the network
// side effects (start → save → submit section → complete). It never throws:
// every failure ends up in `state.error` (and `MockTestPhase.error` for
// foreground loads).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock_test_repository.dart';
import '../../data/models/mock_test_models.dart';

enum MockTestPhase {
  idle,
  loading,
  ready,
  intro,
  running,
  sectionDone,
  evaluating,
  result,
  error,
}

class MockTestState {
  final MockTestPhase phase;
  final String? error;
  final List<MockTestSummary> sets;
  final MockTestSet? set;
  final MockTestAttempt? attempt;
  final String? currentSkill; // listening|reading|writing|speaking
  final List<String> plannedSkills;
  final int remainingSeconds;
  final bool paused;
  final Map<String, Map<String, String>> answers; // skill -> qid -> answer
  final Map<String, Set<String>> flagged; // skill -> qids
  final Map<String, SectionScore> scores; // skill -> score
  final MockTestResult? result;
  final List<MockTestHistoryItem> history;
  final bool submitting; // section submit / complete in flight
  final Map<String, dynamic>? attemptDetail;

  const MockTestState({
    this.phase = MockTestPhase.idle,
    this.error,
    this.sets = const [],
    this.set,
    this.attempt,
    this.currentSkill,
    this.plannedSkills = const [],
    this.remainingSeconds = 0,
    this.paused = false,
    this.answers = const {},
    this.flagged = const {},
    this.scores = const {},
    this.result,
    this.history = const [],
    this.submitting = false,
    this.attemptDetail,
  });

  // ── Convenience getters for the UI ──────────────────────

  bool get isStrict => attempt?.isStrict ?? true;

  bool get isPractice => !isStrict;

  bool get isLoading => phase == MockTestPhase.loading;

  bool get isRunning => phase == MockTestPhase.running;

  /// A network mutation is in flight (submit / complete).
  bool get isBusy => submitting || phase == MockTestPhase.evaluating;

  bool get canPause => isRunning && isPractice && !paused;

  Map<String, String> get currentAnswers =>
      currentSkill == null ? const {} : (answers[currentSkill!] ?? const {});

  Set<String> get currentFlagged =>
      currentSkill == null ? const {} : (flagged[currentSkill!] ?? const {});

  SectionScore? get currentScore =>
      currentSkill == null ? null : scores[currentSkill!];

  int get answeredCount => currentAnswers.values
      .where((answer) => answer.trim().isNotEmpty)
      .length;

  /// `mm:ss` below one hour, `hh:mm:ss` above.
  String get formattedRemaining {
    final total = remainingSeconds < 0 ? 0 : remainingSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
    return '$mm:$ss';
  }

  MockTestState copyWith({
    MockTestPhase? phase,
    String? error,
    bool clearError = false,
    List<MockTestSummary>? sets,
    MockTestSet? set,
    bool clearSet = false,
    MockTestAttempt? attempt,
    bool clearAttempt = false,
    String? currentSkill,
    bool clearCurrentSkill = false,
    List<String>? plannedSkills,
    int? remainingSeconds,
    bool? paused,
    Map<String, Map<String, String>>? answers,
    Map<String, Set<String>>? flagged,
    Map<String, SectionScore>? scores,
    MockTestResult? result,
    bool clearResult = false,
    List<MockTestHistoryItem>? history,
    bool? submitting,
    Map<String, dynamic>? attemptDetail,
    bool clearAttemptDetail = false,
  }) {
    return MockTestState(
      phase: phase ?? this.phase,
      error: clearError ? null : (error ?? this.error),
      sets: sets ?? this.sets,
      set: clearSet ? null : (set ?? this.set),
      attempt: clearAttempt ? null : (attempt ?? this.attempt),
      currentSkill:
          clearCurrentSkill ? null : (currentSkill ?? this.currentSkill),
      plannedSkills: plannedSkills ?? this.plannedSkills,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      paused: paused ?? this.paused,
      answers: answers ?? this.answers,
      flagged: flagged ?? this.flagged,
      scores: scores ?? this.scores,
      result: clearResult ? null : (result ?? this.result),
      history: history ?? this.history,
      submitting: submitting ?? this.submitting,
      attemptDetail:
          clearAttemptDetail ? null : (attemptDetail ?? this.attemptDetail),
    );
  }
}

final mockTestProvider =
    StateNotifierProvider<MockTestNotifier, MockTestState>((ref) {
  return MockTestNotifier(ref.watch(mockTestRepositoryProvider));
});

class MockTestNotifier extends StateNotifier<MockTestState> {
  MockTestNotifier(this._repository) : super(const MockTestState());

  final MockTestRepository _repository;

  Timer? _timer;
  Timer? _saveDebounce;
  Future<void>? _saveLoop;
  bool _saveRequested = false;
  bool _autoSubmitted = false;
  Map<String, dynamic>? _speakingAutoBody;

  static const int _saveDebounceMs = 1500;

  // ── Loading ─────────────────────────────────────────────

  /// GET /mock-tests. Ignored while an attempt is in progress.
  Future<bool> loadSets() async {
    if (_inExam) return false;
    state = state.copyWith(phase: MockTestPhase.loading, clearError: true);
    try {
      final sets = await _repository.fetchSets();
      if (!mounted) return false;
      state = state.copyWith(phase: MockTestPhase.ready, sets: sets);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        phase: MockTestPhase.error,
        error: _message(error),
      );
      return false;
    }
  }

  /// GET /mock-tests/{id} — sanitized set for the preview/intro screen.
  Future<bool> loadSet(String setId) async {
    if (_inExam) return false;
    state = state.copyWith(phase: MockTestPhase.loading, clearError: true);
    try {
      final set = await _repository.fetchSet(setId);
      if (!mounted) return false;
      state = state.copyWith(
        phase: MockTestPhase.ready,
        set: set,
        attempt: null,
        clearAttempt: true,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        phase: MockTestPhase.error,
        error: _message(error),
      );
      return false;
    }
  }

  /// Shows the intro/preview screen for the already loaded set.
  void openIntro() {
    if (state.set == null || _inExam) return;
    state = state.copyWith(phase: MockTestPhase.intro, clearError: true);
  }

  // ── Attempt lifecycle ───────────────────────────────────

  /// POST /mock-tests/attempts then starts the first section.
  Future<bool> start(
    String setId,
    String mode, {
    List<String>? skills,
  }) async {
    if (_inExam) return false;

    stopTimer();
    _cancelDebounce();
    _autoSubmitted = false;
    _speakingAutoBody = null;

    final normalizedMode = mode == 'practice' ? 'practice' : 'strict';
    final requested = (skills ?? const <String>[])
        .map((skill) => skill.trim().toLowerCase())
        .where((skill) => skill.isNotEmpty)
        .toList(growable: false);

    state = state.copyWith(
      phase: MockTestPhase.loading,
      clearError: true,
      paused: false,
    );

    try {
      var set = state.set;
      if (set == null || set.id != setId) {
        set = await _repository.fetchSet(setId);
        if (!mounted) return false;
      }

      final attempt = await _repository.startAttempt(
        setId,
        normalizedMode,
        skills: requested,
      );
      if (!mounted) return false;

      var planned = attempt.sections
          .map((section) => section.skill.trim().toLowerCase())
          .where((skill) => skill.isNotEmpty)
          .toList();
      if (planned.isEmpty) {
        planned = requested.isNotEmpty ? List<String>.from(requested) : [];
      }
      if (planned.isEmpty) {
        planned = List<String>.from(set.skills);
      }
      if (planned.isEmpty) {
        throw const MockTestException('This mock test has no sections to run.');
      }

      final firstSkill = planned.first;
      final remaining = _initialRemaining(attempt, set, firstSkill);

      state = state.copyWith(
        phase: MockTestPhase.running,
        set: set,
        attempt: attempt,
        plannedSkills: planned,
        currentSkill: firstSkill,
        remainingSeconds: remaining,
        paused: false,
        answers: _emptyAnswers(planned),
        flagged: _emptyFlags(planned),
        scores: const {},
        clearResult: true,
        submitting: false,
        clearError: true,
      );

      startTimer();
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        phase: MockTestPhase.error,
        error: _message(error),
        submitting: false,
        paused: false,
      );
      return false;
    }
  }

  // ── Clock ───────────────────────────────────────────────

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Keeps the latest speaking payload so a timeout submit can include it.
  void setSpeakingAutoBody(Map<String, dynamic>? body) {
    _speakingAutoBody = body;
  }

  void _tick() {
    if (!mounted) return;
    if (state.paused || state.phase != MockTestPhase.running) return;

    if (state.remainingSeconds <= 0) {
      autoSubmitCurrentSection();
      return;
    }

    final next = state.remainingSeconds - 1;
    state = state.copyWith(remainingSeconds: next < 0 ? 0 : next);
    if (next <= 0) {
      autoSubmitCurrentSection();
    }
  }

  /// Pauses the clock. Practice mode only — strict mode ignores it.
  bool pause() {
    if (state.phase != MockTestPhase.running || state.isStrict) return false;
    if (state.paused) return true;
    stopTimer();
    state = state.copyWith(paused: true);
    return true;
  }

  void resume() {
    if (!state.paused) return;
    if (state.phase != MockTestPhase.running) return;
    state = state.copyWith(paused: false);
    startTimer();
  }

  // ── Answers ─────────────────────────────────────────────

  /// Updates `answers[currentSkill][questionId]` and schedules a debounced
  /// save (1.5s). An empty value removes the answer.
  void setAnswer(String questionId, String value) {
    final skill = state.currentSkill;
    if (skill == null || state.phase != MockTestPhase.running) return;

    final answers = _copyAnswers(state.answers);
    final skillAnswers = Map<String, String>.from(
      answers[skill] ?? const <String, String>{},
    );
    if (value.trim().isEmpty) {
      skillAnswers.remove(questionId);
    } else {
      skillAnswers[questionId] = value;
    }
    answers[skill] = skillAnswers;

    state = state.copyWith(answers: answers, clearError: true);
    _scheduleSave();
  }

  void toggleFlag(String questionId) {
    final skill = state.currentSkill;
    if (skill == null || state.phase != MockTestPhase.running) return;

    final flagged = _copyFlags(state.flagged);
    final skillFlags = Set<String>.from(
      flagged[skill] ?? const <String>{},
    );
    if (!skillFlags.remove(questionId)) {
      skillFlags.add(questionId);
    }
    flagged[skill] = skillFlags;

    state = state.copyWith(flagged: flagged, clearError: true);
    _scheduleSave();
  }

  /// Immediate save, e.g. before submitting or when the app goes to
  /// background. Coalesces concurrent calls: the returned future completes
  /// after every queued save finished.
  Future<void> saveNow() {
    _cancelDebounce();
    _saveRequested = true;
    final running = _saveLoop;
    if (running != null) return running;
    final loop = _runSaveLoop();
    _saveLoop = loop;
    return loop;
  }

  Future<void> _runSaveLoop() async {
    while (_saveRequested) {
      _saveRequested = false;
      await _performSave();
    }
    _saveLoop = null;
  }

  Future<void> _performSave() async {
    if (!mounted) return;
    if (state.phase != MockTestPhase.running) return;

    final attempt = state.attempt;
    final skill = state.currentSkill;
    if (attempt == null || skill == null) return;

    final answers = Map<String, String>.from(
      state.answers[skill] ?? const <String, String>{},
    );
    final flagged = (state.flagged[skill] ?? const <String>{})
        .toList(growable: false);
    final remaining = state.remainingSeconds;

    try {
      await _repository.saveProgress(
        attempt.id,
        skill,
        answers,
        flagged,
        remaining,
      );
    } catch (error) {
      if (!mounted) return;
      // Background save failure: keep the exam running, just surface it.
      state = state.copyWith(error: _message(error));
    }
  }

  // ── Sections ────────────────────────────────────────────

  /// Submits the current section and stores its score.
  ///
  /// - listening/reading/writing: `{"answers": {...}}`
  /// - speaking: exactly the body passed through [extraBody]
  ///   (`part1_qa`, `part2_answer`, `part3_qa`, `follow_up_qa`).
  Future<bool> submitCurrentSection({Map<String, dynamic>? extraBody}) async {
    if (state.submitting) return false;
    if (state.phase == MockTestPhase.sectionDone ||
        state.phase == MockTestPhase.result ||
        state.phase == MockTestPhase.evaluating) {
      return false;
    }

    final attempt = state.attempt;
    final skill = state.currentSkill;
    if (attempt == null || skill == null) return false;

    stopTimer();
    _cancelDebounce();
    state = state.copyWith(
      submitting: true,
      paused: false,
      clearError: true,
    );

    try {
      await saveNow();
      if (!mounted) return false;

      final answers = Map<String, String>.from(
        state.answers[skill] ?? const <String, String>{},
      );
      final body = <String, dynamic>{};
      if (skill == 'speaking') {
        if (extraBody != null) {
          body.addAll(extraBody);
        } else if (_speakingAutoBody != null) {
          // Timeout fallback: use the latest payload reported by the section.
          body.addAll(_speakingAutoBody!);
        }
      } else {
        body['answers'] = answers;
        if (extraBody != null) body.addAll(extraBody);
      }

      final score = await _repository.submitSection(attempt.id, skill, body);
      if (!mounted) return false;

      final scores = Map<String, SectionScore>.from(state.scores);
      scores[skill] = score;

      state = state.copyWith(
        scores: scores,
        phase: MockTestPhase.sectionDone,
        submitting: false,
        clearError: true,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        submitting: false,
        error: _message(error),
      );
      // Resume the clock when time is left (manual submit failure).
      if (state.phase == MockTestPhase.running &&
          state.remainingSeconds > 0 &&
          !state.paused) {
        startTimer();
      }
      return false;
    }
  }

  /// Timeout handler — runs at most once per section.
  Future<void> autoSubmitCurrentSection() async {
    if (_autoSubmitted || state.submitting) return;
    if (state.phase != MockTestPhase.running) return;

    _autoSubmitted = true;
    stopTimer();
    if (state.remainingSeconds > 0) {
      state = state.copyWith(remainingSeconds: 0);
    }
    await submitCurrentSection();
  }

  /// Moves to the next unscored planned section, or completes the attempt
  /// when every section has a score.
  Future<bool> nextSection() async {
    if (state.submitting) return false;

    final planned = state.plannedSkills;
    if (planned.isEmpty) return false;

    final currentDone = state.phase == MockTestPhase.sectionDone;
    if (!currentDone &&
        !state.scores.containsKey(state.currentSkill ?? '')) {
      state = state.copyWith(
        error: 'Submit this section before moving on.',
      );
      return false;
    }

    String? next;
    for (final skill in planned) {
      if (state.scores.containsKey(skill)) continue;
      if (!currentDone && skill == state.currentSkill) continue;
      next = skill;
      break;
    }

    if (next == null) {
      return complete();
    }

    stopTimer();
    _cancelDebounce();
    _autoSubmitted = false;
    _speakingAutoBody = null;

    final answers = _copyAnswers(state.answers);
    answers.putIfAbsent(next, () => <String, String>{});
    final flagged = _copyFlags(state.flagged);
    flagged.putIfAbsent(next, () => <String>{});

    state = state.copyWith(
      phase: MockTestPhase.running,
      currentSkill: next,
      remainingSeconds: _durationFor(next),
      paused: false,
      answers: answers,
      flagged: flagged,
      clearError: true,
    );
    startTimer();
    return true;
  }

  /// Practice mode only: jump back to a previous section. Strict mode
  /// ignores it.
  bool goToSection(String skill) {
    if (state.isStrict) return false;
    if (!state.plannedSkills.contains(skill)) return false;
    if (state.submitting) return false;
    if (state.phase == MockTestPhase.result ||
        state.phase == MockTestPhase.evaluating) {
      return false;
    }

    stopTimer();
    _cancelDebounce();
    _autoSubmitted = false;
    _speakingAutoBody = null;

    state = state.copyWith(
      phase: MockTestPhase.running,
      currentSkill: skill,
      remainingSeconds: _durationFor(skill),
      paused: false,
      clearError: true,
    );
    startTimer();
    return true;
  }

  /// POST /mock-tests/attempts/{id}/complete
  Future<bool> complete() async {
    final attempt = state.attempt;
    if (attempt == null) return false;
    if (state.submitting) return false;
    if (state.phase == MockTestPhase.result) return false;

    stopTimer();
    _cancelDebounce();
    state = state.copyWith(
      phase: MockTestPhase.evaluating,
      submitting: true,
      paused: false,
      clearError: true,
    );

    try {
      final result = await _repository.completeAttempt(attempt.id);
      if (!mounted) return false;

      final scores = Map<String, SectionScore>.from(state.scores)
        ..addAll(result.skills);

      state = state.copyWith(
        phase: MockTestPhase.result,
        result: result,
        scores: scores,
        submitting: false,
        clearError: true,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        phase: MockTestPhase.error,
        submitting: false,
        error: _message(error),
      );
      return false;
    }
  }

  // ── History & review ────────────────────────────────────

  Future<bool> loadHistory() async {
    final wasIdle = state.phase == MockTestPhase.idle;
    if (wasIdle) {
      state = state.copyWith(phase: MockTestPhase.loading, clearError: true);
    }
    try {
      final history = await _repository.fetchHistory();
      if (!mounted) return false;
      state = state.copyWith(
        history: history,
        phase: wasIdle ? MockTestPhase.ready : state.phase,
        clearError: true,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        phase: wasIdle ? MockTestPhase.error : state.phase,
        error: _message(error),
      );
      return false;
    }
  }

  Future<bool> loadAttemptDetail(String attemptId) async {
    final wasIdle = state.phase == MockTestPhase.idle;
    if (wasIdle) {
      state = state.copyWith(phase: MockTestPhase.loading, clearError: true);
    }
    try {
      final detail = await _repository.fetchAttemptDetail(attemptId);
      if (!mounted) return false;
      state = state.copyWith(
        attemptDetail: detail,
        phase: wasIdle ? MockTestPhase.ready : state.phase,
        clearError: true,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        phase: wasIdle ? MockTestPhase.error : state.phase,
        error: _message(error),
      );
      return false;
    }
  }

  /// Clears the attempt but keeps the loaded set list/history.
  void reset() {
    stopTimer();
    _cancelDebounce();
    _autoSubmitted = false;
    _speakingAutoBody = null;
    _saveRequested = false;
    _saveLoop = null;

    state = MockTestState(
      phase: state.sets.isEmpty ? MockTestPhase.idle : MockTestPhase.ready,
      sets: state.sets,
      history: state.history,
    );
  }

  // ── Internals ───────────────────────────────────────────

  bool get _inExam =>
      state.phase == MockTestPhase.running ||
      state.phase == MockTestPhase.sectionDone ||
      state.phase == MockTestPhase.evaluating;

  void _scheduleSave() {
    if (!mounted) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: _saveDebounceMs),
      () => saveNow(),
    );
  }

  void _cancelDebounce() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
  }

  int _durationFor(String skill) {
    final attempt = state.attempt;
    if (attempt != null) {
      for (final section in attempt.sections) {
        if (section.skill == skill && section.durationSeconds > 0) {
          return section.durationSeconds;
        }
      }
    }

    final set = state.set;
    if (set != null) {
      switch (skill) {
        case 'listening':
          final listening = set.listening;
          if (listening != null && listening.durationSeconds > 0) {
            return listening.durationSeconds;
          }
          break;
        case 'reading':
          final reading = set.reading;
          if (reading != null && reading.durationSeconds > 0) {
            return reading.durationSeconds;
          }
          break;
        case 'writing':
          final writing = set.writing;
          if (writing != null && writing.durationSeconds > 0) {
            return writing.durationSeconds;
          }
          break;
        case 'speaking':
          final speaking = set.speaking;
          if (speaking != null && speaking.durationSeconds > 0) {
            return speaking.durationSeconds;
          }
          break;
      }
    }

    return _defaultDuration(skill);
  }

  int _initialRemaining(
    MockTestAttempt attempt,
    MockTestSet set,
    String skill,
  ) {
    final duration = _durationFor(skill);
    final startedAt = attempt.startedAt;
    if (startedAt == null) return duration;

    // The server clock is authoritative: elapsed time still counts after an
    // app restart, so the section is never reset.
    final elapsed =
        DateTime.now().toUtc().difference(startedAt.toUtc()).inSeconds;
    if (elapsed <= 0) return duration;

    final left = duration - elapsed;
    return left < 0 ? 0 : left;
  }

  static int _defaultDuration(String skill) {
    switch (skill) {
      case 'listening':
        return 1800;
      case 'reading':
        return 3600;
      case 'writing':
        return 3600;
      case 'speaking':
        return 840;
      default:
        return 1800;
    }
  }

  Map<String, Map<String, String>> _emptyAnswers(List<String> skills) {
    return <String, Map<String, String>>{
      for (final skill in skills) skill: <String, String>{},
    };
  }

  Map<String, Set<String>> _emptyFlags(List<String> skills) {
    return <String, Set<String>>{
      for (final skill in skills) skill: <String>{},
    };
  }

  Map<String, Map<String, String>> _copyAnswers(
    Map<String, Map<String, String>> source,
  ) {
    return <String, Map<String, String>>{
      for (final entry in source.entries)
        entry.key: Map<String, String>.from(entry.value),
    };
  }

  Map<String, Set<String>> _copyFlags(Map<String, Set<String>> source) {
    return <String, Set<String>>{
      for (final entry in source.entries)
        entry.key: Set<String>.from(entry.value),
    };
  }

  String _message(Object error) {
    if (error is MockTestException) return error.message;
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    stopTimer();
    _cancelDebounce();
    super.dispose();
  }
}
