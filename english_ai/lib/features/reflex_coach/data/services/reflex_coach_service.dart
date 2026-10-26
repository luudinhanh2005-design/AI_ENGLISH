import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_config.dart';
import '../models/reflex_model.dart';

class ReflexCoachService {
  static final ReflexCoachService instance = ReflexCoachService._internal();
  ReflexCoachService._internal();

  /// Fetch all reflex topics and challenges
  Future<List<ReflexTopic>> getReflexTopics() async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrlV1}/ai/reflex-topics');
      final resp = await http.get(url).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(resp.bodyBytes));
        return data.map((e) => ReflexTopic.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('ReflexCoachService: Could not fetch remote topics ($e), using local fallback');
    }
    return _localFallbackTopics;
  }

  /// Assess user's English spoken reflex attempt
  Future<ReflexEvaluation> assessReflex({
    required String promptVi,
    required String userEn,
    String topic = 'General',
    String level = 'A2',
  }) async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrlV1}/ai/reflex-assess');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt_vi': promptVi,
          'user_en': userEn,
          'topic': topic,
          'level': level,
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(resp.bodyBytes));
        return ReflexEvaluation.fromJson(data);
      }
    } catch (e) {
      debugPrint('ReflexCoachService: Could not connect to assess API ($e), using local evaluation');
    }

    return _localAssess(promptVi, userEn);
  }

  ReflexEvaluation _localAssess(String promptVi, String userEn) {
    final lower = userEn.trim().toLowerCase();
    final isAwkward = lower.contains('what time is it i can') ||
        lower.contains('what time is it can i') ||
        lower.split(' ').length > 8;

    if (isAwkward) {
      return ReflexEvaluation(
        score: 65,
        isValid: false,
        feedbackVi:
            'Ý tưởng của bạn đã rõ ràng, nhưng cách nói "$userEn" bị lặp từ và ghép câu theo lối mòn tiếng Việt. Người bản xứ thường dùng cấu trúc ngắn gọn, dứt khoát hơn.',
        betterOptions: const [
          ReflexOption(
            english: 'What time is check-in?',
            vietnamese: 'Mấy giờ là giờ nhận phòng?',
            contextNote: 'Cách nói ngắn gọn, tự nhiên nhất của người bản xứ',
          ),
          ReflexOption(
            english: 'When can I check in?',
            vietnamese: 'Tôi có thể nhận phòng lúc mấy giờ?',
            contextNote: 'Rất lịch sự và phổ biến tại khách sạn',
          ),
          ReflexOption(
            english: 'Could you tell me the check-in time, please?',
            vietnamese: 'Làm ơn cho tôi biết giờ nhận phòng được không?',
            contextNote: 'Trang trọng, nhã nhặn',
          ),
        ],
        grammarNote:
            'Khi hỏi giờ của một dịch vụ hay thủ tục (nhận phòng, mở cửa, bay...), người bản xứ dùng "What time is + Danh từ" hoặc "When can I + Động từ" thay vì "What time is it + S + V".',
        vocabularyHighlights: const [
          'check-in (thủ tục nhận phòng)',
          'check-in time (giờ nhận phòng)',
        ],
      );
    }

    return ReflexEvaluation(
      score: 85,
      isValid: true,
      feedbackVi: 'Phản xạ câu nói tiếng Anh của bạn rất tốt, diễn đạt rõ ràng và dễ hiểu!',
      betterOptions: [
        ReflexOption(
          english: userEn.trim(),
          vietnamese: promptVi,
          contextNote: 'Cách nói chuẩn',
        ),
      ],
      grammarNote: 'Hãy tiếp tục giữ vững phản xạ nhanh và dứt khoát như vậy!',
      vocabularyHighlights: const [],
    );
  }

  static final List<ReflexTopic> _localFallbackTopics = [
    const ReflexTopic(
      id: 'hotel_travel',
      title: 'Khách sạn & Du lịch',
      titleEn: 'Hotel & Travel',
      icon: 'hotel_rounded',
      description: 'Thủ tục nhận/trả phòng, gửi hành lý, yêu cầu dịch vụ',
      challenges: [
        ReflexChallenge(
          id: 'ht_1',
          topicId: 'hotel_travel',
          promptVi: 'Tôi có thể nhận phòng lúc mấy giờ?',
          level: 'A2',
          hints: ['What time', 'check-in', 'when'],
          suggestedAnswers: [
            'What time is check-in?',
            'When can I check in?',
            'Could you tell me the check-in time, please?',
          ],
          contextDesc: 'Hỏi lễ tân khách sạn về thời gian nhận phòng',
        ),
        ReflexChallenge(
          id: 'ht_2',
          topicId: 'hotel_travel',
          promptVi: 'Bạn có thể giữ hành lý giúp tôi trước giờ nhận phòng không?',
          level: 'B1',
          hints: ['store luggage', 'leave bags', 'before check-in'],
          suggestedAnswers: [
            'Could you store my luggage before check-in?',
            'Can I leave my bags here until check-in?',
            'Is it possible to hold my luggage?',
          ],
          contextDesc: 'Đến khách sạn sớm và cần gửi vali để đi dạo',
        ),
        ReflexChallenge(
          id: 'ht_3',
          topicId: 'hotel_travel',
          promptVi: 'Phòng này có kèm bữa sáng miễn phí không?',
          level: 'A2',
          hints: ['breakfast', 'included', 'complimentary'],
          suggestedAnswers: [
            'Is breakfast included with this room?',
            'Does this room include breakfast?',
            'Is complimentary breakfast provided?',
          ],
          contextDesc: 'Kiểm tra quyền lợi ăn sáng khi đặt phòng',
        ),
        ReflexChallenge(
          id: 'ht_4',
          topicId: 'hotel_travel',
          promptVi: 'Tôi muốn làm thủ tục trả phòng.',
          level: 'A1',
          hints: ['check out', 'ready to'],
          suggestedAnswers: [
            'I would like to check out, please.',
            'I am ready to check out.',
            'Can I check out now?',
          ],
          contextDesc: 'Ra quầy lễ tân thanh toán và trả chìa khóa phòng',
        ),
      ],
    ),
    const ReflexTopic(
      id: 'dining_cafe',
      title: 'Nhà hàng & Cafe',
      titleEn: 'Dining & Cafe',
      icon: 'restaurant_rounded',
      description: 'Gọi món, hỏi bàn, thanh toán, lưu ý dị ứng',
      challenges: [
        ReflexChallenge(
          id: 'dc_1',
          topicId: 'dining_cafe',
          promptVi: 'Bàn này đã có ai ngồi chưa?',
          level: 'A1',
          hints: ['table', 'taken', 'anyone sitting'],
          suggestedAnswers: [
            'Is this table taken?',
            'Is anyone sitting here?',
            'Is this seat free?',
          ],
          contextDesc: 'Tìm chỗ ngồi trong quán đông khách',
        ),
        ReflexChallenge(
          id: 'dc_2',
          topicId: 'dining_cafe',
          promptVi: 'Cho tôi xem thực đơn được không?',
          level: 'A1',
          hints: ['menu', 'see/have'],
          suggestedAnswers: [
            'Could I see the menu, please?',
            'Can we have the menu?',
            'May I have a look at the menu?',
          ],
          contextDesc: 'Mới vào bàn và muốn xem danh sách món ăn',
        ),
        ReflexChallenge(
          id: 'dc_3',
          topicId: 'dining_cafe',
          promptVi: 'Món này có cay không?',
          level: 'A2',
          hints: ['dish', 'spicy/hot'],
          suggestedAnswers: [
            'Is this dish spicy?',
            'How spicy is this?',
            'Is it very spicy?',
          ],
          contextDesc: 'Hỏi nhân viên trước khi chọn món lạ',
        ),
        ReflexChallenge(
          id: 'dc_4',
          topicId: 'dining_cafe',
          promptVi: 'Làm ơn cho tôi thanh toán tiền.',
          level: 'A2',
          hints: ['bill / check', 'please'],
          suggestedAnswers: [
            'Could I have the bill, please?',
            'Check, please.',
            'Can we pay now?',
          ],
          contextDesc: 'Ăn xong và gọi phục vụ tính tiền',
        ),
      ],
    ),
    const ReflexTopic(
      id: 'work_office',
      title: 'Công sở & Đi làm',
      titleEn: 'Work & Office',
      icon: 'business_center_rounded',
      description: 'Hạn chót, dời cuộc họp, xin phép, trao đổi công việc',
      challenges: [
        ReflexChallenge(
          id: 'wo_1',
          topicId: 'work_office',
          promptVi: 'Khi nào là hạn chót của dự án này?',
          level: 'A2',
          hints: ['deadline', 'due date', 'project'],
          suggestedAnswers: [
            'When is the deadline for this project?',
            'What is the due date for this project?',
            'When does this project need to be finished?',
          ],
          contextDesc: 'Hỏi sếp hoặc đồng nghiệp về thời hạn nộp bài',
        ),
        ReflexChallenge(
          id: 'wo_2',
          topicId: 'work_office',
          promptVi: 'Tôi có thể xin phép về sớm hôm nay được không?',
          level: 'B1',
          hints: ['leave early', 'mind if I'],
          suggestedAnswers: [
            'Could I leave a bit early today?',
            'Would it be alright if I left early today?',
            'Can I take off a little early today?',
          ],
          contextDesc: 'Có việc gia đình đột xuất cần xin phép quản lý',
        ),
        ReflexChallenge(
          id: 'wo_3',
          topicId: 'work_office',
          promptVi: 'Chúng ta có thể dời cuộc họp sang chiều mai không?',
          level: 'B1',
          hints: ['reschedule', 'push back', 'tomorrow afternoon'],
          suggestedAnswers: [
            'Can we reschedule the meeting to tomorrow afternoon?',
            'Could we push back the meeting to tomorrow afternoon?',
            'Is it possible to move the meeting?',
          ],
          contextDesc: 'Trùng lịch họp và cần đổi sang buổi khác',
        ),
      ],
    ),
    const ReflexTopic(
      id: 'daily_social',
      title: 'Giao tiếp Hằng ngày',
      titleEn: 'Daily Chit-chat',
      icon: 'forum_rounded',
      description: 'Rủ đi chơi, hỏi thăm bạn bè, kết nối tự nhiên',
      challenges: [
        ReflexChallenge(
          id: 'ds_1',
          topicId: 'daily_social',
          promptVi: 'Hôm nay bạn có rảnh đi cà phê với tôi không?',
          level: 'A2',
          hints: ['free for coffee', 'grab coffee'],
          suggestedAnswers: [
            'Are you free for coffee today?',
            'Do you want to grab coffee today?',
            'Would you like to get a coffee with me today?',
          ],
          contextDesc: 'Rủ bạn bè hoặc đồng nghiệp đi uống nước trò chuyện',
        ),
        ReflexChallenge(
          id: 'ds_2',
          topicId: 'daily_social',
          promptVi: 'Dạo này công việc của bạn thế nào rồi?',
          level: 'A2',
          hints: ['how is work', 'going lately'],
          suggestedAnswers: [
            'How has work been lately?',
            'How is work going?',
            'How are things at work?',
          ],
          contextDesc: 'Hỏi thăm cuộc sống công việc của người quen lâu ngày gặp lại',
        ),
        ReflexChallenge(
          id: 'ds_3',
          topicId: 'daily_social',
          promptVi: 'Xin lỗi, bạn có thể nói chậm lại một chút được không?',
          level: 'A1',
          hints: ['speak slower', 'a bit slower'],
          suggestedAnswers: [
            'Could you please speak a little slower?',
            'Can you speak more slowly, please?',
            'Could you slow down a bit?',
          ],
          contextDesc: 'Khi người nước ngoài nói quá nhanh và bạn nghe không kịp',
        ),
      ],
    ),
  ];
}
