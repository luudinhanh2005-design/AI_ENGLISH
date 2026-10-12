import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/vocabulary_models.dart';

/// Provides ALL vocabulary words — tries API first, then fallback to static.
final allVocabularyWordsProvider =
    FutureProvider<List<VocabularyWordModel>>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
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
            .get('${ApiEndpoints.vocabularyTopics}/${topic.id}/words')
            .timeout(const Duration(seconds: 5));
        final words = (wordsResp.data as List<dynamic>)
            .map((e) =>
                VocabularyWordModel.fromJson(e as Map<String, dynamic>))
            .toList();
        allWords.addAll(words);
      } catch (_) {
        // skip topic that fails
      }
    }
    if (allWords.isNotEmpty) return allWords;
  } catch (_) {
    // Network error — fall through to static
  }
  return buildStaticWords();
});

List<VocabularyWordModel> buildStaticWords() => [
      const VocabularyWordModel(
        id: 's1', topicId: 'static', word: 'Apple',
        phonetic: '/ˈæp.əl/', partOfSpeech: 'noun',
        meaningVi: 'Quả táo', meaningEn: 'A round fruit with red or green skin',
        exampleSentence: 'I eat an apple every day.',
        exampleTranslation: 'Tôi ăn một quả táo mỗi ngày.', level: 'A1',
      ),
      const VocabularyWordModel(
        id: 's2', topicId: 'static', word: 'Book',
        phonetic: '/bʊk/', partOfSpeech: 'noun',
        meaningVi: 'Quyển sách', meaningEn: 'A written or printed work',
        exampleSentence: 'This is my book.',
        exampleTranslation: 'Đây là quyển sách của tôi.', level: 'A1',
      ),
      const VocabularyWordModel(
        id: 's3', topicId: 'static', word: 'Teacher',
        phonetic: '/ˈtiː.tʃər/', partOfSpeech: 'noun',
        meaningVi: 'Giáo viên', meaningEn: 'A person who teaches',
        exampleSentence: 'My teacher is very kind.',
        exampleTranslation: 'Giáo viên của tôi rất tốt bụng.', level: 'A1',
      ),
      const VocabularyWordModel(
        id: 's4', topicId: 'static', word: 'Student',
        phonetic: '/ˈstjuː.dənt/', partOfSpeech: 'noun',
        meaningVi: 'Học sinh', meaningEn: 'A person who is studying',
        exampleSentence: 'She is a good student.',
        exampleTranslation: 'Cô ấy là một học sinh giỏi.', level: 'A1',
      ),
      const VocabularyWordModel(
        id: 's5', topicId: 'static', word: 'Water',
        phonetic: '/ˈwɔː.tər/', partOfSpeech: 'noun',
        meaningVi: 'Nước', meaningEn: 'A clear liquid essential for life',
        exampleSentence: 'Drink water every day.',
        exampleTranslation: 'Uống nước mỗi ngày.', level: 'A1',
      ),
      const VocabularyWordModel(
        id: 's6', topicId: 'static', word: 'Food',
        phonetic: '/fuːd/', partOfSpeech: 'noun',
        meaningVi: 'Thức ăn', meaningEn: 'Any substance consumed for nutrition',
        exampleSentence: 'Vietnamese food is delicious.',
        exampleTranslation: 'Thức ăn Việt Nam rất ngon.', level: 'A1',
      ),
      const VocabularyWordModel(
        id: 's7', topicId: 'static', word: 'House',
        phonetic: '/haʊs/', partOfSpeech: 'noun',
        meaningVi: 'Ngôi nhà', meaningEn: 'A building for people to live in',
        exampleSentence: 'My house is near the school.',
        exampleTranslation: 'Nhà tôi gần trường học.', level: 'A1',
      ),
      const VocabularyWordModel(
        id: 's8', topicId: 'static', word: 'Friend',
        phonetic: '/frend/', partOfSpeech: 'noun',
        meaningVi: 'Người bạn',
        meaningEn: 'A person you like and enjoy spending time with',
        exampleSentence: 'She is my best friend.',
        exampleTranslation: 'Cô ấy là người bạn thân nhất của tôi.', level: 'A1',
      ),
      const VocabularyWordModel(
        id: 's9', topicId: 'static', word: 'Family',
        phonetic: '/ˈfæm.ɪ.li/', partOfSpeech: 'noun',
        meaningVi: 'Gia đình', meaningEn: 'A group of related people',
        exampleSentence: 'I love my family very much.',
        exampleTranslation: 'Tôi yêu gia đình tôi rất nhiều.', level: 'A1',
      ),
      const VocabularyWordModel(
        id: 's10', topicId: 'static', word: 'School',
        phonetic: '/skuːl/', partOfSpeech: 'noun',
        meaningVi: 'Trường học',
        meaningEn: 'An institution for educating children',
        exampleSentence: 'I go to school every morning.',
        exampleTranslation: 'Tôi đến trường mỗi buổi sáng.', level: 'A1',
      ),
      const VocabularyWordModel(
        id: 's11', topicId: 'static', word: 'Happy',
        phonetic: '/ˈhæp.i/', partOfSpeech: 'adjective',
        meaningVi: 'Vui vẻ / Hạnh phúc',
        meaningEn: 'Feeling or showing pleasure or contentment',
        exampleSentence: 'I am happy to meet you.',
        exampleTranslation: 'Tôi rất vui được gặp bạn.', level: 'A1',
      ),
      const VocabularyWordModel(
        id: 's12', topicId: 'static', word: 'Beautiful',
        phonetic: '/ˈbjuː.tɪ.fəl/', partOfSpeech: 'adjective',
        meaningVi: 'Đẹp', meaningEn: 'Pleasing the senses or mind aesthetically',
        exampleSentence: 'Vietnam is a beautiful country.',
        exampleTranslation: 'Việt Nam là một đất nước xinh đẹp.', level: 'A2',
      ),
      const VocabularyWordModel(
        id: 's13', topicId: 'static', word: 'Communicate',
        phonetic: '/kəˈmjuː.nɪ.keɪt/', partOfSpeech: 'verb',
        meaningVi: 'Giao tiếp',
        meaningEn: 'Share or exchange information with others',
        exampleSentence: 'We need to communicate clearly.',
        exampleTranslation: 'Chúng ta cần giao tiếp rõ ràng.', level: 'A2',
      ),
      const VocabularyWordModel(
        id: 's14', topicId: 'static', word: 'Education',
        phonetic: '/ˌedʒ.uˈkeɪ.ʃən/', partOfSpeech: 'noun',
        meaningVi: 'Giáo dục',
        meaningEn: 'The process of receiving or giving instruction',
        exampleSentence: 'Education is very important.',
        exampleTranslation: 'Giáo dục rất quan trọng.', level: 'A2',
      ),
      const VocabularyWordModel(
        id: 's15', topicId: 'static', word: 'Vocabulary',
        phonetic: '/vəˈkæb.jʊ.lər.i/', partOfSpeech: 'noun',
        meaningVi: 'Từ vựng', meaningEn: 'The set of words a person knows',
        exampleSentence: 'Build your vocabulary every day.',
        exampleTranslation: 'Xây dựng vốn từ vựng mỗi ngày.', level: 'A2',
      ),
      const VocabularyWordModel(
        id: 's16', topicId: 'static', word: 'Confident',
        phonetic: '/ˈkɒn.fɪ.dənt/', partOfSpeech: 'adjective',
        meaningVi: 'Tự tin',
        meaningEn: 'Feeling or showing certainty about something',
        exampleSentence: 'Be confident when you speak.',
        exampleTranslation: 'Hãy tự tin khi bạn nói.', level: 'A2',
      ),
      const VocabularyWordModel(
        id: 's17', topicId: 'static', word: 'Improve',
        phonetic: '/ɪmˈpruːv/', partOfSpeech: 'verb',
        meaningVi: 'Cải thiện', meaningEn: 'Make or become better',
        exampleSentence: 'I want to improve my English.',
        exampleTranslation: 'Tôi muốn cải thiện tiếng Anh của mình.', level: 'B1',
      ),
      const VocabularyWordModel(
        id: 's18', topicId: 'static', word: 'Experience',
        phonetic: '/ɪkˈspɪər.i.əns/', partOfSpeech: 'noun',
        meaningVi: 'Kinh nghiệm',
        meaningEn: 'Knowledge or skill gained from doing something',
        exampleSentence: 'She has a lot of experience.',
        exampleTranslation: 'Cô ấy có nhiều kinh nghiệm.', level: 'B1',
      ),
      const VocabularyWordModel(
        id: 's19', topicId: 'static', word: 'Opportunity',
        phonetic: '/ˌɒp.əˈtjuː.nɪ.ti/', partOfSpeech: 'noun',
        meaningVi: 'Cơ hội',
        meaningEn: 'A time when a situation makes it possible to do something',
        exampleSentence: 'This is a great opportunity.',
        exampleTranslation: 'Đây là một cơ hội tuyệt vời.', level: 'B1',
      ),
      const VocabularyWordModel(
        id: 's20', topicId: 'static', word: 'Knowledge',
        phonetic: '/ˈnɒl.ɪdʒ/', partOfSpeech: 'noun',
        meaningVi: 'Kiến thức',
        meaningEn: 'Facts and skills acquired through experience',
        exampleSentence: 'Knowledge is power.',
        exampleTranslation: 'Kiến thức là sức mạnh.', level: 'B1',
      ),
      const VocabularyWordModel(
        id: 's21', topicId: 'static', word: 'Challenge',
        phonetic: '/ˈtʃæl.ɪndʒ/', partOfSpeech: 'noun',
        meaningVi: 'Thử thách',
        meaningEn: "A task or situation that tests someone's abilities",
        exampleSentence: 'Learning English is a challenge.',
        exampleTranslation: 'Học tiếng Anh là một thử thách.', level: 'B1',
      ),
      const VocabularyWordModel(
        id: 's22', topicId: 'static', word: 'Fluent',
        phonetic: '/ˈfluː.ənt/', partOfSpeech: 'adjective',
        meaningVi: 'Lưu loát',
        meaningEn: 'Able to speak a language easily and accurately',
        exampleSentence: 'She speaks fluent English.',
        exampleTranslation: 'Cô ấy nói tiếng Anh lưu loát.', level: 'B1',
      ),
      const VocabularyWordModel(
        id: 's23', topicId: 'static', word: 'Technology',
        phonetic: '/tekˈnɒl.ə.dʒi/', partOfSpeech: 'noun',
        meaningVi: 'Công nghệ',
        meaningEn: 'Application of scientific knowledge for practical purposes',
        exampleSentence: 'Technology changes our lives.',
        exampleTranslation: 'Công nghệ thay đổi cuộc sống.', level: 'B1',
      ),
      const VocabularyWordModel(
        id: 's24', topicId: 'static', word: 'Grammar',
        phonetic: '/ˈɡræm.ər/', partOfSpeech: 'noun',
        meaningVi: 'Ngữ pháp',
        meaningEn: 'The rules for using a language correctly',
        exampleSentence: 'Good grammar is important.',
        exampleTranslation: 'Ngữ pháp tốt rất quan trọng.', level: 'A2',
      ),
      const VocabularyWordModel(
        id: 's25', topicId: 'static', word: 'Complex',
        phonetic: '/ˈkɒm.pleks/', partOfSpeech: 'adjective',
        meaningVi: 'Phức tạp',
        meaningEn: 'Consisting of many different and connected parts',
        exampleSentence: 'This problem is complex.',
        exampleTranslation: 'Vấn đề này rất phức tạp.', level: 'B2',
      ),
      const VocabularyWordModel(
        id: 's26', topicId: 'static', word: 'Achieve',
        phonetic: '/əˈtʃiːv/', partOfSpeech: 'verb',
        meaningVi: 'Đạt được',
        meaningEn: 'Successfully reach a desired objective',
        exampleSentence: 'You can achieve your goal.',
        exampleTranslation: 'Bạn có thể đạt được mục tiêu.', level: 'B2',
      ),
      const VocabularyWordModel(
        id: 's27', topicId: 'static', word: 'Substantial',
        phonetic: '/səbˈstæn.ʃəl/', partOfSpeech: 'adjective',
        meaningVi: 'Đáng kể / To lớn',
        meaningEn: 'Of considerable importance, size, or worth',
        exampleSentence: 'There has been substantial progress.',
        exampleTranslation: 'Đã có sự tiến bộ đáng kể.', level: 'C1',
      ),
      const VocabularyWordModel(
        id: 's28', topicId: 'static', word: 'Inevitable',
        phonetic: '/ɪnˈev.ɪ.tə.bəl/', partOfSpeech: 'adjective',
        meaningVi: 'Không thể tránh khỏi',
        meaningEn: 'Certain to happen and cannot be prevented',
        exampleSentence: 'Change is inevitable in life.',
        exampleTranslation: 'Thay đổi là điều không thể tránh khỏi.', level: 'C1',
      ),
    ];
