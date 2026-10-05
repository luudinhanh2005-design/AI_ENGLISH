import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Secure storage service for tokens and sensitive data.
/// Uses FlutterSecureStorage for tokens, SharedPreferences for settings.
class StorageService {
  static late final FlutterSecureStorage _secureStorage;
  static late final SharedPreferences _prefs;

  StorageService._();

  /// Initialize storage — call in main() before runApp.
  static Future<void> init() async {
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    _prefs = await SharedPreferences.getInstance();
  }

  // ---------------------------------------------// Token Management
  // ---------------------------------------------
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(
      key: AppConstants.accessTokenKey,
      value: accessToken,
    );
    await _secureStorage.write(
      key: AppConstants.refreshTokenKey,
      value: refreshToken,
    );
  }

  static Future<String?> getAccessToken() async {
    return _secureStorage.read(key: AppConstants.accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: AppConstants.refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConstants.accessTokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
  }

  // ---------------------------------------------// User Data
  // ---------------------------------------------
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _prefs.setString(
      AppConstants.userDataKey,
      jsonEncode(userData),
    );
  }

  static Map<String, dynamic>? getUserData() {
    final data = _prefs.getString(AppConstants.userDataKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  // ---------------------------------------------// Onboarding
  // ---------------------------------------------
  static Future<void> setOnboardingComplete() async {
    await _prefs.setBool(AppConstants.onboardingCompleteKey, true);
  }

  static bool isOnboardingComplete() {
    return _prefs.getBool(AppConstants.onboardingCompleteKey) ?? false;
  }

  // ---------------------------------------------// Theme
  // ---------------------------------------------
  static Future<void> saveThemeMode(String mode) async {
    await _prefs.setString(AppConstants.themeKey, mode);
  }

  static String getThemeMode() {
    return _prefs.getString(AppConstants.themeKey) ?? 'dark';
  }

  // ---------------------------------------------// Clear All
  // ---------------------------------------------
  static Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs.clear();
  }
}
