import 'package:flutter/foundation.dart' show kIsWeb;
/// API configuration constants.
/// In production, these should come from environment configuration.
class ApiEndpoints {
  ApiEndpoints._();

  // Base URL — change to your backend URL
  static String get baseUrl => kIsWeb ? 'http://localhost:8000/api/v1' : 'http://10.0.2.2:8000/api/v1';
  // Use 'http://localhost:8000/api/v1' for iOS simulator
  // Use 'http://10.0.2.2:8000/api/v1' for Android emulator
  // Use your actual IP for physical device

  // ---------------------------------------------// Auth
  // ---------------------------------------------
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String googleAuth = '/auth/google';

  // ---------------------------------------------// User
  // ---------------------------------------------
  static const String userMe = '/users/me';
  static const String userOnboarding = '/users/me/onboarding';

  // ---------------------------------------------// Placement Test
  // ---------------------------------------------
  static const String placementQuestions = '/placement/questions';
  static const String placementSubmit = '/placement/submit';

  // ---------------------------------------------// Vocabulary & Spaced Repetition (SM-2)
  // ---------------------------------------------
  static const String vocabularyTopics = '/vocabulary/topics';
  static String vocabularyTopicWords(String topicId) => '/vocabulary/topics/$topicId/words';
  static const String vocabularyDue = '/vocabulary/due';
  static String vocabularyReviewWord(String wordId) => '/vocabulary/words/$wordId/review';

  // ---------------------------------------------// Grammar Lessons
  // ---------------------------------------------
  static const String grammarLessons = '/grammar/lessons';
  static String grammarLessonById(String id) => '/grammar/lessons/$id';
  static String grammarSubmitLesson(String id) => '/grammar/lessons/$id/submit';

  // ---------------------------------------------// Exercises
  // ---------------------------------------------
  static const String exerciseGenerate = '/exercises/generate';
  static String exerciseById(String id) => '/exercises/$id';
  static String exerciseSubmit(String id) => '/exercises/$id/submit';

  // ---------------------------------------------// Speaking
  // ---------------------------------------------
  static const String speakingSession = '/speaking/session';
  static const String speakingTranscribe = '/speaking/transcribe';
  static const String speakingRespond = '/speaking/respond';
  static const String speakingScenarios = '/speaking/scenarios';
  static String speakingReport(String id) => '/speaking/session/$id/report';

  // ---------------------------------------------// Pronunciation
  // ---------------------------------------------
  static const String pronunciationAnalyze = '/pronunciation/analyze';

  // ---------------------------------------------// Writing
  // ---------------------------------------------
  static const String writingPrompts = '/writing/prompts';
  static const String writingSubmit = '/writing/submit';
  static String writingFeedback(String id) => '/writing/$id/feedback';

  // ---------------------------------------------// AI Tutor
  // ---------------------------------------------
  static const String aiChat = '/ai/chat';
  static const String aiConversations = '/ai/conversations';
  static String aiConversationById(String id) => '/ai/conversations/$id';

  // ---------------------------------------------// Learning Path
  // ---------------------------------------------
  static const String learningPath = '/learning-path';
  static const String learningPathGenerate = '/learning-path/generate';
  static const String dailyPlan = '/daily-plan';

  // ---------------------------------------------// Progress
  // ---------------------------------------------
  static const String progress = '/progress';
  static const String progressSkills = '/progress/skills';
  static const String progressStreak = '/progress/streak';
  static const String progressAchievements = '/progress/achievements';
  static const String progressAnalytics = '/progress/analytics';
}
