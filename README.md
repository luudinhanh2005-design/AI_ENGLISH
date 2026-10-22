# EnglishAI — Personalized AI English Learning Assistant

> An AI-powered personalized English learning platform that evaluates the learner, adapts learning content, enables real-time AI conversation, analyzes speaking and writing, automatically generates exercises, and continuously improves the learning path based on user performance.

## 🏗️ Architecture

- **Frontend**: Flutter + Dart (Riverpod, GoRouter, Dio)
- **Backend**: Python + FastAPI (async SQLAlchemy)
- **Database**: PostgreSQL / Supabase (in-memory fallback for quick local runs)
- **AI**: Local LLM + optional Gemini/OpenAI fallback, Speech-to-Text + Text-to-Speech

## 📁 Project structure

```
AI_ENGLISH/
├── english_ai/                 # Flutter app
│   ├── lib/
│   │   ├── core/               # Theme, network, router, services
│   │   ├── features/           # Auth, onboarding, home, ...
│   │   └── shared/             # Reusable widgets
│   └── pubspec.yaml
├── backend/                    # FastAPI server
│   ├── app/
│   └── main.py
├── scripts/
│   ├── android_ensure_emulator.ps1   # Windows
│   ├── android_ensure_emulator.sh    # macOS / Linux
│   └── run_phone.ps1                 # Real-phone runner
├── .vscode/                    # Shared launch/task config (F5 works out of the box)
├── docker-compose.yml
└── run.bat / run.ps1 / run.sh / run_phone.bat
```

---

## 🚀 Quick start for new contributors

### 0. Prerequisites

| Tool | Version | Needed for |
|---|---|---|
| Flutter SDK | stable, 3.24+ (Dart 3.1+) | App |
| Python | 3.10+ | Backend |
| Git + **Git LFS** | any recent | Cloning (the AI model is 114 MB in LFS) |
| Android SDK | platform-tools, emulator, **platforms;android-36**, **build-tools;36.0.0** | Android build |
| Android system image | API 29 `default` (`x86_64` or `arm64-v8a`) | Emulator |
| JDK | 17 (bundled with Android Studio) | Android build |
| Docker Desktop | optional, recommended | Backend + PostgreSQL + Redis |

> **Git LFS is required.** Install it once **before** cloning:
> `git lfs install`
> Without LFS the model file is only a 130-byte pointer and AI Tutor features fail.

### 1. Clone

```bash
git lfs install
git clone https://github.com/luudinhanh2005-design/AI_ENGLISH.git
cd AI_ENGLISH
```

If you cloned before installing Git LFS:

```bash
git lfs install && git lfs pull
```

### 2. Start the backend

**Option A — Docker (recommended: includes PostgreSQL + Redis)**

```bash
docker compose up --build
```

**Option B — Local Python**

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate
# macOS / Linux
source venv/bin/activate

pip install -r requirements.txt
cp .env.example .env          # optional: defaults work in development
python main.py                # http://localhost:8000
```

Check it:

```bash
curl http://localhost:8000/health
# {"status":"healthy","app":"EnglishAI","version":"1.0.0"}
```

> No PostgreSQL running? The API starts anyway and uses **in-memory storage**.
> Everything works, but accounts/data reset when the server stops. Use Docker
> (or set `DATABASE_URL`) if you need persistence.
>
> AI Tutor / Speech need the heavier stack: `pip install -r requirements-ai.txt`.
> Core auth, learning features and the API work without it.

### 3. Run the Flutter app

```bash
cd english_ai
flutter pub get
```

> **Windows shortcut:** from the repository root, `run.bat` starts the backend if
> needed and restarts the Flutter web server in one command. It is safe to run
> again: a healthy backend is reused and an old Flutter server on port 5173 is
> stopped automatically.

Pick **one** of the three options below.

#### Option 1 — Web (lightest, no Android SDK needed)

```bash
flutter run -d chrome     # or: flutter run -d edge
```

The backend URL defaults to `http://localhost:8000` on web.

#### Option 2 — Android emulator

```bash
# Windows
powershell -ExecutionPolicy Bypass -File ..\scripts\android_ensure_emulator.ps1

# macOS / Linux
chmod +x ../scripts/android_ensure_emulator.sh
../scripts/android_ensure_emulator.sh

cd ..
cd english_ai
flutter run -d emulator-5554
```

The script creates `englishai_light` automatically on the first run and picks a
profile that matches the host hardware. Android reaches the host backend through
`10.0.2.2` automatically — no configuration needed.

#### Option 3 — Real phone (one command)

**Android over USB (recommended):**

1. Enable **Developer options → USB debugging** on the phone.
2. Connect the USB cable and accept the RSA prompt.
3. From the repository root:

```bat
run_phone.bat
```

The script starts the backend if needed, runs `adb reverse`, and launches Flutter
with `API_BASE_URL=http://127.0.0.1:8000`.

**Wi-Fi (Android or iPhone):**

```bat
run_phone.bat --wifi
```

It auto-detects the computer's LAN IPv4. Override it when necessary:

```bat
run_phone.bat --wifi 192.168.1.10
run_phone.bat --wifi --device "iPhone cua Minh"
```

> The phone and the computer must be on the same network. Allow port 8000 in the
> firewall. For Wi-Fi the backend must listen on `0.0.0.0`; the script starts it
> that way and warns you if an already-running backend only listens on localhost.
> The API base URL is resolved centrally in
> `english_ai/lib/core/constants/app_config.dart`; no code edits needed.

### VS Code: one key

Open the repository in VS Code and press **F5**:

- **Full stack (Backend + Flutter)** — starts the backend and the emulator, then runs the app.
- **Flutter (Web / Chrome)** — web without the emulator.
- **Backend (FastAPI)** — backend only.

`.vscode/` is committed, so no manual setup is required. Select your Python
interpreter (`backend/venv`) the first time.

---

## 🤖 Android emulator guide

### Hardware requirements

| Component | Requirement |
|---|---|
| CPU | VT-x (Intel) or AMD-V/SVM, **enabled in BIOS** |
| Virtualisation layer | AEHD or Windows Hypervisor Platform (Windows), KVM (Linux), Hypervisor.framework (macOS) |
| RAM | 8 GB minimum, 16 GB comfortable |
| Disk | SSD strongly recommended (HDD makes Gradle/emulator painfully slow) |
| GPU | **No dedicated GPU required** — Intel/AMD integrated graphics are enough; the script falls back to software rendering if needed |

The script runs `emulator -accel-check` first and stops with instructions if
virtualisation is unavailable, instead of hanging for minutes.

### What the script does

- Reuses an already-running emulator instead of killing other instances.
- Creates `englishai_light` from API 29 if it does not exist.
- Picks a light profile:

  | Host | Cores | RAM | Resolution |
  |---|---:|---:|---|
  | ≥ 8 logical CPUs, ≥ 8 GB RAM | 4 | 2048 MB | 720×1280 @ 320 dpi |
  | ≤ 4 logical CPUs or < 8 GB RAM | 2 | 1536 MB | 540×960 @ 240 dpi |

- Uses the host GPU (`-gpu auto`), so integrated graphics are fine.
- **Disables quick-boot snapshots by default.** Emulator 36 otherwise writes a
  ~2 GB RAM snapshot on first boot. Pass `-Snapshot` (PowerShell) or
  `--snapshot` (bash) to opt back in for faster boots.
- No SD card partition.

Useful options:

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File scripts\android_ensure_emulator.ps1 -Gpu host
powershell -ExecutionPolicy Bypass -File scripts\android_ensure_emulator.ps1 -Headless
powershell -ExecutionPolicy Bypass -File scripts\android_ensure_emulator.ps1 -ForceCreate
```

```bash
# macOS / Linux
./scripts/android_ensure_emulator.sh --gpu host
./scripts/android_ensure_emulator.sh --headless
./scripts/android_ensure_emulator.sh --force-create
```

> The data partition reports **6 GB logical** in `df`, but the image is sparse:
> a fresh AVD with the app installed uses **~400 MB on disk**. Do not try to
> shrink it through `disk.dataPartition.size` — emulator 36 ignores that key and
> recreates a 6 GB file.

### Installing the Android SDK pieces manually

```bash
sdkmanager --install \
  "platform-tools" "emulator" "cmdline-tools;latest" \
  "platforms;android-36" "build-tools;36.0.0" \
  "system-images;android-29;default;x86_64"
```

On **Apple Silicon** replace the last line with:

```bash
"system-images;android-29;default;arm64-v8a"
```

`platforms;android-36` is required: the project forces `compileSdk 36` for all
subprojects (see `english_ai/android/build.gradle.kts`).

---

## 🔐 Configuration

The app reads the backend URL from `AppConfig`:

| Platform | Default |
|---|---|
| Web / desktop | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| Real device (USB) | `run_phone.bat` — `http://127.0.0.1:8000` via `adb reverse` |
| Real device (Wi-Fi) | `run_phone.bat --wifi` — `http://<LAN_IP>:8000` |

Backend secrets live in `backend/.env` (git-ignored). Start from
`backend/.env.example`. `JWT_SECRET_KEY` is required in production; in
development a random one is generated (tokens are invalidated on restart).

### Google Sign-In (optional)

1. Backend: set `GOOGLE_OAUTH_CLIENT_ID` in `backend/.env`.
2. Flutter: run with
   `--dart-define=GOOGLE_CLIENT_ID=<web-client-id>.apps.googleusercontent.com`.
3. For Android, register the debug SHA-1 of **your** machine in Google Cloud
   Console, otherwise you get `ApiException: 12500`.

Email/password login works without any of this. The emulator image used here
(`default`) has no Google Play Services, so Google Sign-In cannot work on it.

### What is not in the repository

- `backend/.env`, database credentials, Supabase keys
- Python virtualenv, Flutter build output, Gradle caches
- AVDs and Android system images (they live outside the repo, on each machine)

---

## 🧪 Troubleshooting

| Symptom | Fix |
|---|---|
| `record_linux` / `record_platform_interface` version conflict | `flutter pub get` — `pubspec.lock` pins `record 6.x`; run `flutter clean` if stale |
| Kotlin daemon / cache errors | Already mitigated (`kotlin.incremental=false`); run `flutter clean` and rebuild |
| `compileSdk` mismatch | Install `platforms;android-36`; the root build script forces `compileSdk 36` |
| App stuck on the splash screen | Start the backend first: `GET /health` must return 200 |
| Emulator very slow | Use `-Gpu host`, close other apps, and run `flutter run --profile` |
| `Emulator did not come online` | Check `%TEMP%\englishai-emulator\stderr.log` (Windows) or `/tmp/englishai-emulator/stdout.log` |
| `Hardware acceleration is NOT available` | Enable VT-x/AMD-V in BIOS; install AEHD or enable Windows Hypervisor Platform |
| Model file is 130 bytes | `git lfs install && git lfs pull` |
| Port 8000 busy | Run on another port and pass `--dart-define=API_BASE_URL=http://localhost:<port>` |
| Google Sign-In fails with 12500 | Missing Play Services image or unregistered SHA-1; use email/password |
| `Attempted to add an invalid command to the render pass` | Impeller warning on the emulator; harmless |

---

## 📋 Development phases

| Phase | Status | Focus |
|---|---|---|
| Phase 1 | ✅ Complete | Foundation — Auth, Onboarding, Theme, Backend |
| Phase 2 | ✅ Complete | Learning — Vocab (SM-2), Grammar, Listening, Reading, Placement |
| Phase 3 | ✅ Complete | AI — Tutor chat, Exercise Gen, Writing Eval (local LLM + Gemini/OpenAI fallback) |
| Phase 4 | ✅ Complete | Speech — STT, TTS, Voice conversation, Pronunciation |
| Phase 5 | 🚧 In progress | Optimization — CI/CD, Alembic migrations, Docker, hardening |

## 📄 License

Private project — All rights reserved.
