# Tính năng đã phát triển

Tài liệu này tổng hợp các tính năng đã hoàn thiện trong đợt phát triển gần nhất.
Một số nội dung C1/C2 và IELTS Mock vẫn đang ở trạng thái **BETA** và cần được
người review nội dung xác nhận trước khi bỏ nhãn BETA.

## 1. Grammar C-Full (A1–C2)

- **96 bài học**, **480 câu hỏi**, mỗi bài đúng **5 câu**.
- Dữ liệu nằm trong `english_ai/assets/data/grammar/*.json` và được tải offline.
- Màn hình Grammar có 3 tab:
  - **Học**: lý thuyết, ví dụ và tiến độ từng bài.
  - **Ngữ pháp**: danh sách bài theo cấp độ A1–C2.
  - **Trắc nghiệm**: làm quiz của bài đã chọn.
- Tiến độ được lưu bằng `SharedPreferences`; khi đăng nhập, tiến độ được đồng
  bộ best-effort với backend.
- **C1/C2 vẫn gắn BETA** cho đến khi 20 bài C1/C2 được review thủ công.
  Practice Arena mặc định không chọn bài BETA.

## 2. Practice Arena

### P0 — dữ liệu thật và liên kết đúng

- Hiển thị `totalXp` và `streak` thật từ tài khoản đang đăng nhập.
- Lưu **độ chính xác all-time** và tiến độ **x/5 câu hôm nay** bằng
  `SharedPreferences`; mục tiêu ngày tự reset theo ngày local.
- Đã bỏ phần chấm Writing AI giả trong Practice. Nút **Writing AI** mở
  `/writing` và dùng luồng `/ai/evaluate-writing` thật.
- Các nút trong Practice mở đúng màn hình:
  - Writing AI → `/writing`
  - Viết câu → `/writing-practice`
  - Luyện nói → `/ai-tutor/call`
  - Flashcards → `/vocabulary/review`
  - IELTS Mock → màn hình mock test (BETA)
  - Mistake Notebook → màn hình sổ lỗi

### P1 — quiz ngữ pháp và XP

- Practice dùng dữ liệu Grammar C-Full.
- Mỗi lượt chọn **một bài ngẫu nhiên**, ưu tiên bài chưa hoàn thành ở trình độ
  hiện tại; mặc định bỏ qua bài C1/C2 BETA.
- Mỗi lượt gồm **5 câu**, có phản hồi đúng/sai và giải thích.
- Khi nộp bài:
  - Gửi attempt lên backend qua `GrammarSyncService.submitAttemptDetailed()`.
  - Nhận XP của riêng lượt làm bài, làm mới user XP/streak.
  - Hiển thị kết quả, số câu đúng, XP nhận được.
  - Có trạng thái offline/queued, lỗi và nút thử lại.
  - Sau khi hoàn thành, nút **Bài tiếp theo** tải lượt mới và reset về `1/5 câu`.
- Chống cộng điểm hai lần khi người dùng bấm đáp án liên tiếp.

### P2 — bố cục và responsive

- Thứ tự màn hình: header/thống kê → quiz ngữ pháp → lưới kỹ năng 2×2 →
  các thẻ nâng cao.
- Lưới 2×2 gồm Writing AI, Viết câu, Luyện nói, Flashcards.
- Thẻ IELTS Mock có nhãn **BETA**.
- Đã kiểm tra bố cục tại các chiều rộng `360px`, `412px`, `800px`.
- Nút **Trắc Nghiệm Ngữ Pháp** thay cho tên cũ “Trắc Nghiệm Tốc Độ”.
  Nhãn bottom navigation được giữ nguyên.

## 3. Kho từ vựng và Flashcards

- Catalog chuẩn: `backend/app/data/vocabulary/catalog.json`.
- **20 chủ đề, 200 từ**; mỗi chủ đề 10 từ.
- Mỗi từ có phiên âm, từ loại, nghĩa Việt/Anh, câu ví dụ, bản dịch, level CEFR,
  collocations, synonyms, antonyms, tags và thứ tự hiển thị.
- ID topic/word dùng UUID5 cố định để tiến độ SM-2 không mất khi seed lại.
- Backend upsert catalog khi khởi động; migration `0006_vocabulary_content`
  bổ sung các cột nội dung mới.
- Flutter dùng deck offline sinh từ catalog; hỗ trợ flashcard và ôn tập SM-2.
- Script đồng bộ:

  ```bash
  python scripts/sync_vocabulary_catalog.py
  python scripts/sync_vocabulary_catalog.py --check
  ```

- Chi tiết dữ liệu: `docs/vocabulary_catalog.md`.

## 4. Placement Test v2

- Đánh giá CEFR A1–C2 theo 5 kỹ năng: Listening, Reading, Use of English,
  Writing, Speaking.
- Ba chế độ: `quick`, `standard`, `full`.
- API mới dùng session, answer, stage completion, writing và speaking.
- Kết quả gồm CEFR, khoảng tin cậy, quy đổi điểm thi, điểm mạnh/yếu, roadmap và
  can-do descriptors.
- Luồng Flutter bắt đầu tại `/placement`.
- Chi tiết: `docs/placement_test.md`.

## 5. IELTS Mock Test

- Nội dung Academic và General Training.
- Hỗ trợ 4 kỹ năng: Listening, Reading, Writing, Speaking.
- Có audio, đề bài và tiến trình làm bài.
- Trạng thái: **BETA** — cần review nội dung trước khi dùng như đề chính thức.

## 6. Pronunciation

- Luyện phát âm với voice, tốc độ đọc và chế độ nghe lặp.
- Có chấm điểm và lưu attempt phục vụ theo dõi tiến bộ.
- Đã xử lý lỗi ghi âm trên Android trong phạm vi trước đó.

## 7. Tài khoản, giao diện và cấu hình

- Người dùng chưa đăng nhập mặc định dùng theme sáng.
- Google Sign-In đã được đồng bộ client ID giữa Flutter và backend.
- **Trạng thái Google Sign-In:** chưa đăng nhập được trên web cho đến khi thêm
  các origin vào Google Cloud Console:
  - `http://localhost:5173`
  - `http://localhost:8080`
  - origin production tương ứng
- Email/password vẫn dùng được mà không cần Google.
- Tài khoản demo local: `test@gmail.com` / `Password123`.
  Không bật demo account trong production.

## 8. Kiểm thử và dữ liệu

Các test chính:

```bash
# Backend
cd backend
pip install pytest
python -m pytest tests -q

# Flutter
cd english_ai
flutter test

# Build web
flutter build web --release --no-wasm-dry-run
```

Kết quả gần nhất:

- Backend: **69 passed, 3 skipped**.
- Flutter: **48 passed, 1 skipped**.
- Practice và Grammar có test riêng cho layout, quiz, XP, offline, double-answer
  và lỗi tải tiến độ.
- Vocabulary có test catalog, sync và tiến độ local.
- Placement có test model/provider và engine/API phía backend.

## 9. Giới hạn đã biết

- Google Sign-In web vẫn bị chặn bởi Google Cloud authorized origins.
- C1/C2 Grammar và IELTS Mock vẫn là BETA.
- Một số cảnh báo `flutter analyze` cũ ngoài phạm vi Practice vẫn còn; CI dùng
  chế độ không coi info/warning là lỗi.
- Chưa kiểm thử runtime Android trong đợt này.
- Dữ liệu local (Practice/Vocabulary) gắn với browser/profile; đổi browser sẽ
  bắt đầu tiến độ local mới.

## 10. Tài liệu liên quan

- `README.md` — cài đặt, Docker, Git LFS, chạy web/Android.
- `docs/RELEASE_NOTES.md` — tổng kết đợt phát hành.
- `docs/vocabulary_catalog.md` — cấu trúc và quy trình cập nhật từ vựng.
- `docs/placement_test.md` — API và luồng Placement Test.
- `docs/ielts_mock_test.md` — nội dung IELTS Mock.
- `backend/GRAMMAR_BACKEND.md` — API, seed và review Grammar.
