# EnglishAI — Personalized AI English Learning Assistant

> An AI-powered personalized English learning platform that evaluates the learner, adapts learning content, enables real-time AI conversation, analyzes speaking and writing, automatically generates exercises, and continuously improves the learning path based on user performance.

## 🏗️ Architecture

- **Frontend**: Flutter + Dart (Riverpod, GoRouter, Dio)
- **Backend**: Python + FastAPI (async SQLAlchemy)
- **Database**: PostgreSQL / Supabase
- **AI**: LLM API + RAG + Speech-to-Text + Text-to-Speech

## 📁 Project Structure

```
AI ENGLISH/
├── english_ai/          # Flutter mobile app
│   ├── lib/
│   │   ├── core/        # Theme, network, router, services
│   │   ├── features/    # Auth, onboarding, home, etc.
│   │   └── shared/      # Reusable widgets
│   └── pubspec.yaml
│
└── backend/             # FastAPI server
    ├── app/
    │   ├── api/         # Endpoints
    │   ├── models/      # SQLAlchemy models
    │   ├── schemas/     # Pydantic validation
    │   └── utils/       # Security, helpers
    └── main.py
```

## 🚀 Quick Start

### Backend

```bash
cd backend
python -m venv venv
.\venv\Scripts\activate  # Windows
pip install -r requirements.txt      # core API + auth + DB
pip install -r requirements-ai.txt   # optional: AI Tutor + Speech
# Copy .env.example to .env and fill in real values
# Create PostgreSQL database named "english_ai" (or use Supabase)
alembic upgrade head                 # create/update the schema
python main.py                       # runs on http://localhost:8000
```

> The heavy AI Tutor and Speech stack (torch, transformers, faster-whisper,
> edge-tts, ...) lives in `requirements-ai.txt` and is only needed for those
> features. For a GPU build of torch, see the note at the top of that file.
> In `development` the server also auto-creates tables on startup; in
> `production` run `alembic upgrade head` (the app then only checks the
> connection).

### Flutter

```bash
cd english_ai
flutter pub get

# Web (defaults to http://localhost:8000)
flutter run -d edge

# Android emulator (auto-uses 10.0.2.2) or a physical device:
flutter run --dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:8000
```

The backend base URL is resolved centrally in
`english_ai/lib/core/constants/app_config.dart` and can be overridden at build
time with `--dart-define=API_BASE_URL=...` (no code edits needed).

### Docker (backend + Postgres + Redis)

From the repository root:

```bash
docker compose up --build
```

This starts PostgreSQL, Redis and the API (running `alembic upgrade head` on
boot) at `http://localhost:8000`. Copy `backend/.env.example` values into the
compose `environment` block or a `backend/.env` file as needed. Build the image
with the AI/Speech stack via `--build-arg REQUIREMENTS=requirements-ai.txt`.

### Google Sign-In (optional)

1. Backend: set `GOOGLE_OAUTH_CLIENT_ID` in `backend/.env` to your Google
   **Web** OAuth client ID. The `/api/v1/auth/google` endpoint verifies the
   ID token and creates/links the local account.
2. Flutter: run with
   `--dart-define=GOOGLE_CLIENT_ID=<web-client-id>.apps.googleusercontent.com`
   (the same value). The button is disabled until it is configured.

## 📋 Development Phases

| Phase | Status | Focus |
|---|---|---|
| Phase 1 | ✅ Complete | Foundation — Auth, Onboarding, Theme, Backend |
| Phase 2 | ✅ Complete | Learning — Vocab (SM-2), Grammar, Listening, Reading, Placement |
| Phase 3 | ✅ Complete | AI — Tutor chat, Exercise Gen, Writing Eval (local LLM + Gemini/OpenAI fallback) |
| Phase 4 | ✅ Complete | Speech — STT, TTS, Voice conversation, Pronunciation |
| Phase 5 | 🚧 In progress | Optimization — CI/CD, Alembic migrations, Docker, hardening |

### Environment & security notes

- `backend/.env` is git-ignored. Never commit real secrets; `JWT_SECRET_KEY`
  is required in production (the app refuses to start without a strong value).
- Demo/offline accounts (`test@gmail.com`, `admin@gmail.com`) are gated by
  `ENABLE_DEMO_ACCOUNTS` and **must be disabled in production**.
- Generated audio and large model weights are not tracked (see `.gitignore`;
  `*.safetensors` uses Git LFS).

## 📄 License

Private project — All rights reserved.
