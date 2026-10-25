"""
Seed initial learning data for EnglishAI:
- Placement Test Question Bank
- Vocabulary Topics & Words
- Grammar Lessons & Practice Quizzes
"""

import asyncio
import logging
import uuid

from sqlalchemy import select

from app.database import async_session_factory, init_db, is_db_connected
from app.models.learning import (
    GrammarLesson,
    PlacementQuestion,
    VocabularyTopic,
    VocabularyWord,
)
from app.utils.vocabulary_catalog import (
    catalog_topics,
    normalize_word,
    topic_id as vocab_topic_id,
    word_id as vocab_word_id,
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
SAMPLE_VOCABULARY = catalog_topics()



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

        # 2. Seed / update Vocabulary Topics & Words
        inserted, updated = await _upsert_vocabulary(db)
        await db.commit()
        logger.info(
            "✅ Vocabulary catalog synced: %d inserted, %d updated.",
            inserted,
            updated,
        )

        # 3. Seed Grammar Lessons
        g_count = await db.execute(select(GrammarLesson))
        if not g_count.scalars().first():
            logger.info("Seeding Grammar Lessons...")
            for g_data in SAMPLE_GRAMMAR:
                db.add(GrammarLesson(**g_data))
            await db.commit()
            logger.info("✅ Grammar Lessons seeded.")

    logger.info("🎉 All learning data seeded successfully!")


_WORD_CONTENT_FIELDS = (
    "word",
    "phonetic",
    "part_of_speech",
    "meaning_vi",
    "meaning_en",
    "example_sentence",
    "example_translation",
    "audio_url",
    "image_url",
    "level",
    "collocations",
    "synonyms",
    "antonyms",
    "tags",
    "order_index",
)


def _word_payload(data: dict) -> dict:
    return {field: data.get(field) for field in _WORD_CONTENT_FIELDS}


async def _upsert_vocabulary(db) -> tuple[int, int]:
    """Create or update every catalog topic/word without deleting progress.

    Existing rows are matched by stable UUID first and then by normalized
    headword.  This makes the operation safe for databases seeded by an older
    version of the app.
    """
    inserted = 0
    updated = 0

    for t_data in catalog_topics():
        slug = str(t_data["slug"])
        tid = vocab_topic_id(slug)

        topic = await db.get(VocabularyTopic, tid)
        if topic is None:
            by_slug = await db.execute(
                select(VocabularyTopic).where(VocabularyTopic.slug == slug)
            )
            topic = by_slug.scalar_one_or_none()

        if topic is None:
            topic = VocabularyTopic(
                id=tid,
                slug=slug,
                title=str(t_data["title"]),
                description=t_data.get("description"),
                icon_name=str(t_data.get("icon_name", "book")),
                level=str(t_data.get("level", "A1")),
                total_words=len(t_data.get("words", [])),
                order_index=int(t_data.get("order_index", 0)),
                is_active=True,
            )
            db.add(topic)
            await db.flush()
        else:
            topic.slug = slug
            topic.title = str(t_data["title"])
            topic.description = t_data.get("description")
            topic.icon_name = str(t_data.get("icon_name", "book"))
            topic.level = str(t_data.get("level", "A1"))
            topic.order_index = int(t_data.get("order_index", 0))
            topic.is_active = True

        existing = await db.execute(
            select(VocabularyWord).where(VocabularyWord.topic_id == topic.id)
        )
        existing_by_word = {
            normalize_word(word.word): word for word in existing.scalars().all()
        }

        for w_data in t_data.get("words", []):
            wid = (
                uuid.UUID(str(w_data["id"]))
                if w_data.get("id")
                else vocab_word_id(str(w_data["word"]))
            )
            word = existing_by_word.get(normalize_word(str(w_data["word"])))
            if word is None:
                word = await db.get(VocabularyWord, wid)

            if word is None:
                db.add(
                    VocabularyWord(
                        id=wid,
                        topic_id=topic.id,
                        **_word_payload(w_data),
                    )
                )
                inserted += 1
            else:
                word.topic_id = topic.id
                for field, value in _word_payload(w_data).items():
                    setattr(word, field, value)
                updated += 1

        topic.total_words = len(t_data.get("words", []))
        await db.flush()

    return inserted, updated


async def seed_vocabulary() -> int:
    """Idempotently sync the vocabulary catalog.

    Returns the number of newly inserted words.  Existing words and user
    progress are preserved.
    """
    if not is_db_connected():
        return 0

    async with async_session_factory() as db:
        inserted, updated = await _upsert_vocabulary(db)
        await db.commit()

    logger.info(
        "✅ Vocabulary catalog synced: %d inserted, %d updated", inserted, updated
    )
    return inserted


async def seed_vocabulary_if_empty() -> int:
    """Backward-compatible alias for the old startup hook.

    The name is kept because some deployments still import it, but the
    implementation now performs an idempotent upsert on every startup.
    """
    return await seed_vocabulary()


if __name__ == "__main__":
    asyncio.run(seed_data())
