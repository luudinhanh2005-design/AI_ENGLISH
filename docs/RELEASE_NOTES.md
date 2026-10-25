# Release notes — 2026-10-25

## Phạm vi

Đợt này gom các thay đổi đang có trên nhánh phát triển vào một bản release để
đồng nghiệp có thể clone và chạy:

- Practice Arena P0/P1/P2
- Grammar C-Full và đồng bộ tiến độ/XP
- Kho từ vựng 20 chủ đề, 200 từ + flashcards/SM-2
- Placement Test v2
- IELTS Mock Test (BETA)
- Tài liệu tính năng và hướng dẫn chạy cho người mới

## Thay đổi chính

### Practice Arena

- XP/streak lấy từ tài khoản thật.
- Lưu độ chính xác all-time và mục tiêu `x/5` câu/ngày bằng
  `SharedPreferences`.
- Quiz ngữ pháp 5 câu, chọn một bài ngẫu nhiên, ưu tiên bài chưa hoàn thành,
  mặc định bỏ qua C1/C2 BETA.
- Nộp attempt, nhận XP, hiển thị kết quả, retry/offline và chuyển bài tiếp theo.
- Bố cục quiz-first, lưới kỹ năng 2×2, responsive ở 360/412/800 px.
- Các liên kết Writing AI, Viết câu, Luyện nói, Flashcards, IELTS Mock và
  Mistake Notebook mở đúng màn hình.
- Bỏ chấm Writing AI giả; dùng luồng `/writing` và `/ai/evaluate-writing`.

### Grammar

- 96 bài A1–C2, 480 câu hỏi, 5 câu/bài.
- 3 tab Học / Ngữ pháp / Trắc nghiệm.
- C1/C2 giữ nhãn BETA chờ review 20 bài.
- `GrammarSyncService.submitAttemptDetailed()` trả kết quả của từng attempt,
  vẫn giữ tương thích với `submitAttempt()`.

### Vocabulary

- Catalog JSON là nguồn dữ liệu duy nhất.
- 20 chủ đề, 200 từ; UUID5 ổn định cho tiến độ SM-2.
- Migration `0006_vocabulary_content` bổ sung collocations, synonyms, antonyms,
  tags và order_index.
- Đồng bộ catalog sang deck Flutter bằng
  `scripts/sync_vocabulary_catalog.py`.

### Placement

- Placement v2 theo CEFR, 5 kỹ năng, 3 chế độ quick/standard/full.
- Sửa xử lý 404 khi người dùng chưa có kết quả trước đó.
- Không để lỗi tải lịch sử/kết quả cũ chặn màn hình giới thiệu.
- Sau onboarding chuyển sang `/placement`.

### Khác

- Người dùng chưa đăng nhập mặc định dùng theme sáng.
- Cập nhật CORS development cho cổng `5173` và `127.0.0.1`.
- Cập nhật test Practice/Grammar cũ theo tên và luồng mới.

## Kiểm tra đã chạy

```text
Backend:  pip install pytest && pytest tests -q
          69 passed, 3 skipped

Flutter:  flutter test
          48 passed, 1 skipped

Analyze:  flutter analyze --no-fatal-infos --no-fatal-warnings
          0 error, 0 warning, 1248 info (chủ yếu deprecation/trailing comma cũ)

Web:      flutter build web --release --no-wasm-dry-run
          Built build/web

Alembic:  alembic upgrade head --sql
          Bao gồm 0006_vocabulary_content

Clean clone (Git LFS):
          cloned the release branch, LFS model 114.25 MiB downloaded
          backend tests: 69 passed, 3 skipped
          flutter tests: 48 passed, 1 skipped
          flutter build web: success
          backend /health: 200
          demo login: success
```

## Cách chạy nhanh cho đồng nghiệp

```bash
git lfs install
git clone https://github.com/luudinhanh2005-design/AI_ENGLISH.git
cd AI_ENGLISH
```

Windows:

```bat
run.bat
```

macOS/Linux:

```bash
./run.sh
```

Hoặc chạy backend bằng Docker:

```bash
docker compose up --build
```

Kiểm tra backend:

```bash
curl http://localhost:8000/health
```

Tài khoản demo local:

```text
Email:    test@gmail.com
Password: Password123
```

Lưu ý:

- Tài khoản demo chỉ dùng cho development.
- Không commit `backend/.env`.
- Nếu không dùng PostgreSQL, backend chạy bằng in-memory; dữ liệu reset khi
  restart.
- Google Sign-In web cần thêm authorized JavaScript origins trong Google Cloud
  Console trước khi dùng.

## Giới hạn còn lại

- Google Sign-In web vẫn lỗi `403: The given origin is not allowed for the
  given client ID` cho đến khi cấu hình Google Cloud.
- C1/C2 Grammar và IELTS Mock vẫn là BETA.
- Chưa kiểm thử runtime Android trong đợt này.
- Các info analyzer cũ ngoài phạm vi Practice chưa được dọn hết.
- Tiến độ local của Practice/Vocabulary gắn với browser profile hiện tại.

## Tài liệu

- `docs/FEATURES.md` — danh sách chức năng chi tiết.
- `README.md` — cài đặt, Docker, Git LFS, Android, troubleshooting.
- `docs/vocabulary_catalog.md` — quy trình cập nhật từ vựng.
- `docs/placement_test.md` — API và luồng Placement.
- `backend/GRAMMAR_BACKEND.md` — backend Grammar.
