// Data layer for the IELTS Mock Test feature.
//
// All endpoints and payload shapes follow docs/ielts_mock_test_contract.md.
// Errors are normalised into [MockTestException] so the presentation layer
// never has to deal with Dio internals.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import 'models/mock_test_models.dart';

/// Readable error surfaced by [MockTestRepository].
///
/// [message] always prefers the backend `detail` field when available.
class MockTestException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  const MockTestException(this.message, {this.statusCode, this.cause});

  @override
  String toString() => message;
}

class MockTestRepository {
  MockTestRepository(this._dio);

  final Dio _dio;

  /// GET /mock-tests
  Future<List<MockTestSummary>> fetchSets() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.mockTests);
      return _asList(response.data)
          .map((item) => MockTestSummary.fromJson(_asMap(item)))
          .where((summary) => summary.id.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw _wrap(error, 'Could not load mock tests.');
    }
  }

  /// GET /mock-tests/{setId} — sanitized set (no answer keys).
  Future<MockTestSet> fetchSet(String setId) async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.mockTestById(setId));
      final map = _unwrap(response.data, const ['set', 'data']);
      final set = MockTestSet.fromJson(map);
      if (set.id.isEmpty) {
        throw const MockTestException('The mock test could not be loaded.');
      }
      return set;
    } catch (error) {
      throw _wrap(error, 'Could not load this mock test.');
    }
  }

  /// POST /mock-tests/attempts
  Future<MockTestAttempt> startAttempt(
    String setId,
    String mode, {
    List<String>? skills,
  }) async {
    try {
      final body = <String, dynamic>{
        'set_id': setId,
        'mode': mode,
      };
      if (skills != null && skills.isNotEmpty) {
        body['skills'] = skills;
      }

      final response = await _dio.post<dynamic>(
        ApiEndpoints.mockTestAttempts,
        data: body,
      );
      final attempt = MockTestAttempt.fromJson(
        _unwrap(response.data, const ['attempt', 'data']),
      );
      if (attempt.id.isEmpty) {
        throw const MockTestException(
          'The server did not return an attempt id.',
        );
      }
      return attempt;
    } catch (error) {
      throw _wrap(error, 'Could not start the mock test.');
    }
  }

  /// PATCH /mock-tests/attempts/{attemptId}
  ///
  /// Persists the answers, flags and remaining time of one section.
  Future<void> saveProgress(
    String attemptId,
    String skill,
    Map<String, String> answers,
    List<String> flagged,
    int remainingSeconds,
  ) async {
    try {
      await _dio.patch<dynamic>(
        ApiEndpoints.mockTestAttempt(attemptId),
        data: <String, dynamic>{
          'skill': skill,
          'answers': answers,
          'flagged': flagged,
          'remaining_seconds': remainingSeconds < 0 ? 0 : remainingSeconds,
        },
      );
    } catch (error) {
      throw _wrap(error, 'Could not save your progress.');
    }
  }

  /// POST /mock-tests/attempts/{attemptId}/sections/{skill}/submit
  ///
  /// [body] is the skill-specific payload:
  /// - listening/reading/writing: `{"answers": {...}}`
  /// - speaking: `part1_qa`, `part2_answer`, `part3_qa`, `follow_up_qa`
  Future<SectionScore> submitSection(
    String attemptId,
    String skill,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.mockTestSectionSubmit(attemptId, skill),
        data: body,
      );
      final map = _unwrap(
        response.data,
        const ['score', 'section_score', 'result', 'data'],
      );
      return SectionScore.fromJson(_withSkill(map, skill));
    } catch (error) {
      throw _wrap(error, 'Could not submit this section.');
    }
  }

  /// POST /mock-tests/attempts/{attemptId}/complete
  Future<MockTestResult> completeAttempt(String attemptId) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.mockTestComplete(attemptId),
        data: const <String, dynamic>{},
      );
      final map = _unwrap(response.data, const ['result', 'data']);
      final result = MockTestResult.fromJson(map);
      if (result.attemptId.isEmpty) {
        // Be tolerant: some backends omit attempt_id in the result payload.
        return MockTestResult(
          attemptId: attemptId,
          overallBand: result.overallBand,
          skills: result.skills,
          xpAwarded: result.xpAwarded,
          completedAt: result.completedAt,
        );
      }
      return result;
    } catch (error) {
      throw _wrap(error, 'Could not finish the mock test.');
    }
  }

  /// GET /mock-tests/attempts — newest first.
  Future<List<MockTestHistoryItem>> fetchHistory() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.mockTestAttempts);
      return _asList(response.data)
          .map((item) => MockTestHistoryItem.fromJson(_asMap(item)))
          .where((item) => item.attemptId.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw _wrap(error, 'Could not load your mock test history.');
    }
  }

  /// GET /mock-tests/attempts/{attemptId}
  ///
  /// Returns the raw detail payload so the review UI can read `sections`,
  /// `scores` and `review` directly.
  Future<Map<String, dynamic>> fetchAttemptDetail(String attemptId) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.mockTestAttempt(attemptId),
      );
      final map = _asMap(response.data);
      if (map.isEmpty) {
        throw const MockTestException('This attempt could not be loaded.');
      }
      return map;
    } catch (error) {
      throw _wrap(error, 'Could not load this attempt.');
    }
  }
}

/// Global repository provider.
final mockTestRepositoryProvider = Provider<MockTestRepository>(
  (ref) => MockTestRepository(ref.watch(dioProvider)),
);

// ─────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────

MockTestException _wrap(Object error, String fallback) {
  if (error is MockTestException) return error;

  if (error is DioException) {
    final detail = _detailFrom(error.response?.data);
    return MockTestException(
      detail.isNotEmpty ? detail : _dioMessage(error, fallback),
      statusCode: error.response?.statusCode,
      cause: error,
    );
  }

  if (error is NetworkException) {
    return MockTestException(error.message, cause: error);
  }
  if (error is AuthException) {
    return MockTestException(error.message, cause: error);
  }
  if (error is ValidationException) {
    return MockTestException(error.message, cause: error);
  }
  if (error is ServerException) {
    return MockTestException(
      error.message,
      statusCode: error.statusCode,
      cause: error,
    );
  }

  return MockTestException(fallback, cause: error);
}

String _dioMessage(DioException error, String fallback) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return 'The request timed out. Please try again.';
    case DioExceptionType.connectionError:
      return 'No internet connection.';
    case DioExceptionType.cancel:
      return 'The request was cancelled.';
    case DioExceptionType.badCertificate:
      return 'The server certificate could not be verified.';
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode;
      return status == null ? fallback : 'Server error ($status).';
    case DioExceptionType.unknown:
      return error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : fallback;
  }
}

String _detailFrom(dynamic data) {
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (detail is List) {
      final messages = detail
          .map((entry) {
            if (entry is Map) {
              return (entry['msg'] ?? entry['message'] ?? '').toString().trim();
            }
            return entry?.toString().trim() ?? '';
          })
          .where((message) => message.isNotEmpty)
          .toList();
      if (messages.isNotEmpty) return messages.join('; ');
    }
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
  }
  if (data is String && data.trim().isNotEmpty) return data.trim();
  return '';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  if (value is Map) {
    for (final key in const ['items', 'data', 'results', 'sets', 'attempts']) {
      final nested = value[key];
      if (nested is List) return nested;
    }
  }
  return const <dynamic>[];
}

/// Returns the nested object when the API wraps the payload, otherwise the
/// map itself.
Map<String, dynamic> _unwrap(dynamic value, List<String> keys) {
  final map = _asMap(value);
  for (final key in keys) {
    final nested = map[key];
    if (nested is Map) return _asMap(nested);
  }
  return map;
}

Map<String, dynamic> _withSkill(Map<String, dynamic> json, String skill) {
  final current = json['skill'];
  if (current is String && current.trim().isNotEmpty) return json;
  return <String, dynamic>{...json, 'skill': skill};
}
