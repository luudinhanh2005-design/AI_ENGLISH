/// User entity — domain layer representation.
class User {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? currentLevel;
  final String? targetLevel;
  final String? learningGoal;
  final int dailyLearningMinutes;
  final int streak;
  final int totalXp;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.currentLevel,
    this.targetLevel,
    this.learningGoal,
    this.dailyLearningMinutes = 20,
    this.streak = 0,
    this.totalXp = 0,
    this.hasCompletedOnboarding = false,
    required this.createdAt,
  });

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? currentLevel,
    String? targetLevel,
    String? learningGoal,
    int? dailyLearningMinutes,
    int? streak,
    int? totalXp,
    bool? hasCompletedOnboarding,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currentLevel: currentLevel ?? this.currentLevel,
      targetLevel: targetLevel ?? this.targetLevel,
      learningGoal: learningGoal ?? this.learningGoal,
      dailyLearningMinutes: dailyLearningMinutes ?? this.dailyLearningMinutes,
      streak: streak ?? this.streak,
      totalXp: totalXp ?? this.totalXp,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
