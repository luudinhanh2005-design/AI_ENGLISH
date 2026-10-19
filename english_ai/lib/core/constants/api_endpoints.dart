import 'app_config.dart';

/// API configuration constants.
/// The base URL is resolved centrally in [AppConfig] and can be overridden
/// at build time with `--dart-define=API_BASE_URL=...`.
class ApiEndpoints {
  ApiEndpoints._();

  static String get baseUrl => AppConfig.apiBaseUrlV1;

  // ── Auth ──────────────────────────────────────
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String googleAuth = '/auth/google';

  // ── User ──────────────────────────────────────
  static const String userMe = '/users/me';
  static const String userOnboarding = '/users/me/onboarding';

  // ── Placement Test ────────────────────────────
  static const String placementQuestions = '/placement/questions';
  static const String placementSubmit = '/placement/submit';

  // ── Vocabulary & Spaced Repetition (SM-2) ─────
  static const String vocabularyTopics = '/vocabulary/topics';
  static String vocabularyTopicWords(String topicId) =>
      '/vocabulary/topics/$topicId/words';
  static const String vocabularyDue = '/vocabulary/due';
  static String vocabularyReviewWord(String wordId) =>
      '/vocabulary/words/$wordId/review';

  // ── Grammar Lessons ───────────────────────────
  static const String grammarLessons = '/grammar/lessons';
  static String grammarLessonById(String id) => '/grammar/lessons/$id';
  static String grammarSubmitLesson(String id) => '/grammar/lessons/$id/submit';

  // ── AI Tutor & Intelligent Engine ─────────────
  static const String aiStatus = '/ai/status';
  static const String aiChat = '/ai/chat';
  static const String aiTranslate = '/ai/translate';
  static const String aiSessions = '/ai/sessions';
  static String aiSessionMessages(String sessionId) =>
      '/ai/sessions/$sessionId/messages';
  static const String aiGenerateExercises = '/ai/generate-exercises';
  static const String aiEvaluateWriting = '/ai/evaluate-writing';

  // ── Speech AI & Pronunciation ─────────────────
  static const String speechAssess = '/speech/assess';
  static const String speechTranscribe = '/speech/transcribe';
  static const String speechTts = '/speech/tts';
  static const String speechPractice = '/speech/practice';
  static const String speechDrills = '/speech/drills';
  static const String speechHistory = '/speech/history';
  static const String speechStats = '/speech/stats';
}
