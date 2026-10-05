"""
Test Phase 2 Learning Endpoints:
Placement Test, Vocabulary SM-2, Grammar Lessons.
"""

import sys
if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    getattr(sys.stdout, "reconfigure")(encoding='utf-8')

from fastapi.testclient import TestClient
from main import app

print("=" * 60)
print("🚀 EnglishAI - Phase 2 Learning System Verification")
print("=" * 60)

with TestClient(app, raise_server_exceptions=False) as client:
    # 1. Register & Login test user
    print("\n[1/4] Tạo tài khoản học viên thử nghiệm...")
    import uuid
    rand_email = f"learner_{uuid.uuid4().hex[:6]}@example.com"
    reg_res = client.post("/api/v1/auth/register", json={
        "email": rand_email,
        "password": "Password123!",
        "name": "Minh Vu"
    })
    assert reg_res.status_code == 201, f"Register failed: {reg_res.text}"
    token = reg_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print(f"  • Đăng ký thành công: {rand_email} ✅")

    # 2. Placement Test
    print("\n[2/4] Kiểm tra Placement Test (Đánh giá năng lực đầu vào)...")
    q_res = client.get("/api/v1/placement/questions", headers=headers)
    assert q_res.status_code == 200, f"Get questions failed: {q_res.text}"
    questions = q_res.json()
    print(f"  • Số lượng câu hỏi tải về: {len(questions)} câu ✅")
    
    # Submit answers
    answers = []
    for q in questions:
        answers.append({"question_id": q["id"], "selected_option": 1})
    
    sub_res = client.post("/api/v1/placement/submit", json={"answers": answers}, headers=headers)
    assert sub_res.status_code == 200, f"Submit placement failed: {sub_res.text}"
    result = sub_res.json()
    print(f"  • Điểm đánh giá: {result['score_percentage']}% ({result['correct_count']}/{result['total_questions']})")
    print(f"  • Xếp loại trình độ CEFR: {result['assessed_level']} ✅")
    print(f"  • Phân tích kỹ năng: {result['skill_breakdown']}")

    # 3. Vocabulary & SM-2
    print("\n[3/4] Kiểm tra Từ vựng & Thuật toán SM-2 Spaced Repetition...")
    topics_res = client.get("/api/v1/vocabulary/topics", headers=headers)
    assert topics_res.status_code == 200
    topics = topics_res.json()
    print(f"  • Danh sách chủ đề từ vựng: {len(topics)} chủ đề ✅")
    
    due_res = client.get("/api/v1/vocabulary/due", headers=headers)
    assert due_res.status_code == 200
    due_items = due_res.json()
    print(f"  • Thẻ từ vựng cần học hôm nay: {len(due_items)} thẻ ✅")
    
    if due_items:
        test_word_id = due_items[0]["word"]["id"]
        # Review with rating 4 (Good)
        rev_res = client.post(
            f"/api/v1/vocabulary/words/{test_word_id}/review",
            json={"quality": 4},
            headers=headers
        )
        assert rev_res.status_code == 200
        prog = rev_res.json()
        print(f"  • Kết quả SM-2 sau khi chấm điểm 4: interval={prog['interval_days']} ngày, ease_factor={prog['ease_factor']} ✅")

    # 4. Grammar Lessons
    print("\n[4/4] Kiểm tra Bài học Ngữ pháp & Trắc nghiệm...")
    g_res = client.get("/api/v1/grammar/lessons", headers=headers)
    assert g_res.status_code == 200
    lessons = g_res.json()
    print(f"  • Danh sách bài ngữ pháp: {len(lessons)} bài học ✅")

    if lessons:
        lesson_id = lessons[0]["id"]
        detail_res = client.get(f"/api/v1/grammar/lessons/{lesson_id}", headers=headers)
        assert detail_res.status_code == 200
        lesson_detail = detail_res.json()
        print(f"  • Nội dung bài học '{lesson_detail['title']}': Đã tải Markdown & ví dụ ✅")
        
        # Submit quiz answers
        submit_quiz_res = client.post(
            f"/api/v1/grammar/lessons/{lesson_id}/submit",
            json={"answers": [{"question_index": 0, "selected_option": 1}]},
            headers=headers
        )
        assert submit_quiz_res.status_code == 200
        quiz_res = submit_quiz_res.json()
        print(f"  • Chấm điểm bài tập ngữ pháp: {quiz_res['score']}% (Được thưởng {quiz_res['xp_earned']} XP) ✅")

print("\n" + "=" * 60)
print("🎉 TẤT CẢ MODULE HỌC TẬP PHASE 2 HOẠT ĐỘNG HOÀN HẢO!")
print("=" * 60)
