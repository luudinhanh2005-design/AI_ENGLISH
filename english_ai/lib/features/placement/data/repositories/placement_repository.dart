import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http_parser/http_parser.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/placement_models.dart';

/// Thin Dio wrapper around the placement API (v2).
class PlacementRepository {
  final Dio _dio;

  PlacementRepository(this._dio);

  Future<PlacementConfigModel> getConfig() async {
    final response = await _dio.get(ApiEndpoints.placementConfig);
    return PlacementConfigModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<PlacementSessionModel> createSession({
    required String mode,
    required String targetExam,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.placementSessions,
      data: {'mode': mode, 'target_exam': targetExam},
    );
    return PlacementSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<PlacementSessionModel> getSession(String sessionId) async {
    final response = await _dio.get(ApiEndpoints.placementSession(sessionId));
    return PlacementSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> saveAnswer({
    required String sessionId,
    required String itemId,
    required List<String> answer,
    int responseTimeMs = 0,
  }) async {
    await _dio.post(
      ApiEndpoints.placementAnswers(sessionId),
      data: {
        'item_id': itemId,
        'answer': answer,
        'response_time_ms': responseTimeMs,
      },
    );
  }

  Future<PlacementSessionModel> completeStage({
    required String sessionId,
    required String stageToken,
    required Map<String, List<String>> answers,
    Map<String, int> responseTimes = const {},
  }) async {
    final response = await _dio.post(
      ApiEndpoints.placementCompleteStage(sessionId),
      data: {
        'stage_token': stageToken,
        'answers': answers.entries
            .map(
              (entry) => {
                'item_id': entry.key,
                'answer': entry.value,
                'response_time_ms': responseTimes[entry.key] ?? 0,
              },
            )
            .toList(),
      },
    );
    return PlacementSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<PlacementSessionModel> submitWriting({
    required String sessionId,
    required String taskId,
    required String text,
    int responseTimeMs = 0,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.placementWriting(sessionId),
      data: {
        'task_id': taskId,
        'text': text,
        'response_time_ms': responseTimeMs,
      },
    );
    return PlacementSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<PlacementSessionModel> submitSpeaking({
    required String sessionId,
    required String taskId,
    required Uint8List audioBytes,
  }) async {
    const extension = kIsWeb ? 'webm' : 'wav';
    const contentType = kIsWeb ? 'webm' : 'wav';
    final formData = FormData.fromMap({
      'task_id': taskId,
      'audio': MultipartFile.fromBytes(
        audioBytes,
        filename: 'placement_answer.$extension',
        contentType: MediaType('audio', contentType),
      ),
    });
    final response = await _dio.post(
      ApiEndpoints.placementSpeaking(sessionId),
      data: formData,
    );
    return PlacementSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<PlacementSessionModel> skipSpeaking({
    required String sessionId,
    required String taskId,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.placementSkipSpeaking(sessionId),
      data: {'task_id': taskId},
    );
    return PlacementSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<PlacementResultModel?> getLatestResult() async {
    try {
      final response = await _dio.get(ApiEndpoints.placementLatestResult);
      return PlacementResultModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on ServerException catch (error) {
      // The error interceptor converts 404 responses into ServerException
      // instead of DioException. A 404 simply means the user has no previous
      // placement result yet, which is normal for first-time users.
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<PlacementHistoryEntryModel>> getHistory({int limit = 20}) async {
    final response = await _dio.get(
      ApiEndpoints.placementHistory,
      queryParameters: {'limit': limit},
    );
    final data = response.data as List<dynamic>? ?? [];
    return data
        .map(
          (item) => PlacementHistoryEntryModel.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<PlacementResultModel> getResult(String resultId) async {
    final response = await _dio.get(ApiEndpoints.placementResult(resultId));
    return PlacementResultModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> abandonSession(String sessionId) async {
    await _dio.delete(ApiEndpoints.placementSession(sessionId));
  }
}
