"""
Seed initial learning data for EnglishAI:
- Placement Test Question Bank
- Vocabulary Topics & Words
- Grammar Lessons & Practice Quizzes
"""

import asyncio
import logging
from sqlalchemy import select

from app.database import async_session_factory, init_db
from app.models.learning import (
    GrammarLesson,
    PlacementQuestion,
    VocabularyTopic,
    VocabularyWord,
)

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────
# 1. Placement Questions Data
# ──────────────────────────────────────────────
SAMPLE_QUESTIONS = [
    # Vocabulary
    {
        "skill": "vocabulary",
        "difficulty_level": "A1",
        "question_text": "Choose the word that means 'a place where you borrow books':",
        "options": ["Bakery", "Library", "Pharmacy", "Museum"],
        "correct_option": 1,
        "explanation": "A library is a building or room containing collections of books and periodicals for reading.",
        "order_index": 1,
    },
    {
        "skill": "vocabulary",
        "difficulty_level": "A2",
        "question_text": "I am looking forward to ________ you at the conference tomorrow.",
        "options": ["see", "saw", "seeing", "seen"],
        "correct_option": 2,
        "explanation": "'Look forward to' is followed by a gerund (V-ing): seeing.",
        "order_index": 2,
    },
    {
        "skill": "vocabulary",
        "difficulty_level": "B1",
        "question_text": "The company decided to ________ the launch of its new smartphone due to technical glitches.",
        "options": ["postpone", "accelerate", "compose", "resemble"],
        "correct_option": 0,
        "explanation": "'Postpone' means to delay something to a later time.",
        "order_index": 3,
    },
    {
        "skill": "vocabulary",
        "difficulty_level": "B2",
        "question_text": "His explanation was so ________ that everyone immediately grasped the complex algorithm.",
        "options": ["lucid", "ambiguous", "tedious", "superficial"],
        "correct_option": 0,
        "explanation": "'Lucid' means expressed clearly and easy to understand.",
        "order_index": 4,
    },
    # Grammar
    {
        "skill": "grammar",
        "difficulty_level": "A1",
        "question_text": "She ________ English every day with her AI tutor.",
        "options": ["study", "studies", "studying", "is study"],
        "correct_option": 1,
        "explanation": "With third-person singular (She), present simple takes 'studies'.",
        "order_index": 5,
    },
    {
        "skill": "grammar",
        "difficulty_level": "A2",
        "question_text": "We haven't seen John ________ last summer.",
        "options": ["for", "since", "during", "from"],
        "correct_option": 1,
        "explanation": "'Since' is used with a specific point in time (last summer) in the present perfect.",
        "order_index": 6,
    },
    {
        "skill": "grammar",
        "difficulty_level": "B1",
        "question_text": "If I ________ more time, I would learn a third language.",
        "options": ["have", "had", "will have", "would have"],
        "correct_option": 1,
        "explanation": "Second conditional (unreal present): If + Past Simple (had), would + bare infinitive.",
        "order_index": 7,
    },
    {
        "skill": "grammar",
        "difficulty_level": "B2",
        "question_text": "Hardly ________ the airport when the thunderstorm started.",
        "options": [
            "we had reached",
            "had we reached",
            "we reached",
            "did we reach",
        ],
        "correct_option": 1,
        "explanation": "Inversion after negative adverbial 'Hardly': Hardly + had + subject + past participle.",
        "order_index": 8,
    },
    # Reading
    {
        "skill": "reading",
        "difficulty_level": "B1",
        "context_text": "Artificial intelligence is reshaping education by personalizing lessons to individual learner paces. Rather than a one-size-fits-all curriculum, AI analyzes errors and emphasizes areas requiring reinforcement.",
        "question_text": "According to the passage, how does AI primarily benefit education?",
        "options": [
            "By replacing human teachers completely.",
            "By adapting content to each learner's unique needs.",
            "By shortening the school day.",
            "By making examinations much more difficult.",
        ],
        "correct_option": 1,
        "explanation": "The passage notes that AI personalizes lessons to individual learner paces rather than one-size-fits-all.",
        "order_index": 9,
    },
    {
        "skill": "reading",
        "difficulty_level": "B2",
        "context_text": "Neuroplasticity proves that the human brain retains the ability to forge novel neural pathways throughout adulthood. Deliberate practice, paired with spaced repetition, significantly augments long-term linguistic retention.",
        "question_text": "What does the author suggest about language learning in adults?",
        "options": [
            "Adults can no longer build new neural connections.",
            "Spaced repetition is only effective for children.",
            "The brain can continue adapting and acquiring languages through targeted practice.",
            "Learning speed is entirely predetermined by genetics.",
        ],
        "correct_option": 2,
        "explanation": "Neuroplasticity allows adults to create new neural pathways through deliberate practice and spaced repetition.",
        "order_index": 10,
    },
]


# ──────────────────────────────────────────────
# 2. Vocabulary Topics & Words
# ──────────────────────────────────────────────
SAMPLE_VOCABULARY = [
    {
        "slug": "daily-communication",
        "title": "Daily Communication & Socializing",
        "description": "Essential words and natural phrases for everyday English conversations.",
        "icon_name": "chat_bubble",
        "level": "A1-A2",
        "words": [
            {
                "word": "greetings",
                "phonetic": "/ˈɡriːtɪŋz/",
                "part_of_speech": "noun",
                "meaning_vi": "Lời chào hỏi, câu chào xã giao",
                "meaning_en": "Words or actions used to welcome someone",
                "example_sentence": "She exchanged warm greetings with her colleagues this morning.",
                "example_translation": "Cô ấy đã chào hỏi đồng nghiệp một cách ấm áp sáng nay.",
                "level": "A1",
            },
            {
                "word": "appreciate",
                "phonetic": "/əˈpriːʃieɪt/",
                "part_of_speech": "verb",
                "meaning_vi": "Trân trọng, cảm kích, đánh giá cao",
                "meaning_en": "To recognize the full worth or value of something",
                "example_sentence": "I really appreciate your timely assistance with this project.",
                "example_translation": "Tôi thực sự rất cảm kích sự giúp đỡ kịp thời của bạn trong dự án này.",
                "level": "A2",
            },
            {
                "word": "fluent",
                "phonetic": "/ˈfluːənt/",
                "part_of_speech": "adjective",
                "meaning_vi": "Lưu loát, trôi chảy",
                "meaning_en": "Able to express oneself easily and articulately",
                "example_sentence": "He became fluent in English after six months of daily AI speaking practice.",
                "example_translation": "Anh ấy đã nói tiếng Anh lưu loát sau 6 tháng luyện nói hàng ngày cùng AI.",
                "level": "B1",
            },
            {
                "word": "apologize",
                "phonetic": "/əˈpɒlədʒaɪz/",
                "part_of_speech": "verb",
                "meaning_vi": "Xin lỗi, nhận lỗi",
                "meaning_en": "To express regret for something done wrong",
                "example_sentence": "I sincerely apologize for the delay in replying to your email.",
                "example_translation": "Tôi chân thành xin lỗi vì sự chậm trễ trong việc phản hồi thư của bạn.",
                "level": "A2",
            },
            {
                "word": "enthusiastic",
                "phonetic": "/ɪnˌθjuːziˈæstɪk/",
                "part_of_speech": "adjective",
                "meaning_vi": "Nhiệt tình, hào hứng",
                "meaning_en": "Having or showing intense and eager enjoyment or interest",
                "example_sentence": "The students were enthusiastic about practicing spoken English with the AI tutor.",
                "example_translation": "Các học viên rất hào hứng luyện nói tiếng Anh cùng gia sư AI.",
                "level": "B1",
            },
            {
                "word": "confidence",
                "phonetic": "/ˈkɒnfɪdəns/",
                "part_of_speech": "noun",
                "meaning_vi": "Sự tự tin",
                "meaning_en": "The feeling or belief that one can have faith in or rely on someone or something",
                "example_sentence": "Daily practice builds your speaking confidence rapidly.",
                "example_translation": "Việc luyện tập mỗi ngày giúp bạn xây dựng sự tự tin khi nói rất nhanh chóng.",
                "level": "A2",
            },
            {
                "word": "convenient",
                "phonetic": "/kənˈviːniənt/",
                "part_of_speech": "adjective",
                "meaning_vi": "Thuận tiện, tiện lợi",
                "meaning_en": "Fitting in well with a person's needs, activities, and plans",
                "example_sentence": "Learning English on your smartphone is extremely convenient.",
                "example_translation": "Học tiếng Anh ngay trên điện thoại thông minh cực kỳ thuận tiện.",
                "level": "A2",
            },
        ],
    },
    {
        "slug": "tech-and-ai",
        "title": "Technology & Artificial Intelligence",
        "description": "Modern technical vocabulary for software, data, and modern innovation.",
        "icon_name": "laptop",
        "level": "B1-B2",
        "words": [
            {
                "word": "algorithm",
                "phonetic": "/ˈælɡərɪðəm/",
                "part_of_speech": "noun",
                "meaning_vi": "Thuật toán, quy trình xử lý từng bước",
                "meaning_en": "A step-by-step process or set of rules to be followed in calculations",
                "example_sentence": "The recommendation algorithm tailors daily lessons to your weak spots.",
                "example_translation": "Thuật toán gợi ý tùy biến bài học mỗi ngày dựa trên các điểm yếu của bạn.",
                "level": "B1",
            },
            {
                "word": "automation",
                "phonetic": "/ˌɔːtəˈmeɪʃn/",
                "part_of_speech": "noun",
                "meaning_vi": "Sự tự động hóa",
                "meaning_en": "The use of largely automatic equipment in an operation",
                "example_sentence": "Automation empowers engineers to focus on creative problem solving.",
                "example_translation": "Tự động hóa giúp các kỹ sư tập trung vào việc giải quyết vấn đề mang tính sáng tạo.",
                "level": "B2",
            },
            {
                "word": "breakthrough",
                "phonetic": "/ˈbreɪkθruː/",
                "part_of_speech": "noun",
                "meaning_vi": "Bước đột phá, thành tựu quan trọng",
                "meaning_en": "A sudden, dramatic, and important discovery or development",
                "example_sentence": "Large Language Models represent a monumental breakthrough in NLP.",
                "example_translation": "Các mô hình ngôn ngữ lớn đại diện cho một bước đột phá vĩ đại trong xử lý ngôn ngữ tự nhiên.",
                "level": "B2",
            },
            {
                "word": "latency",
                "phonetic": "/ˈleɪtənsi/",
                "part_of_speech": "noun",
                "meaning_vi": "Độ trễ phản hồi hệ thống",
                "meaning_en": "The delay before a transfer of data begins following an instruction",
                "example_sentence": "Low latency is essential for seamless voice interactions with the AI tutor.",
                "example_translation": "Độ trễ thấp là điều cốt lõi để tương tác bằng giọng nói mượt mà với gia sư AI.",
                "level": "B2",
            },
            {
                "word": "optimize",
                "phonetic": "/ˈɒptɪmaɪz/",
                "part_of_speech": "verb",
                "meaning_vi": "Tối ưu hóa, tinh chỉnh cho hiệu quả nhất",
                "meaning_en": "Make the best or most effective use of a situation or resource",
                "example_sentence": "We optimized the database queries to reduce loading time by ninety percent.",
                "example_translation": "Chúng tôi đã tối ưu hóa các truy vấn cơ sở dữ liệu để giảm 90% thời gian tải.",
                "level": "B2",
            },
        ],
    },
    {
        "slug": "business-and-workplace",
        "title": "Business & Career Advancement",
        "description": "Professional terminology for meetings, negotiation, and corporate communications.",
        "icon_name": "briefcase",
        "level": "B1-B2",
        "words": [
            {
                "word": "collaborate",
                "phonetic": "/kəˈlæbəreɪt/",
                "part_of_speech": "verb",
                "meaning_vi": "Hợp tác, làm việc nhóm",
                "meaning_en": "Work jointly on an activity or project",
                "example_sentence": "Engineers and designers collaborate closely to refine the user experience.",
                "example_translation": "Các kỹ sư và nhà thiết kế hợp tác chặt chẽ để hoàn thiện trải nghiệm người dùng.",
                "level": "B1",
            },
            {
                "word": "deadline",
                "phonetic": "/ˈdedlaɪn/",
                "part_of_speech": "noun",
                "meaning_vi": "Hạn chót, thời hạn hoàn thành",
                "meaning_en": "The latest time or date by which something should be completed",
                "example_sentence": "We successfully delivered the mobile app three days ahead of the deadline.",
                "example_translation": "Chúng tôi đã bàn giao ứng dụng di động thành công trước thời hạn 3 ngày.",
                "level": "A2",
            },
            {
                "word": "negotiate",
                "phonetic": "/nɪˈɡəʊʃieɪt/",
                "part_of_speech": "verb",
                "meaning_vi": "Đàm phán, thương lượng",
                "meaning_en": "Try to reach an agreement or compromise by discussion with others",
                "example_sentence": "She was able to negotiate a higher salary thanks to her fluent English.",
                "example_translation": "Cô ấy đã có thể đàm phán mức lương cao hơn nhờ khả năng tiếng Anh lưu loát.",
                "level": "B2",
            },
            {
                "word": "revenue",
                "phonetic": "/ˈrevənjuː/",
                "part_of_speech": "noun",
                "meaning_vi": "Doanh thu, thu nhập của doanh nghiệp",
                "meaning_en": "Income, especially when of a company or organization and of a substantial nature",
                "example_sentence": "Expanding into international markets boosted annual revenue by forty percent.",
                "example_translation": "Mở rộng sang thị trường quốc tế đã thúc đẩy doanh thu hàng năm tăng 40%.",
                "level": "B1",
            },
            {
                "word": "stakeholder",
                "phonetic": "/ˈsteɪkhəʊldə/",
                "part_of_speech": "noun",
                "meaning_vi": "Các bên liên quan, đối tác đầu tư",
                "meaning_en": "A person with an interest or concern in something, especially a business",
                "example_sentence": "All key stakeholders approved the new product roadmap during the meeting.",
                "example_translation": "Tất cả các bên liên quan chủ chốt đã thông qua lộ trình sản phẩm mới trong cuộc họp.",
                "level": "B2",
            },
        ],
    },
    {
        "slug": "travel-and-tourism",
        "title": "Travel, Hospitality & Culture",
        "description": "Indispensable phrases for airports, hotels, directions, and dining abroad.",
        "icon_name": "flight",
        "level": "A2-B1",
        "words": [
            {
                "word": "destination",
                "phonetic": "/ˌdestɪˈneɪʃn/",
                "part_of_speech": "noun",
                "meaning_vi": "Điểm đến, đích đến",
                "meaning_en": "The place to which someone or something is going or being sent",
                "example_sentence": "Da Nang is a famous destination for international travelers visiting Vietnam.",
                "example_translation": "Đà Nẵng là một điểm đến nổi tiếng đối với khách du lịch quốc tế khi đến Việt Nam.",
                "level": "A2",
            },
            {
                "word": "itinerary",
                "phonetic": "/aɪˈtɪnərəri/",
                "part_of_speech": "noun",
                "meaning_vi": "Lịch trình chuyến đi, hành trình chi tiết",
                "meaning_en": "A planned route or journey",
                "example_sentence": "Our tour guide shared a detailed itinerary for our three-day visit to Tokyo.",
                "example_translation": "Hướng dẫn viên đã chia sẻ lịch trình chi tiết cho chuyến tham quan Tokyo 3 ngày của chúng tôi.",
                "level": "B1",
            },
            {
                "word": "accommodation",
                "phonetic": "/əˌkɒməˈdeɪʃn/",
                "part_of_speech": "noun",
                "meaning_vi": "Chỗ ở, phòng nghỉ lưu trú",
                "meaning_en": "A room, group of rooms, or building in which someone may live or stay",
                "example_sentence": "We booked a cozy accommodation near the beach with ocean view.",
                "example_translation": "Chúng tôi đã đặt một chỗ ở ấm cúng gần bãi biển với tầm nhìn hướng ra đại dương.",
                "level": "B1",
            },
            {
                "word": "reservation",
                "phonetic": "/ˌrezəˈveɪʃn/",
                "part_of_speech": "noun",
                "meaning_vi": "Sự đặt chỗ trước (bàn ăn, phòng khách sạn)",
                "meaning_en": "An arrangement whereby something is booked or reserved for a particular person",
                "example_sentence": "I would like to make a dinner reservation for two people at seven tonight.",
                "example_translation": "Tôi muốn đặt bàn ăn tối cho 2 người lúc 7 giờ tối nay.",
                "level": "A2",
            },
        ],
    },
    {
        "slug": "academic-and-ielts",
        "title": "Academic & IELTS Essential",
        "description": "High-band academic vocabulary for IELTS Writing, Reading, and formal presentations.",
        "icon_name": "menu_book",
        "level": "B2-C1",
        "words": [
            {
                "word": "significant",
                "phonetic": "/sɪɡˈnɪfɪkənt/",
                "part_of_speech": "adjective",
                "meaning_vi": "Đáng kể, có ý nghĩa quan trọng",
                "meaning_en": "Sufficiently great or important to be worthy of attention",
                "example_sentence": "There has been a significant rise in digital education over the past decade.",
                "example_translation": "Đã có một sự gia tăng đáng kể trong giáo dục kỹ thuật số trong suốt thập kỷ qua.",
                "level": "B2",
            },
            {
                "word": "perspective",
                "phonetic": "/pəˈspektɪv/",
                "part_of_speech": "noun",
                "meaning_vi": "Góc nhìn, quan điểm",
                "meaning_en": "A particular attitude towards or way of regarding something; a point of view",
                "example_sentence": "The author provides a unique perspective on climate change solutions.",
                "example_translation": "Tác giả mang lại một góc nhìn độc đáo về các giải pháp ứng phó với biến đổi khí hậu.",
                "level": "B2",
            },
            {
                "word": "comprehensive",
                "phonetic": "/ˌkɒmprɪˈhensɪv/",
                "part_of_speech": "adjective",
                "meaning_vi": "Toàn diện, bao quát mọi khía cạnh",
                "meaning_en": "Complete and including everything that is necessary",
                "example_sentence": "This app provides a comprehensive learning path from beginner to advanced.",
                "example_translation": "Ứng dụng này cung cấp một lộ trình học tập toàn diện từ sơ cấp đến nâng cao.",
                "level": "C1",
            },
            {
                "word": "facilitate",
                "phonetic": "/fəˈsɪlɪteɪt/",
                "part_of_speech": "verb",
                "meaning_vi": "Tạo điều kiện thuận lợi, làm cho dễ dàng hơn",
                "meaning_en": "Make an action or process easy or easier",
                "example_sentence": "Interactive feedback facilitates faster mastery of complex grammar rules.",
                "example_translation": "Phản hồi tương tác tạo điều kiện giúp làm chủ các quy tắc ngữ pháp phức tạp nhanh hơn.",
                "level": "C1",
            },
        ],
    },
]



# ──────────────────────────────────────────────
# 3. Grammar Lessons Data
# ──────────────────────────────────────────────
SAMPLE_GRAMMAR = [
    {
        "slug": "present-simple-vs-continuous",
        "title": "Present Simple vs. Present Continuous",
        "level": "A1-A2",
        "summary": "Understand when to express universal habits vs. actions happening right now.",
        "formula": "Simple: S + V(s/es) | Continuous: S + am/is/are + V-ing",
        "content_markdown": """
### 1. Present Simple (Hiện tại đơn)
Dùng để diễn tả sự thật hiển nhiên, thói quen lặp đi lặp lại hoặc lịch trình cố định.
* **Cấu trúc**: `S + V(s/es) + O`
* **Dấu hiệu**: *always, usually, often, every day, on Mondays*
* **Ví dụ**: *I study English every evening.*

---

### 2. Present Continuous (Hiện tại tiếp diễn)
Dùng để diễn tả hành động đang diễn ra tại thời điểm nói hoặc xu hướng tạm thời.
* **Cấu trúc**: `S + am/is/are + V-ing`
* **Dấu hiệu**: *now, right now, at the moment, currently*
* **Ví dụ**: *She is practicing pronunciation right now.*
        """,
        "examples": [
            {"en": "Water boils at 100 degrees Celsius.", "vi": "Nước sôi ở 100 độ C."},
            {"en": "Listen! The teacher is explaining the lesson.", "vi": "Lắng nghe kìa! Giáo viên đang giải thích bài học."},
        ],
        "practice_questions": [
            {
                "question": "Look at the sky! It ________ heavily.",
                "options": ["rains", "is raining", "rained", "has rained"],
                "correct_option": 1,
                "explanation": "'Look at the sky!' indicates an action occurring right now -> Present Continuous.",
            },
            {
                "question": "My father ________ coffee every morning before work.",
                "options": ["drinks", "is drinking", "drink", "drank"],
                "correct_option": 0,
                "explanation": "'Every morning' indicates a habitual action -> Present Simple.",
            },
        ],
        "order_index": 1,
    },
    {
        "slug": "present-perfect-tense",
        "title": "The Present Perfect Tense",
        "level": "B1",
        "summary": "Connect past actions to present consequences with 'have/has + V3/ed'.",
        "formula": "S + have/has + Past Participle (V3/ed)",
        "content_markdown": """
### Present Perfect (Hiện tại hoàn thành)
Dùng để diễn tả:
1. Hành động đã xảy ra trong quá khứ nhưng không xác định rõ thời gian.
2. Trải nghiệm từ trước tới nay (*ever, never*).
3. Hành động bắt đầu trong quá khứ và vẫn tiếp diễn ở hiện tại (*since, for*).

* **Công thức**: `S + have/has + V3/ed`
* **Ví dụ**: *I have lived in Hanoi for five years.*
        """,
        "examples": [
            {"en": "Have you ever visited Tokyo?", "vi": "Bạn đã từng đến Tokyo bao giờ chưa?"},
            {"en": "He has just finished his AI placement exam.", "vi": "Anh ấy vừa hoàn thành bài thi xếp lớp AI."},
        ],
        "practice_questions": [
            {
                "question": "They ________ in this neighborhood since 2018.",
                "options": ["lived", "are living", "have lived", "will live"],
                "correct_option": 2,
                "explanation": "Since + past year (2018) requires the Present Perfect tense.",
            }
        ],
        "order_index": 2,
    },
]


async def seed_data():
    """Seed data into the database if tables are empty."""
    logger.info("🌱 Seeding learning data...")
    await init_db()

    async with async_session_factory() as db:
        # 1. Seed Placement Questions
        q_count = await db.execute(select(PlacementQuestion))
        if not q_count.scalars().first():
            logger.info("Seeding Placement Questions...")
            for q_data in SAMPLE_QUESTIONS:
                db.add(PlacementQuestion(**q_data))
            await db.commit()
            logger.info("✅ Placement Questions seeded.")

        # 2. Seed Vocabulary Topics & Words
        topic_count = await db.execute(select(VocabularyTopic))
        if not topic_count.scalars().first():
            logger.info("Seeding Vocabulary Topics and Words...")
            for t_data in SAMPLE_VOCABULARY:
                words_data = t_data.pop("words", [])
                topic = VocabularyTopic(
                    **t_data,
                    total_words=len(words_data),
                )
                db.add(topic)
                await db.flush()

                for w_data in words_data:
                    word = VocabularyWord(topic_id=topic.id, **w_data)
                    db.add(word)
            await db.commit()
            logger.info("✅ Vocabulary Topics and Words seeded.")

        # 3. Seed Grammar Lessons
        g_count = await db.execute(select(GrammarLesson))
        if not g_count.scalars().first():
            logger.info("Seeding Grammar Lessons...")
            for g_data in SAMPLE_GRAMMAR:
                db.add(GrammarLesson(**g_data))
            await db.commit()
            logger.info("✅ Grammar Lessons seeded.")

    logger.info("🎉 All learning data seeded successfully!")


if __name__ == "__main__":
    asyncio.run(seed_data())
