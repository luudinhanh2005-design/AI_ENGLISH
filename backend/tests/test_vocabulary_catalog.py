from app.api.v1.vocabulary import (
    _FALLBACK_ALL_WORDS,
    _FALLBACK_TOPICS,
    _fallback_word_page,
)
from app.utils.vocabulary_catalog import (
    catalog_words,
    load_catalog,
    normalize_word,
    topic_id,
    word_id,
)


def test_catalog_has_starter_bank():
    catalog = load_catalog()
    assert len(catalog["topics"]) == 20
    assert len(catalog_words()) == 200
    assert len({word["id"] for word in catalog_words()}) == 200
    assert len({normalize_word(word["word"]) for word in catalog_words()}) == 200


def test_catalog_ids_are_stable():
    first = catalog_words()[0]
    assert first["id"] == str(word_id(first["word"]))
    topic = load_catalog()["topics"][0]
    assert topic["id"] == str(topic_id(topic["slug"]))


def test_catalog_words_have_learning_content():
    required = {
        "word",
        "phonetic",
        "part_of_speech",
        "meaning_vi",
        "meaning_en",
        "example_sentence",
        "example_translation",
        "level",
    }
    for word in catalog_words():
        assert required <= set(word)
        for field in required:
            assert str(word[field]).strip(), f"{word['word']} is missing {field}"
        assert isinstance(word["collocations"], list)
        assert isinstance(word["synonyms"], list)
        assert isinstance(word["antonyms"], list)


def test_fallback_deck_is_built_from_catalog():
    assert len(_FALLBACK_TOPICS) == 20
    assert len(_FALLBACK_ALL_WORDS) == 200
    assert _FALLBACK_TOPICS[0].title == "Giao Tiếp Hàng Ngày"


def test_fallback_search_and_filters():
    page = _fallback_word_page(
        q="coffee",
        topic_id=None,
        topic_slug=None,
        level=None,
        page=1,
        limit=10,
    )
    assert page.total == 0

    page = _fallback_word_page(
        q="delicious",
        topic_id=None,
        topic_slug=None,
        level=None,
        page=1,
        limit=10,
    )
    assert page.total == 1
    assert page.items[0].word == "delicious"

    page = _fallback_word_page(
        q=None,
        topic_id=None,
        topic_slug="food-and-dining",
        level="A1",
        page=1,
        limit=10,
    )
    assert page.total == 2
    assert {item.word for item in page.items} == {"menu", "delicious"}
