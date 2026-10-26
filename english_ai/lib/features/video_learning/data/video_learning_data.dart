import 'models/subtitle_line.dart';
import 'models/video_lesson.dart';

class VideoLearningData {
  static const List<VideoLesson> sampleLessons = [
    VideoLesson(
      id: 'vid_coffee_ordering',
      title: 'Ordering at a Cozy Café',
      vietnameseTitle: 'Gọi đồ uống tại quán cà phê',
      description:
          'Học cách gọi đồ uống tự nhiên, yêu cầu tùy chỉnh cỡ ly, độ ngọt và thanh toán bằng tiếng Anh.',
      category: 'Giao tiếp hàng ngày',
      level: 'A2',
      durationSeconds: 75,
      // Sample video link using reliable public MP4 stream with CORS support
      videoUrl: 'https://vjs.zencdn.net/v/oceans.mp4',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=800&q=80',
      learningObjectives: [
        'Cách dùng cấu trúc lịch sự "Could I get..." hoặc "I\'d like to have..."',
        'Thuật ngữ kích cỡ ly: single shot, oat milk, iced, to go',
        'Phản xạ khi nhân viên hỏi lại về thẻ thành viên và thanh toán',
      ],
      xpReward: 35,
      subtitles: [
        SubtitleLine(
          id: 'sub_1_1',
          startMs: 0,
          endMs: 4500,
          englishText: 'Good morning! What can I get started for you today?',
          vietnameseText: 'Chào buổi sáng! Hôm nay tôi có thể lấy gì cho bạn?',
          ipa: '/ɡʊd ˈmɔːrnɪŋ wʌt kæn aɪ ɡɛt ˈstɑːrtɪd fɔːr juː təˈdeɪ/',
          vocabulary: [
            SubtitleVocabItem(
              word: 'get started',
              partOfSpeech: 'phrasal verb',
              ipa: '/ɡɛt ˈstɑːrtɪd/',
              meaningVi: 'Bắt đầu chuẩn bị / phục vụ',
              exampleSentence: 'Let us get started with some drinks.',
            ),
          ],
          grammarNotes: [
            'Câu chào cửa miệng cực kỳ phổ biến của nhân viên phục vụ tại Mỹ.',
            'Nối âm: "What can I" nói lướt thành /wʌt-kə-naɪ/.',
          ],
          reflexQuestion: 'How would you respond when the barista asks what to start for you?',
          suggestedResponse: 'Hi! Could I get an iced caramel latte with oat milk, please?',
        ),
        SubtitleLine(
          id: 'sub_1_2',
          startMs: 4800,
          endMs: 9500,
          englishText: 'Hi! Could I get a medium iced caramel latte, please?',
          vietnameseText: 'Chào bạn! Cho tôi một ly latte caramel đá cỡ vừa nhé, làm ơn.',
          ipa: '/haɪ kʊd aɪ ɡɛt ə ˈmiːdiəm aɪst ˈkærəmɛl ˈlɑːteɪ pliːz/',
          vocabulary: [
            SubtitleVocabItem(
              word: 'medium',
              partOfSpeech: 'adjective',
              ipa: '/ˈmiːdiəm/',
              meaningVi: 'Cỡ vừa (size M)',
              exampleSentence: 'I prefer a medium size cup.',
            ),
            SubtitleVocabItem(
              word: 'latte',
              partOfSpeech: 'noun',
              ipa: '/ˈlɑːteɪ/',
              meaningVi: 'Cà phê latte sữa',
              exampleSentence: 'This caramel latte smells amazing.',
            ),
          ],
          grammarNotes: [
            'Cấu trúc "Could I get + [món đồ] + please?" là cách gọi món tự nhiên và lịch sự nhất.',
            'Nối âm: "Could I" đọc nối thành /kʊ-daɪ/.',
          ],
          reflexQuestion: 'Order an iced latte with oat milk using "Could I get...".',
          suggestedResponse: 'Could I get an iced latte with oat milk, please?',
        ),
        SubtitleLine(
          id: 'sub_1_3',
          startMs: 9800,
          endMs: 14500,
          englishText: 'Sure thing! Would you prefer regular whole milk or plant-based milk?',
          vietnameseText: 'Chắc chắn rồi! Bạn thích dùng sữa tươi thông thường hay sữa hạt thực vật?',
          ipa: '/ʃʊr θɪŋ wʊd juː prɪˈfɜːr ˈrɛɡjələr hoʊl mɪlk ɔːr plænt beɪst mɪlk/',
          vocabulary: [
            SubtitleVocabItem(
              word: 'plant-based',
              partOfSpeech: 'adjective',
              ipa: '/plænt beɪst/',
              meaningVi: 'Có nguồn gốc thực vật (sữa yến mạch, sữa đậu nành)',
              exampleSentence: 'Do you offer any plant-based alternatives?',
            ),
            SubtitleVocabItem(
              word: 'prefer',
              partOfSpeech: 'verb',
              ipa: '/prɪˈfɜːr/',
              meaningVi: 'Thích hơn, ưu tiên chọn',
              exampleSentence: 'I prefer oat milk over almond milk.',
            ),
          ],
          grammarNotes: [
            '"Would you prefer A or B?" dùng để hỏi sở thích một cách trang trọng, lịch thiệp.',
          ],
          reflexQuestion: 'Choose oat milk instead of regular milk.',
          suggestedResponse: 'I would like oat milk, please.',
        ),
        SubtitleLine(
          id: 'sub_1_4',
          startMs: 14800,
          endMs: 19800,
          englishText: 'Oat milk would be fantastic, and less ice if possible.',
          vietnameseText: 'Sữa yến mạch thì tuyệt vời quá, và cho ít đá nếu có thể nhé.',
          ipa: '/oʊt mɪlk wʊd biː fænˈtæstɪk ænd lɛs aɪs ɪf ˈpɒsəbl/',
          vocabulary: [
            SubtitleVocabItem(
              word: 'less ice',
              partOfSpeech: 'noun phrase',
              ipa: '/lɛs aɪs/',
              meaningVi: 'Ít đá',
              exampleSentence: 'Can I have less ice in my milk tea?',
            ),
            SubtitleVocabItem(
              word: 'fantastic',
              partOfSpeech: 'adjective',
              ipa: '/fænˈtæstɪk/',
              meaningVi: 'Tuyệt vời',
              exampleSentence: 'That sounds fantastic!',
            ),
          ],
          grammarNotes: [
            'Cụm "if possible" (nếu có thể) đặt ở cuối câu để tăng tính mềm mỏng, lịch sự khi đưa ra yêu cầu.',
          ],
          reflexQuestion: 'Ask for less ice and half sugar.',
          suggestedResponse: 'Could I have less ice and half sugar, if possible?',
        ),
        SubtitleLine(
          id: 'sub_1_5',
          startMs: 20200,
          endMs: 25500,
          englishText: 'You got it! Is that for here or to go?',
          vietnameseText: 'Đã rõ! Bạn dùng tại quán hay mang đi?',
          ipa: '/juː ɡɑːt ɪt ɪz ðæt fɔːr hɪər ɔːr tə ɡoʊ/',
          vocabulary: [
            SubtitleVocabItem(
              word: 'for here',
              partOfSpeech: 'phrase',
              ipa: '/fɔːr hɪər/',
              meaningVi: 'Dùng tại chỗ (ở quán)',
              exampleSentence: 'Table for two, for here please.',
            ),
            SubtitleVocabItem(
              word: 'to go',
              partOfSpeech: 'phrase',
              ipa: '/tə ɡoʊ/',
              meaningVi: 'Mang đi (take away)',
              exampleSentence: 'I am running late, so make it to go.',
            ),
          ],
          grammarNotes: [
            '"For here or to go?" là câu hỏi cực kỳ thông dụng ở Bắc Mỹ (tương đương "Eat in or take away?" ở Anh).',
          ],
          reflexQuestion: 'Answer that you want to take it away (to go).',
          suggestedResponse: 'To go, please! Thank you.',
        ),
        SubtitleLine(
          id: 'sub_1_6',
          startMs: 26000,
          endMs: 31000,
          englishText: 'To go, please! Can I also pay by contactless card?',
          vietnameseText: 'Mang đi nhé! Tôi có thể quẹt thẻ không chạm được không?',
          ipa: '/tə ɡoʊ pliːz kæn aɪ ˈɔːlsoʊ peɪ baɪ ˈkɒntæktləs kɑːrd/',
          vocabulary: [
            SubtitleVocabItem(
              word: 'contactless',
              partOfSpeech: 'adjective',
              ipa: '/ˈkɒntæktləs/',
              meaningVi: 'Không tiếp xúc / không chạm (Apple Pay, thẻ chip chạm)',
              exampleSentence: 'We accept contactless payments.',
            ),
          ],
          grammarNotes: [
            '"pay by + [loại thẻ / phương thức]": pay by card, pay by cash, pay by phone.',
          ],
          reflexQuestion: 'Ask if you can pay with Apple Pay or card.',
          suggestedResponse: 'Do you accept Apple Pay or card?',
        ),
      ],
    ),
    VideoLesson(
      id: 'vid_job_interview',
      title: 'Ace Your Job Interview Introduction',
      vietnameseTitle: 'Tự giới thiệu bản thân ấn tượng khi phỏng vấn',
      description:
          'Cách trả lời câu hỏi kinh điển "Tell me about yourself" một cách tự tin, chuyên nghiệp và súc tích.',
      category: 'Phỏng vấn & Công sở',
      level: 'B1',
      durationSeconds: 85,
      videoUrl:
          'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=800&q=80',
      learningObjectives: [
        'Cấu trúc Present - Past - Future khi giới thiệu bản thân',
        'Từ vựng chỉ kỹ năng chuyên môn: passionate about, specialize in, track record',
        'Phản xạ trả lời trôi chảy không ngập ngừng',
      ],
      xpReward: 40,
      subtitles: [
        SubtitleLine(
          id: 'sub_2_1',
          startMs: 0,
          endMs: 5200,
          englishText: 'Thank you for having me today. I am truly excited about this opportunity.',
          vietnameseText: 'Cảm ơn quý công ty đã dành thời gian phỏng vấn tôi hôm nay. Tôi thực sự hào hứng với cơ hội này.',
          ipa: '/θæŋk juː fɔːr ˈhævɪŋ miː təˈdeɪ aɪ æm ˈtruːli ɪkˈsaɪtɪd əˈbaʊt ðɪs ˌɒpərˈtuːnəti/',
          vocabulary: [
            SubtitleVocabItem(
              word: 'opportunity',
              partOfSpeech: 'noun',
              ipa: '/ˌɒpərˈtuːnəti/',
              meaningVi: 'Cơ hội việc làm / dịp tốt',
              exampleSentence: 'This role is a tremendous career opportunity.',
            ),
          ],
          grammarNotes: [
            '"Thank you for having me": Lời mở đầu tiêu chuẩn thể hiện sự tôn trọng nhà tuyển dụng.',
          ],
          reflexQuestion: 'Open your interview with gratitude and enthusiasm.',
          suggestedResponse: 'Thank you for having me today. It is a pleasure to meet you.',
        ),
        SubtitleLine(
          id: 'sub_2_2',
          startMs: 5500,
          endMs: 11000,
          englishText: 'For the past three years, I have been working as a software engineer specializing in mobile apps.',
          vietnameseText: 'Trong ba năm qua, tôi đã làm việc với tư cách là kỹ sư phần mềm chuyên về ứng dụng di động.',
          ipa: '/fɔːr ðə pæst θriː jɪərz aɪ hæv biːn ˈwɜːrkɪŋ æz ə ˈsɒftweər ˌɛndʒɪˈnɪər ˈspɛʃəlaɪzɪŋ ɪn ˈmoʊbl æps/',
          vocabulary: [
            SubtitleVocabItem(
              word: 'specialize in',
              partOfSpeech: 'verb phrase',
              ipa: '/ˈspɛʃəlaɪz ɪn/',
              meaningVi: 'Chuyên về lĩnh vực gì',
              exampleSentence: 'I specialize in Flutter app development.',
            ),
          ],
          grammarNotes: [
            'Thì hiện tại hoàn thành tiếp diễn "I have been working..." nhấn mạnh hành động liên tục từ quá khứ đến nay.',
          ],
          reflexQuestion: 'State your current profession and years of experience.',
          suggestedResponse: 'I have been working in software development for over three years.',
        ),
        SubtitleLine(
          id: 'sub_2_3',
          startMs: 11500,
          endMs: 18000,
          englishText: 'My greatest strength is solving complex problems while collaborating closely with cross-functional teams.',
          vietnameseText: 'Thế mạnh lớn nhất của tôi là giải quyết các vấn đề phức tạp đồng thời phối hợp chặt chẽ với các đội ngũ đa chức năng.',
          ipa: '/maɪ ˈɡreɪtɪst strɛŋθ ɪz ˈsɒlvɪŋ ˈkɒmplɛks ˈprɒbləmz waɪl kəˈlæbəreɪtɪŋ ˈkloʊsli wɪð krɒs ˈfʌŋkʃənl tiːmz/',
          vocabulary: [
            SubtitleVocabItem(
              word: 'collaborate',
              partOfSpeech: 'verb',
              ipa: '/kəˈlæbəreɪt/',
              meaningVi: 'Hợp tác, phối hợp làm việc',
              exampleSentence: 'We collaborate closely with product managers.',
            ),
            SubtitleVocabItem(
              word: 'cross-functional',
              partOfSpeech: 'adjective',
              ipa: '/krɒs ˈfʌŋkʃənl/',
              meaningVi: 'Đa phòng ban, đa chức năng',
              exampleSentence: 'Our project involves cross-functional teams.',
            ),
          ],
          grammarNotes: [
            'Cụm "My greatest strength is + V-ing" là cách mở đầu câu trả lời về điểm mạnh rất ghi điểm.',
          ],
          reflexQuestion: 'Share your top professional strength.',
          suggestedResponse: 'My greatest strength is quick learning and effective team communication.',
        ),
      ],
    ),
    VideoLesson(
      id: 'vid_asking_directions',
      title: 'Navigating Cities & Asking Directions',
      vietnameseTitle: 'Hỏi đường và tìm phương hướng khi du lịch',
      description:
          'Không còn bỡ ngỡ khi lạc đường tại nước ngoài với các mẫu câu hỏi đường thông minh và hiểu chỉ dẫn.',
      category: 'Du lịch & Khám phá',
      level: 'A2',
      durationSeconds: 65,
      videoUrl: 'https://vjs.zencdn.net/v/oceans.mp4',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=800&q=80',
      learningObjectives: [
        'Mẫu câu hỏi đường lịch sự "Excuse me, do you happen to know..."',
        'Các từ chỉ phương hướng: turn left, head straight, across the street, landmark',
        'Xác nhận lại quãng đường mất bao lâu đi bộ',
      ],
      xpReward: 30,
      subtitles: [
        SubtitleLine(
          id: 'sub_3_1',
          startMs: 0,
          endMs: 5000,
          englishText: 'Excuse me, could you tell me how to get to the Central Train Station?',
          vietnameseText: 'Xin lỗi, bạn có thể chỉ cho tôi đường đến Ga xe lửa Trung tâm không?',
          ipa: '/ɪkˈskjuːz miː kʊd juː tɛl miː haʊ tə ɡɛt tə ðə ˈsɛntrəl treɪn ˈsteɪʃn/',
          vocabulary: [
            SubtitleVocabItem(
              word: 'how to get to',
              partOfSpeech: 'phrase',
              ipa: '/haʊ tə ɡɛt tuː/',
              meaningVi: 'Cách đi đến nơi nào đó',
              exampleSentence: 'Can you show me how to get to the museum?',
            ),
          ],
          grammarNotes: [
            'Dùng "Excuse me" trước khi bắt chuyện hỏi đường người lạ trên phố.',
            'Cấu trúc gián tiếp lịch sự: "Could you tell me how to..." (không đảo ngữ trợ động từ).',
          ],
          reflexQuestion: 'Ask someone politely how to reach the nearest subway station.',
          suggestedResponse: 'Excuse me, could you tell me how to get to the nearest subway?',
        ),
        SubtitleLine(
          id: 'sub_3_2',
          startMs: 5200,
          endMs: 11000,
          englishText: 'Sure! Walk straight down this avenue for two blocks, then turn left at the traffic light.',
          vietnameseText: 'Chắc chắn rồi! Hãy đi thẳng đại lộ này qua hai ngã tư, sau đó rẽ trái ở cột đèn giao thông.',
          ipa: '/ʃʊr wɔːk streɪt daʊn ðɪs ˈævənjuː fɔːr tuː blɒks ðɛn tɜːrn lɛft æt ðə ˈtræfɪk laɪt/',
          vocabulary: [
            SubtitleVocabItem(
              word: 'block',
              partOfSpeech: 'noun',
              ipa: '/blɒk/',
              meaningVi: 'Khối nhà / đoạn phố giữa hai giao lộ',
              exampleSentence: 'The bank is just two blocks away.',
            ),
            SubtitleVocabItem(
              word: 'traffic light',
              partOfSpeech: 'noun',
              ipa: '/ˈtræfɪk laɪt/',
              meaningVi: 'Đèn giao thông',
              exampleSentence: 'Wait at the traffic light before crossing.',
            ),
          ],
          grammarNotes: [
            'Câu mệnh lệnh chỉ đường dùng động từ nguyên mẫu: Walk straight, turn left, keep going.',
          ],
          reflexQuestion: 'How would you guide someone to turn right at the corner?',
          suggestedResponse: 'Go straight ahead and turn right at the corner.',
        ),
      ],
    ),
  ];

  static VideoLesson? getById(String id) {
    try {
      return sampleLessons.firstWhere((e) => e.id == id);
    } catch (_) {
      return sampleLessons.first;
    }
  }
}
