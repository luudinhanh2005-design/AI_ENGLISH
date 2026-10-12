import 'models/vocabulary_models.dart';

List<VocabularyTopicModel> buildStaticTopics() {
  return [
    const VocabularyTopicModel(
      id: 'topic_daily_comm',
      slug: 'daily-communication',
      title: 'Giao Tiếp Hàng Ngày',
      description: 'Từ vựng thông dụng trong chào hỏi, trò chuyện và sinh hoạt thường nhật.',
      iconName: 'chat_bubble',
      level: 'A1-A2',
      totalWords: 10,
    ),
    const VocabularyTopicModel(
      id: 'topic_work_business',
      slug: 'work-and-business',
      title: 'Công Việc & Công Sở',
      description: 'Thuật ngữ văn phòng, phỏng vấn xin việc, họp hành và đàm phán.',
      iconName: 'briefcase',
      level: 'B1-B2',
      totalWords: 10,
    ),
    const VocabularyTopicModel(
      id: 'topic_travel_world',
      slug: 'travel-and-tourism',
      title: 'Du Lịch & Khám Phá',
      description: 'Hỏi đường, sân bay, đặt khách sạn, ẩm thực và mua sắm khi đi xa.',
      iconName: 'flight',
      level: 'A2-B1',
      totalWords: 10,
    ),
    const VocabularyTopicModel(
      id: 'topic_tech_digital',
      slug: 'technology-and-digital',
      title: 'Công Nghệ & Kỹ Thuật Số',
      description: 'Trí tuệ nhân tạo, thiết bị số, mạng xã hội và phần mềm hiện đại.',
      iconName: 'laptop',
      level: 'B1-B2',
      totalWords: 10,
    ),
    const VocabularyTopicModel(
      id: 'topic_emotions_life',
      slug: 'emotions-and-feelings',
      title: 'Cảm Xúc & Tính Cách',
      description: 'Bày tỏ tâm trạng, miêu tả tính cách con người và thái độ sống.',
      iconName: 'menu_book',
      level: 'A2-B1',
      totalWords: 10,
    ),
  ];
}

List<VocabularyWordModel> buildTopicWords(String topicId) {
  switch (topicId) {
    case 'topic_daily_comm':
      return [
        const VocabularyWordModel(
          id: 'dc_1', topicId: 'topic_daily_comm', word: 'Greeting',
          phonetic: '/ˈɡriː.tɪŋ/', partOfSpeech: 'noun',
          meaningVi: 'Lời chào hỏi', meaningEn: 'Something friendly that you say or do when you meet someone',
          exampleSentence: 'A warm greeting always makes guests feel welcome.',
          exampleTranslation: 'Một lời chào ấm áp luôn khiến khách cảm thấy được hoan nghênh.', level: 'A1',
        ),
        const VocabularyWordModel(
          id: 'dc_2', topicId: 'topic_daily_comm', word: 'Neighborhood',
          phonetic: '/ˈneɪ.bə.hʊd/', partOfSpeech: 'noun',
          meaningVi: 'Khu phố, hàng xóm', meaningEn: 'An area of a town or city that people live in',
          exampleSentence: 'We live in a peaceful neighborhood.',
          exampleTranslation: 'Chúng tôi sống trong một khu phố yên bình.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'dc_3', topicId: 'topic_daily_comm', word: 'Appointment',
          phonetic: '/əˈpɔɪnt.mənt/', partOfSpeech: 'noun',
          meaningVi: 'Cuộc hẹn, lịch hẹn', meaningEn: 'A formal arrangement to meet someone at a particular time',
          exampleSentence: 'I have a dentist appointment at 3 PM.',
          exampleTranslation: 'Tôi có một lịch hẹn với nha sĩ lúc 3 giờ chiều.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'dc_4', topicId: 'topic_daily_comm', word: 'Routine',
          phonetic: '/ruːˈtiːn/', partOfSpeech: 'noun',
          meaningVi: 'Thói quen hàng ngày', meaningEn: 'A usual or fixed way of doing things',
          exampleSentence: 'Exercise is an essential part of my morning routine.',
          exampleTranslation: 'Tập thể dục là một phần thiết yếu trong thói quen buổi sáng của tôi.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'dc_5', topicId: 'topic_daily_comm', word: 'Convenient',
          phonetic: '/kənˈviː.ni.ənt/', partOfSpeech: 'adjective',
          meaningVi: 'Tiện lợi, thuận tiện', meaningEn: 'Suitable or agreeable to the needs or purpose',
          exampleSentence: 'Online shopping is extremely convenient.',
          exampleTranslation: 'Mua sắm trực tuyến vô cùng tiện lợi.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'dc_6', topicId: 'topic_daily_comm', word: 'Polite',
          phonetic: '/pəˈlaɪt/', partOfSpeech: 'adjective',
          meaningVi: 'Lịch sự, nhã nhặn', meaningEn: 'Behaving in a way that is socially correct and considerate',
          exampleSentence: 'It is polite to say thank you when receiving help.',
          exampleTranslation: 'Nói lời cảm ơn khi nhận được giúp đỡ là điều lịch sự.', level: 'A1',
        ),
        const VocabularyWordModel(
          id: 'dc_7', topicId: 'topic_daily_comm', word: 'Apologize',
          phonetic: '/əˈpɒl.ə.dʒaɪz/', partOfSpeech: 'verb',
          meaningVi: 'Xin lỗi', meaningEn: 'To say sorry for having done something wrong',
          exampleSentence: 'He apologized for being late to the dinner.',
          exampleTranslation: 'Anh ấy đã xin lỗi vì đến muộn bữa tối.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'dc_8', topicId: 'topic_daily_comm', word: 'Invitation',
          phonetic: '/ˌɪn.vɪˈteɪ.ʃən/', partOfSpeech: 'noun',
          meaningVi: 'Lời mời', meaningEn: 'A request to attend an event or perform an action',
          exampleSentence: 'Thank you so much for the birthday invitation.',
          exampleTranslation: 'Cảm ơn bạn rất nhiều vì lời mời sinh nhật.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'dc_9', topicId: 'topic_daily_comm', word: 'Recommend',
          phonetic: '/ˌrek.əˈmend/', partOfSpeech: 'verb',
          meaningVi: 'Gợi ý, giới thiệu', meaningEn: 'To suggest that someone would be good or suitable',
          exampleSentence: 'Can you recommend a good local restaurant?',
          exampleTranslation: 'Bạn có thể gợi ý một nhà hàng địa phương ngon không?', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'dc_10', topicId: 'topic_daily_comm', word: 'Appreciate',
          phonetic: '/əˈpriː.ʃi.eɪt/', partOfSpeech: 'verb',
          meaningVi: 'Cảm kích, trân trọng', meaningEn: 'To recognize how good someone or something is',
          exampleSentence: 'I really appreciate your timely assistance.',
          exampleTranslation: 'Tôi thực sự cảm kích sự giúp đỡ kịp thời của bạn.', level: 'B1',
        ),
      ];

    case 'topic_work_business':
      return [
        const VocabularyWordModel(
          id: 'wb_1', topicId: 'topic_work_business', word: 'Colleague',
          phonetic: '/ˈkɒl.iːɡ/', partOfSpeech: 'noun',
          meaningVi: 'Đồng nghiệp', meaningEn: 'One of a group of people who work together',
          exampleSentence: 'My colleagues are very supportive and cooperative.',
          exampleTranslation: 'Các đồng nghiệp của tôi rất hỗ trợ và hợp tác.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'wb_2', topicId: 'topic_work_business', word: 'Deadline',
          phonetic: '/ˈded.laɪn/', partOfSpeech: 'noun',
          meaningVi: 'Hạn chót', meaningEn: 'A time or day by which something must be done',
          exampleSentence: 'We must submit the proposal before the Friday deadline.',
          exampleTranslation: 'Chúng ta phải nộp đề xuất trước hạn chót thứ Sáu.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'wb_3', topicId: 'topic_work_business', word: 'Negotiate',
          phonetic: '/nəˈɡəʊ.ʃi.eɪt/', partOfSpeech: 'verb',
          meaningVi: 'Đàm phán, thương lượng', meaningEn: 'To have formal discussions with someone in order to reach an agreement',
          exampleSentence: 'They negotiated a favorable contract with the new client.',
          exampleTranslation: 'Họ đã đàm phán một hợp đồng có lợi với khách hàng mới.', level: 'B2',
        ),
        const VocabularyWordModel(
          id: 'wb_4', topicId: 'topic_work_business', word: 'Productivity',
          phonetic: '/ˌprɒd.ʌkˈtɪv.ə.ti/', partOfSpeech: 'noun',
          meaningVi: 'Năng suất làm việc', meaningEn: 'The rate at which a person or company does useful work',
          exampleSentence: 'Flexible working hours can boost employee productivity.',
          exampleTranslation: 'Giờ làm việc linh hoạt có thể nâng cao năng suất nhân viên.', level: 'B2',
        ),
        const VocabularyWordModel(
          id: 'wb_5', topicId: 'topic_work_business', word: 'Strategy',
          phonetic: '/ˈstræt.ə.dʒi/', partOfSpeech: 'noun',
          meaningVi: 'Chiến lược', meaningEn: 'A detailed plan for achieving success in business',
          exampleSentence: 'The marketing strategy generated impressive sales results.',
          exampleTranslation: 'Chiến lược tiếp thị đã mang lại kết quả doanh số ấn tượng.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'wb_6', topicId: 'topic_work_business', word: 'Presentation',
          phonetic: '/ˌprez.ənˈteɪ.ʃən/', partOfSpeech: 'noun',
          meaningVi: 'Bài thuyết trình', meaningEn: 'A talk giving information about something',
          exampleSentence: 'She gave an outstanding presentation to the board.',
          exampleTranslation: 'Cô ấy đã có bài thuyết trình xuất sắc trước hội đồng.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'wb_7', topicId: 'topic_work_business', word: 'Promotion',
          phonetic: '/prəˈməʊ.ʃən/', partOfSpeech: 'noun',
          meaningVi: 'Sự thăng tiến', meaningEn: 'The act of raising someone to a higher position or rank',
          exampleSentence: 'He earned a promotion after exceeding all targets.',
          exampleTranslation: 'Anh ấy được thăng chức sau khi vượt mọi chỉ tiêu.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'wb_8', topicId: 'topic_work_business', word: 'Budget',
          phonetic: '/ˈbʌdʒ.ɪt/', partOfSpeech: 'noun',
          meaningVi: 'Ngân sách', meaningEn: 'A plan to show how much money a person or organization will spend',
          exampleSentence: 'The project was completed well within budget.',
          exampleTranslation: 'Dự án đã hoàn thành trong phạm vi ngân sách cho phép.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'wb_9', topicId: 'topic_work_business', word: 'Feedback',
          phonetic: '/ˈfiːd.bæk/', partOfSpeech: 'noun',
          meaningVi: 'Ý kiến phản hồi', meaningEn: 'Information about reactions to a product or a person\'s performance',
          exampleSentence: 'Constructive feedback helps employees grow rapidly.',
          exampleTranslation: 'Phản hồi mang tính xây dựng giúp nhân viên phát triển nhanh chóng.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'wb_10', topicId: 'topic_work_business', word: 'Objective',
          phonetic: '/əbˈdʒek.tɪv/', partOfSpeech: 'noun',
          meaningVi: 'Mục tiêu', meaningEn: 'Something that you plan to do or achieve',
          exampleSentence: 'Our primary objective is to improve customer satisfaction.',
          exampleTranslation: 'Mục tiêu hàng đầu của chúng tôi là cải thiện sự hài lòng của khách hàng.', level: 'B2',
        ),
      ];

    case 'topic_travel_world':
      return [
        const VocabularyWordModel(
          id: 'tw_1', topicId: 'topic_travel_world', word: 'Destination',
          phonetic: '/ˌdes.tɪˈneɪ.ʃən/', partOfSpeech: 'noun',
          meaningVi: 'Điểm đến', meaningEn: 'The place where someone is going or being sent',
          exampleSentence: 'Da Nang is a popular travel destination in Vietnam.',
          exampleTranslation: 'Đà Nẵng là một điểm đến du lịch nổi tiếng ở Việt Nam.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'tw_2', topicId: 'topic_travel_world', word: 'Reservation',
          phonetic: '/ˌrez.əˈveɪ.ʃən/', partOfSpeech: 'noun',
          meaningVi: 'Sự đặt chỗ trước', meaningEn: 'An arrangement in which something is kept for you',
          exampleSentence: 'I made a hotel reservation two weeks in advance.',
          exampleTranslation: 'Tôi đã đặt phòng khách sạn trước hai tuần.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'tw_3', topicId: 'topic_travel_world', word: 'Itinerary',
          phonetic: '/aɪˈtɪn.ər.ər.i/', partOfSpeech: 'noun',
          meaningVi: 'Lịch trình chuyến đi', meaningEn: 'A detailed plan or route of a journey',
          exampleSentence: 'Our travel itinerary includes four historic temples.',
          exampleTranslation: 'Lịch trình du lịch của chúng tôi bao gồm bốn ngôi đền cổ.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'tw_4', topicId: 'topic_travel_world', word: 'Departure',
          phonetic: '/dɪˈpɑː.tʃər/', partOfSpeech: 'noun',
          meaningVi: 'Giờ khởi hành, chuyến bay đi', meaningEn: 'The fact of a person or vehicle leaving somewhere',
          exampleSentence: 'Please check your departure gate on the screen.',
          exampleTranslation: 'Vui lòng kiểm tra cổng khởi hành của bạn trên màn hình.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'tw_5', topicId: 'topic_travel_world', word: 'Souvenir',
          phonetic: '/ˌsuː.vənˈɪər/', partOfSpeech: 'noun',
          meaningVi: 'Quà lưu niệm', meaningEn: 'Something you buy or keep to remember a place or event',
          exampleSentence: 'I bought handcrafted souvenirs for my family.',
          exampleTranslation: 'Tôi đã mua quà lưu niệm thủ công cho gia đình.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'tw_6', topicId: 'topic_travel_world', word: 'Luggage',
          phonetic: '/ˈlʌɡ.ɪdʒ/', partOfSpeech: 'noun',
          meaningVi: 'Hành lý', meaningEn: 'The bags, suitcases, etc. that contain your possessions and you take with you when you are traveling',
          exampleSentence: 'You are allowed two pieces of carry-on luggage.',
          exampleTranslation: 'Bạn được phép mang theo hai kiện hành lý xách tay.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'tw_7', topicId: 'topic_travel_world', word: 'Customs',
          phonetic: '/ˈkʌs.təmz/', partOfSpeech: 'noun',
          meaningVi: 'Hải quan', meaningEn: 'The place at an airport or border where goods are checked',
          exampleSentence: 'We spent twenty minutes passing through airport customs.',
          exampleTranslation: 'Chúng tôi mất hai mươi phút để qua cửa hải quan sân bay.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'tw_8', topicId: 'topic_travel_world', word: 'Scenic',
          phonetic: '/ˈsiː.nɪk/', partOfSpeech: 'adjective',
          meaningVi: 'Phong cảnh đẹp', meaningEn: 'Having or allowing you to see beautiful natural features',
          exampleSentence: 'They took a scenic coastal drive along the ocean.',
          exampleTranslation: 'Họ đã lái xe trên cung đường ven biển tuyệt đẹp.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'tw_9', topicId: 'topic_travel_world', word: 'Exchange',
          phonetic: '/ɪksˈtʃeɪndʒ/', partOfSpeech: 'verb',
          meaningVi: 'Đổi tiền, trao đổi', meaningEn: 'To change money into another currency',
          exampleSentence: 'Where can I exchange US dollars to Vietnamese Dong?',
          exampleTranslation: 'Tôi có thể đổi đô la Mỹ sang tiền Việt ở đâu?', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'tw_10', topicId: 'topic_travel_world', word: 'Adventure',
          phonetic: '/ədˈven.tʃər/', partOfSpeech: 'noun',
          meaningVi: 'Chuyến phiêu lưu', meaningEn: 'An unusual, exciting, and possibly dangerous activity',
          exampleSentence: 'Climbing Mount Fansipan was an unforgettable adventure.',
          exampleTranslation: 'Leo đỉnh Fansipan là một chuyến phiêu lưu không thể nào quên.', level: 'B1',
        ),
      ];

    case 'topic_tech_digital':
      return [
        const VocabularyWordModel(
          id: 'td_1', topicId: 'topic_tech_digital', word: 'Algorithm',
          phonetic: '/ˈæl.ɡə.rɪ.ðəm/', partOfSpeech: 'noun',
          meaningVi: 'Thuật toán', meaningEn: 'A set of mathematical instructions or rules in calculations',
          exampleSentence: 'The recommendation algorithm suggests relevant content.',
          exampleTranslation: 'Thuật toán gợi ý nội dung phù hợp với sở thích của bạn.', level: 'B2',
        ),
        const VocabularyWordModel(
          id: 'td_2', topicId: 'topic_tech_digital', word: 'Artificial',
          phonetic: '/ˌɑː.tɪˈfɪʃ.əl/', partOfSpeech: 'adjective',
          meaningVi: 'Nhân tạo', meaningEn: 'Made by people, often as a copy of something natural',
          exampleSentence: 'Artificial Intelligence is revolutionizing language education.',
          exampleTranslation: 'Trí tuệ nhân tạo đang tạo bước ngoặt lớn trong giáo dục ngoại ngữ.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'td_3', topicId: 'topic_tech_digital', word: 'Cybersecurity',
          phonetic: '/ˌsaɪ.bə.sɪˈkjʊə.rə.ti/', partOfSpeech: 'noun',
          meaningVi: 'An ninh mạng', meaningEn: 'Ways of protecting computer systems and data against digital attacks',
          exampleSentence: 'Good password practices are basic cybersecurity hygiene.',
          exampleTranslation: 'Đặt mật khẩu an toàn là nguyên tắc an ninh mạng cơ bản.', level: 'B2',
        ),
        const VocabularyWordModel(
          id: 'td_4', topicId: 'topic_tech_digital', word: 'Interface',
          phonetic: '/ˈɪn.tə.feɪs/', partOfSpeech: 'noun',
          meaningVi: 'Giao diện', meaningEn: 'A connection between two pieces of electronic equipment, or between a person and a computer',
          exampleSentence: 'This app has a clean and intuitive user interface.',
          exampleTranslation: 'Ứng dụng này có giao diện người dùng rất sạch sẽ và trực quan.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'td_5', topicId: 'topic_tech_digital', word: 'Database',
          phonetic: '/ˈdeɪ.tə.beɪs/', partOfSpeech: 'noun',
          meaningVi: 'Cơ sở dữ liệu', meaningEn: 'A large amount of information stored in a computer system',
          exampleSentence: 'Customer profiles are stored securely in the cloud database.',
          exampleTranslation: 'Hồ sơ khách hàng được lưu trữ an toàn trong cơ sở dữ liệu đám mây.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'td_6', topicId: 'topic_tech_digital', word: 'Automate',
          phonetic: '/ˈɔː.tə.meɪt/', partOfSpeech: 'verb',
          meaningVi: 'Tự động hóa', meaningEn: 'To make a process in a factory or office operate automatically',
          exampleSentence: 'We can automate repetitive daily tasks to save hours.',
          exampleTranslation: 'Chúng ta có thể tự động hóa các tác vụ lặp đi lặp lại để tiết kiệm thời gian.', level: 'B2',
        ),
        const VocabularyWordModel(
          id: 'td_7', topicId: 'topic_tech_digital', word: 'Bandwidth',
          phonetic: '/ˈbænd.wɪtθ/', partOfSpeech: 'noun',
          meaningVi: 'Băng thông', meaningEn: 'The amount of information that can be sent through a connection at one time',
          exampleSentence: 'Streaming 4K video requires high internet bandwidth.',
          exampleTranslation: 'Xem video 4K trực tuyến yêu cầu băng thông mạng cao.', level: 'B2',
        ),
        const VocabularyWordModel(
          id: 'td_8', topicId: 'topic_tech_digital', word: 'Browse',
          phonetic: '/braʊz/', partOfSpeech: 'verb',
          meaningVi: 'Lướt web, duyệt qua', meaningEn: 'To look through a book or use the internet',
          exampleSentence: 'You can browse thousands of articles for free.',
          exampleTranslation: 'Bạn có thể duyệt qua hàng ngàn bài viết hoàn toàn miễn phí.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'td_9', topicId: 'topic_tech_digital', word: 'Encryption',
          phonetic: '/ɪnˈkrɪp.ʃən/', partOfSpeech: 'noun',
          meaningVi: 'Mã hóa dữ liệu', meaningEn: 'The process of changing electronic information into protected code',
          exampleSentence: 'End-to-end encryption keeps private messages safe.',
          exampleTranslation: 'Mã hóa đầu cuối giúp tin nhắn riêng tư luôn được bảo mật.', level: 'B2',
        ),
        const VocabularyWordModel(
          id: 'td_10', topicId: 'topic_tech_digital', word: 'Notification',
          phonetic: '/ˌnəʊ.tɪ.fɪˈkeɪ.ʃən/', partOfSpeech: 'noun',
          meaningVi: 'Thông báo', meaningEn: 'A message that appears on a phone or screen to inform the user',
          exampleSentence: 'Turn on notifications so you don\'t miss any study reminders.',
          exampleTranslation: 'Bật thông báo để không bỏ lỡ các nhắc nhở học tập.', level: 'A2',
        ),
      ];

    case 'topic_emotions_life':
      return [
        const VocabularyWordModel(
          id: 'el_1', topicId: 'topic_emotions_life', word: 'Enthusiastic',
          phonetic: '/ɪnˌθjuː.ziˈæs.tɪk/', partOfSpeech: 'adjective',
          meaningVi: 'Nhiệt tình, hăng hái', meaningEn: 'Showing energetic interest and excitement',
          exampleSentence: 'He is very enthusiastic about learning new foreign languages.',
          exampleTranslation: 'Anh ấy rất nhiệt tình với việc học các ngoại ngữ mới.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'el_2', topicId: 'topic_emotions_life', word: 'Optimistic',
          phonetic: '/ˌɒp.tɪˈmɪs.tɪk/', partOfSpeech: 'adjective',
          meaningVi: 'Lạc quan', meaningEn: 'Hoping or believing that good things will happen in the future',
          exampleSentence: 'She remained optimistic despite the tough challenges.',
          exampleTranslation: 'Cô ấy vẫn giữ tinh thần lạc quan bất chấp những thử thách khó khăn.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'el_3', topicId: 'topic_emotions_life', word: 'Confident',
          phonetic: '/ˈkɒn.fɪ.dənt/', partOfSpeech: 'adjective',
          meaningVi: 'Tự tin', meaningEn: 'Being certain of your abilities or having trust in people',
          exampleSentence: 'Practice speaking aloud to feel more confident.',
          exampleTranslation: 'Hãy luyện nói thành tiếng để cảm thấy tự tin hơn.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'el_4', topicId: 'topic_emotions_life', word: 'Frustrated',
          phonetic: '/frʌsˈtreɪ.tɪd/', partOfSpeech: 'adjective',
          meaningVi: 'Nản lòng, bực bội', meaningEn: 'Feeling annoyed or less confident because you cannot achieve what you want',
          exampleSentence: 'Don\'t feel frustrated when making grammar mistakes.',
          exampleTranslation: 'Đừng cảm thấy nản lòng khi mắc lỗi ngữ pháp.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'el_5', topicId: 'topic_emotions_life', word: 'Compassionate',
          phonetic: '/kəmˈpæʃ.ən.ət/', partOfSpeech: 'adjective',
          meaningVi: 'Giàu lòng trắc ẩn, nhân ái', meaningEn: 'Feeling or showing sympathy and concern for others',
          exampleSentence: 'A compassionate doctor listens carefully to patients.',
          exampleTranslation: 'Một bác sĩ giàu lòng nhân ái sẽ luôn lắng nghe bệnh nhân.', level: 'B2',
        ),
        const VocabularyWordModel(
          id: 'el_6', topicId: 'topic_emotions_life', word: 'Generous',
          phonetic: '/ˈdʒen.ər.əs/', partOfSpeech: 'adjective',
          meaningVi: 'Hào phóng, rộng lượng', meaningEn: 'Willing to give money, help, kindness, etc.',
          exampleSentence: 'He made a generous donation to the local school.',
          exampleTranslation: 'Anh ấy đã có một khoản quyên góp hào phóng cho trường học địa phương.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'el_7', topicId: 'topic_emotions_life', word: 'Grateful',
          phonetic: '/ˈɡreɪt.fəl/', partOfSpeech: 'adjective',
          meaningVi: 'Biết ơn', meaningEn: 'Showing or expressing thanks, especially for kindness',
          exampleSentence: 'I am deeply grateful for all your valuable advice.',
          exampleTranslation: 'Tôi vô cùng biết ơn tất cả những lời khuyên quý báu của bạn.', level: 'B1',
        ),
        const VocabularyWordModel(
          id: 'el_8', topicId: 'topic_emotions_life', word: 'Determined',
          phonetic: '/dɪˈtɜː.mɪnd/', partOfSpeech: 'adjective',
          meaningVi: 'Quyết tâm, kiên định', meaningEn: 'Wanting to do something very much and not allowing difficulties to stop you',
          exampleSentence: 'She is determined to achieve an IELTS 7.5 this year.',
          exampleTranslation: 'Cô ấy quyết tâm đạt điểm IELTS 7.5 trong năm nay.', level: 'B2',
        ),
        const VocabularyWordModel(
          id: 'el_9', topicId: 'topic_emotions_life', word: 'Curious',
          phonetic: '/ˈkjʊə.ri.əs/', partOfSpeech: 'adjective',
          meaningVi: 'Tò mò, ham học hỏi', meaningEn: 'Interested in learning about people or things around you',
          exampleSentence: 'Curious learners absorb new knowledge much faster.',
          exampleTranslation: 'Những người học có tính tò mò sẽ tiếp thu kiến thức mới nhanh hơn nhiều.', level: 'A2',
        ),
        const VocabularyWordModel(
          id: 'el_10', topicId: 'topic_emotions_life', word: 'Patient',
          phonetic: '/ˈpeɪ.ʃənt/', partOfSpeech: 'adjective',
          meaningVi: 'Kiên nhẫn', meaningEn: 'Able to wait, or to continue doing something despite difficulties',
          exampleSentence: 'Language learning takes time, so remember to stay patient.',
          exampleTranslation: 'Học ngôn ngữ cần có thời gian, vì vậy hãy nhớ luôn kiên nhẫn.', level: 'A2',
        ),
      ];

    default:
      return buildTopicWords('topic_daily_comm');
  }
}
