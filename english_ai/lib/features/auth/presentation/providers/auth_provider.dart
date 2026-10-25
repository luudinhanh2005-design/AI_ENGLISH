import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Provides the auth repository instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final remoteDataSource = AuthRemoteDataSource(dio);
  return AuthRepositoryImpl(remoteDataSource);
});

/// Current authenticated user state.
/// AsyncValue<User?> — null means not authenticated.
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<User?>>((ref) {
  return AuthStateNotifier(ref, ref.watch(authRepositoryProvider));
});

class AuthStateNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref _ref;
  final AuthRepository _repository;

  AuthStateNotifier(this._ref, this._repository)
      : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final user = await _repository.getCurrentUser();
      if (user == null) {
        await _resetThemeToDefault();
      }
      state = AsyncValue.data(user);
    } catch (e) {
      await _resetThemeToDefault();
      state = const AsyncValue.data(null);
    }
  }

  /// Keeps signed-out users on the light theme, which is also the default for
  /// new accounts. Theme failures must not block authentication.
  Future<void> _resetThemeToDefault() async {
    try {
      await _ref.read(themeModeProvider.notifier).resetToDefault();
    } catch (_) {
      // Storage may not be available in tests; authentication still proceeds.
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.login(
        email: email,
        password: password,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.register(
        name: name,
        email: email,
        password: password,
      );
      await _resetThemeToDefault();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> loginWithGoogle({required String idToken}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.loginWithGoogle(idToken: idToken);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _resetThemeToDefault();
    try {
      await _repository.logout();
    } finally {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> forgotPassword({required String email}) async {
    await _repository.forgotPassword(email: email);
  }

  Future<void> saveOnboarding({
    required String learningGoal,
    required int dailyMinutes,
    required List<String> topics,
  }) async {
    await _repository.saveOnboarding(
      learningGoal: learningGoal,
      dailyMinutes: dailyMinutes,
      topics: topics,
    );
    // Refresh user state
    await _init();
  }

  Future<void> refreshUser() async {
    await _init();
  }

  Future<User> updateProfile({
    String? name,
    String? avatarUrl,
    int? dailyLearningMinutes,
    String? targetLevel,
    String? currentLevel,
    String? learningGoal,
  }) async {
    final updated = await _repository.updateProfile(
      name: name,
      avatarUrl: avatarUrl,
      dailyLearningMinutes: dailyLearningMinutes,
      targetLevel: targetLevel,
      currentLevel: currentLevel,
      learningGoal: learningGoal,
    );
    state = AsyncValue.data(updated);
    return updated;
  }

  void updateUser(User user) {
    state = AsyncValue.data(user);
  }
}
