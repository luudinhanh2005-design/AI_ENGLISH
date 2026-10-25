#!/usr/bin/env python3
"""Generate the Flutter offline vocabulary deck from the backend catalog.

Source of truth: backend/app/data/vocabulary/catalog.json
Output:         english_ai/lib/features/vocabulary/data/vocabulary_data.dart

Run from the repository root:
    python scripts/sync_vocabulary_catalog.py

Use --check in CI to fail when the generated file is stale.
"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "backend" / "app" / "data" / "vocabulary" / "catalog.json"
OUTPUT_PATH = (
    ROOT
    / "english_ai"
    / "lib"
    / "features"
    / "vocabulary"
    / "data"
    / "vocabulary_data.dart"
)

NAMESPACE = uuid.NAMESPACE_DNS


def _norm(value: str) -> str:
    return " ".join(value.strip().lower().split())


def _topic_id(slug: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"vocab-topic-{slug}"))


def _word_id(word: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"vocab-word-{_norm(word)}"))


def _dart_string(value: str) -> str:
    """Single-quoted Dart string literal."""
    escaped = (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
    )
    return f"'{escaped}'"


def _dart_list(values: list[Any]) -> str:
    if not values:
        return "[]"
    return "[" + ", ".join(_dart_string(str(item)) for item in values) + "]"


def _load() -> dict[str, Any]:
    data = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    topics = data.get("topics")
    if not isinstance(topics, list) or not topics:
        raise SystemExit("Catalog must contain a non-empty topics list")

    seen_words: dict[str, str] = {}
    for topic in topics:
        slug = str(topic["slug"]).strip().lower()
        topic["_id"] = _topic_id(slug)
        for order, word in enumerate(topic.get("words", [])):
            headword = _norm(str(word["word"]))
            if headword in seen_words:
                raise SystemExit(
                    f"Duplicate headword '{headword}' in {slug} and {seen_words[headword]}"
                )
            seen_words[headword] = slug
            word["_id"] = _word_id(headword)
            word["_order"] = order
    return data


def render(data: dict[str, Any]) -> str:
    topics = data["topics"]
    lines: list[str] = [
        "// GENERATED CODE - DO NOT EDIT BY HAND.",
        "//",
        "// Source: backend/app/data/vocabulary/catalog.json",
        "// Regenerate: python scripts/sync_vocabulary_catalog.py",
        "",
        "import 'models/vocabulary_models.dart';",
        "",
        "const String vocabularyCatalogVersion = "
        + _dart_string(str(data.get("version", 1)))
        + ";",
        "",
        "List<VocabularyTopicModel> buildStaticTopics() => const [",
    ]

    for topic in topics:
        lines.extend(
            [
                "      VocabularyTopicModel(",
                f"        id: {_dart_string(topic['_id'])},",
                f"        slug: {_dart_string(str(topic['slug']))},",
                f"        title: {_dart_string(str(topic['title']))},",
                "        description: "
                + (
                    _dart_string(str(topic["description"]))
                    if topic.get("description")
                    else "null"
                )
                + ",",
                f"        iconName: {_dart_string(str(topic.get('icon_name', 'book')))},",
                f"        level: {_dart_string(str(topic.get('level', 'A1')))},",
                f"        totalWords: {len(topic.get('words', []))},",
                "      ),",
            ]
        )

    lines.extend(["    ];", "", "List<VocabularyWordModel> buildTopicWords(String topicId) {", "  switch (topicId) {"])

    for topic in topics:
        lines.extend(
            [
                f"    case {_dart_string(topic['_id'])}:",
                f"    case {_dart_string(str(topic['slug']))}:",
                "      return const [",
            ]
        )
        for word in topic.get("words", []):
            lines.extend(
                [
                    "        VocabularyWordModel(",
                    f"          id: {_dart_string(word['_id'])},",
                    f"          topicId: {_dart_string(topic['_id'])},",
                    f"          word: {_dart_string(str(word['word']))},",
                    f"          phonetic: {_dart_string(str(word['phonetic']))},",
                    f"          partOfSpeech: {_dart_string(str(word['part_of_speech']))},",
                    f"          meaningVi: {_dart_string(str(word['meaning_vi']))},",
                    f"          meaningEn: {_dart_string(str(word['meaning_en']))},",
                    f"          exampleSentence: {_dart_string(str(word['example_sentence']))},",
                    f"          exampleTranslation: {_dart_string(str(word['example_translation']))},",
                    "          audioUrl: "
                    + (
                        _dart_string(str(word["audio_url"]))
                        if word.get("audio_url")
                        else "null"
                    )
                    + ",",
                    "          imageUrl: "
                    + (
                        _dart_string(str(word["image_url"]))
                        if word.get("image_url")
                        else "null"
                    )
                    + ",",
                    f"          level: {_dart_string(str(word.get('level', 'A1')))},",
                    f"          collocations: {_dart_list(word.get('collocations') or [])},",
                    f"          synonyms: {_dart_list(word.get('synonyms') or [])},",
                    f"          antonyms: {_dart_list(word.get('antonyms') or [])},",
                    f"          tags: {_dart_list(word.get('tags') or [])},",
                    f"          orderIndex: {int(word.get('_order', 0))},",
                    "        ),",
                ]
            )
        lines.append("      ];")

    lines.extend(
        [
            "    default:",
            "      return const [];",
            "  }",
            "}",
            "",
            "List<VocabularyWordModel> buildStaticWords() => buildStaticTopics()",
            "    .expand((topic) => buildTopicWords(topic.id))",
            "    .toList(growable: false);",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="Only verify that the generated Dart file is up to date.",
    )
    args = parser.parse_args()

    rendered = render(_load())

    if args.check:
        current = OUTPUT_PATH.read_text(encoding="utf-8") if OUTPUT_PATH.exists() else ""
        if current != rendered:
            print(
                "vocabulary_data.dart is stale. Run: python scripts/sync_vocabulary_catalog.py",
                file=sys.stderr,
            )
            raise SystemExit(1)
        print("vocabulary_data.dart is up to date.")
        return

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(rendered, encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
