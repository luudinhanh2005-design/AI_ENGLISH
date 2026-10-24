List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return <String>[];
}

class GrammarExample {
  final String english;
  final String vietnamese;
  final String note;

  const GrammarExample({
    required this.english,
    required this.vietnamese,
    this.note = '',
  });

  factory GrammarExample.fromJson(Map<String, dynamic> json) {
    return GrammarExample(
      english: (json['english'] ?? json['en'] ?? '').toString(),
      vietnamese: (json['vietnamese'] ?? json['vi'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'english': english,
        'vietnamese': vietnamese,
        'note': note,
      };
}

class GrammarQuizItem {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const GrammarQuizItem({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory GrammarQuizItem.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList()
        : <String>[];
    final rawCorrect =
        json['correct_index'] ?? json['correctIndex'] ?? json['correct_option'] ?? 0;
    final correctIndex = rawCorrect is int
        ? rawCorrect
        : int.tryParse(rawCorrect.toString()) ?? 0;

    return GrammarQuizItem(
      question: (json['question'] ?? '').toString(),
      options: options,
      correctIndex: correctIndex,
      explanation:
          (json['explanation'] ?? json['explanation_vi'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correct_index': correctIndex,
        'explanation': explanation,
      };
}

class GrammarLesson {
  final String id;
  final String title;
  final String titleVi;
  final String level;
  final String category;
  final String description;
  final String formulaAffirmative;
  final String formulaNegative;
  final String formulaQuestion;
  final List<String> timeMarkers;
  final List<String> usageRules;
  final List<GrammarExample> examples;
  final List<String> commonMistakes;
  final List<GrammarQuizItem> quiz;
  final bool isBeta;
  final int version;

  /// Public API slug. The local seed uses the same value as [id].
  String get slug => id;

  const GrammarLesson({
    required this.id,
    required this.title,
    required this.titleVi,
    required this.level,
    required this.category,
    required this.description,
    required this.formulaAffirmative,
    required this.formulaNegative,
    required this.formulaQuestion,
    required this.timeMarkers,
    required this.usageRules,
    required this.examples,
    required this.commonMistakes,
    required this.quiz,
    this.isBeta = false,
    this.version = 1,
  });

  factory GrammarLesson.fromJson(Map<String, dynamic> json) {
    final rawExamples = json['examples'];
    final rawQuiz = json['quiz'] ?? json['practice_questions'];
    final level = (json['level'] ?? '').toString().toUpperCase();

    return GrammarLesson(
      id: (json['id'] ?? json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      titleVi: (json['title_vi'] ?? json['titleVi'] ?? '').toString(),
      level: level,
      category: (json['category'] ?? '').toString(),
      description:
          (json['description'] ?? json['summary'] ?? '').toString(),
      formulaAffirmative:
          (json['formula_affirmative'] ?? json['formulaAffirmative'] ?? '')
              .toString(),
      formulaNegative:
          (json['formula_negative'] ?? json['formulaNegative'] ?? '')
              .toString(),
      formulaQuestion:
          (json['formula_question'] ?? json['formulaQuestion'] ?? '')
              .toString(),
      timeMarkers: _stringList(json['time_markers'] ?? json['timeMarkers']),
      usageRules: _stringList(json['usage_rules'] ?? json['usageRules']),
      examples: rawExamples is List
          ? rawExamples
              .whereType<Map>()
              .map((e) => GrammarExample.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <GrammarExample>[],
      commonMistakes:
          _stringList(json['common_mistakes'] ?? json['commonMistakes']),
      quiz: rawQuiz is List
          ? rawQuiz
              .whereType<Map>()
              .map(
                (e) => GrammarQuizItem.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : <GrammarQuizItem>[],
      // An explicit server flag wins after human review; otherwise C1/C2 are
      // beta by default until reviewed.
      isBeta: json.containsKey('is_beta')
          ? json['is_beta'] == true
          : json.containsKey('isBeta')
              ? json['isBeta'] == true
              : level == 'C1' || level == 'C2',
      version: int.tryParse('${json['version'] ?? 1}') ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'title_vi': titleVi,
        'level': level,
        'category': category,
        'description': description,
        'formula_affirmative': formulaAffirmative,
        'formula_negative': formulaNegative,
        'formula_question': formulaQuestion,
        'time_markers': timeMarkers,
        'usage_rules': usageRules,
        'examples': examples.map((e) => e.toJson()).toList(),
        'common_mistakes': commonMistakes,
        'quiz': quiz.map((q) => q.toJson()).toList(),
        'is_beta': isBeta,
        'version': version,
      };
}

const List<GrammarLesson> grammarLessonsData = [
  GrammarLesson(
    id: 'past_simple',
    title: 'Past Simple Tense',
    titleVi: 'Thì Quá Khứ Đơn',
    level: 'A2',
    category: 'Các Thì (Tenses)',
    description:
        'Diễn đạt hành động đã xảy ra và chấm dứt hoàn toàn trong quá khứ.',
    formulaAffirmative: 'S + V2 / V-ed (+ O)',
    formulaNegative: "S + did not (didn't) + V (nguyên mẫu)",
    formulaQuestion: 'Did + S + V (nguyên mẫu)?',
    timeMarkers: [
      'yesterday (hôm qua)',
      'ago (2 days ago, 3 years ago)',
      'last night / last week / last month / last year',
      'in + năm quá khứ (in 1995, in 2020)',
      'when I was a child...',
    ],
    usageRules: [
      'Hành động đã xảy ra và kết thúc hoàn toàn tại thời điểm xác định trong quá khứ.',
      'Chuỗi các hành động xảy ra nối tiếp nhau trong quá khứ (kể chuyện, tường thuật).',
      'Thói quen hoặc sự thật trong quá khứ đã chấm dứt (thường dùng kèm used to).',
    ],
    examples: [
      GrammarExample(
        english: 'We visited the Louvre Museum yesterday.',
        vietnamese: 'Hôm qua chúng tôi đã ghé thăm bảo tàng Louvre.',
        note: 'Động từ visit là có quy tắc -> thêm -ed: visited.',
      ),
      GrammarExample(
        english: "She didn't receive your email this morning.",
        vietnamese: 'Sáng nay cô ấy đã không nhận được email của bạn.',
        note:
            "Khi có trợ động từ didn't, động từ chính giữ nguyên mẫu (receive).",
      ),
      GrammarExample(
        english: 'Did you lock the front door before leaving?',
        vietnamese: 'Bạn đã khóa cửa trước khi rời đi chưa?',
        note: 'Câu hỏi nghi vấn đảo Did lên đầu câu, động từ lock nguyên mẫu.',
      ),
      GrammarExample(
        english: 'He woke up, brushed his teeth, and left for work.',
        vietnamese: 'Anh ấy thức dậy, đánh răng rồi đi làm.',
        note:
            'Chuỗi hành động liên tiếp đều chia ở quá khứ đơn (woke, brushed, left).',
      ),
    ],
    commonMistakes: [
      "SAI: She didn't went to school yesterday. -> ĐÚNG: She didn't go to school yesterday. (Sau didn't dùng động từ nguyên thể)",
      'SAI: I see him two days ago. -> ĐÚNG: I saw him two days ago. (Quá khứ của see là saw)',
    ],
    quiz: [
      GrammarQuizItem(
        question: 'She _______ to Da Nang with her family last summer.',
        options: ['goes', 'went', 'has gone', 'is going'],
        correctIndex: 1,
        explanation:
            'Dấu hiệu "last summer" chỉ quá khứ đơn -> động từ bất quy tắc của go là "went".',
      ),
      GrammarQuizItem(
        question: 'Which sentence is grammatically CORRECT?',
        options: [
          "They didn't ate dinner yet.",
          'Did you bought that jacket yesterday?',
          "I didn't see anyone at the office.",
          'He lived in Hanoi when he is young.',
        ],
        correctIndex: 2,
        explanation:
            '"I didn\'t see..." đúng cấu trúc phủ định quá khứ đơn (didn\'t + V nguyên mẫu).',
      ),
      GrammarQuizItem(
        question: '_______ you finish the project on time yesterday?',
        options: ['Do', 'Were', 'Did', 'Have'],
        correctIndex: 2,
        explanation: 'Trợ động từ quá khứ đơn của động từ thường là "Did".',
      ),
    ],
  ),
  GrammarLesson(
    id: 'present_perfect',
    title: 'Present Perfect Tense',
    titleVi: 'Thì Hiện Tại Hoàn Thành',
    level: 'B1',
    category: 'Các Thì (Tenses)',
    description:
        'Hành động bắt đầu trong quá khứ kéo dài đến hiện tại hoặc trải nghiệm có kết quả ở hiện tại.',
    formulaAffirmative: 'S + have / has + V3 / V-ed',
    formulaNegative: "S + have not (haven't) / has not (hasn't) + V3 / V-ed",
    formulaQuestion: 'Have / Has + S + V3 / V-ed?',
    timeMarkers: [
      'already (đã... rồi)',
      'yet (chưa - dùng câu phủ định và nghi vấn)',
      'just (vừa mới)',
      'ever (đã từng) / never (chưa bao giờ)',
      'since + mốc thời gian (since 2018, since Monday)',
      'for + khoảng thời gian (for 5 years, for two months)',
      'recently / so far / up to now',
    ],
    usageRules: [
      'Hành động bắt đầu trong quá khứ và vẫn tiếp tục diễn ra ở hiện tại.',
      'Trải nghiệm, kinh nghiệm sống tính đến thời điểm hiện tại (Have you ever...?).',
      'Hành động vừa mới xảy ra và để lại kết quả hoặc ảnh hưởng rõ ràng ở hiện tại.',
    ],
    examples: [
      GrammarExample(
        english: 'I have lived in this apartment for five years.',
        vietnamese:
            'Tôi đã sống ở căn hộ này được 5 năm (và hiện tại vẫn đang sống ở đây).',
        note: 'Dùng "for" đi kèm khoảng thời gian (five years).',
      ),
      GrammarExample(
        english: 'She has already finished her master degree thesis.',
        vietnamese: 'Cô ấy đã hoàn thành xong luận văn thạc sĩ rồi.',
        note: '"Already" đứng giữa trợ động từ has và V3 (finished).',
      ),
      GrammarExample(
        english: 'Have you ever tried traditional Vietnamese pho?',
        vietnamese:
            'Bạn đã từng ăn thử món phở truyền thống của Việt Nam chưa?',
        note: '"Ever" dùng trong câu hỏi hỏi về trải nghiệm.',
      ),
      GrammarExample(
        english: "I haven't received any confirmation email yet.",
        vietnamese: 'Tôi vẫn chưa nhận được bất kỳ email xác nhận nào.',
        note: '"Yet" đứng cuối câu phủ định.',
      ),
    ],
    commonMistakes: [
      'SAI: I have seen that movie yesterday. -> ĐÚNG: I saw that movie yesterday. (Có mốc thời gian cụ thể "yesterday" phải dùng Quá khứ đơn, không dùng Hiện tại hoàn thành)',
      'SAI: He has worked here since 3 years. -> ĐÚNG: He has worked here for 3 years. ("since" dùng cho mốc thời gian, "for" dùng cho khoảng thời gian)',
    ],
    quiz: [
      GrammarQuizItem(
        question: 'They have been close friends _______ childhood.',
        options: ['for', 'since', 'in', 'ago'],
        correctIndex: 1,
        explanation: '"Childhood" là mốc thời gian bắt đầu -> dùng "since".',
      ),
      GrammarQuizItem(
        question: 'She _______ her keys, so she cannot open the door now.',
        options: ['lost', 'has lost', 'is losing', 'loses'],
        correctIndex: 1,
        explanation:
            'Hành động mất chìa khóa trong quá khứ để lại kết quả ở hiện tại (không mở được cửa) -> Hiện tại hoàn thành.',
      ),
      GrammarQuizItem(
        question: 'Have you _______ to Japan before?',
        options: ['ever be', 'ever been', 'already be', 'never went'],
        correctIndex: 1,
        explanation:
            'Have + S + ever + V3 (been) là cấu trúc chuẩn để hỏi về trải nghiệm.',
      ),
    ],
  ),
  GrammarLesson(
    id: 'second_conditional',
    title: 'Second Conditional',
    titleVi: 'Câu Điều Kiện Loại 2',
    level: 'B2',
    category: 'Câu Điều Kiện (Conditionals)',
    description:
        'Diễn đạt điều kiện giả định không có thật hoặc trái ngược với thực tế ở hiện tại hoặc tương lai.',
    formulaAffirmative:
        'If + S + V2/ed (were), S + would/could/might + V (nguyên mẫu)',
    formulaNegative: "If + S + didn't + V, S + wouldn't + V",
    formulaQuestion: 'What would you do if + S + V2/were?',
    timeMarkers: [
      'If I were you, I would... (Lời khuyên: Nếu tôi là bạn...)',
      'If I had more time... (Nếu tôi có nhiều thời gian hơn)',
      'If I won the lottery... (Nếu tôi trúng số)',
    ],
    usageRules: [
      'Giả định một tình huống không có thật ở hiện tại (ví dụ: thực tế tôi không giàu -> If I were rich).',
      'Đưa ra lời khuyên một cách lịch sự và tự nhiên (If I were you...).',
      'Trong văn phong chuẩn, động từ "to be" trong mệnh đề If luôn dùng "were" cho tất cả các ngôi (I, he, she, it).',
    ],
    examples: [
      GrammarExample(
        english: 'If I had a million dollars, I would travel around the world.',
        vietnamese:
            'Nếu tôi có một triệu đô la, tôi sẽ đi du lịch khắp thế giới.',
        note: 'Thực tế hiện tại tôi không có một triệu đô.',
      ),
      GrammarExample(
        english: 'If I were you, I would accept that job offer immediately.',
        vietnamese:
            'Nếu tôi là bạn, tôi sẽ nhận lời mời làm việc đó ngay lập tức.',
        note: 'Lời khuyên phổ biến dùng "If I were you".',
      ),
      GrammarExample(
        english:
            'If she studied harder, she could pass the certification exam.',
        vietnamese:
            'Nếu cô ấy chăm học hơn thì cô ấy đã có thể đỗ kỳ thi chứng chỉ.',
        note: 'Dùng "could" để chỉ khả năng có thể xảy ra.',
      ),
    ],
    commonMistakes: [
      'SAI: If I will have time, I would help you. -> ĐÚNG: If I had time, I would help you. (Không dùng will/would trong mệnh đề If)',
      'SAI: If I was you... (trong văn viết trang trọng hoặc bài thi) -> ĐÚNG: If I were you...',
    ],
    quiz: [
      GrammarQuizItem(
        question: 'If I _______ his phone number, I would call him right away.',
        options: ['know', 'knew', 'have known', 'will know'],
        correctIndex: 1,
        explanation:
            'Mệnh đề If của câu điều kiện loại 2 chia ở quá khứ đơn (V2) -> "knew".',
      ),
      GrammarQuizItem(
        question: 'What _______ if you found a lost wallet on the street?',
        options: ['will you do', 'would you do', 'did you do', 'have you done'],
        correctIndex: 1,
        explanation:
            'Mệnh đề chính của câu điều kiện loại 2: would + V nguyên mẫu -> "would you do".',
      ),
    ],
  ),
  GrammarLesson(
    id: 'present_simple',
    title: 'Present Simple Tense',
    titleVi: 'Thì Hiện Tại Đơn',
    level: 'A1',
    category: 'Các Thì (Tenses)',
    description: 'Diễn đạt thói quen hàng ngày, sự thật hiển nhiên và chân lý.',
    formulaAffirmative: 'S + V(s/es) (+ O)',
    formulaNegative: "S + do not (don't) / does not (doesn't) + V",
    formulaQuestion: 'Do / Does + S + V?',
    timeMarkers: [
      'always, usually, often, sometimes, rarely, never',
      'every day / every week / every month',
      'once a week, twice a month',
    ],
    usageRules: [
      'Thói quen, hành động lặp đi lặp lại hàng ngày (I wake up at 6 AM).',
      'Chân lý, quy luật tự nhiên, sự thật hiển nhiên (The sun rises in the east).',
      'Lịch trình cố định của tàu xe, máy bay, sự kiện (The train leaves at 8 PM).',
    ],
    examples: [
      GrammarExample(
        english: 'He drinks a cup of black coffee every morning.',
        vietnamese: 'Anh ấy uống một tách cà phê đen mỗi buổi sáng.',
        note: 'Chủ ngữ ngôi thứ ba số ít (He) -> thêm -s vào động từ: drinks.',
      ),
      GrammarExample(
        english: "They don't work on weekends.",
        vietnamese: 'Họ không làm việc vào các ngày cuối tuần.',
        note: 'Chủ ngữ số nhiều (They) -> dùng trợ động từ don\'t.',
      ),
      GrammarExample(
        english: 'Water boils at 100 degrees Celsius.',
        vietnamese: 'Nước sôi ở nhiệt độ 100 độ C.',
        note: 'Sự thật khoa học hiển nhiên luôn chia ở Hiện tại đơn.',
      ),
    ],
    commonMistakes: [
      'SAI: She work in a hospital. -> ĐÚNG: She works in a hospital. (Quên thêm -s/-es cho ngôi he/she/it)',
      'SAI: Does he has a car? -> ĐÚNG: Does he have a car? (Sau trợ động từ Does động từ phải nguyên mẫu: have)',
    ],
    quiz: [
      GrammarQuizItem(
        question: 'My brother _______ English very fluently.',
        options: ['speak', 'speaks', 'is speaking', 'spoken'],
        correctIndex: 1,
        explanation:
            'Chủ ngữ "My brother" là ngôi thứ 3 số ít -> thêm "s": speaks.',
      ),
      GrammarQuizItem(
        question: '_______ they live in the downtown area?',
        options: ['Do', 'Does', 'Are', 'Is'],
        correctIndex: 0,
        explanation: 'Chủ ngữ "they" dùng trợ động từ "Do".',
      ),
    ],
  ),
  GrammarLesson(
    id: 'passive_voice',
    title: 'Passive Voice',
    titleVi: 'Câu Bị Động',
    level: 'B1',
    category: 'Cấu Trúc Câu (Structures)',
    description:
        'Nhấn mạnh đối tượng chịu tác động của hành động thay vì người thực hiện hành động.',
    formulaAffirmative: 'S + be (chia theo thì) + V3/ed (+ by O)',
    formulaNegative: 'S + be not + V3/ed (+ by O)',
    formulaQuestion: 'Be + S + V3/ed (+ by O)?',
    timeMarkers: [
      'by + người thực hiện (by the manager, by the team)',
      'Thường dùng khi không biết hoặc không cần nhấn mạnh người làm',
    ],
    usageRules: [
      'Nhấn mạnh vào kết quả hoặc đối tượng bị tác động.',
      'Dùng trong văn bản học thuật, tin tức báo chí, báo cáo khoa học.',
      'Hiện tại đơn: S + am/is/are + V3 | Quá khứ đơn: S + was/were + V3 | Tương lai: S + will be + V3.',
    ],
    examples: [
      GrammarExample(
        english: 'The report was submitted by the team yesterday.',
        vietnamese: 'Bản báo cáo đã được nộp bởi nhóm vào ngày hôm qua.',
        note: 'Bị động quá khứ đơn: was + submitted.',
      ),
      GrammarExample(
        english: 'English is spoken by millions of people worldwide.',
        vietnamese: 'Tiếng Anh được nói bởi hàng triệu người trên toàn cầu.',
        note: 'Bị động hiện tại đơn: is + spoken (V3 của speak).',
      ),
      GrammarExample(
        english: 'The new bridge will be completed next year.',
        vietnamese: 'Cây cầu mới sẽ được hoàn thành vào năm tới.',
        note: 'Bị động tương lai đơn: will be + completed.',
      ),
    ],
    commonMistakes: [
      'SAI: The letter was sent by yesterday. -> ĐÚNG: The letter was sent yesterday. ("by" chỉ đi với người/tác nhân, không đi với trạng từ thời gian)',
      'SAI: The house was build in 1990. -> ĐÚNG: The house was built in 1990. (Phải dùng phân từ 2 V3: built)',
    ],
    quiz: [
      GrammarQuizItem(
        question: 'This famous novel _______ by J.K. Rowling in 1997.',
        options: ['wrote', 'is written', 'was written', 'has written'],
        correctIndex: 2,
        explanation:
            'Năm 1997 là quá khứ đơn, câu bị động: was + V3 (written).',
      ),
      GrammarQuizItem(
        question: 'The meeting rooms _______ cleaned every morning.',
        options: ['is', 'are', 'was', 'were'],
        correctIndex: 1,
        explanation:
            'Chủ ngữ "The meeting rooms" số nhiều, thì hiện tại đơn: are + cleaned.',
      ),
    ],
  ),
  GrammarLesson(
    id: 'relative_clauses',
    title: 'Relative Clauses',
    titleVi: 'Mệnh Đề Quan Hệ',
    level: 'B2',
    category: 'Cấu Trúc Câu (Structures)',
    description:
        'Mệnh đề bổ nghĩa cho danh từ đứng trước, giúp câu văn ngắn gọn và liên kết mạch lạc.',
    formulaAffirmative:
        'Danh từ + Đại từ quan hệ (Who/Which/That/Whose/Where) + Mệnh đề',
    formulaNegative: 'Tùy theo cấu trúc của mệnh đề quan hệ',
    formulaQuestion: 'Dùng như thành phần bổ nghĩa trong câu hỏi',
    timeMarkers: [
      'Who: thay thế danh từ chỉ người',
      'Which: thay thế danh từ chỉ đồ vật, con vật',
      'That: thay cho cả người và vật trong mệnh đề xác định',
      'Where: thay cho nơi chốn',
      'Whose: chỉ sở hữu',
    ],
    usageRules: [
      'Mệnh đề quan hệ xác định (Defining): Cung cấp thông tin bắt buộc để nhận biết danh từ (không có dấu phẩy).',
      'Mệnh đề quan hệ không xác định (Non-defining): Cung cấp thông tin bổ sung (ngăn cách bằng dấu phẩy, không dùng "that").',
      '"Whose" đứng trước danh từ để chỉ sự sở hữu (The girl whose car was stolen).',
    ],
    examples: [
      GrammarExample(
        english: 'The teacher who taught us mathematics was very patient.',
        vietnamese: 'Người thầy giáo dạy toán chúng tôi rất kiên nhẫn.',
        note: '"Who" thay thế cho danh từ chỉ người (The teacher).',
      ),
      GrammarExample(
        english: 'The laptop which I bought last week works perfectly.',
        vietnamese:
            'Chiếc máy tính xách tay mà tôi mua tuần trước hoạt động rất tốt.',
        note: '"Which" thay thế cho đồ vật (The laptop).',
      ),
      GrammarExample(
        english: 'This is the coffee shop where we first met.',
        vietnamese: 'Đây là quán cà phê nơi mà lần đầu tiên chúng ta gặp nhau.',
        note: '"Where" thay thế cho danh từ chỉ địa điểm (the coffee shop).',
      ),
    ],
    commonMistakes: [
      'SAI: My father, that is 60 years old, loves gardening. -> ĐÚNG: My father, who is 60 years old, loves gardening. (Không dùng "that" trong mệnh đề có dấu phẩy)',
    ],
    quiz: [
      GrammarQuizItem(
        question: 'The man _______ lives next door is an architect.',
        options: ['which', 'who', 'whom', 'whose'],
        correctIndex: 1,
        explanation:
            '"The man" là danh từ chỉ người làm chủ ngữ -> dùng "who".',
      ),
      GrammarQuizItem(
        question: 'I visited the hospital _______ my sister works.',
        options: ['which', 'where', 'that', 'who'],
        correctIndex: 1,
        explanation:
            'Bổ nghĩa cho nơi chốn (the hospital) và có cấu trúc S+V phía sau -> dùng "where".',
      ),
    ],
  ),
];
