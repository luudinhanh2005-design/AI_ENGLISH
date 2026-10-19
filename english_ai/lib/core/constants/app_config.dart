import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Central runtime configuration.
///
/// Override the backend URL at build/run time without editing code:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
class AppConfig {
  AppConfig._();

  /// Optional override supplied via `--dart-define=API_BASE_URL=...`.
  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Backend origin (without the `/api/v1` suffix), e.g. `http://10.0.2.2:8000`.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride.replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb) return 'http://localhost:8000';
    // Android emulator maps the host machine's loopback to 10.0.2.2.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    // iOS simulator, desktop, etc.
    return 'http://localhost:8000';
  }

  /// Base URL for versioned API calls, e.g. `http://10.0.2.2:8000/api/v1`.
  static String get apiBaseUrlV1 => '$apiBaseUrl/api/v1';

  /// Google OAuth Web client ID, supplied at build time with
  /// `--dart-define=GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com`.
  /// Must match the backend's `GOOGLE_OAUTH_CLIENT_ID`.
  static const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  /// Whether Google Sign-In has been configured at build time.
  static bool get isGoogleSignInConfigured => googleClientId.isNotEmpty;

  /// Resolve a server-relative media path (e.g. `/speech/audio/x.mp3`)
  /// into an absolute URL. Absolute URLs are returned unchanged.
  static String resolveMediaUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$apiBaseUrl$normalized';
  }
}
