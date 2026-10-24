# IELTS Mock Test — Data & API Contract (v1)

> Mọi agent phải code đúng hợp đồng này. Không tự đổi tên field.
> Nội dung đề nằm trong `backend/app/data/ielts_mock/<set_id>/`.

---

## 1. Cấu trúc nội dung đề

Mỗi bộ đề là 1 thư mục:

```
backend/app/data/ielts_mock/academic_01/
  meta.json
  listening.json
  reading.json
  writing.json
  speaking.json
```

`meta.json`

```json
{
  "id": "academic_01",
  "type": "academic",
  "title": "IELTS Academic Mock Test 01",
  "description": "Full 4-skill mock test",
  "version": 1,
  "skills": ["listening", "reading", "writing", "speaking"]
}
```

`type`: `academic` | `general`.

### 1.1 listening.json

```json
{
  "duration_seconds": 1800,
  "review_seconds": 120,
  "parts": [
    {
      "id": "L1",
      "title": "Part 1",
      "audio_url": "/api/v1/speech/audio/ielts_academic_01_part1.mp3",
      "transcript": "Full script with speaker labels...",
      "instructions": "Questions 1–10. Complete the notes below. Write ONE WORD AND/OR A NUMBER for each answer.",
      "groups": [
        {
          "id": "L1-G1",
          "type": "form_completion",
          "instructions": "Complete the booking form below.",
          "options": [],
          "questions": [
            {
              "id": "L1-1",
              "number": 1,
              "prompt": "Name of guest: ______",
              "answer": ["Sarah Whitfield"],
              "alternatives": ["Sarah"],
              "explanation": "Người gọi tự giới thiệu: 'My name is Sarah Whitfield.'"
            }
          ]
        }
      ]
    }
  ]
}
```

`type` của group: `form_completion` | `note_completion` | `sentence_completion` |
`mcq` | `matching` | `map_labelling` | `short_answer`.

- `mcq`/`matching`: `options: [{"key":"A","text":"..."}]`; `answer` là key.
- Completion: `prompt` chứa chỗ trống `______`; `answer` là list các đáp án được chấp nhận (phần tử đầu là đáp án chính).
- Mỗi part đúng 10 câu, tổng 40 câu, `number` từ 1 đến 40 liên tục.

### 1.2 reading.json

```json
{
  "duration_seconds": 3600,
  "passages": [
    {
      "id": "R1",
      "title": "Passage 1",
      "text": "Paragraph 1...\n\nParagraph 2...",
      "instructions": "You should spend about 20 minutes on Questions 1–13.",
      "groups": [
        {
          "id": "R1-G1",
          "type": "tfng",
          "instructions": "Do the following statements agree with the information given in the passage?",
          "options": [],
          "questions": [
            {
              "id": "R1-1",
              "number": 1,
              "prompt": "Statement ...",
              "answer": ["TRUE"],
              "alternatives": ["T", "YES", "Y"],
              "explanation": "..."
            }
          ]
        }
      ]
    }
  ]
}
```

`type`: `tfng` | `ynng` | `mcq` | `matching_headings` | `matching_information` |
`summary_completion` | `sentence_completion` | `short_answer`.

- Tổng 40 câu, `number` 1–40.
- Academic: 3 passages. General: 3 sections (Section 1 có thể gồm 2 văn bản ngắn — gộp vào 1 passage với `text` nối bằng tiêu đề phụ).

### 1.3 writing.json

```json
{
  "duration_seconds": 3600,
  "tasks": [
    {
      "id": "W1",
      "task": 1,
      "min_words": 150,
      "recommended_minutes": 20,
      "prompt": "The chart below shows ... Summarise the information ...",
      "visual": {
        "type": "bar_chart",
        "title": "Percentage of households with internet access",
        "description": "Mô tả dữ liệu / bảng số liệu dạng text để hiển thị.",
        "data": [
          {"label": "2010", "value": "45%"},
          {"label": "2020", "value": "88%"}
        ]
      },
      "guidance": ["Giới thiệu biểu đồ", "So sánh số liệu chính", "Nêu xu hướng"],
      "sample_answer": "Band 8 sample answer ..."
    }
  ]
}
```

- Academic Task 1: biểu đồ/bảng/quy trình/bản đồ (`visual.type`).
- General Task 1: lá thư; `visual` có thể `null`.
- Task 2 (`id: "W2"`) luôn là essay, `min_words: 250`, `recommended_minutes: 40`.
- `sample_answer` chỉ dùng cho review, **không gửi xuống client trước khi nộp**.

### 1.4 speaking.json

```json
{
  "duration_seconds": 840,
  "part1": {
    "topics": [
      {
        "id": "P1-T1",
        "topic": "Hometown",
        "questions": ["Where is your hometown?", "...", "...", "..."]
      }
    ]
  },
  "part2": {
    "cue_card": "Describe a skill you learned that was difficult at first.",
    "prompts": ["What the skill was", "When and how you learned it", "Why it was difficult", "How you feel about it now"],
    "prep_seconds": 60,
    "speak_seconds": 120,
    "follow_ups": ["Is this skill common in your country?", "Would you recommend it to others?"]
  },
  "part3": {
    "questions": ["...", "...", "...", "..."]
  }
}
```

- Part 1: 3 topics, mỗi topic 4 câu.
- Part 2: 4 prompts + 2 follow-ups.
- Part 3: 6 câu hỏi thảo luận.

---

## 2. API

Base: `/api/v1/mock-tests`. Tất cả endpoint dùng `get_optional_user` (cho phép khách).

### GET /mock-tests

Trả `[{id,type,title,description,duration_minutes,skills}]`.

### GET /mock-tests/{set_id}

Trả đề đã **sanitize** (bỏ `answer`, `alternatives`, `explanation`, `transcript`, `sample_answer`):

```json
{
  "id": "academic_01",
  "type": "academic",
  "title": "...",
  "description": "...",
  "skills": ["listening", "reading", "writing", "speaking"],
  "sections": {
    "listening": {"duration_seconds": 1800, "review_seconds": 120, "parts": [...]},
    "reading": {"duration_seconds": 3600, "passages": [...]},
    "writing": {"duration_seconds": 3600, "tasks": [...]},
    "speaking": {"duration_seconds": 840, "part1": {...}, "part2": {...}, "part3": {...}}
  }
}
```

### POST /mock-tests/attempts

Body: `{"set_id": "academic_01", "mode": "strict"}` (`strict` | `practice`).

```json
{
  "attempt_id": "uuid",
  "set_id": "academic_01",
  "mode": "strict",
  "started_at": "2026-10-24T10:00:00Z",
  "sections": [
    {"skill": "listening", "duration_seconds": 1800, "status": "pending"}
  ]
}
```

### PATCH /mock-tests/attempts/{attempt_id}

Body: `{"skill": "reading", "answers": {"R1-1": "TRUE"}, "flagged": ["R1-3"], "remaining_seconds": 2400}`

Trả `{"ok": true}`. Lưu `answers[skill]`, `flagged[skill]`, `section_started_at[skill]`.

### POST /mock-tests/attempts/{attempt_id}/sections/{skill}/submit

`skill` ∈ `listening|reading|writing|speaking`.

- Listening/Reading body: `{"answers": {"L1-1": "A"}}`
- Writing body: `{"answers": {"W1": "...", "W2": "..."}}`
- Speaking body: `{"part1_qa": [{"question": "...", "answer": "..."}], "part2_answer": "...", "part3_qa": [{"question": "...", "answer": "..."}], "follow_up_qa": [{"question": "...", "answer": "..."}]}`

Trả unified `SectionScore`:

```json
{
  "skill": "listening",
  "band": 6.5,
  "raw_score": 28,
  "total": 40,
  "criteria": {},
  "comment": "...",
  "details": [
    {"question_id": "L1-1", "number": 1, "user_answer": "B", "correct_answer": "A", "is_correct": false, "explanation": "..."}
  ],
  "strengths": [],
  "improvements": [],
  "corrections": [],
  "extra": {}
}
```

Writing/Speaking: `criteria` chứa 4 tiêu chí (`task_achievement`, `coherence`, `lexical`, `grammar`; hoặc `fluency`, `lexical`, `grammar`, `pronunciation`), `details: []`.

### POST /mock-tests/attempts/{attempt_id}/complete

Trả:

```json
{
  "attempt_id": "uuid",
  "overall_band": 6.5,
  "skills": {"listening": {SectionScore}, "reading": {...}, "writing": {...}, "speaking": {...}},
  "xp_awarded": 200,
  "completed_at": "..."
}
```

### GET /mock-tests/attempts

Trả lịch sử (mới nhất trước):

```json
[{"attempt_id":"...","set_id":"academic_01","title":"...","type":"academic","mode":"strict","status":"completed","overall_band":6.5,"completed_at":"...","skills":{"listening":6.5,"reading":6.0,"writing":6.5,"speaking":6.5}}]
```

### GET /mock-tests/attempts/{attempt_id}

Trả chi tiết đầy đủ: attempt + `sections` (đề sanitize) + `scores` + `review` (chỉ có sau khi section đã nộp).

---

## 3. Quy tắc chấm

### 3.1 Chuẩn hóa đáp án (backend)

- trim, lowercase, gộp khoảng trắng.
- Bỏ dấu câu hai đầu; giữ `-` và `'`.
- So khớp với `answer` + `alternatives`.
- TFNG/YNNG: `true|t|yes|y` → TRUE; `false|f|no|n` → FALSE; `not given|ng|notgiven|not-mentioned` → NOT GIVEN. YNNG dùng YES/NO/NOT GIVEN.
- MCQ/matching: so sánh key (`A`) hoặc text option đã chuẩn hóa.

### 3.2 Bảng band

Listening:

| Raw | Band |
|---|---|
| 39–40 | 9.0 |
| 37–38 | 8.5 |
| 35–36 | 8.0 |
| 32–34 | 7.5 |
| 30–31 | 7.0 |
| 26–29 | 6.5 |
| 23–25 | 6.0 |
| 18–22 | 5.5 |
| 16–17 | 5.0 |
| 13–15 | 4.5 |
| 10–12 | 4.0 |
| 8–9 | 3.5 |
| 6–7 | 3.0 |
| 4–5 | 2.5 |
| 0–3 | 2.0 |

Academic Reading:

| Raw | Band |
|---|---|
| 39–40 | 9.0 |
| 37–38 | 8.5 |
| 35–36 | 8.0 |
| 33–34 | 7.5 |
| 30–32 | 7.0 |
| 27–29 | 6.5 |
| 23–26 | 6.0 |
| 19–22 | 5.5 |
| 15–18 | 5.0 |
| 13–14 | 4.5 |
| 10–12 | 4.0 |
| 8–9 | 3.5 |
| 6–7 | 3.0 |
| 4–5 | 2.5 |
| 0–3 | 2.0 |

General Reading:

| Raw | Band |
|---|---|
| 40 | 9.0 |
| 39 | 8.5 |
| 37–38 | 8.0 |
| 36 | 7.5 |
| 34–35 | 7.0 |
| 32–33 | 6.5 |
| 30–31 | 6.0 |
| 27–29 | 5.5 |
| 23–26 | 5.0 |
| 19–22 | 4.5 |
| 15–18 | 4.0 |
| 12–14 | 3.5 |
| 8–11 | 3.0 |
| 5–7 | 2.5 |
| 0–4 | 2.0 |

### 3.3 Overall

`overall = round_to_half(mean(4 skills))`:
- phần lẻ `.25` → lên `.5`
- `.75` → lên số nguyên kế tiếp
- `.0`/`.5` giữ nguyên

### 3.4 Writing (AI)

4 tiêu chí mỗi task, band 0–9 bước 0.5:
- Task 1: `task_achievement`, `coherence`, `lexical`, `grammar`
- Task 2: `task_response`, `coherence`, `lexical`, `grammar`
- Band task = trung bình 4 tiêu chí, làm tròn 0.5.
- Band Writing = `(Task1 + Task2 * 2) / 3`, làm tròn 0.5.
- Fallback heuristic khi LLM lỗi: word count, số đoạn, cohesive devices, đa dạng từ, độ dài câu; trả band ước tính + comment.

### 3.5 Speaking (AI)

4 tiêu chí: `fluency`, `lexical`, `grammar`, `pronunciation`; band = trung bình, làm tròn 0.5.

---

## 4. Quy tắc UI (strict vs practice)

| Hành vi | strict | practice |
|---|---|---|
| Tạm dừng | Không | Có |
| Quay lại section trước | Không | Có |
| Nghe lại audio | Không (1 lần/part) | Có |
| Hiện đáp án mẫu / gợi ý | Không | Có |
| Speaking gõ text thay nói | Không | Có |
| Kết quả | Band thi thử | Ghi nhãn "Band ước tính – luyện tập" |

- Timer tính từ `started_at` + `duration_seconds` do server trả; app background/reload không được reset.
- Hết giờ: tự nộp section hiện tại.
- Không gửi answer key xuống client trước khi nộp.

---

## 5. File ownership (tránh conflict)

| Nhóm | Được tạo/sửa |
|---|---|
| Backend core | `backend/app/models/mock_test.py`, `backend/app/schemas/mock_test.py`, `backend/app/services/mock_test_service.py`, `backend/app/api/v1/mock_tests.py`, `backend/migrations/versions/0003_mock_tests.py`, `backend/tests/test_mock_test_service.py`, `backend/app/models/__init__.py`, `backend/app/api/v1/router.py` |
| Backend AI/audio | `backend/app/services/ielts_writing_service.py`, `scripts/generate_listening_audio.py`, `scripts/validate_mock_content.py` |
| Content | `backend/app/data/ielts_mock/**` |
| Flutter core | `english_ai/lib/features/mock_test/data/**`, `presentation/providers/**`, `presentation/screens/{hub,intro,runner,result,history}_screen.dart`, `presentation/widgets/{exam_timer_bar,question_navigator,section_bridge}.dart` |
| Flutter L&R | `english_ai/lib/features/mock_test/presentation/sections/{listening,reading}_section.dart`, `presentation/widgets/{exam_audio_player,passage_panel,question_renderer}.dart` |
| Flutter W&S | `english_ai/lib/features/mock_test/presentation/sections/{writing,speaking}_section.dart` |
| Orchestrator | `english_ai/lib/core/constants/api_endpoints.dart`, `english_ai/lib/core/router/app_router.dart`, các điểm vào home/practice/profile, `pubspec.yaml`, tài liệu |

Không ai được sửa file ngoài danh sách của mình.

---

## 6. Constructor contract cho section widgets (Flutter)

```dart
class ListeningSectionView extends StatefulWidget {
  const ListeningSectionView({
    super.key,
    required this.section,
    required this.answers,
    required this.flagged,
    required this.onAnswer,
    required this.onToggleFlag,
    required this.onRequestSubmit,
    required this.strict,
  });
}

class ReadingSectionView extends StatefulWidget {
  const ReadingSectionView({
    super.key,
    required this.section,
    required this.answers,
    required this.flagged,
    required this.onAnswer,
    required this.onToggleFlag,
    required this.onRequestSubmit,
  });
}

class WritingSectionView extends StatefulWidget {
  const WritingSectionView({
    super.key,
    required this.section,
    required this.answers,      // "W1"/"W2" -> text
    required this.onAnswer,     // (taskId, text)
    required this.onRequestSubmit,
    required this.strict,
  });
}

class SpeakingSectionView extends StatefulWidget {
  const SpeakingSectionView({
    super.key,
    required this.section,
    required this.strict,
    required this.onCompleted, // (part1Qa, part2Answer, part3Qa, followUpQa)
  });
}
```

`answers` là `Map<String,String>`; `flagged` là `Set<String>`.
