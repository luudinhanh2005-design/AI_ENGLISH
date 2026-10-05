/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'EnglishAI';
  static const String appTagline = 'Your AI English Learning Assistant';

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String themeKey = 'theme_mode';

  // English levels
  static const List<String> levels = ['A1', 'A2', 'B1', 'B2', 'C1'];

  // Learning goals
  static const List<String> learningGoals = [
    'Giao tiếp',
    'Công việc',
    'Phỏng vấn',
    'TOEIC',
    'IELTS',
    'Du lịch',
    'Khác',
  ];

  // Daily minutes options
  static const List<int> dailyMinutesOptions = [10, 20, 30, 60];

  // Interest topics
  static const List<String> topics = [
    'Technology',
    'Business',
    'Travel',
    'Daily Life',
    'Food',
    'Education',
    'Entertainment',
    'Science',
  ];

  // Skills
  static const List<String> skills = [
    'Vocabulary',
    'Grammar',
    'Listening',
    'Speaking',
    'Reading',
    'Writing',
    'Pronunciation',
  ];

  // Gamification
  static const int xpPerLesson = 10;
  static const int xpPerExercise = 5;
  static const int xpPerConversation = 15;
  static const int xpPerWriting = 10;
  static const int xpPerReview = 3;
}
