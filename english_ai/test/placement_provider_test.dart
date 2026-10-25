import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:english_ai/core/network/api_client.dart';
import 'package:english_ai/features/placement/presentation/providers/placement_provider.dart';

const _configJson = {
  'version': '2.0.0',
  'description': 'test blueprint',
  'skill_labels': {'listening': 'Nghe'},
  'modes': {
    'quick': {
      'label': 'Quick',
      'description': 'fast',
      'skills': ['listening'],
      'stages': 2,
      'items_per_stage': 1,
      'time_limit_seconds': 1200,
      'writing_tasks': 0,
      'speaking_tasks': 0,
    },
  },
  'cut_scores': {'B1': 0.0},
  'level_labels': {'B1': 'B1'},
  'level_descriptions_vi': {'B1': 'Mo ta'},
  'exam_mapping': <String, dynamic>{},
  'can_do': <String, dynamic>{},
};

class _PlacementAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;

    if (path.endsWith('/placement/config')) {
      return _jsonResponse(_configJson);
    }
    if (path.endsWith('/placement/results/latest')) {
      return _jsonResponse(
        {'detail': 'No placement result found'},
        statusCode: 404,
      );
    }
    if (path.endsWith('/placement/history')) {
      return _jsonResponse(<dynamic>[]);
    }

    return _jsonResponse(
      {'detail': 'Unexpected test request: $path'},
      statusCode: 500,
    );
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(
  Object body, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('placement intro loads when latest result is 404', () async {
    SharedPreferences.setMockInitialValues({});

    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://test.local/api/v1',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    )..httpClientAdapter = _PlacementAdapter();
    dio.interceptors.add(ErrorInterceptor());

    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);

    final initialized = Completer<void>();
    final subscription = container.listen<PlacementState>(
      placementProvider,
      (previous, next) {
        if (next.initialized && !initialized.isCompleted) {
          initialized.complete();
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await initialized.future.timeout(const Duration(seconds: 5));

    final state = container.read(placementProvider);
    expect(state.config, isNotNull);
    expect(state.config!.modes, contains('quick'));
    expect(state.latestResult, isNull);
    expect(state.errorMessage, isNull);
  });
}
