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
pip install -r requirements.txt
# Create PostgreSQL database named "english_ai"
# Edit .env with your database URL
python main.py
```

### Flutter

```bash
cd english_ai
flutter pub get
flutter run
```

## 📋 Development Phases

| Phase | Status | Focus |
|---|---|---|
| Phase 1 | ✅ Complete | Foundation — Auth, Onboarding, Theme, Backend |
| Phase 2 | 🔜 Next | Learning — Vocab, Grammar, Listening, Reading |
| Phase 3 | ⏳ Planned | AI — Tutor, Exercise Gen, Writing Eval |
| Phase 4 | ⏳ Planned | Speech — STT, TTS, Conversation, Pronunciation |
| Phase 5 | ⏳ Planned | Optimization — Testing, Security, Performance |

## 📄 License

Private project — All rights reserved.
