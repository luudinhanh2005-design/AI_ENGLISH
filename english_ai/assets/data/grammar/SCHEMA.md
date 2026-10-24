# Grammar content schema (A1–C2)

You are generating data for a Flutter grammar feature. The app expects a **JSON array** of lesson objects. No markdown fences, no comments, valid UTF-8 JSON.

## Source of truth

- Read `english_ai/assets/data/grammar/curriculum.json`.
- Each lesson has an exact `id`, `title`, `title_vi`, `level`, `category` to reuse.
- Do **not** invent new ids, rename titles, or change levels.

## Required lesson object

```json
{
  "id": "present_simple",
  "title": "Present Simple",
  "title_vi": "Thì Hiện Tại Đơn",
  "level": "A1",
  "category": "Các Thì",
  "description": "Diễn tả thói quen, sự thật hiển nhiên và lịch trình cố định.",
  "formula_affirmative": "S + V(s/es) + O",
  "formula_negative": "S + do/does not + V + O",
  "formula_question": "Do/Does + S + V + O?",
  "time_markers": [
    "always / usually / often / sometimes / never",
    "every day / every week / on Mondays",
    "in the morning / at night"
  ],
  "usage_rules": [
    "Dùng cho thói quen lặp đi lặp lại.",
    "Dùng cho sự thật hiển nhiên hoặc chân lý.",
    "Dùng cho lịch trình, thời gian biểu cố định."
  ],
  "examples": [
    {
      "english": "I study English every evening.",
      "vietnamese": "Tôi học tiếng Anh mỗi tối.",
      "note": "Thói quen hằng ngày."
    },
    {
      "english": "Water boils at 100 degrees Celsius.",
      "vietnamese": "Nước sôi ở 100 độ C.",
      "note": "Sự thật hiển nhiên."
    },
    {
      "english": "The train leaves at 8 a.m.",
      "vietnamese": "Tàu khởi hành lúc 8 giờ sáng.",
      "note": "Lịch trình cố định."
    }
  ],
  "common_mistakes": [
    "Thêm -s sai: 'He go' → 'He goes'.",
    "Dùng do với ngôi thứ ba: 'Does he goes?' → 'Does he go?'.",
    "Quên trạng từ tần suất đúng vị trí: 'I always am happy' → 'I am always happy'."
  ],
  "quiz": [
    {
      "question": "She _____ to school every day.",
      "options": ["go", "goes", "going", "gone"],
      "correct_index": 1,
      "explanation": "Chủ ngữ 'She' ngôi thứ ba số ít nên động từ thêm -es: goes."
    },
    {
      "question": "They _____ coffee in the morning.",
      "options": ["drinks", "drink", "drinking", "drank"],
      "correct_index": 1,
      "explanation": "Chủ ngữ 'They' số nhiều nên dùng động từ nguyên mẫu 'drink'."
    },
    {
      "question": "_____ he play football?",
      "options": ["Do", "Does", "Is", "Are"],
      "correct_index": 1,
      "explanation": "Câu hỏi với chủ ngữ ngôi thứ ba số ít dùng 'Does'."
    },
    {
      "question": "My sister _____ TV every evening.",
      "options": ["watch", "watches", "watching", "watched"],
      "correct_index": 1,
      "explanation": "'My sister' là ngôi thứ ba số ít nên thêm -es: watches."
    },
    {
      "question": "We _____ not work on Sundays.",
      "options": ["do", "does", "are", "is"],
      "correct_index": 0,
      "explanation": "Chủ ngữ 'We' dùng trợ động từ 'do' ở câu phủ định."
    }
  ]
}
```

## Rules

- `description`: 2–3 câu tiếng Việt, nêu mục đích sử dụng.
- `formula_*`: công thức tiếng Anh, ngắn gọn; có thể kèm ghi chú tiếng Việt trong ngoặc.
- `time_markers`: **3–6** mục, mỗi mục là dấu hiệu/từ khóa kèm nghĩa tiếng Việt.
- `usage_rules`: **3–5** mục, tiếng Việt, cụ thể.
- `examples`: **3–5** mục; mỗi mục có `english`, `vietnamese`, `note` (có thể rỗng nhưng nên có).
- `common_mistakes`: **3–5** mục, tiếng Việt, nêu lỗi sai + cách sửa.
- `quiz`: **đúng 5 câu**; mỗi câu có **đúng 4 lựa chọn**, `correct_index` từ 0 đến 3, `explanation` tiếng Việt.
- Không trùng câu hỏi trong cùng bài.
- Nội dung phải đúng ngữ pháp, phù hợp level.
- A1/A2 dùng câu đơn giản; B1/B2 trung bình; C1/C2 nâng cao, học thuật.
- Không dùng markdown trong JSON.
- File phải là một array JSON hợp lệ, ví dụ:
  `[ { ... }, { ... } ]`

## Validation

Run after writing:

```bash
python -c "import json; d=json.load(open('english_ai/assets/data/grammar/a1.json', encoding='utf-8')); print(len(d))"
```

If the file is large, write it in one go; do not leave placeholders.
