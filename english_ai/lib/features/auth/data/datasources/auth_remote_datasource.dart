import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../models/user_model.dart';

/// Remote data source for authentication API calls.
class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource(this._dio);

  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.login,
      data: {
        'email': email,
        'password': password,
      },
    );
    return AuthResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.register,
      data: {
        'name': name,
        'email': email,
        'password': password,
      },
    );
    return AuthResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<AuthResponseModel> loginWithGoogle({
    required String idToken,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.googleAuth,
      data: {'id_token': idToken},
    );
    return AuthResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> logout() async {
    await _dio.post(ApiEndpoints.logout);
  }

  Future<UserModel> getCurrentUser() async {
    final response = await _dio.get(ApiEndpoints.userMe);
    return UserModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> forgotPassword({required String email}) async {
    await _dio.post(
      ApiEndpoints.forgotPassword,
      data: {'email': email},
    );
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _dio.post(
      ApiEndpoints.resetPassword,
      data: {
        'token': token,
        'new_password': password,
      },
    );
  }

  Future<UserModel> saveOnboarding({
    required String learningGoal,
    required int dailyMinutes,
    required List<String> topics,
  }) async {
    final response = await _dio.put(
      ApiEndpoints.userOnboarding,
      data: {
        'learning_goal': learningGoal,
        'daily_learning_minutes': dailyMinutes,
        'interested_topics': topics,
      },
    );
    return UserModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<UserModel> updateProfile({
    String? name,
    String? avatarUrl,
    int? dailyLearningMinutes,
    String? targetLevel,
    String? currentLevel,
    String? learningGoal,
  }) async {
    final response = await _dio.put(
      ApiEndpoints.userMe,
      data: {
        if (name != null) 'name': name,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (dailyLearningMinutes != null)
          'daily_learning_minutes': dailyLearningMinutes,
        if (targetLevel != null) 'target_level': targetLevel,
        if (currentLevel != null) 'current_level': currentLevel,
        if (learningGoal != null) 'learning_goal': learningGoal,
      },
    );
    return UserModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
