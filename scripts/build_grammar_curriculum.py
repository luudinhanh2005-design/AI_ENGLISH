"""Build the canonical A1-C2 grammar curriculum index.

This file is the single source of truth for lesson ids/titles/levels.
Content agents read the generated JSON and write one file per level.
"""
from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "english_ai" / "assets" / "data" / "grammar" / "curriculum.json"

# (id, title, title_vi, level, category)
LESSONS = [
    # ── A1 (18) ──────────────────────────────────────────────────────────
    ("verb_to_be", "Verb To Be (am/is/are)", "Động từ To Be", "A1", "Nền tảng"),
    ("subject_pronouns_possessives", "Subject Pronouns & Possessive Adjectives", "Đại từ nhân xưng & tính từ sở hữu", "A1", "Nền tảng"),
    ("articles_basic", "Articles a/an/the (Basic)", "Mạo từ cơ bản", "A1", "Danh từ & Mạo từ"),
    ("singular_plural_demonstratives", "Singular/Plural & This/That/These/Those", "Danh từ số ít/số nhiều & chỉ định từ", "A1", "Danh từ & Mạo từ"),
    ("present_simple", "Present Simple", "Thì Hiện Tại Đơn", "A1", "Các Thì"),
    ("present_continuous", "Present Continuous", "Thì Hiện Tại Tiếp Diễn", "A1", "Các Thì"),
    ("present_simple_vs_continuous", "Present Simple vs Present Continuous", "Hiện tại đơn vs Hiện tại tiếp diễn", "A1", "Các Thì"),
    ("can_cannot_imperatives", "Can/Can't & Imperatives", "Can/Can't & Câu mệnh lệnh", "A1", "Modal & Câu lệnh"),
    ("there_is_are_some_any", "There is/are & Some/Any", "There is/are & Some/Any", "A1", "Lượng từ"),
    ("countable_uncountable_basic", "Countable & Uncountable Nouns (Basic)", "Danh từ đếm được/không đếm được", "A1", "Danh từ & Lượng từ"),
    ("prepositions_place", "Prepositions of Place", "Giới từ chỉ nơi chốn", "A1", "Giới từ"),
    ("prepositions_time", "Prepositions of Time", "Giới từ chỉ thời gian", "A1", "Giới từ"),
    ("past_simple_was_were", "Past Simple: Was/Were", "Quá khứ đơn với Was/Were", "A1", "Các Thì"),
    ("past_simple_regular_irregular", "Past Simple: Regular & Irregular Verbs", "Quá khứ đơn: động từ có quy tắc & bất quy tắc", "A1", "Các Thì"),
    ("adverbs_frequency_question_words", "Adverbs of Frequency & Question Words", "Trạng từ tần suất & từ hỏi", "A1", "Trạng từ & Câu hỏi"),
    ("object_pronouns_like_ving", "Object Pronouns & Like + V-ing", "Đại từ tân ngữ & Like + V-ing", "A1", "Nền tảng"),
    ("basic_conjunctions", "Basic Conjunctions (and/but/or/because)", "Liên từ cơ bản", "A1", "Liên từ"),
    ("possessive_s_have_got", "Possessive 's & Have Got", "Sở hữu 's & Have Got", "A1", "Nền tảng"),

    # ── A2 (18) ──────────────────────────────────────────────────────────
    ("past_continuous", "Past Continuous", "Quá khứ tiếp diễn", "A2", "Các Thì"),
    ("past_simple_vs_continuous", "Past Simple vs Past Continuous", "Quá khứ đơn vs Quá khứ tiếp diễn", "A2", "Các Thì"),
    ("present_perfect_experience", "Present Perfect (Experience/Result)", "Hiện tại hoàn thành (trải nghiệm/kết quả)", "A2", "Các Thì"),
    ("present_perfect_vs_past_simple", "Present Perfect vs Past Simple", "Hiện tại hoàn thành vs Quá khứ đơn", "A2", "Các Thì"),
    ("will_vs_going_to", "Will vs Be Going To", "Will vs Be Going To", "A2", "Tương lai"),
    ("present_continuous_future", "Present Continuous for Future", "Hiện tại tiếp diễn diễn tả tương lai", "A2", "Tương lai"),
    ("comparatives", "Comparatives", "So sánh hơn", "A2", "So sánh"),
    ("superlatives_as_as", "Superlatives & As...As", "So sánh nhất & As...As", "A2", "So sánh"),
    ("too_enough", "Too & Enough", "Too & Enough", "A2", "So sánh"),
    ("modals_obligation", "Must/Have To/Should", "Must/Have To/Should", "A2", "Modal"),
    ("may_might_permission", "May/Might & Permission", "May/Might & Xin phép", "A2", "Modal"),
    ("quantifiers", "Much/Many/A lot/A few/A little", "Lượng từ", "A2", "Lượng từ"),
    ("some_any_no_every_compounds", "Some/Any/No/Every + Compounds", "Some/Any/No/Every & từ ghép", "A2", "Lượng từ"),
    ("prepositions_movement", "Prepositions of Movement", "Giới từ chỉ chuyển động", "A2", "Giới từ"),
    ("gerunds_infinitives_basic", "Gerunds & Infinitives (Basic)", "Danh động từ & động từ nguyên mẫu", "A2", "Động từ"),
    ("question_tags_adverbs_manner", "Question Tags & Adverbs of Manner", "Câu hỏi đuôi & trạng từ chỉ cách thức", "A2", "Câu hỏi & Trạng từ"),
    ("defining_relative_clauses", "Defining Relative Clauses", "Mệnh đề quan hệ xác định", "A2", "Mệnh đề"),
    ("first_conditional_used_to", "First Conditional & Used To", "Câu điều kiện loại 1 & Used To", "A2", "Điều kiện & Quá khứ"),

    # ── B1 (20) ──────────────────────────────────────────────────────────
    ("present_perfect_continuous", "Present Perfect Continuous", "Hiện tại hoàn thành tiếp diễn", "B1", "Các Thì"),
    ("present_perfect_simple_vs_continuous", "Present Perfect Simple vs Continuous", "Hiện tại hoàn thành vs tiếp diễn", "B1", "Các Thì"),
    ("past_perfect", "Past Perfect", "Quá khứ hoàn thành", "B1", "Các Thì"),
    ("past_perfect_vs_past_simple", "Past Perfect vs Past Simple", "Quá khứ hoàn thành vs Quá khứ đơn", "B1", "Các Thì"),
    ("future_continuous", "Future Continuous", "Tương lai tiếp diễn", "B1", "Tương lai"),
    ("future_perfect", "Future Perfect", "Tương lai hoàn thành", "B1", "Tương lai"),
    ("second_conditional", "Second Conditional", "Câu điều kiện loại 2", "B1", "Điều kiện"),
    ("first_vs_second_conditional", "First vs Second Conditional", "Điều kiện loại 1 vs 2", "B1", "Điều kiện"),
    ("third_conditional", "Third Conditional", "Câu điều kiện loại 3", "B1", "Điều kiện"),
    ("mixed_conditionals", "Mixed Conditionals", "Câu điều kiện hỗn hợp", "B1", "Điều kiện"),
    ("passive_present_past", "Passive Voice: Present/Past", "Bị động hiện tại/quá khứ", "B1", "Bị động"),
    ("passive_perfect_future_modals", "Passive: Perfect/Future/Modals", "Bị động hoàn thành/tương lai/modal", "B1", "Bị động"),
    ("reported_speech", "Reported Speech", "Câu tường thuật", "B1", "Tường thuật"),
    ("relative_clauses_defining_non_defining", "Relative Clauses: Defining & Non-defining", "Mệnh đề quan hệ xác định/không xác định", "B1", "Mệnh đề"),
    ("relative_clauses_whose_where_when", "Relative Clauses: Whose/Where/When", "Mệnh đề quan hệ với whose/where/when", "B1", "Mệnh đề"),
    ("modals_deduction_present", "Modals of Deduction (Present)", "Modal suy đoán hiện tại", "B1", "Modal"),
    ("modals_obligation_past", "Modals of Obligation/Advice (Past)", "Modal nghĩa vụ/lời khuyên quá khứ", "B1", "Modal"),
    ("gerunds_infinitives_advanced", "Gerunds vs Infinitives (Advanced)", "Danh động từ vs nguyên mẫu nâng cao", "B1", "Động từ"),
    ("causative_have_get", "Causative Have/Get Something Done", "Câu sai khiến", "B1", "Cấu trúc"),
    ("wish_if_only_present", "Wish/If Only (Present)", "Wish/If Only hiện tại", "B1", "Ước"),

    # ── B2 (20) ──────────────────────────────────────────────────────────
    ("future_in_the_past", "Future in the Past", "Tương lai trong quá khứ", "B2", "Các Thì"),
    ("narrative_tenses_review", "Narrative Tenses Review", "Ôn tập các thì tự sự", "B2", "Các Thì"),
    ("past_perfect_continuous", "Past Perfect Continuous", "Quá khứ hoàn thành tiếp diễn", "B2", "Các Thì"),
    ("passive_reporting_impersonal", "Passive with Reporting Verbs & Impersonal Passive", "Bị động với động từ tường thuật & bị động khách quan", "B2", "Bị động"),
    ("advanced_conditionals", "Advanced Conditionals (Unless/Provided/As long as)", "Điều kiện nâng cao", "B2", "Điều kiện"),
    ("wish_if_only_past", "Wish/If Only (Past)", "Wish/If Only quá khứ", "B2", "Ước"),
    ("its_time_high_time", "It's Time/It's High Time", "It's Time/It's High Time", "B2", "Cấu trúc"),
    ("modal_perfects", "Modal Perfects", "Modal hoàn thành", "B2", "Modal"),
    ("speculation_deduction_past", "Speculation & Deduction (Past)", "Suy đoán quá khứ", "B2", "Modal"),
    ("advanced_relative_clauses", "Advanced Relative Clauses (Preposition + Which/Whom)", "Mệnh đề quan hệ nâng cao", "B2", "Mệnh đề"),
    ("reduced_relative_clauses", "Reduced Relative Clauses", "Mệnh đề quan hệ rút gọn", "B2", "Mệnh đề"),
    ("participle_clauses", "Participle Clauses", "Mệnh đề phân từ", "B2", "Mệnh đề"),
    ("gerund_infinitive_nuances", "Gerund/Infinitive Nuances", "Sắc thái gerund/infinitive", "B2", "Động từ"),
    ("inversion_negative_adverbials", "Inversion with Negative Adverbials", "Đảo ngữ với trạng từ phủ định", "B2", "Đảo ngữ"),
    ("cleft_sentences", "Cleft Sentences", "Câu chẻ", "B2", "Nhấn mạnh"),
    ("subjunctive", "Subjunctive (Suggest/Insist/It is essential)", "Thức giả định", "B2", "Thức giả định"),
    ("articles_advanced", "Articles Advanced", "Mạo từ nâng cao", "B2", "Danh từ & Mạo từ"),
    ("quantifiers_advanced", "Quantifiers Advanced", "Lượng từ nâng cao", "B2", "Lượng từ"),
    ("linking_words_advanced", "Linking Words Advanced", "Liên từ nâng cao", "B2", "Liên từ"),
    ("ellipsis_substitution", "Ellipsis & Substitution", "Tỉnh lược & thay thế", "B2", "Cấu trúc"),

    # ── C1 (10) ──────────────────────────────────────────────────────────
    ("advanced_inversion", "Advanced Inversion", "Đảo ngữ nâng cao", "C1", "Đảo ngữ"),
    ("cleft_emphasis", "Cleft Sentences & Emphasis", "Câu chẻ & nhấn mạnh", "C1", "Nhấn mạnh"),
    ("subjunctive_formal", "Subjunctive & Formal Structures", "Giả định & cấu trúc trang trọng", "C1", "Thức giả định"),
    ("advanced_passive", "Advanced Passive Constructions", "Bị động nâng cao", "C1", "Bị động"),
    ("nominalisation", "Nominalisation", "Danh từ hóa", "C1", "Cấu trúc"),
    ("participle_reduced_advanced", "Participle & Reduced Relative Clauses (Advanced)", "Phân từ & mệnh đề quan hệ rút gọn nâng cao", "C1", "Mệnh đề"),
    ("advanced_conditionals_hypothetical", "Advanced Conditionals & Hypothetical Past", "Điều kiện nâng cao & quá khứ giả định", "C1", "Điều kiện"),
    ("modal_perfects_speculation", "Modal Perfects & Advanced Speculation", "Modal hoàn thành & suy đoán nâng cao", "C1", "Modal"),
    ("discourse_cohesion", "Discourse Markers & Cohesion", "Dấu hiệu diễn ngôn & liên kết", "C1", "Diễn ngôn"),
    ("complex_noun_phrases", "Complex Noun Phrases & Determiners", "Cụm danh từ phức & từ hạn định", "C1", "Danh từ"),

    # ── C2 (10) ──────────────────────────────────────────────────────────
    ("inversion_focus_mastery", "Inversion & Focus Mastery", "Đảo ngữ & nhấn mạnh chuyên sâu", "C2", "Đảo ngữ"),
    ("advanced_cleft_focus", "Advanced Cleft & Focus Structures", "Câu chẻ & cấu trúc nhấn mạnh nâng cao", "C2", "Nhấn mạnh"),
    ("subjunctive_archaic_formal", "Subjunctive, Archaic & Formal Structures", "Giả định, cổ ngữ & trang trọng", "C2", "Thức giả định"),
    ("complex_counterfactuals", "Complex Conditionals & Counterfactuals", "Điều kiện phức & phản thực", "C2", "Điều kiện"),
    ("advanced_modality_hedging", "Advanced Modality & Hedging", "Modal nâng cao & rào đón", "C2", "Modal"),
    ("nominalisation_academic", "Nominalisation & Academic Style", "Danh từ hóa & văn phong học thuật", "C2", "Cấu trúc"),
    ("advanced_cohesion_discourse", "Advanced Cohesion & Discourse", "Liên kết & diễn ngôn nâng cao", "C2", "Diễn ngôn"),
    ("ellipsis_formal", "Ellipsis & Substitution in Formal Texts", "Tỉnh lược & thay thế trong văn bản trang trọng", "C2", "Cấu trúc"),
    ("idiomatic_grammar", "Idiomatic Grammar & Fixed Expressions", "Ngữ pháp thành ngữ & cụm cố định", "C2", "Thành ngữ"),
    ("register_style_precision", "Register, Style & C2 Precision", "Phong cách & độ chính xác C2", "C2", "Phong cách"),
]


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    data = [
        {
            "id": lid,
            "title": title,
            "title_vi": title_vi,
            "level": level,
            "category": category,
        }
        for lid, title, title_vi, level, category in LESSONS
    ]
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    counts: dict[str, int] = {}
    for item in data:
        counts[item["level"]] = counts.get(item["level"], 0) + 1
    print(f"Wrote {len(data)} lessons to {OUT}")
    for level in ("A1", "A2", "B1", "B2", "C1", "C2"):
        print(f"  {level}: {counts.get(level, 0)}")


if __name__ == "__main__":
    main()
