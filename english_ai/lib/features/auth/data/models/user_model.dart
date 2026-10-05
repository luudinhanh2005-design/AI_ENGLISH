import '../../domain/entities/user.dart';

/// Data model for User with JSON serialization.
/// Extends the domain entity with data layer concerns.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    super.avatarUrl,
    super.currentLevel,
    super.targetLevel,
    super.learningGoal,
    super.dailyLearningMinutes,
    super.streak,
    super.totalXp,
    super.hasCompletedOnboarding,
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      currentLevel: json['current_level'] as String?,
      targetLevel: json['target_level'] as String?,
      learningGoal: json['learning_goal'] as String?,
      dailyLearningMinutes: json['daily_learning_minutes'] as int? ?? 20,
      streak: json['streak'] as int? ?? 0,
      totalXp: json['total_xp'] as int? ?? 0,
      hasCompletedOnboarding:
          json['has_completed_onboarding'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'current_level': currentLevel,
      'target_level': targetLevel,
      'learning_goal': learningGoal,
      'daily_learning_minutes': dailyLearningMinutes,
      'streak': streak,
      'total_xp': totalXp,
      'has_completed_onboarding': hasCompletedOnboarding,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Auth response model containing tokens and user data.
class AuthResponseModel {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
