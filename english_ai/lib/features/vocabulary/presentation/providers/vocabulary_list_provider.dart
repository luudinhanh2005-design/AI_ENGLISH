import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/vocabulary_models.dart';
import '../../data/vocabulary_data.dart';

/// Provides ALL vocabulary words — tries the paginated API first, then the
/// generated offline catalog.
///
/// The backend may be an older deployment without `/vocabulary/words`; in that
/// case we fall back to the legacy per-topic endpoint before using local data.
final allVocabularyWordsProvider =
    FutureProvider<List<VocabularyWordModel>>((ref) async {
  final dio = ref.watch(dioProvider);

  try {
    final words = <VocabularyWordModel>[];
    const pageSize = 200;
    for (var page = 1; page <= 20; page++) {
      final response = await dio.get(
        ApiEndpoints.vocabularyWords,
        queryParameters: {'page': page, 'limit': pageSize},
      ).timeout(const Duration(seconds: 6));

      final data = response.data;
      if (data is! Map<String, dynamic>) break;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => VocabularyWordModel.fromJson(e as Map<String, dynamic>))
          .toList();
      words.addAll(items);
      if (data['has_more'] != true || items.isEmpty) break;
    }
    if (words.isNotEmpty) return words;
  } catch (_) {
    // Try the legacy topic loop below.
  }

  try {
    final topicsResp = await dio
        .get(ApiEndpoints.vocabularyTopics)
        .timeout(const Duration(seconds: 5));

    final topics = (topicsResp.data as List<dynamic>)
        .map((e) => VocabularyTopicModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final allWords = <VocabularyWordModel>[];
    for (final topic in topics) {
      try {
        final wordsResp = await dio
            .get(ApiEndpoints.vocabularyTopicWords(topic.id))
            .timeout(const Duration(seconds: 5));
        final words = (wordsResp.data as List<dynamic>)
            .map((e) => VocabularyWordModel.fromJson(e as Map<String, dynamic>))
            .toList();
        allWords.addAll(words);
      } catch (_) {
        // Skip a topic that fails; another one may still work.
      }
    }
    if (allWords.isNotEmpty) return allWords;
  } catch (_) {
    // Network error — use the generated offline catalog.
  }

  return buildStaticWords();
});
