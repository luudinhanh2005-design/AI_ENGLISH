import '../entities/user.dart';

/// Auth repository contract — domain layer.
abstract class AuthRepository {
  Future<User> login({
    required String email,
    required String password,
  });

  Future<User> register({
    required String name,
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<User?> getCurrentUser();

  Future<void> forgotPassword({required String email});

  Future<void> resetPassword({
    required String token,
    required String password,
  });

  Future<void> saveOnboarding({
    required String learningGoal,
    required int dailyMinutes,
    required List<String> topics,
  });
}
