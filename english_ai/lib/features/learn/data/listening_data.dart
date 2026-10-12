class DialogueLine {
  final String speaker;
  final String text;
  final String textVi;

  const DialogueLine({
    required this.speaker,
    required this.text,
    required this.textVi,
  });
}

class ListeningVocab {
  final String word;
  final String phonetic;
  final String meaning;
  final String example;

  const ListeningVocab({
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.example,
  });
}

class ListeningQuestion {
  final String question;
  final String questionVi;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const ListeningQuestion({
    required this.question,
    required this.questionVi,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class ListeningLesson {
  final String id;
  final String title;
  final String titleVi;
  final String level;
  final String topic;
  final String scenarioVi;
  final List<DialogueLine> dialogue;
  final List<ListeningVocab> keyVocab;
  final List<ListeningQuestion> questions;

  const ListeningLesson({
    required this.id,
    required this.title,
    required this.titleVi,
    required this.level,
    required this.topic,
    required this.scenarioVi,
    required this.dialogue,
    required this.keyVocab,
    required this.questions,
  });
}

const List<ListeningLesson> listeningLessonsData = [
  ListeningLesson(
    id: 'lis_01',
    title: 'At the Coffee Shop',
    titleVi: 'Tại quán cà phê',
    level: 'A1',
    topic: 'Daily Life',
    scenarioVi: 'David gọi đồ uống và bánh ngọt tại một quán cà phê ở trung tâm thành phố.',
    dialogue: [
      DialogueLine(
        speaker: 'Barista',
        text: 'Good morning! What can I get for you today?',
        textVi: 'Chào buổi sáng! Tôi có thể lấy gì cho bạn hôm nay?',
      ),
      DialogueLine(
        speaker: 'David',
        text: 'Hi! Could I have a medium iced latte with oat milk, please?',
        textVi: 'Xin chào! Cho tôi một ly latte đá cỡ vừa với sữa yến mạch được không?',
      ),
      DialogueLine(
        speaker: 'Barista',
        text: 'Sure thing. Would you like any syrup with that?',
        textVi: 'Chắc chắn rồi. Bạn có muốn thêm siro gì không?',
      ),
      DialogueLine(
        speaker: 'David',
        text: 'Yes, just one pump of vanilla syrup, please.',
        textVi: 'Vâng, chỉ một pump siro vani thôi nhé.',
      ),
      DialogueLine(
        speaker: 'Barista',
        text: 'Great. Anything to eat? We have fresh croissants and blueberry muffins today.',
        textVi: 'Tuyệt. Bạn có muốn ăn gì không? Hôm nay chúng tôi có bánh sừng bò tươi và bánh muffin việt quất.',
      ),
      DialogueLine(
        speaker: 'David',
        text: 'I will take one blueberry muffin as well. How much is that?',
        textVi: 'Tôi sẽ lấy một bánh muffin việt quất nữa. Tổng cộng hết bao nhiêu vậy?',
      ),
      DialogueLine(
        speaker: 'Barista',
        text: 'That will be seven dollars and fifty cents. Cash or card?',
        textVi: 'Của bạn hết 7 đô la 50 xu. Bạn trả tiền mặt hay thẻ?',
      ),
      DialogueLine(
        speaker: 'David',
        text: 'Card, please. Here you go!',
        textVi: 'Thẻ nhé. Của bạn đây!',
      ),
    ],
    keyVocab: [
      ListeningVocab(
        word: 'Oat milk',
        phonetic: '/əʊt mɪlk/',
        meaning: 'Sữa yến mạch',
        example: 'Many people prefer oat milk over regular milk.',
      ),
      ListeningVocab(
        word: 'Vanilla syrup',
        phonetic: '/vəˈnɪlə ˈsɪrəp/',
        meaning: 'Siro hương vani',
        example: 'He added vanilla syrup to sweeten his drink.',
      ),
      ListeningVocab(
        word: 'Croissant',
        phonetic: '/kwæˈsɒ̃/',
        meaning: 'Bánh sừng bò',
        example: 'Warm croissants are perfect for breakfast.',
      ),
    ],
    questions: [
      ListeningQuestion(
        question: 'What kind of milk did David request?',
        questionVi: 'David đã yêu cầu loại sữa nào?',
        options: ['Almond milk', 'Oat milk', 'Soy milk', 'Whole milk'],
        correctIndex: 1,
        explanation: 'David nói rõ: "Could I have a medium iced latte with oat milk, please?"',
      ),
      ListeningQuestion(
        question: 'What pastry did David choose to eat?',
        questionVi: 'David đã chọn loại bánh ngọt nào?',
        options: ['Croissant', 'Chocolate cookie', 'Blueberry muffin', 'Apple pie'],
        correctIndex: 2,
        explanation: 'David nói: "I will take one blueberry muffin as well."',
      ),
      ListeningQuestion(
        question: 'How did David pay for his order?',
        questionVi: 'David đã thanh toán bằng hình thức nào?',
        options: ['Cash', 'Credit card', 'Bank transfer', 'Gift voucher'],
        correctIndex: 1,
        explanation: 'David trả lời người pha chế: "Card, please. Here you go!"',
      ),
    ],
  ),

  ListeningLesson(
    id: 'lis_02',
    title: 'Weekend Plans and Outdoor Activities',
    titleVi: 'Kế hoạch cuối tuần & Hoạt động ngoài trời',
    level: 'A2',
    topic: 'Leisure',
    scenarioVi: 'Emma và Mark thảo luận về kế hoạch đi dã ngoại và leo núi vào cuối tuần.',
    dialogue: [
      DialogueLine(
        speaker: 'Emma',
        text: 'Hey Mark, do you have any plans for this upcoming weekend?',
        textVi: 'Chào Mark, cuối tuần này cậu có kế hoạch gì chưa?',
      ),
      DialogueLine(
        speaker: 'Mark',
        text: 'Not really! I was thinking about catching up on sleep and watching movies.',
        textVi: 'Chưa có gì đặc biệt cả! Mình đang tính ngủ bù và xem vài bộ phim.',
      ),
      DialogueLine(
        speaker: 'Emma',
        text: 'The weather forecast says it will be sunny and warm on Saturday. We should go hiking in Pine Valley!',
        textVi: 'Dự báo thời tiết nói thứ Bảy trời sẽ nắng ấm đấy. Tụi mình nên đi leo núi ở Thung lũng Pine!',
      ),
      DialogueLine(
        speaker: 'Mark',
        text: 'That sounds amazing! Who else is coming with us?',
        textVi: 'Nghe tuyệt đấy! Có ai khác đi cùng tụi mình không?',
      ),
      DialogueLine(
        speaker: 'Emma',
        text: 'I invited Sarah and Lucas. We are planning to bring sandwiches, fruits, and cold drinks for a picnic.',
        textVi: 'Mình đã rủ Sarah và Lucas. Tụi mình tính mang sandwich, trái cây và nước lạnh để dã ngoại.',
      ),
      DialogueLine(
        speaker: 'Mark',
        text: 'Awesome. What time should we meet at the park entrance?',
        textVi: 'Tuyệt vời. Mấy giờ tụi mình gặp nhau ở cổng công viên nhỉ?',
      ),
      DialogueLine(
        speaker: 'Emma',
        text: 'How about eight in the morning? That way we can beat the afternoon heat.',
        textVi: 'Tầm 8 giờ sáng được không? Như vậy tụi mình có thể tránh được cái nóng buổi trưa.',
      ),
      DialogueLine(
        speaker: 'Mark',
        text: 'Perfect! I will bring my portable speaker and camera.',
        textVi: 'Hoàn hảo! Mình sẽ mang loa di động và máy ảnh theo.',
      ),
    ],
    keyVocab: [
      ListeningVocab(
        word: 'Weather forecast',
        phonetic: '/ˈweðə fɔːkɑːst/',
        meaning: 'Dự báo thời tiết',
        example: 'Check the weather forecast before heading outside.',
      ),
      ListeningVocab(
        word: 'Beat the heat',
        phonetic: '/biːt ðə hiːt/',
        meaning: 'Tránh nóng, đi trước giờ nắng gắt',
        example: 'We started our hike at dawn to beat the heat.',
      ),
      ListeningVocab(
        word: 'Portable speaker',
        phonetic: '/ˈpɔːtəbl ˈspiːkə/',
        meaning: 'Loa di động',
        example: 'He brought a portable speaker to play music on the trail.',
      ),
    ],
    questions: [
      ListeningQuestion(
        question: 'What is the weather forecasted to be on Saturday?',
        questionVi: 'Thời tiết được dự báo thế nào vào thứ Bảy?',
        options: ['Rainy and cold', 'Sunny and warm', 'Foggy and windy', 'Stormy'],
        correctIndex: 1,
        explanation: 'Emma nói: "The weather forecast says it will be sunny and warm on Saturday."',
      ),
      ListeningQuestion(
        question: 'What time are they meeting at the park entrance?',
        questionVi: 'Họ sẽ gặp nhau lúc mấy giờ tại cổng công viên?',
        options: ['7:00 AM', '8:00 AM', '9:30 AM', '12:00 PM'],
        correctIndex: 1,
        explanation: 'Emma đề xuất: "How about eight in the morning? That way we can beat the afternoon heat."',
      ),
      ListeningQuestion(
        question: 'What items will Mark bring?',
        questionVi: 'Mark sẽ mang theo những món đồ nào?',
        options: ['Sandwiches and fruits', 'Tent and flashlight', 'Portable speaker and camera', 'First-aid kit'],
        correctIndex: 2,
        explanation: 'Mark chốt lại: "I will bring my portable speaker and camera."',
      ),
    ],
  ),

  ListeningLesson(
    id: 'lis_03',
    title: 'Airport Check-in and Gate Changes',
    titleVi: 'Thủ tục sân bay & Đổi cổng lên máy bay',
    level: 'B1',
    topic: 'Travel',
    scenarioVi: 'Alex làm thủ tục lên chuyến bay quốc tế và nhận thông báo quan trọng từ nhân viên hàng không.',
    dialogue: [
      DialogueLine(
        speaker: 'Agent',
        text: 'Good afternoon, welcome to SkyAir. Where are you flying to today?',
        textVi: 'Chào buổi chiều, chào mừng quý khách đến với SkyAir. Hôm nay bạn bay tới đâu?',
      ),
      DialogueLine(
        speaker: 'Alex',
        text: 'Hello. I am flying to Tokyo on flight SK420. Here is my passport and booking reference.',
        textVi: 'Xin chào. Tôi bay đến Tokyo trên chuyến bay SK420. Đây là hộ chiếu và mã đặt vé của tôi.',
      ),
      DialogueLine(
        speaker: 'Agent',
        text: 'Thank you, Alex. Do you have any luggage to check in today?',
        textVi: 'Cảm ơn Alex. Bạn có hành lý ký gửi nào hôm nay không?',
      ),
      DialogueLine(
        speaker: 'Alex',
        text: 'Just this one large suitcase. And I have this backpack as carry-on luggage.',
        textVi: 'Chỉ một vali lớn này thôi. Và tôi có balo này làm hành lý xách tay.',
      ),
      DialogueLine(
        speaker: 'Agent',
        text: 'Please place your suitcase on the scale. Perfect, exactly twenty-one kilograms.',
        textVi: 'Vui lòng đặt vali lên cân. Hoàn hảo, đúng 21 kg.',
      ),
      DialogueLine(
        speaker: 'Agent',
        text: 'Please be aware that your departure gate has moved from Gate B12 to Gate C05 due to maintenance.',
        textVi: 'Xin lưu ý cổng khởi hành của bạn đã đổi từ B12 sang C05 do bảo trì.',
      ),
      DialogueLine(
        speaker: 'Alex',
        text: 'Thanks for letting me know. What time does boarding begin?',
        textVi: 'Cảm ơn đã báo cho tôi. Mấy giờ bắt đầu lên máy bay vậy?',
      ),
      DialogueLine(
        speaker: 'Agent',
        text: 'Boarding begins promptly at 3:45 PM. You have about forty-five minutes to go through security.',
        textVi: 'Lên máy bay bắt đầu đúng lúc 3h45 chiều. Bạn có khoảng 45 phút để qua cửa an ninh.',
      ),
    ],
    keyVocab: [
      ListeningVocab(
        word: 'Carry-on luggage',
        phonetic: '/ˈkæri ɒn ˈlʌɡɪdʒ/',
        meaning: 'Hành lý xách tay',
        example: 'Liquids in carry-on luggage must not exceed 100ml.',
      ),
      ListeningVocab(
        word: 'Departure gate',
        phonetic: '/dɪˈpɑːtʃə ɡeɪt/',
        meaning: 'Cổng xuất phát / Cổng lên máy bay',
        example: 'Passengers should check the monitor for their departure gate.',
      ),
      ListeningVocab(
        word: 'Boarding time',
        phonetic: '/ˈbɔːdɪŋ taɪm/',
        meaning: 'Thời gian lên máy bay',
        example: 'Boarding closes 15 minutes prior to takeoff.',
      ),
    ],
    questions: [
      ListeningQuestion(
        question: 'Where is Alex traveling to?',
        questionVi: 'Alex đang đi du lịch tới đâu?',
        options: ['London', 'Seoul', 'Tokyo', 'Sydney'],
        correctIndex: 2,
        explanation: 'Alex trả lời: "I am flying to Tokyo on flight SK420."',
      ),
      ListeningQuestion(
        question: 'What is the new departure gate for Alex’s flight?',
        questionVi: 'Cổng khởi hành mới cho chuyến bay của Alex là cổng nào?',
        options: ['Gate B12', 'Gate C05', 'Gate A08', 'Gate D14'],
        correctIndex: 1,
        explanation: 'Nhân viên thông báo: "your departure gate has moved from Gate B12 to Gate C05."',
      ),
      ListeningQuestion(
        question: 'At what time does the boarding process start?',
        questionVi: 'Quy trình lên máy bay bắt đầu lúc mấy giờ?',
        options: ['3:00 PM', '3:15 PM', '3:45 PM', '4:30 PM'],
        correctIndex: 2,
        explanation: 'Nhân viên xác nhận: "Boarding begins promptly at 3:45 PM."',
      ),
    ],
  ),

  ListeningLesson(
    id: 'lis_04',
    title: 'Consultation at the Medical Clinic',
    titleVi: 'Khám bệnh tại phòng khám bác sĩ',
    level: 'B1',
    topic: 'Healthcare',
    scenarioVi: 'John đến gặp bác sĩ Miller vì bị đau họng, sốt nhẹ và mệt mỏi trong 3 ngày qua.',
    dialogue: [
      DialogueLine(
        speaker: 'Dr. Miller',
        text: 'Good morning, John. What symptoms have you been experiencing lately?',
        textVi: 'Chào John. Gần đây bạn gặp phải những triệu chứng gì?',
      ),
      DialogueLine(
        speaker: 'John',
        text: 'I have had a sore throat, mild fever, and persistent dry cough for the past three days.',
        textVi: 'Tôi bị đau họng, sốt nhẹ và ho khan dai dẳng suốt 3 ngày nay.',
      ),
      DialogueLine(
        speaker: 'Dr. Miller',
        text: 'Let me check your temperature and listen to your chest. Take a deep breath in... and exhale.',
        textVi: 'Để tôi đo nhiệt độ và nghe ngực bạn nhé. Hít một hơi thật sâu... và thở ra.',
      ),
      DialogueLine(
        speaker: 'John',
        text: 'Is it anything serious, doctor? I was worried it might be bronchitis.',
        textVi: 'Có nghiêm trọng không bác sĩ? Tôi lo là có thể bị viêm phế quản.',
      ),
      DialogueLine(
        speaker: 'Dr. Miller',
        text: 'Your lungs sound clear. It appears to be a standard upper respiratory viral infection.',
        textVi: 'Phổi của bạn nghe rất trong. Có vẻ đây chỉ là nhiễm virus đường hô hấp trên thông thường.',
      ),
      DialogueLine(
        speaker: 'John',
        text: 'Do I need to take antibiotics for this?',
        textVi: 'Tôi có cần uống thuốc kháng sinh không?',
      ),
      DialogueLine(
        speaker: 'Dr. Miller',
        text: 'No, antibiotics only fight bacteria, not viruses. I will prescribe throat lozenges and paracetamol for the fever.',
        textVi: 'Không, kháng sinh chỉ diệt vi khuẩn, không diệt virus. Tôi sẽ kê viên ngậm ho và paracetamol để hạ sốt.',
      ),
      DialogueLine(
        speaker: 'Dr. Miller',
        text: 'Drink plenty of warm fluids and get adequate rest for the next forty-eight hours.',
        textVi: 'Uống nhiều nước ấm và nghỉ ngơi đầy đủ trong 48 giờ tới nhé.',
      ),
    ],
    keyVocab: [
      ListeningVocab(
        word: 'Persistent cough',
        phonetic: '/pəˈsɪstənt kɒf/',
        meaning: 'Cơn ho dai dẳng, kéo dài',
        example: 'See a physician if you develop a persistent cough.',
      ),
      ListeningVocab(
        word: 'Antibiotics',
        phonetic: '/ˌæntibaɪˈɒtɪks/',
        meaning: 'Thuốc kháng sinh',
        example: 'Overusing antibiotics can lead to resistance.',
      ),
      ListeningVocab(
        word: 'Throat lozenge',
        phonetic: '/θrəʊt ˈlɒzɪndʒ/',
        meaning: 'Viên ngậm đau họng',
        example: 'A soothing throat lozenge eased his irritation.',
      ),
    ],
    questions: [
      ListeningQuestion(
        question: 'How long has John been feeling sick?',
        questionVi: 'John đã cảm thấy mệt mỏi trong bao lâu?',
        options: ['One day', 'Three days', 'One week', 'Two weeks'],
        correctIndex: 1,
        explanation: 'John nói: "...for the past three days."',
      ),
      ListeningQuestion(
        question: 'Why did the doctor decide NOT to prescribe antibiotics?',
        questionVi: 'Tại sao bác sĩ quyết định KHÔNG kê thuốc kháng sinh?',
        options: [
          'John is allergic to antibiotics',
          'Antibiotics only work against bacteria, not viral infections',
          'The clinic ran out of antibiotics',
          'John refused to take any pills',
        ],
        correctIndex: 1,
        explanation: 'Bác sĩ giải thích: "No, antibiotics only fight bacteria, not viruses."',
      ),
      ListeningQuestion(
        question: 'What self-care advice did Dr. Miller provide?',
        questionVi: 'Bác sĩ Miller đã đưa ra lời khuyên tự chăm sóc nào?',
        options: [
          'Go for a run immediately',
          'Drink warm fluids and get sufficient rest for 48 hours',
          'Fast for two days',
          'Avoid drinking any water',
        ],
        correctIndex: 1,
        explanation: 'Bác sĩ khuyên: "Drink plenty of warm fluids and get adequate rest for the next forty-eight hours."',
      ),
    ],
  ),

  ListeningLesson(
    id: 'lis_05',
    title: 'Job Interview: Software Engineer Position',
    titleVi: 'Phỏng vấn tuyển dụng: Vị trí Kỹ sư phần mềm',
    level: 'B2',
    topic: 'Career',
    scenarioVi: 'Lisa (Trưởng phòng nhân sự) phỏng vấn Kevin về kinh nghiệm làm việc và kỹ năng giải quyết sự cố kỹ thuật.',
    dialogue: [
      DialogueLine(
        speaker: 'Lisa',
        text: 'Welcome Kevin. Thank you for taking the time to speak with our engineering leadership team today.',
        textVi: 'Chào mừng Kevin. Cảm ơn bạn đã dành thời gian trao đổi với ban lãnh đạo kỹ thuật của chúng tôi hôm nay.',
      ),
      DialogueLine(
        speaker: 'Kevin',
        text: 'Thank you for the opportunity, Lisa. I am genuinely excited about your product vision.',
        textVi: 'Cảm ơn cơ hội này, Lisa. Tôi thực sự rất hào hứng với tầm nhìn sản phẩm của công ty.',
      ),
      DialogueLine(
        speaker: 'Lisa',
        text: 'Could you walk me through a complex technical bottleneck you recently encountered and resolved?',
        textVi: 'Bạn có thể chia sẻ về một nút thắt kỹ thuật phức tạp mà bạn gặp phải và xử lý gần đây không?',
      ),
      DialogueLine(
        speaker: 'Kevin',
        text: 'In my prior role, our backend microservice suffered from high latency during flash sales events.',
        textVi: 'Ở công ty trước, hệ thống microservice backend bị độ trễ rất cao trong các đợt mở bán flash sale.',
      ),
      DialogueLine(
        speaker: 'Kevin',
        text: 'By analyzing database query profiling, I discovered unindexed foreign keys causing table locks.',
        textVi: 'Bằng cách phân tích hiệu năng truy vấn database, tôi phát hiện các khóa ngoại chưa đánh index gây khóa bảng.',
      ),
      DialogueLine(
        speaker: 'Kevin',
        text: 'I implemented Redis caching and optimized query indexing, which reduced response latency by seventy percent.',
        textVi: 'Tôi đã triển khai caching bằng Redis và tối ưu hóa index truy vấn, giúp giảm 70% độ trễ phản hồi.',
      ),
      DialogueLine(
        speaker: 'Lisa',
        text: 'That is an impressive outcome. How do you handle cross-functional disagreements with product managers?',
        textVi: 'Kết quả thật ấn tượng. Bạn xử lý các bất đồng ý kiến giữa các bộ phận với Product Manager như thế nào?',
      ),
      DialogueLine(
        speaker: 'Kevin',
        text: 'I prioritize objective data over emotional opinions, always framing trade-offs around user impact and delivery deadlines.',
        textVi: 'Tôi ưu tiên dữ liệu khách quan hơn cảm tính, luôn đặt các điểm đánh đổi vào tác động người dùng và tiến độ bàn giao.',
      ),
    ],
    keyVocab: [
      ListeningVocab(
        word: 'Technical bottleneck',
        phonetic: '/ˈteknɪkl ˈbɒtlnek/',
        meaning: 'Nút thắt kỹ thuật, điểm nghẽn hiệu năng',
        example: 'Identifying technical bottlenecks is vital for scalability.',
      ),
      ListeningVocab(
        word: 'Cross-functional',
        phonetic: '/krɒs ˈfʌŋkʃənl/',
        meaning: 'Liên phòng ban / Đa chức năng',
        example: 'Effective communication is key to cross-functional alignment.',
      ),
      ListeningVocab(
        word: 'Trade-off',
        phonetic: '/ˈtreɪd ɒf/',
        meaning: 'Sự đánh đổi',
        example: 'Engineers frequently balance trade-offs between speed and quality.',
      ),
    ],
    questions: [
      ListeningQuestion(
        question: 'What issue was Kevin’s previous system experiencing?',
        questionVi: 'Hệ thống trước đây của Kevin gặp phải sự cố gì?',
        options: [
          'Security data breach',
          'High latency during flash sale spikes',
          'Loss of user passwords',
          'Complete hardware failure',
        ],
        correctIndex: 1,
        explanation: 'Kevin nói: "our backend microservice suffered from high latency during flash sales events."',
      ),
      ListeningQuestion(
        question: 'By how much did Kevin reduce response latency?',
        questionVi: 'Kevin đã giảm độ trễ phản hồi bao nhiêu phần trăm?',
        options: ['30%', '50%', '70%', '95%'],
        correctIndex: 2,
        explanation: 'Kevin khẳng định: "...which reduced response latency by seventy percent."',
      ),
      ListeningQuestion(
        question: 'How does Kevin resolve disagreements with product managers?',
        questionVi: 'Kevin giải quyết bất đồng với Product Manager bằng cách nào?',
        options: [
          'He ignores their feedback',
          'He relies on objective data and focuses on user impact and deadlines',
          'He immediately escalates to executive managers',
          'He accepts every request without discussion',
        ],
        correctIndex: 1,
        explanation: 'Kevin giải thích: "I prioritize objective data over emotional opinions, framing trade-offs around user impact."',
      ),
    ],
  ),

  ListeningLesson(
    id: 'lis_06',
    title: 'Smart Cities & Sustainable Urban Living',
    titleVi: 'Thành phố thông minh & Phát triển đô thị bền vững',
    level: 'B2',
    topic: 'Environment & Tech',
    scenarioVi: 'Giáo sư Anderson và phóng viên Maya thảo luận về ứng dụng trí tuệ nhân tạo để giảm khí thải đô thị.',
    dialogue: [
      DialogueLine(
        speaker: 'Maya',
        text: 'Professor Anderson, how are artificial intelligence systems transforming modern urban infrastructure?',
        textVi: 'Thưa Giáo sư Anderson, các hệ thống trí tuệ nhân tạo đang biến đổi hạ tầng đô thị hiện đại ra sao?',
      ),
      DialogueLine(
        speaker: 'Prof. Anderson',
        text: 'The biggest breakthrough is dynamic traffic orchestration, which adjusts signal lights based on real-time vehicle flow.',
        textVi: 'Đột phá lớn nhất là điều phối giao thông động, điều chỉnh đèn tín hiệu dựa trên lưu lượng phương tiện thời gian thực.',
      ),
      DialogueLine(
        speaker: 'Maya',
        text: 'Does that substantially reduce greenhouse gas emissions?',
        textVi: 'Điều đó có giúp giảm đáng kể lượng khí thải nhà kính không thưa giáo sư?',
      ),
      DialogueLine(
        speaker: 'Prof. Anderson',
        text: 'Empirical data shows an eighteen percent decrease in idle fuel consumption across metropolitan pilots.',
        textVi: 'Số liệu thực nghiệm cho thấy giảm 18% lượng nhiên liệu tiêu hao khi dừng chờ tại các đô thị thử nghiệm.',
      ),
      DialogueLine(
        speaker: 'Maya',
        text: 'What about decentralized renewable energy integration?',
        textVi: 'Thế còn việc tích hợp năng lượng tái tạo phi tập trung thì sao?',
      ),
      DialogueLine(
        speaker: 'Prof. Anderson',
        text: 'Predictive algorithms allow smart grids to store excess solar energy in residential batteries before peak evening hours.',
        textVi: 'Các thuật toán dự báo cho phép lưới điện thông minh lưu trữ điện mặt trời dư thừa vào pin dân dụng trước giờ cao điểm.',
      ),
    ],
    keyVocab: [
      ListeningVocab(
        word: 'Greenhouse gas emissions',
        phonetic: '/ˈɡriːnhaʊs ɡæs ɪˈmɪʃnz/',
        meaning: 'Khí thải nhà kính',
        example: 'Renewable technologies aim to mitigate greenhouse gas emissions.',
      ),
      ListeningVocab(
        word: 'Predictive algorithm',
        phonetic: '/prɪˈdɪktɪv ˈælɡərɪðəm/',
        meaning: 'Thuật toán dự báo',
        example: 'Predictive algorithms optimize battery distribution.',
      ),
      ListeningVocab(
        word: 'Smart grid',
        phonetic: '/smɑːt ɡrɪd/',
        meaning: 'Lưới điện thông minh',
        example: 'A smart grid balances electricity demand automatically.',
      ),
    ],
    questions: [
      ListeningQuestion(
        question: 'What is the main function of AI traffic orchestration?',
        questionVi: 'Chức năng chính của điều phối giao thông bằng AI là gì?',
        options: [
          'Issuing speeding tickets automatically',
          'Adjusting traffic lights dynamically based on real-time flow',
          'Building wider highways',
          'Stopping all cars in the city',
        ],
        correctIndex: 1,
        explanation: 'Giáo sư cho biết: "...adjusts signal lights based on real-time vehicle flow."',
      ),
      ListeningQuestion(
        question: 'By how much was idle fuel consumption reduced in the pilot cities?',
        questionVi: 'Lượng nhiên liệu tiêu hao khi dừng chờ đã giảm bao nhiêu phần trăm tại các thành phố thử nghiệm?',
        options: ['8%', '18%', '28%', '50%'],
        correctIndex: 1,
        explanation: 'Giáo sư khẳng định: "Empirical data shows an eighteen percent decrease in idle fuel consumption."',
      ),
      ListeningQuestion(
        question: 'When do smart grids store excess solar energy?',
        questionVi: 'Lưới điện thông minh lưu trữ điện mặt trời dư thừa khi nào?',
        options: [
          'During the middle of the night',
          'Before peak evening hours',
          'Only in winter months',
          'Never',
        ],
        correctIndex: 1,
        explanation: 'Giáo sư nêu: "...store excess solar energy in residential batteries before peak evening hours."',
      ),
    ],
  ),
];
