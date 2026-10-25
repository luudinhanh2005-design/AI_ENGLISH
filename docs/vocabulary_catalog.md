# Kho từ vựng & Flashcards

## Nguồn dữ liệu duy nhất

`backend/app/data/vocabulary/catalog.json` là nguồn chuẩn cho toàn bộ kho từ vựng.

- Backend đọc file này khi khởi động và upsert vào PostgreSQL.
- Flutter không tự viết lại danh sách từ; file
  `english_ai/lib/features/vocabulary/data/vocabulary_data.dart` được sinh tự động
  từ catalog để dùng làm deck offline.
- ID của topic và word là UUID5 cố định, nên tiến độ SM-2 không bị mất khi thêm từ
  mới hoặc khởi động lại backend.

## Cấu trúc hiện tại

- 20 chủ đề, 200 từ (mỗi chủ đề 10 từ).
- Mỗi từ có: phiên âm, từ loại, nghĩa Việt, nghĩa Anh, câu ví dụ, bản dịch,
  level CEFR, collocations, synonyms, antonyms, tags và thứ tự hiển thị.
- Các chủ đề: giao tiếp, công nghệ/AI, công việc, du lịch, học thuật/IELTS,
  ẩm thực, sức khỏe, giáo dục, mua sắm, nhà cửa, môi trường, cảm xúc,
  giải trí, gia đình, giao thông, khoa học, thể thao, nghệ thuật, thời tiết,
  pháp luật.

## Thêm hoặc sửa từ

1. Sửa `backend/app/data/vocabulary/catalog.json`.
2. Chạy kiểm tra và sinh lại deck Flutter:

   ```bash
   python scripts/sync_vocabulary_catalog.py
   python scripts/sync_vocabulary_catalog.py --check
   ```

3. Chạy migration mới nếu schema thay đổi:

   ```bash
   cd backend
   alembic upgrade head
   ```

4. Khởi động backend. Hàm `seed_vocabulary()` sẽ upsert các topic/word mới và
   cập nhật `total_words`; không xóa word cũ và không xóa tiến độ người học.

Lưu ý:

- Không đổi spelling/case của một headword đã có nếu muốn giữ tiến độ cũ.
- Không dùng trùng một headword ở hai chủ đề; loader sẽ báo lỗi.
- Từ mới nên có đủ `example_sentence`, `example_translation` và ít nhất một
  collocation để flashcard có nội dung học sâu.

## Ghi chú khi DB đã có dữ liệu cũ

- Nếu các bảng đã được tạo bởi `Base.metadata.create_all` nhưng `alembic_version`
  còn ở revision cũ, không nên chạy `upgrade head` ngay. Cần kiểm tra schema,
  stamp revision tương ứng rồi mới upgrade phần còn thiếu.
- Word có ID ngẫu nhiên từ phiên bản trước cần được chuẩn hóa về UUID5 và cập
  nhật `user_word_progress.word_id` trong cùng transaction. Nếu không, tiến độ
  server và deck offline sẽ dùng hai ID khác nhau cho cùng một từ.

## API

- `GET /vocabulary/topics` — danh sách chủ đề kèm số từ thực tế.
- `GET /vocabulary/words?page=1&limit=50&q=&level=&topic_id=&topic_slug=` —
  danh sách có phân trang, tìm kiếm theo từ/nghĩa, lọc level và chủ đề.
- `GET /vocabulary/topics/{topic_id}/words` — toàn bộ từ của một chủ đề.
- `GET /vocabulary/stats` — tổng số từ, số đã học, số đến hạn, số đã thuộc.
- `GET /vocabulary/due?limit=20` — từ đến hạn + từ mới, dùng cho flashcard.
- `POST /vocabulary/words/{word_id}/review` — gửi rating SM-2.

## Hành vi offline

- Flutter dùng deck sinh từ catalog khi API không khả dụng.
- Tiến độ được lưu cục bộ theo `user + word_id` trong `VocabularyProgressStore`.
- Từ offline vẫn dùng chung công thức SM-2 với backend; khi có mạng, backend là
  nguồn chuẩn cho lịch ôn của từ đã có trên server.
- Các từ mới trong catalog có ID UUID hợp lệ nên có thể review trên server ngay
  khi backend đã được seed.

## Lộ trình mở rộng tiếp theo

1. Nâng lên 500–1.000 từ, ưu tiên tần suất giao tiếp A1–B2 trước khi thêm C1.
2. Bổ sung collocations/word family theo từng topic và kiểm tra bằng script.
3. Thêm bài kiểm tra ngắn (cloze, nghe – chọn nghĩa) cho từng cụm 10 từ.
4. Đồng bộ tiến độ offline lên server bằng migration key `word + part_of_speech`.
5. Thêm audio TTS/URL cho từng word và chế độ học theo level/ngày.
