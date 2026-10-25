import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/placement_models.dart';
import '../../data/repositories/placement_repository.dart';

class PlacementState {
  final bool initialized;
  final bool isLoading;
  final bool isSaving;
  final bool isSubmitting;
  final String? errorMessage;
  final PlacementConfigModel? config;
  final PlacementSessionModel? session;
  final PlacementResultModel? result;
  final PlacementResultModel? latestResult;
  final List<PlacementHistoryEntryModel> history;

  const PlacementState({
    this.initialized = false,
    this.isLoading = false,
    this.isSaving = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.config,
    this.session,
    this.result,
    this.latestResult,
    this.history = const [],
  });

  PlacementState copyWith({
    bool? initialized,
    bool? isLoading,
    bool? isSaving,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    PlacementConfigModel? config,
    PlacementSessionModel? session,
    bool clearSession = false,
    PlacementResultModel? result,
    bool clearResult = false,
    PlacementResultModel? latestResult,
    List<PlacementHistoryEntryModel>? history,
  }) {
    return PlacementState(
      initialized: initialized ?? this.initialized,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      config: config ?? this.config,
      session: clearSession ? null : (session ?? this.session),
      result: clearResult ? null : (result ?? this.result),
      latestResult: clearResult ? null : (latestResult ?? this.latestResult),
      history: history ?? this.history,
    );
  }

  PlacementCurrentModel? get current => session?.current;
  bool get inProgress => session != null && !(session?.completed ?? false);
}

final placementProvider =
    StateNotifierProvider<PlacementNotifier, PlacementState>((ref) {
  return PlacementNotifier(
    ref,
    PlacementRepository(ref.watch(dioProvider)),
  );
});

class PlacementNotifier extends StateNotifier<PlacementState> {
  final Ref _ref;
  final PlacementRepository _repository;

  static const _prefsSessionKey = 'placement_session_id';
  bool _initializing = false;

  PlacementNotifier(this._ref, this._repository)
      : super(const PlacementState()) {
    initialize();
  }

  // ── Boot ───────────────────────────────────────

  Future<void> initialize({bool force = false}) async {
    if (_initializing) return;
    if (state.initialized && !force) return;
    _initializing = true;
    state = state.copyWith(isLoading: true, clearError: true);

    PlacementConfigModel config;
    try {
      config = await _repository.getConfig();
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        initialized: true,
        isLoading: false,
        errorMessage: _errorMessage(
          error,
          fallback: 'Không thể tải bài kiểm tra trình độ. Vui lòng thử lại.',
        ),
      );
      _initializing = false;
      return;
    }

    // Latest result and history are supplementary. A failure here (for
    // example the normal 404 when a user has never taken the test) must not
    // prevent the intro screen from opening.
    PlacementResultModel? latestResult;
    List<PlacementHistoryEntryModel> history = const [];
    try {
      latestResult = await _repository.getLatestResult();
    } catch (_) {
      latestResult = null;
    }
    try {
      history = await _repository.getHistory(limit: 8);
    } catch (_) {
      history = const [];
    }

    if (!mounted) return;
    state = state.copyWith(
      initialized: true,
      isLoading: false,
      config: config,
      latestResult: latestResult,
      history: history,
      clearError: true,
    );
    await _restoreSession();
    _initializing = false;
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(_prefsSessionKey);
      if (sessionId == null || sessionId.isEmpty) return;
      final session = await _repository.getSession(sessionId);
      if (!mounted) return;
      if (session.completed && session.result != null) {
        state = state.copyWith(
          result: session.result,
          latestResult: session.result,
          clearSession: true,
        );
        await _clearSavedSession();
      } else if (session.isInProgress) {
        state = state.copyWith(session: session, clearError: true);
      } else {
        await _clearSavedSession();
      }
    } catch (_) {
      await _clearSavedSession();
    }
  }

  // ── Session lifecycle ─────────────────────────

  Future<bool> start({
    required String mode,
    required String targetExam,
  }) async {
    state = state.copyWith(
      isLoading: true,
      isSubmitting: true,
      clearError: true,
      clearResult: true,
    );
    try {
      final session = await _repository.createSession(
        mode: mode,
        targetExam: targetExam,
      );
      await _saveSessionId(session.sessionId);
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        isSubmitting: false,
        session: session,
        clearError: true,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        isSubmitting: false,
        errorMessage: _errorMessage(
          error,
          fallback: 'Không thể bắt đầu bài kiểm tra. Vui lòng thử lại.',
        ),
      );
      return false;
    }
  }

  Future<void> refreshSession() async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null) return;
    try {
      final session = await _repository.getSession(sessionId);
      if (!mounted) return;
      await _applySession(session);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: _errorMessage(
          error,
          fallback: 'Không thể đồng bộ phiên kiểm tra.',
        ),
      );
    }
  }

  Future<bool> saveAnswer({
    required String itemId,
    required List<String> answer,
    int responseTimeMs = 0,
  }) async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repository.saveAnswer(
        sessionId: sessionId,
        itemId: itemId,
        answer: answer,
        responseTimeMs: responseTimeMs,
      );
      if (!mounted) return false;
      state = state.copyWith(isSaving: false);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        isSaving: false,
        errorMessage: _errorMessage(
          error,
          fallback: 'Không thể lưu câu trả lời. Kiểm tra kết nối và thử lại.',
        ),
      );
      return false;
    }
  }

  Future<bool> completeStage({
    required String stageToken,
    required Map<String, List<String>> answers,
    Map<String, int> responseTimes = const {},
  }) async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final session = await _repository.completeStage(
        sessionId: sessionId,
        stageToken: stageToken,
        answers: answers,
        responseTimes: responseTimes,
      );
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false);
      await _applySession(session);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _errorMessage(
          error,
          fallback: 'Không thể hoàn thành chặng thi. Vui lòng thử lại.',
        ),
      );
      return false;
    }
  }

  Future<bool> submitWriting({
    required String taskId,
    required String text,
    int responseTimeMs = 0,
  }) async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final session = await _repository.submitWriting(
        sessionId: sessionId,
        taskId: taskId,
        text: text,
        responseTimeMs: responseTimeMs,
      );
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false);
      await _applySession(session);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _errorMessage(
          error,
          fallback: 'Không thể gửi bài viết. Vui lòng thử lại.',
        ),
      );
      return false;
    }
  }

  Future<bool> submitSpeaking({
    required String taskId,
    required Uint8List audioBytes,
  }) async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final session = await _repository.submitSpeaking(
        sessionId: sessionId,
        taskId: taskId,
        audioBytes: audioBytes,
      );
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false);
      await _applySession(session);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _errorMessage(
          error,
          fallback: 'Không thể gửi bài nói. Vui lòng thử lại.',
        ),
      );
      return false;
    }
  }

  Future<bool> skipSpeaking({required String taskId}) async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final session = await _repository.skipSpeaking(
        sessionId: sessionId,
        taskId: taskId,
      );
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false);
      await _applySession(session);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _errorMessage(
          error,
          fallback: 'Không thể bỏ qua nhiệm vụ nói. Vui lòng thử lại.',
        ),
      );
      return false;
    }
  }

  Future<void> _applySession(PlacementSessionModel session) async {
    if (session.completed && session.result != null) {
      state = state.copyWith(
        session: session,
        result: session.result,
        latestResult: session.result,
        clearError: true,
      );
      await _clearSavedSession();
      unawaited(
        _ref.read(authStateProvider.notifier).refreshUser().catchError((_) {}),
      );
      await loadHistory();
      return;
    }
    state = state.copyWith(session: session, clearError: true);
  }

  Future<void> loadHistory() async {
    try {
      final history = await _repository.getHistory(limit: 8);
      if (!mounted) return;
      state = state.copyWith(history: history);
    } catch (_) {
      // History is supplementary; keep the current list on failure.
    }
  }

  Future<bool> openHistoryResult(String resultId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repository.getResult(resultId);
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, result: result);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: _errorMessage(
          error,
          fallback: 'Không thể tải kết quả đã lưu.',
        ),
      );
      return false;
    }
  }

  Future<void> abandonCurrentSession() async {
    final sessionId = state.session?.sessionId;
    if (sessionId == null) return;
    try {
      await _repository.abandonSession(sessionId);
    } catch (_) {
      // Best effort only.
    }
    await _clearSavedSession();
    if (!mounted) return;
    state = state.copyWith(clearSession: true, clearError: true);
  }

  void clearError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(clearError: true);
  }

  void dismissResult() {
    state = state.copyWith(clearResult: true);
    refreshLatest();
  }

  Future<void> refreshLatest() async {
    try {
      final latest = await _repository.getLatestResult();
      if (!mounted) return;
      if (latest == null) {
        state = state.copyWith(clearResult: true);
        return;
      }
      state = state.copyWith(latestResult: latest);
    } catch (_) {
      // Ignore; latest result is optional.
    }
  }

  // ── Persistence helpers ───────────────────────

  Future<void> _saveSessionId(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsSessionKey, sessionId);
    } catch (_) {
      // Offline persistence is best effort.
    }
  }

  Future<void> _clearSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsSessionKey);
    } catch (_) {
      // Ignore.
    }
  }

  String _errorMessage(Object error, {required String fallback}) {
    if (error is ServerException) {
      if (error.statusCode == 401) {
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      }
      return error.message.isNotEmpty ? error.message : fallback;
    }
    if (error is AuthException) {
      return error.message.isNotEmpty ? error.message : fallback;
    }
    if (error is NetworkException) {
      return 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.';
    }
    if (error is ValidationException) {
      return error.message.isNotEmpty ? error.message : fallback;
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.response?.statusCode == 401) {
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.';
      }
    }
    return fallback;
  }
}
