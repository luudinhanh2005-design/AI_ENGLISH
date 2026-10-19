import '../../../../core/services/storage_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Auth repository implementation bridging domain and data layers.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final response = await _remoteDataSource.login(
      email: email,
      password: password,
    );

    // Save tokens securely
    await StorageService.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );

    // Cache user data
    await StorageService.saveUserData(response.user.toJson());

    return response.user;
  }

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _remoteDataSource.register(
      name: name,
      email: email,
      password: password,
    );

    await StorageService.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );

    await StorageService.saveUserData(response.user.toJson());

    return response.user;
  }

  @override
  Future<User> loginWithGoogle({required String idToken}) async {
    final response = await _remoteDataSource.loginWithGoogle(idToken: idToken);

    await StorageService.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );

    await StorageService.saveUserData(response.user.toJson());

    return response.user;
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } finally {
      // Always clear local data, even if API call fails
      await StorageService.clearAll();
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    // First try to get token
    final token = await StorageService.getAccessToken();
    if (token == null) return null;

    // Try remote first, fall back to cached
    try {
      final user = await _remoteDataSource.getCurrentUser();
      await StorageService.saveUserData(user.toJson());
      return user;
    } catch (e) {
      // Fall back to cached user data
      final cached = StorageService.getUserData();
      if (cached != null) {
        return User(
          id: cached['id'] as String,
          email: cached['email'] as String,
          name: cached['name'] as String,
          avatarUrl: cached['avatar_url'] as String?,
          currentLevel: cached['current_level'] as String?,
          targetLevel: cached['target_level'] as String?,
          learningGoal: cached['learning_goal'] as String?,
          dailyLearningMinutes:
              cached['daily_learning_minutes'] as int? ?? 20,
          streak: cached['streak'] as int? ?? 0,
          totalXp: cached['total_xp'] as int? ?? 0,
          hasCompletedOnboarding:
              cached['has_completed_onboarding'] as bool? ?? false,
          createdAt: DateTime.parse(cached['created_at'] as String),
        );
      }
      return null;
    }
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    await _remoteDataSource.forgotPassword(email: email);
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _remoteDataSource.resetPassword(
      token: token,
      password: password,
    );
  }

  @override
  Future<void> saveOnboarding({
    required String learningGoal,
    required int dailyMinutes,
    required List<String> topics,
  }) async {
    final user = await _remoteDataSource.saveOnboarding(
      learningGoal: learningGoal,
      dailyMinutes: dailyMinutes,
      topics: topics,
    );

    await StorageService.saveUserData(user.toJson());
    await StorageService.setOnboardingComplete();
  }
}
