# Grammar backend (C-Full)

Server-authoritative grammar content, idempotent quiz attempts, XP ledger, and
a minimal admin workspace. The Flutter app still ships the 96-lesson JSON seed
and keeps working offline; it prefers the server bundle when available.

## 1. Apply the schema

From `backend/`:

```bash
python -m alembic upgrade head
```

This adds:

- `users.role` (`user`, `reviewer`, `admin`)
- versioned grammar content fields on `grammar_lessons`
- `grammar_lesson_versions`
- `grammar_attempts` with unique `(user_id, attempt_id)`
- unique `user_grammar_progress(user_id, lesson_id)`
- `xp_transactions` idempotency ledger
- `grammar_admin_audit`

## 2. Import the bundled curriculum

```bash
python -m app.utils.import_grammar --dry-run
python -m app.utils.import_grammar
```

The import is idempotent by slug + content hash. It imports 96 lessons and
480 questions, archives legacy `create_all` sample rows that have no content,
and creates an immutable version row per lesson version.

## 3. Public API

Base path: `/api/v1/grammar`

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/manifest` | public | Lightweight versions/hashes for sync |
| GET | `/bundle` | public | All published lessons for offline cache |
| GET | `/lessons` | optional | Summaries + progress when signed in |
| GET | `/lessons/{slug}` | public | Full local-compatible lesson payload |
| POST | `/attempts` | user | Idempotent attempt + XP |
| GET | `/progress` | user | Server best scores and total XP |
| POST | `/lessons/{slug}/submit` | user | Legacy alias; new clients use `/attempts` |

`POST /attempts` request:

```json
{
  "attempt_id": "uuid-v4",
  "lesson_slug": "present_simple",
  "lesson_version": 1,
  "answers": [
    {"question_index": 0, "selected_option": 1}
  ]
}
```

Retrying the same `attempt_id` returns the original result with
`duplicate: true` and does not award XP twice. First attempt awards 10 XP
(participation) or 30 XP (pass); later attempts award 5 XP only for a new best.

## 4. Admin workspace

Open:

```text
http://localhost:8000/admin/grammar
```

Sign in with an account whose `role` is `admin` or `reviewer`. The page is a
small single-file SPA (no Node build) backed by:

- `GET/POST/PUT /api/v1/admin/grammar/lessons`
- `POST /api/v1/admin/grammar/lessons/{id}/validate`
- `POST /api/v1/admin/grammar/lessons/{id}/submit-review`
- `POST /api/v1/admin/grammar/lessons/{id}/publish` (admin only)
- `GET /api/v1/admin/grammar/lessons/{id}/versions`
- `POST /api/v1/admin/grammar/lessons/{id}/rollback/{version}` (admin only)
- `POST /api/v1/admin/grammar/import` / `GET /export`
- `GET /api/v1/admin/grammar/stats`
- `GET /api/v1/admin/grammar/audit`

Workflow: `draft` → `in_review` → `published` → `archived`. C1/C2 stay marked
`is_beta` until a human reviewer explicitly changes that flag.

To promote a user to reviewer/admin in a dev database:

```sql
UPDATE users SET role = 'admin' WHERE email = 'admin@gmail.com';
```

## 5. Flutter sync

`lib/features/learn/data/` now contains:

- `grammar_remote_repository.dart` — bundle/progress/attempt HTTP calls
- `grammar_sync_service.dart` — best-score merge and offline queue
- `grammar_progress_store.dart` — local progress + pending attempts
- `grammar_repository.dart` — remote → cache → bundled seed fallback

The local quiz completes immediately. If the device is offline or the user is
not signed in, the attempt is queued with a client UUID and retried on the next
grammar screen load. The server response can only raise the local best score.

## 6. Verification

```bash
cd backend
python -m unittest tests.test_grammar_service -v
python -m app.utils.import_grammar --dry-run
python -m alembic current
```

Database-backed API contract test (creates and removes a disposable user; run
only against development/test data):

```bash
# Windows PowerShell
$env:GRAMMAR_INTEGRATION='1'
python -m unittest tests.test_grammar_api_integration -v
```

```bash
cd english_ai
flutter test
flutter analyze
flutter build web --release
```

Live sync contract test (backend must be running; the test user is cleaned by the
developer after the run):

```bash
# Windows PowerShell
$env:GRAMMAR_INTEGRATION='true'
flutter test test/grammar_sync_integration_test.dart
```

Browser smoke test (Flutter web against the live backend):

1. Start the backend on `http://127.0.0.1:8000`.
2. Build/serve the web app on `http://localhost:8080`.
3. Sign in as a normal user, open Grammar, and verify lesson list/detail/quiz.
4. Confirm the first completed lesson is saved as `Đã hoàn thành · 5/5` and
   XP increases after a fresh sign-in.
5. Block `/api/v1/grammar/attempts`, complete another lesson, then reload
   Grammar with the network restored; the queued attempt should sync.
6. Filter C1 and C2 and confirm `BETA` remains visible in the list and detail.

The last automated run covered all of the above, including a failed attempt
request followed by a successful retry on the next Grammar load.

## 7. C1/C2 beta review

The 20 C1/C2 lessons remain `is_beta=true` until a human reviewer signs off.
The automated checks only prove structural validity (level, 5 questions,
examples, uniqueness, English/Vietnamese fields); they do not replace a
linguistic review.

Reviewer checklist:

- Read the lesson in the admin workspace (`/admin/grammar`).
- Check every example and quiz explanation for natural English and accurate
  Vietnamese guidance.
- Confirm CEFR level, register, and answer key are correct.
- Submit for review, then publish only after sign-off.
- Clear `is_beta` only after the human review; use a dedicated admin account.

Current C1 lessons: `advanced_inversion`, `cleft_emphasis`,
`subjunctive_formal`, `advanced_passive`, `nominalisation`,
`participle_reduced_advanced`, `advanced_conditionals_hypothetical`,
`modal_perfects_speculation`, `discourse_cohesion`,
`complex_noun_phrases`.

Current C2 lessons: `inversion_focus_mastery`, `advanced_cleft_focus`,
`subjunctive_archaic_formal`, `complex_counterfactuals`,
`advanced_modality_hedging`, `nominalisation_academic`,
`advanced_cohesion_discourse`, `ellipsis_formal`, `idiomatic_grammar`,
`register_style_precision`.

## 8. Security notes

- Admin APIs check `users.role`; the demo in-memory admin ID is not trusted.
- The admin page stores its JWT in `sessionStorage`; production deployments
  should put it behind HTTPS and consider an HttpOnly cookie session.
- `ENABLE_DEMO_ACCOUNTS` must be `false` in production.
- The server only serves `status=published` lessons to public clients.

## 9. Production checklist

Copy `.env.production.example` to `.env` on the server and replace every
placeholder. The settings validator refuses to start when
`ENVIRONMENT=production` and the JWT secret is missing/weak or demo accounts
are enabled. It also disables interactive API docs in production.

1. Set a unique `JWT_SECRET_KEY` of at least 32 random characters.
2. Set `ENABLE_DEMO_ACCOUNTS=false` and `DEBUG=false`.
3. Put only real HTTPS web origins in `CORS_ORIGINS`; no `*` or localhost.
   Localhost CORS is disabled automatically when `ENVIRONMENT=production`.
4. Run `python -m alembic upgrade head` and verify it reports
   `0002_grammar_backend`.
5. Import the curriculum with `python -m app.utils.import_grammar` (or the
   admin import endpoint) and confirm 96 published lessons / 20 beta lessons.
6. Create dedicated staff accounts, then set `users.role` to `reviewer` or
   `admin`. Do not rely on the demo accounts.
7. Run the read-only preflight:

```bash
# from backend/, with production variables loaded
python -m app.utils.production_preflight
```

8. Put the API behind TLS and HTTPS-only CORS. The admin page currently keeps
   its JWT in `sessionStorage`; review whether an HttpOnly cookie session is
   required for your deployment.
9. Keep C1/C2 `is_beta=true` until the human review in section 7 is complete.
