"""Targeted content fixes from the grammar QA pass.

Run once from the repository root:
    python scripts/fix_grammar_content.py

The script asserts the expected original values before changing anything so it
cannot silently overwrite a different revision.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "english_ai" / "assets" / "data" / "grammar"


def load(level: str):
    return json.loads((DATA / f"{level}.json").read_text(encoding="utf-8"))


def save(level: str, data) -> None:
    (DATA / f"{level}.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def lesson(data, lesson_id: str):
    return next(item for item in data if item["id"] == lesson_id)


def replace_question(quiz_item: dict, question: str, explanation: str) -> None:
    quiz_item["question"] = question
    quiz_item["explanation"] = explanation


# Idempotency guard: the first fix is the C1 negative-inversion formula.
_existing_c1 = load("c1")
_existing_inversion = lesson(_existing_c1, "advanced_inversion")
if "+ S + not + V" not in _existing_inversion["formula_negative"]:
    print("Grammar content fixes already applied; nothing to do.")
    raise SystemExit(0)


# ── C1: advanced inversion ────────────────────────────────────────────────
c1 = load("c1")
advanced_inversion = lesson(c1, "advanced_inversion")
assert "+ S + not + V" in advanced_inversion["formula_negative"]
advanced_inversion["formula_negative"] = (
    "Rarely/Seldom/At no time + auxiliary + S + V "
    "(Rarely does he ever complain.)"
)
advanced_inversion["formula_question"] = (
    "Had + S + V3, ...? | Were + S + to + V, ...? | Should + S + V, ...? "
    "(Had he objected, would the motion have passed?)"
)
q1 = advanced_inversion["quiz"][0]
assert q1["options"][3] == "did I read"
q1["options"][3] = "I did read"
save("c1", c1)

# ── C1: remove an ambiguous participle distractor ─────────────────────────
c1 = load("c1")
participle = lesson(c1, "participle_reduced_advanced")
pq1 = participle["quiz"][0]
assert pq1["options"][1] == "Analysing"
pq1["options"][1] = "Analyse"
save("c1", c1)

# ── A2: make the indefinite-compound item unambiguous ─────────────────────
a2 = load("a2")
compounds = lesson(a2, "some_any_no_every_compounds")
cq5 = compounds["quiz"][4]
assert cq5["question"] == "_____ in my class likes football."
replace_question(
    cq5,
    "_____ in my class likes football, but I can't remember who.",
    "Câu khẳng định cần đại từ chỉ người làm chủ ngữ; "
    "'Somebody' hợp nghĩa với 'I can't remember who'.",
)
save("a2", a2)

# ── B1: replace duplicated relative-clause examples/questions ─────────────
b1 = load("b1")
relative = lesson(b1, "relative_clauses_defining_non_defining")
assert relative["examples"][0]["english"] == "The man who lives next door is a doctor."
assert relative["examples"][1]["english"] == "This is the book which I told you about."
relative["examples"][0] = {
    "english": "The scientist who discovered the vaccine won a prestigious award.",
    "vietnamese": "Nhà khoa học người đã phát hiện ra vắc-xin đã giành được một giải thưởng danh giá.",
    "note": "Mệnh đề xác định, 'who' thay cho 'the scientist'.",
}
relative["examples"][1] = {
    "english": "My neighbour, who is a retired teacher, volunteers at the library.",
    "vietnamese": "Người hàng xóm của tôi, một giáo viên đã nghỉ hưu, làm tình nguyện tại thư viện.",
    "note": "Mệnh đề không xác định, đặt giữa hai dấu phẩy.",
}
if len(relative["examples"]) < 5:
    relative["examples"].append(
        {
            "english": "The film, which we watched last night, was boring.",
            "vietnamese": "Bộ phim mà chúng tôi xem tối qua thật nhàm chán.",
            "note": "Mệnh đề không xác định; không dùng 'that' sau dấu phẩy.",
        }
    )

rq1 = relative["quiz"][0]
assert rq1["question"] == "The man _____ lives next door is a doctor."
rq1["question"] = "The scientist _____ discovered the vaccine won a prestigious award."
rq1["options"] = ["which", "who", "whose", "where"]
rq1["correct_index"] = 1
rq1["explanation"] = "'The scientist' chỉ người và làm chủ ngữ nên dùng 'who'."

rq2 = relative["quiz"][1]
assert rq2["question"] == "This is the book _____ I told you about."
rq2["question"] = "My neighbour, _____ is a retired teacher, volunteers at the library."
rq2["options"] = ["who", "which", "whose", "where"]
rq2["correct_index"] = 0
rq2["explanation"] = (
    "Mệnh đề không xác định bổ sung thông tin cho 'my neighbour' (người), "
    "dùng 'who' và đặt giữa hai dấu phẩy."
)

rq4 = relative["quiz"][3]
assert rq4["question"] == "The film _____ we watched was boring."
rq4["question"] = "The film, _____ we watched last night, was boring."
rq4["options"] = ["that", "who", "which", "whose"]
rq4["correct_index"] = 2
rq4["explanation"] = (
    "Mệnh đề không xác định sau dấu phẩy không dùng 'that'; "
    "dùng 'which' cho vật."
)

# ── B1: disambiguate present perfect vs past simple ───────────────────────
present_perfect = lesson(b1, "present_perfect_simple_vs_continuous")
pp_q2 = present_perfect["quiz"][1]
assert pp_q2["question"] == "She _____ three emails this morning."
replace_question(
    pp_q2,
    "She _____ three emails so far this morning.",
    "Cụm 'so far this morning' chỉ khoảng thời gian chưa kết thúc nên dùng "
    "hiện tại hoàn thành; 'wrote' không hợp với 'so far'.",
)
pp_q4 = present_perfect["quiz"][3]
assert pp_q4["question"] == "How many pages _____ you read?"
replace_question(
    pp_q4,
    "How many pages _____ you read so far?",
    "Hỏi số lượng với 'so far' dùng hiện tại hoàn thành; "
    "trợ động từ 'have' đi với 'you'.",
)

# ── B1: disambiguate passive present vs past ──────────────────────────────
passive = lesson(b1, "passive_present_past")
passive_q5 = passive["quiz"][4]
assert passive_q5["question"] == "_____ the cake made by your mother?"
replace_question(
    passive_q5,
    "_____ the cake made by your mother yesterday?",
    "Câu hỏi bị động quá khứ với chủ ngữ số ít 'the cake' và trạng ngữ "
    "'yesterday' dùng 'Was'.",
)
save("b1", b1)

# ── B2: remove ambiguous options ──────────────────────────────────────────
b2 = load("b2")
conditionals = lesson(b2, "advanced_conditionals")
cond_q4 = conditionals["quiz"][3]
assert cond_q4["options"] == ["if", "unless", "in case", "provided"]
cond_q4["options"] = ["whether", "unless", "in case", "despite"]
cond_q4["correct_index"] = 2

articles = lesson(b2, "articles_advanced")
art_q2 = articles["quiz"][1]
assert art_q2["options"] == ["The", "A", "An", "(no article)"]
art_q2["options"] = ["Every", "A", "An", "(no article)"]
art_q2["correct_index"] = 3
art_q2["explanation"] = (
    "Nói chung về một loài dùng danh từ số nhiều không mạo từ; "
    "'Every' không đi với danh từ số nhiều."
)
save("b2", b2)

# ── C2: fix malformed revision item and cleft distractor ──────────────────
c2 = load("c2")
register = lesson(c2, "register_style_precision")
reg_q5 = register["quiz"][4]
assert reg_q5["question"] == "Which revision removes redundancy while preserving formality?"
replace_question(
    reg_q5,
    'Which revision of "In my opinion, I think the policy failed" '
    "removes redundancy while preserving formality?",
    "'In my view' đã bao hàm ý kiến cá nhân nên không cần thêm 'I think' "
    "hay 'in my opinion'.",
)

cleft = lesson(c2, "advanced_cleft_focus")
cleft_q4 = cleft["quiz"][3]
assert cleft_q4["options"][2] == "where"
cleft_q4["options"][2] = "whom"
cleft_q4["explanation"] = (
    "It-cleft với trạng ngữ chỉ nơi chốn dùng 'that'; "
    "'whom' chỉ người nên không hợp."
)
save("c2", c2)

print("Applied grammar content fixes.")
