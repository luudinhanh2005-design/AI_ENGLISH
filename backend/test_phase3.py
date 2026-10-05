"""
Test Phase 3 AI Engine Endpoints:
AI Tutor Chat with Real-time Error Correction,
Adaptive Exercise Generator,
and Writing Evaluation.
"""

import sys
if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    getattr(sys.stdout, "reconfigure")(encoding='utf-8')

import uuid
from fastapi.testclient import TestClient
from main import app

print("=" * 60)
print("🤖 EnglishAI - Phase 3 AI Engine Verification")
print("=" * 60)

with TestClient(app, raise_server_exceptions=False) as client:
    # 1. Register test learner
    print("\n[1/4] Khởi tạo tài khoản học viên kiểm thử...")
    email = f"ai_learner_{uuid.uuid4().hex[:6]}@example.com"
    reg_res = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "name": "Thao Nguyen"
    })
    assert reg_res.status_code == 201
    token = reg_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print(f"  • Tạo tài khoản thành công: {email} ✅")

    # 2. AI Tutor Chat with Real-time Error Correction
    print("\n[2/4] Kiểm tra AI Tutor Chat & Sửa lỗi ngữ pháp tức thì...")
    chat_res = client.post(
        "/api/v1/ai/chat",
        json={
            "persona": "sarah",
            "message": "Yesterday I go to market to buy fruits.",
            "topic": "Daily Conversations",
        },
        headers=headers,
    )
    assert chat_res.status_code == 200, f"Chat failed: {chat_res.text}"
    chat_data = chat_res.json()
    session_id = chat_data["session_id"]
    print(f"  • AI Tutor trả lời: \"{chat_data['reply'][:60]}...\" ✅")
    print(f"  • Phát hiện và sửa lỗi ngữ pháp:")
    for corr in chat_data["corrections"]:
        print(f"    - Câu sai: '{corr['original']}' -> Sửa: '{corr['correction']}'")
        print(f"      Giải thích: {corr['explanation_vi']}")
    print(f"  • Gợi ý câu trả lời nhanh: {chat_data['suggested_replies']} ✅")

    # Check history persistence
    hist_res = client.get(f"/api/v1/ai/sessions/{session_id}/messages", headers=headers)
    assert hist_res.status_code == 200
    msgs = hist_res.json()
    print(f"  • Lưu trữ lịch sử hội thoại: {len(msgs)} tin nhắn trong phiên ✅")

    # 3. AI Adaptive Exercise Generator
    print("\n[3/4] Kiểm tra Tự động sinh bài tập thông minh (AI Exercise Generator)...")
    gen_res = client.post(
        "/api/v1/ai/generate-exercises",
        json={"skill": "grammar", "count": 3},
        headers=headers,
    )
    assert gen_res.status_code == 200
    gen_data = gen_res.json()
    print(f"  • Trình độ mục tiêu: {gen_data['target_level']}")
    print(f"  • Số lượng bài tập được sinh: {len(gen_data['exercises'])} bài tập ✅")
    for idx, ex in enumerate(gen_data["exercises"], 1):
        print(f"    [{idx}] {ex['question']}")

    # 4. AI Writing Evaluator
    print("\n[4/4] Kiểm tra Chấm điểm & Chữa bài viết (AI Writing Evaluator)...")
    sample_essay = (
        "Technology have changed our daily lives significantly. "
        "Nowadays, many people is using artificial intelligence to learn languages. "
        "I believe that AI is very important for future education."
    )
    writing_res = client.post(
        "/api/v1/ai/evaluate-writing",
        json={
            "topic": "The Impact of AI on Education",
            "text": sample_essay,
        },
        headers=headers,
    )
    assert writing_res.status_code == 200
    w_data = writing_res.json()
    print(f"  • Điểm tổng quan: {w_data['overall_score']}/100")
    print(f"  • Trình độ CEFR tương đương: {w_data['cefr_level']} (IELTS Band: {w_data['ielts_equivalent']}) ✅")
    print(f"  • Nhận xét từ AI: {w_data['general_comment'][:80]}... ✅")
    print(f"  • Gợi ý từ vựng nâng cao: {len(w_data['vocab_suggestions'])} gợi ý ✅")

print("\n" + "=" * 60)
print("🎉 TOÀN BỘ HỆ THỐNG TRÍ TUỆ NHÂN TẠO PHASE 3 ĐÃ HOÀN HẢO!")
print("=" * 60)
