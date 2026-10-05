import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../constants/api_endpoints.dart';
import '../errors/exceptions.dart';
import '../services/storage_service.dart';

/// Global Dio instance provider.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 90),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 90),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    LoggingInterceptor(),
    ErrorInterceptor(),
  ]);

  return dio;
});

/// Adds JWT bearer token to every request.
class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for public endpoints
    final publicPaths = [
      ApiEndpoints.login,
      ApiEndpoints.register,
      ApiEndpoints.forgotPassword,
      ApiEndpoints.resetPassword,
      ApiEndpoints.refreshToken,
    ];

    final isPublic = publicPaths.any(
      (path) => options.path.contains(path),
    );

    if (!isPublic) {
      final token = await StorageService.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Auto-refresh token on 401
    if (err.response?.statusCode == 401) {
      try {
        final refreshToken = await StorageService.getRefreshToken();
        if (refreshToken != null) {
          final dio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));
          final response = await dio.post(
            ApiEndpoints.refreshToken,
            data: {'refresh_token': refreshToken},
          );

          final newAccessToken = response.data['access_token'];
          final newRefreshToken = response.data['refresh_token'];

          await StorageService.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          // Retry the original request
          err.requestOptions.headers['Authorization'] =
              'Bearer $newAccessToken';

          final retryResponse = await dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        }
      } catch (e) {
        // Refresh failed — clear tokens, user needs to re-login
        await StorageService.clearAll();
      }
    }

    handler.next(err);
  }
}

/// Logs requests and responses for debugging.
class LoggingInterceptor extends Interceptor {
  final _logger = Logger(
    printer: PrettyPrinter(methodCount: 0),
  );

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    _logger.i(
      '→ ${options.method} ${options.path}\n'
      '  Headers: ${options.headers}\n'
      '  Data: ${options.data}',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.i(
      '← ${response.statusCode} ${response.requestOptions.path}\n'
      '  Data: ${response.data}',
    );
    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    _logger.e(
      '✕ ${err.response?.statusCode} ${err.requestOptions.path}\n'
      '  Error: ${err.message}\n'
      '  Response: ${err.response?.data}',
    );
    handler.next(err);
  }
}

/// Converts Dio errors to application exceptions.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw const NetworkException(
          message: 'Connection timed out. Please try again.',
        );

      case DioExceptionType.connectionError:
        throw const NetworkException(
          message: 'No internet connection.',
        );

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final data = err.response?.data;
        String message = 'Something went wrong.';

        if (data is Map<String, dynamic>) {
          message = data['detail'] as String? ?? message;
        }

        if (statusCode == 401) {
          throw AuthException(message: message);
        } else if (statusCode == 422) {
          throw ValidationException(message: message);
        } else {
          throw ServerException(
            message: message,
            statusCode: statusCode,
          );
        }

      default:
        throw ServerException(
          message: err.message ?? 'An unexpected error occurred.',
        );
    }
  }
}
