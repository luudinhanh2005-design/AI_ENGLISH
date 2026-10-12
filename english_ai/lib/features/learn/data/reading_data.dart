class ReadingVocab {
  final String word;
  final String phonetic;
  final String meaning;
  final String contextSentence;

  const ReadingVocab({
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.contextSentence,
  });
}

class ReadingQuestion {
  final String question;
  final String questionVi;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const ReadingQuestion({
    required this.question,
    required this.questionVi,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class ReadingArticle {
  final String id;
  final String title;
  final String titleVi;
  final String level;
  final String topic;
  final int readTimeMinutes;
  final int wordCount;
  final String summaryVi;
  final List<String> paragraphs;
  final List<ReadingVocab> vocabulary;
  final List<ReadingQuestion> questions;

  const ReadingArticle({
    required this.id,
    required this.title,
    required this.titleVi,
    required this.level,
    required this.topic,
    required this.readTimeMinutes,
    required this.wordCount,
    required this.summaryVi,
    required this.paragraphs,
    required this.vocabulary,
    required this.questions,
  });
}

const List<ReadingArticle> readingArticlesData = [
  ReadingArticle(
    id: 'read_01',
    title: 'The Surprising Science of Morning Routines',
    titleVi: 'Khoa học bất ngờ về thói quen buổi sáng',
    level: 'A2',
    topic: 'Health & Lifestyle',
    readTimeMinutes: 3,
    wordCount: 220,
    summaryVi: 'Cách xây dựng thói quen buổi sáng lành mạnh giúp tăng cường năng lượng và khả năng tập trung.',
    paragraphs: [
      'Many successful people attribute their productivity to a deliberate morning routine. Instead of grabbing your smartphone the moment you wake up, behavioral neuroscientists recommend giving your brain at least fifteen minutes without digital screens.',
      'When morning sunlight enters your eyes, it stimulates the production of cortisol, a natural hormone that boosts alertness and resets your internal circadian clock. Drinking a tall glass of water immediately after waking up also rehydrates your vital organs after seven to eight hours of sleep.',
      'You do not need a complicated two-hour routine. A simple sequence of hydrating, getting natural daylight, and doing ten minutes of light stretching or reading can transform your mental clarity and lower stress levels throughout the entire workday.',
    ],
    vocabulary: [
      ReadingVocab(
        word: 'Productivity',
        phonetic: '/ˌprɒdʌkˈtɪvəti/',
        meaning: 'Năng suất làm việc',
        contextSentence: 'A deliberate morning routine significantly boosts daily productivity.',
      ),
      ReadingVocab(
        word: 'Circadian clock',
        phonetic: '/sɜːˈkeɪdiən klɒk/',
        meaning: 'Đồng hồ sinh học',
        contextSentence: 'Natural morning sunlight resets your internal circadian clock.',
      ),
      ReadingVocab(
        word: 'Mental clarity',
        phonetic: '/ˈmentl ˈklærəti/',
        meaning: 'Sự tỉnh táo, minh mẫn tinh thần',
        contextSentence: 'Hydration and gentle exercise improve overall mental clarity.',
      ),
    ],
    questions: [
      ReadingQuestion(
        question: 'What do neuroscientists recommend avoiding right after waking up?',
        questionVi: 'Các nhà thần kinh học khuyên nên tránh điều gì ngay sau khi thức dậy?',
        options: [
          'Drinking cold water',
          'Looking at digital screens and smartphones',
          'Opening bedroom windows',
          'Gentle stretching exercises',
        ],
        correctIndex: 1,
        explanation: 'Đoạn 1 nêu: "...neuroscientists recommend giving your brain at least fifteen minutes without digital screens."',
      ),
      ReadingQuestion(
        question: 'How does natural sunlight affect the human body in the morning?',
        questionVi: 'Ánh sáng tự nhiên ảnh hưởng thế nào đến cơ thể vào buổi sáng?',
        options: [
          'It induces immediate deep sleep',
          'It stimulates cortisol production to reset alertness',
          'It causes severe dehydration',
          'It slows down your heart rate',
        ],
        correctIndex: 1,
        explanation: 'Đoạn 2 nêu: "...it stimulates the production of cortisol, a natural hormone that boosts alertness."',
      ),
      ReadingQuestion(
        question: 'What is the main message of the third paragraph?',
        questionVi: 'Thông điệp chính của đoạn thứ ba là gì?',
        options: [
          'You need a long, stressful workout every morning',
          'Morning routines are useless for busy professionals',
          'A simple, short sequence of healthy habits is very effective',
          'You should only drink coffee in the morning',
        ],
        correctIndex: 2,
        explanation: 'Đoạn 3 khẳng định bạn không cần thói quen 2 tiếng phức tạp, chỉ cần vài bước đơn giản là đã đem lại sự minh mẫn.',
      ),
    ],
  ),

  ReadingArticle(
    id: 'read_02',
    title: 'How Coffee Conquered the World',
    titleVi: 'Cà phê đã chinh phục thế giới như thế nào',
    level: 'B1',
    topic: 'History & Culture',
    readTimeMinutes: 4,
    wordCount: 260,
    summaryVi: 'Hành trình lịch sử từ những đồn điền hoang dã ở Ethiopia đến biểu tượng văn hóa toàn cầu.',
    paragraphs: [
      'According to historical legends, coffee was first discovered in ancient Ethiopian highland forests by a goat herder named Kaldi. He noticed that his goats became exceptionally energetic and refused to sleep after eating the bright red berries of a mysterious wild shrub.',
      'By the fifteenth century, coffee cultivation and trade had expanded across the Arabian Peninsula. Public coffeehouses, known as "qahveh khaneh," became vibrant social hubs where citizens gathered to converse, play chess, listen to musical performances, and debate politics.',
      'When coffee arrived in Europe during the seventeenth century, intellectuals embraced it as an alternative to beer and wine. Coffeehouses in London, Paris, and Vienna quickly earned the nickname "penny universities" because anyone could purchase a cup of coffee and participate in intellectual discussions.',
      'Today, coffee is the second most traded commodity on Earth, surpassed only by crude oil. From traditional Italian espresso to artisanal pour-overs, it continues to fuel global commerce and modern social life.',
    ],
    vocabulary: [
      ReadingVocab(
        word: 'Cultivation',
        phonetic: '/ˌkʌltɪˈveɪʃn/',
        meaning: 'Sự trồng trọt, canh tác',
        contextSentence: 'Coffee cultivation spread rapidly throughout tropical regions.',
      ),
      ReadingVocab(
        word: 'Intellectual',
        phonetic: '/ˌɪntəˈlektʃuəl/',
        meaning: 'Thuộc trí tuệ, giới trí thức',
        contextSentence: 'Scholars gathered to engage in rich intellectual debates.',
      ),
      ReadingVocab(
        word: 'Commodity',
        phonetic: '/kəˈmɒdəti/',
        meaning: 'Hàng hóa thương mại',
        contextSentence: 'Coffee is one of the most widely traded commodities worldwide.',
      ),
    ],
    questions: [
      ReadingQuestion(
        question: 'Where was coffee originally discovered according to legend?',
        questionVi: 'Theo truyền thuyết, cà phê ban đầu được phát hiện ở đâu?',
        options: ['Ancient Rome', 'Highlands of Ethiopia', 'Central Brazil', 'Southern Spain'],
        correctIndex: 1,
        explanation: 'Đoạn 1 nêu: "...coffee was first discovered in ancient Ethiopian highland forests..."',
      ),
      ReadingQuestion(
        question: 'Why were 17th-century European coffeehouses nicknamed "penny universities"?',
        questionVi: 'Tại sao các quán cà phê thế kỷ 17 ở Châu Âu được gọi là "đại học một xu"?',
        options: [
          'University students were forced to work there',
          'One could buy a cup of coffee and engage in intellectual discussions',
          'They charged high tuition fees to enter',
          'Only licensed university professors were allowed inside',
        ],
        correctIndex: 1,
        explanation: 'Đoạn 3 giải thích: "...because anyone could purchase a cup of coffee and participate in intellectual discussions."',
      ),
      ReadingQuestion(
        question: 'Which commodity is traded more globally than coffee?',
        questionVi: 'Mặt hàng nào được giao dịch toàn cầu nhiều hơn cà phê?',
        options: ['Wheat and grains', 'Crude oil', 'Gold and diamonds', 'Natural gas'],
        correctIndex: 1,
        explanation: 'Đoạn 4 nêu: "...surpassed only by crude oil."',
      ),
    ],
  ),

  ReadingArticle(
    id: 'read_03',
    title: 'The Rise of Asynchronous Work Culture',
    titleVi: 'Sự trỗi dậy của văn hóa làm việc bất đồng bộ',
    level: 'B2',
    topic: 'Future of Work',
    readTimeMinutes: 4,
    wordCount: 290,
    summaryVi: 'Tại sao các công ty công nghệ chuyển từ họp hành liên tục sang giao tiếp bất đồng bộ qua văn bản.',
    paragraphs: [
      'The traditional office environment was built on synchronous communication: real-time phone calls, impromptu tap-on-the-shoulder conversations, and endless calendar meetings. While this fostered spontaneous camaraderie, it also created constant cognitive fragmentation for knowledge workers.',
      'As remote work became ubiquitous, leading technology firms pioneered an asynchronous-first culture. Under this model, work does not happen concurrently in real time. Instead, team members communicate primarily through thorough written documentation, clear task briefs, and recorded video memos.',
      'The fundamental advantage of asynchronous communication is deep work. When engineers and designers are liberated from the pressure of responding immediately to instant messages, they can achieve hours of unbroken concentration on complex problem-solving.',
      'However, asynchronous collaboration requires immense discipline. Team members must write with exceptional clarity, provide comprehensive context upfront, and establish clear service-level agreements for non-urgent versus emergency communications.',
    ],
    vocabulary: [
      ReadingVocab(
        word: 'Cognitive fragmentation',
        phonetic: '/ˈkɒɡnətɪv ˌfræɡmenˈteɪʃn/',
        meaning: 'Sự phân mảnh nhận thức, gián đoạn chú ý',
        contextSentence: 'Frequent meetings cause severe cognitive fragmentation throughout the day.',
      ),
      ReadingVocab(
        word: 'Asynchronous',
        phonetic: '/eɪˈsɪŋkrənəs/',
        meaning: 'Bất đồng bộ (không cùng thời gian thực)',
        contextSentence: 'Asynchronous updates allow colleagues across time zones to collaborate smoothly.',
      ),
      ReadingVocab(
        word: 'Deep work',
        phonetic: '/diːp wɜːk/',
        meaning: 'Làm việc tập trung cao độ, không bị ngắt quãng',
        contextSentence: 'Deep work produces high-quality software architectures.',
      ),
    ],
    questions: [
      ReadingQuestion(
        question: 'What was a primary drawback of traditional synchronous office communication?',
        questionVi: 'Nhược điểm chính của giao tiếp đồng bộ tại văn phòng truyền thống là gì?',
        options: [
          'High monthly telephone bills',
          'Constant cognitive fragmentation and interrupted focus',
          'Lack of physical chairs for team members',
          'Strict silence policies in the hallway',
        ],
        correctIndex: 1,
        explanation: 'Đoạn 1 nêu: "...it also created constant cognitive fragmentation for knowledge workers."',
      ),
      ReadingQuestion(
        question: 'What is highlighted as the primary benefit of asynchronous work?',
        questionVi: 'Lợi ích chính của làm việc bất đồng bộ được nhấn mạnh là gì?',
        options: [
          'Employees no longer need to work any hours',
          'Unbroken concentration for deep work and problem-solving',
          'Faster instant messaging replies',
          'Lower office rental expenses only',
        ],
        correctIndex: 1,
        explanation: 'Đoạn 3 khẳng định: "The fundamental advantage of asynchronous communication is deep work."',
      ),
      ReadingQuestion(
        question: 'What is essential for teams adopting asynchronous collaboration?',
        questionVi: 'Điều gì là cần thiết đối với các đội nhóm áp dụng giao tiếp bất đồng bộ?',
        options: [
          'Mandatory daily video check-ins every hour',
          'Exceptional written clarity and thorough context',
          'Never reading project documentation',
          'Relying solely on in-person meetings',
        ],
        correctIndex: 1,
        explanation: 'Đoạn 4 nêu: "Team members must write with exceptional clarity, provide comprehensive context upfront..."',
      ),
    ],
  ),

  ReadingArticle(
    id: 'read_04',
    title: 'Artificial Intelligence in Modern Healthcare',
    titleVi: 'Trí tuệ nhân tạo trong y tế hiện đại',
    level: 'B2',
    topic: 'Medicine & AI',
    readTimeMinutes: 5,
    wordCount: 310,
    summaryVi: 'Ứng dụng thuật toán học sâu để chẩn đoán bệnh sớm và phát triển thuốc điều trị đột phá.',
    paragraphs: [
      'In recent years, artificial intelligence has transitioned from theoretical computational laboratories directly into clinical emergency rooms and diagnostic pathology centers. Deep neural networks trained on millions of high-resolution radiology scans are now capable of identifying microscopic malignant tumors years before they become apparent to the naked human eye.',
      'Beyond diagnostic imaging, generative machine learning models are accelerating pharmaceutical drug discovery. Developing a novel commercial therapeutic historically required over a decade and billions of dollars in trial-and-error laboratory synthesis. AI models can now simulate molecular folding and predict biological binding affinities in a matter of hours.',
      'Despite these breathtaking advances, medical ethicists emphasize that AI systems are clinical decision-support tools rather than autonomous replacements for licensed physicians. The ultimate responsibility for bedside diagnosis, patient empathy, and complex ethical decisions must always remain firmly in human hands.',
    ],
    vocabulary: [
      ReadingVocab(
        word: 'Malignant tumor',
        phonetic: '/məˈlɪɡnənt ˈtjuːmə/',
        meaning: 'Khối u ác tính',
        contextSentence: 'The algorithm detected an early malignant tumor on the lung scan.',
      ),
      ReadingVocab(
        word: 'Binding affinity',
        phonetic: '/ˈbaɪndɪŋ əˈfɪnəti/',
        meaning: 'Ái lực liên kết sinh học',
        contextSentence: 'Computer models calculated the binding affinity between drug molecules and target receptors.',
      ),
      ReadingVocab(
        word: 'Clinical decision-support',
        phonetic: '/ˈklɪnɪkl dɪˈsɪʒn səˈpɔːt/',
        meaning: 'Hỗ trợ ra quyết định lâm sàng',
        contextSentence: 'AI serves as a powerful clinical decision-support system for doctors.',
      ),
    ],
    questions: [
      ReadingQuestion(
        question: 'What capability of AI is highlighted in diagnostic imaging?',
        questionVi: 'Khả năng nào của AI được nêu bật trong chẩn đoán hình ảnh?',
        options: [
          'Operating heavy surgical machinery alone',
          'Spotting microscopic tumors years before they are visible to human eyes',
          'Replacing all hospital administrative staff',
          'Manufacturing physical hospital beds',
        ],
        correctIndex: 1,
        explanation: 'Đoạn 1 nêu: "...capable of identifying microscopic malignant tumors years before they become apparent..."',
      ),
      ReadingQuestion(
        question: 'How does AI transform pharmaceutical drug discovery?',
        questionVi: 'AI làm thay đổi quy trình nghiên cứu phát triển thuốc như thế nào?',
        options: [
          'It replaces the need for clinical patient trials completely',
          'It simulates molecular folding and binding affinity in hours instead of decades',
          'It forces drug prices to increase tenfold',
          'It eliminates chemical testing safety regulations',
        ],
        correctIndex: 1,
        explanation: 'Đoạn 2 chỉ ra: "AI models can now simulate molecular folding and predict biological binding affinities in a matter of hours."',
      ),
      ReadingQuestion(
        question: 'What role should AI maintain according to medical ethicists?',
        questionVi: 'Theo các chuyên gia y đức, AI nên đóng vai trò gì?',
        options: [
          'Full autonomous medical authority over patients',
          'A decision-support tool while human doctors retain final judgment and empathy',
          'An obsolete tool that should not be used in medicine',
          'A replacement for human nurses and surgeons',
        ],
        correctIndex: 1,
        explanation: 'Đoạn 3 nhấn mạnh: "...AI systems are clinical decision-support tools rather than autonomous replacements for licensed physicians."',
      ),
    ],
  ),
];
