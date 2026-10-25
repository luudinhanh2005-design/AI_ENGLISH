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

  // ── Placement Test (CEFR adaptive v2) ─────────
  static const String placementConfig = '/placement/config';
  static const String placementSessions = '/placement/sessions';
  static const String placementLatestResult = '/placement/results/latest';
  static const String placementHistory = '/placement/history';
  static String placementSession(String sessionId) =>
      '/placement/sessions/$sessionId';
  static String placementAnswers(String sessionId) =>
      '/placement/sessions/$sessionId/answers';
  static String placementCompleteStage(String sessionId) =>
      '/placement/sessions/$sessionId/stages/complete';
  static String placementWriting(String sessionId) =>
      '/placement/sessions/$sessionId/writing';
  static String placementSpeaking(String sessionId) =>
      '/placement/sessions/$sessionId/speaking';
  static String placementSkipSpeaking(String sessionId) =>
      '/placement/sessions/$sessionId/speaking/skip';
  static String placementResult(String resultId) =>
      '/placement/results/$resultId';

  // ── Vocabulary & Spaced Repetition (SM-2) ─────
  static const String vocabularyTopics = '/vocabulary/topics';
  static const String vocabularyWords = '/vocabulary/words';
  static const String vocabularyStats = '/vocabulary/stats';
  static String vocabularyTopicWords(String topicId) =>
      '/vocabulary/topics/$topicId/words';
  static const String vocabularyDue = '/vocabulary/due';
  static String vocabularyReviewWord(String wordId) =>
      '/vocabulary/words/$wordId/review';

  // ── Grammar Lessons ───────────────────────────
  static const String grammarLessons = '/grammar/lessons';
  static const String grammarManifest = '/grammar/manifest';
  static const String grammarBundle = '/grammar/bundle';
  static const String grammarAttempts = '/grammar/attempts';
  static const String grammarProgress = '/grammar/progress';
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

  // ── 4 New Advanced Features ───────────────────
  // 1. IELTS Speaking Mock Test
  static const String ieltsPrompt = '/ai/ielts/prompt';
  static const String ieltsEvaluate = '/ai/ielts/evaluate';

  // ── Full IELTS Mock Test (4 skills) ───────────
  static const String mockTests = '/mock-tests';
  static const String mockTestAttempts = '/mock-tests/attempts';
  static String mockTestById(String setId) => '/mock-tests/$setId';
  static String mockTestAttempt(String attemptId) =>
      '/mock-tests/attempts/$attemptId';
  static String mockTestSectionSubmit(String attemptId, String skill) =>
      '/mock-tests/attempts/$attemptId/sections/$skill/submit';
  static String mockTestComplete(String attemptId) =>
      '/mock-tests/attempts/$attemptId/complete';

  // 2. Mistake Notebook & SM-2
  static const String aiMistakes = '/ai/mistakes';
  static String aiMistakeReview(String mistakeId) =>
      '/ai/mistakes/$mistakeId/review';
  static String aiMistakeDelete(String mistakeId) => '/ai/mistakes/$mistakeId';

  // 3. Shadowing Technique
  static const String shadowingDrills = '/speech/shadowing-drills';
  static const String shadowingAssess = '/speech/shadowing-assess';

  // 4. Leaderboard & Gamified Badges
  static const String userLeaderboard = '/users/leaderboard';
  static const String userBadges = '/users/badges';
  static String userBadgeClaim(String badgeId) =>
      '/users/badges/$badgeId/claim';
}
