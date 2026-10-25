"""Canonical vocabulary catalog loader.

The JSON file in ``app/data/vocabulary/catalog.json`` is the single source of
truth for vocabulary lessons.  The backend seeds PostgreSQL from it and the
Flutter offline deck is generated from the same file by
``scripts/sync_vocabulary_catalog.py``.

Keeping IDs deterministic is important: user progress is stored by word ID.
Changing a word's spelling, topic, or case would otherwise orphan progress.
"""

from __future__ import annotations

import json
import re
import uuid
from functools import lru_cache
from pathlib import Path
from typing import Any

CATALOG_PATH = (
    Path(__file__).resolve().parents[1] / "data" / "vocabulary" / "catalog.json"
)

_NAMESPACE = uuid.NAMESPACE_DNS
_WHITESPACE = re.compile(r"\s+")

_REQUIRED_TOPIC_FIELDS = ("slug", "title", "words")
_REQUIRED_WORD_FIELDS = (
    "word",
    "phonetic",
    "part_of_speech",
    "meaning_vi",
    "meaning_en",
    "example_sentence",
    "example_translation",
    "level",
)


def normalize_word(value: str) -> str:
    """Normalize a headword for identity and duplicate checks."""
    return _WHITESPACE.sub(" ", value.strip().lower())


def topic_id(slug: str) -> uuid.UUID:
    """Stable topic UUID shared by the database seed and offline fallback."""
    return uuid.uuid5(_NAMESPACE, f"vocab-topic-{slug}")


def word_id(word: str) -> uuid.UUID:
    """Stable word UUID.

    The legacy seed used ``vocab-word-{word}``.  We deliberately keep that
    scheme so words that already exist in production keep their progress.
    Duplicate headwords across topics are rejected by ``load_catalog``.
    """
    return uuid.uuid5(_NAMESPACE, f"vocab-word-{normalize_word(word)}")


def _as_str_list(value: Any, field: str, *, where: str) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        raise ValueError(f"{field} must be a list of strings ({where})")
    return [item.strip() for item in value if item.strip()]


@lru_cache(maxsize=1)
def load_catalog() -> dict[str, Any]:
    """Load and validate the catalog once per process.

    The returned structure is treated as read-only by callers.
    """
    if not CATALOG_PATH.exists():
        raise FileNotFoundError(f"Vocabulary catalog not found: {CATALOG_PATH}")

    raw = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("Vocabulary catalog root must be an object")

    topics_raw = raw.get("topics")
    if not isinstance(topics_raw, list) or not topics_raw:
        raise ValueError("Vocabulary catalog must contain a non-empty topics list")

    seen_slugs: set[str] = set()
    seen_words: dict[str, str] = {}
    topics: list[dict[str, Any]] = []

    for topic_order, topic in enumerate(topics_raw):
        if not isinstance(topic, dict):
            raise ValueError(f"Topic #{topic_order} must be an object")
        for field in _REQUIRED_TOPIC_FIELDS:
            if not topic.get(field):
                raise ValueError(f"Topic #{topic_order} is missing {field}")

        slug = str(topic["slug"]).strip().lower()
        if slug in seen_slugs:
            raise ValueError(f"Duplicate topic slug: {slug}")
        seen_slugs.add(slug)

        words_raw = topic["words"]
        if not isinstance(words_raw, list) or not words_raw:
            raise ValueError(f"Topic {slug} must contain at least one word")

        tid = topic_id(slug)
        words: list[dict[str, Any]] = []
        for word_order, word in enumerate(words_raw):
            if not isinstance(word, dict):
                raise ValueError(f"Word #{word_order} in {slug} must be an object")
            for field in _REQUIRED_WORD_FIELDS:
                if not str(word.get(field, "")).strip():
                    raise ValueError(
                        f"Word #{word_order} in {slug} is missing {field}"
                    )

            headword = normalize_word(str(word["word"]))
            if headword in seen_words:
                raise ValueError(
                    f"Duplicate headword '{headword}' in {slug} and "
                    f"{seen_words[headword]}"
                )
            seen_words[headword] = slug

            wid = word_id(headword)
            words.append(
                {
                    "id": str(wid),
                    "topic_id": str(tid),
                    "word": str(word["word"]).strip(),
                    "phonetic": str(word["phonetic"]).strip(),
                    "part_of_speech": str(word["part_of_speech"]).strip(),
                    "meaning_vi": str(word["meaning_vi"]).strip(),
                    "meaning_en": str(word["meaning_en"]).strip(),
                    "example_sentence": str(word["example_sentence"]).strip(),
                    "example_translation": str(word["example_translation"]).strip(),
                    "level": str(word["level"]).strip().upper(),
                    "audio_url": word.get("audio_url"),
                    "image_url": word.get("image_url"),
                    "collocations": _as_str_list(
                        word.get("collocations"), "collocations", where=f"{slug}/{headword}"
                    ),
                    "synonyms": _as_str_list(
                        word.get("synonyms"), "synonyms", where=f"{slug}/{headword}"
                    ),
                    "antonyms": _as_str_list(
                        word.get("antonyms"), "antonyms", where=f"{slug}/{headword}"
                    ),
                    "tags": _as_str_list(
                        word.get("tags"), "tags", where=f"{slug}/{headword}"
                    ),
                    "order_index": word_order,
                }
            )

        topics.append(
            {
                "id": str(tid),
                "slug": slug,
                "title": str(topic["title"]).strip(),
                "description": str(topic.get("description", "")).strip() or None,
                "icon_name": str(topic.get("icon_name", "book")).strip() or "book",
                "level": str(topic.get("level", "A1")).strip() or "A1",
                "order_index": int(topic.get("order_index", topic_order)),
                "total_words": len(words),
                "words": words,
            }
        )

    return {
        "version": raw.get("version", 1),
        "updated_at": raw.get("updated_at"),
        "topics": topics,
    }


def catalog_topics() -> list[dict[str, Any]]:
    """Return topics in the shape expected by the legacy seed code."""
    return load_catalog()["topics"]


def catalog_words() -> list[dict[str, Any]]:
    """Return every word across all topics."""
    return [word for topic in catalog_topics() for word in topic["words"]]


def topic_by_slug(slug: str) -> dict[str, Any] | None:
    normalized = slug.strip().lower()
    for topic in catalog_topics():
        if topic["slug"] == normalized:
            return topic
    return None


def word_by_id(value: uuid.UUID | str) -> dict[str, Any] | None:
    target = str(value)
    for word in catalog_words():
        if word["id"] == target:
            return word
    return None
