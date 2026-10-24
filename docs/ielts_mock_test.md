# IELTS Mock Test (4 skills) — Implementation Notes

## Overview
The IELTS Mock Test feature provides a full four-skill (Listening, Reading,
Writing, Speaking) exam experience in both `strict` (exam-like) and `practice`
modes. It ships with two complete sets: `academic_01` and `general_01`.

## Backend
- Content lives in `backend/app/data/ielts_mock/<set_id>/` (JSON).
- API mounted at `/api/v1/mock-tests` (router: `app/api/v1/mock_tests.py`).
- Database table `mock_test_attempts` (migration `0003_mock_tests.py`).
- Writing/Speaking graded by AI with local fallbacks.
- Listening audio is pre-generated as flat mp3 files in
  `backend/storage/audio/` and served via `/api/v1/speech/audio/{filename}`.

## Frontend
- Hub: `/mock-test`. Entry points in Home, Practice and Profile point at the hub.
- Routes: `/mock-test`, `/mock-test/intro`, `/mock-test/run`,
  `/mock-test/result`, `/mock-test/history`.
- Feature module: `english_ai/lib/features/mock_test/`.

## Content authoring
- Each set is a folder with `meta.json`, `listening.json`, `reading.json`,
  `writing.json`, `speaking.json`.
- See `docs/ielts_mock_test_contract.md` for the full JSON and API contract.
- Validate with:
  ```
  python scripts/validate_mock_content.py
  python scripts/validate_mock_content.py --set academic_01
  ```

## Audio generation
```
cd scripts
python generate_listening_audio.py --set academic_01
python generate_listening_audio.py --set academic_01 --part 2 --force
```

## Tests
```
cd backend
python -m pytest tests/test_mock_test_service.py -q
```

## Migration
Run `alembic upgrade head` (or the project's migration command) to create
`mock_test_attempts`.
