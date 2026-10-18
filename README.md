# FinMate — Personal Finance Tracker

Android-only Flutter app + Python FastAPI backend + Supabase (PostgreSQL).
Features: manual/Email/OCR transaction input, dashboard, budgets + FCM alerts,
AI Financial Assistant (Gemini), Gmail auto-import, account deletion.
Clean Architecture (presentation/domain/data) on mobile, REST+JSON backend.

## Project structure

```
FinMate/
  backend/                    # FastAPI (Python 3.10+)
    app/main.py               # app + CORS + /health + 15-min Gmail cron
    app/core/                 # config (.env), security (bcrypt/JWT/Fernet), deps (DB+auth)
    app/models/models.py      # SQLAlchemy: users/transactions/categories/budgets/oauth_tokens/insights
    app/schemas/schemas.py    # Pydantic request/response
    app/services/             # parsers, gmail, budget+FCM, AI/Gemini
    app/api/routers/          # auth, finance (txn+category), insight (dashboard/budget/AI/gmail)
    app/db/supabase_schema.sql
    tests/test_api.py         # pytest endpoint tests
  finmate_flutter/            # Flutter (Android minSdk 26)
    lib/main.dart             # ProviderScope, Firebase/FCM init
    lib/core/                 # constants, theme (M3), api_client (Dio+JWT), receipt_parser
    lib/data/                 # models + ApiService (all REST calls)
    lib/presentation/         # providers (Riverpod) + 5-tab screens
  README.md
```

## 1. Database (Supabase, free tier)

1. Create project at supabase.com → copy **Postgres connection string**, **Project URL**, **anon/service key**.
2. SQL Editor → run `backend/app/db/supabase_schema.sql` (creates tables + default categories).
3. (Optional) Enable RLS and add `auth.uid() = user_id` policies — see comments at bottom of the SQL file.

## 2. Backend setup

```bash
cd backend
python -m venv .venv && .venv/Scripts/activate   # Windows
pip install -r requirements.txt
copy .env.example .env   # fill: DATABASE_URL, JWT_SECRET, ENCRYPTION_KEY, GEMINI_API_KEY,
                         # GOOGLE_CLIENT_ID/SECRET/REDIRECT, SUPABASE_*, FCM_CREDENTIALS_JSON
# Generate Fernet key:
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
uvicorn app.main:app --reload --port 8000
# Docs: http://localhost:8000/docs | Health: /health
pytest -q
```

Deploy (Railway/Render free tier): set root `backend/`, start command
`uvicorn app.main:app --host 0.0.0.0 --port $PORT`, add all `.env` vars,
place `firebase-service-account.json` via secret file. All traffic is HTTPS.

Auth notes: passwords are **bcrypt-hashed**, Gmail tokens are **Fernet-encrypted**,
all user queries filtered by `user_id` from JWT. `/auth/logout` is stateless
(client discards token). Gmail cron runs every 15 min (`app/main.py`).

## 3. Flutter setup (Android only, min SDK 26)

```bash
cd finmate_flutter
flutter pub get
# Point at backend (emulator localhost = 10.0.2.2):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
flutter test
flutter build apk --release   # distribute APK directly (no Play Store)
```

Android config:
- `android/app/build.gradle`: `minSdk 26`, `compileSdk 34`.
- `android/app/src/main/AndroidManifest.xml`: add
  `CAMERA`, `READ_EXTERNAL`/`READ_MEDIA_IMAGES`, `INTERNET`, `POST_NOTIFICATIONS` permissions.
- Firebase: add `google-services.json`, apply `com.google.gms.google-services` plugin
  (FCM + `firebase_messaging`; app subscribes/displays budget alerts in `lib/main.dart`).
- Google Sign-In / OAuth consent: SHA-1 of debug key + Gmail API scope;
  backend `GOOGLE_REDIRECT_URI` must match OAuth client.

State management: **Riverpod** throughout (`lib/presentation/providers/providers.dart`).
HTTP: **Dio**. Tokens: **flutter_secure_storage**. OCR: **google_mlkit_text_recognition**
(on-device, `lib/core/receipt_parser.dart` + `AddTxnScreen._scan`, confirm-before-save).

## API endpoints

Auth/user: `POST /auth/register|login|logout|reset-password`,
`GET|PUT /user/profile`, `DELETE /user/account` (cascades all data).
Gmail: `POST /oauth/gmail/connect`, `GET /oauth/gmail/callback`,
`POST /oauth/gmail/revoke`, `POST /gmail/import`.
Finance: `GET|POST /transactions`, `GET /transactions/search?q=&type=&category_id=&start=&end=`,
`PUT|DELETE /transactions/{id}`, `GET|POST /categories`, `PUT /categories/{id}`.
Insights: `GET /dashboard/summary`, `GET /dashboard/expense-breakdown`,
`GET|POST /budgets`, `PUT /budgets/{id}`, `POST /ai/chat`, `GET /insights?refresh=true`.

## Performance / security / privacy

- Targets: dashboard <2s, OCR <5s (on-device), AI <10s; graceful loading/error/empty states everywhere.
- TLS 1.2+ (hosting-enforced), bcrypt, encrypted OAuth tokens, data minimization
  (only unread bank mails, amounts/merchant/date), user can revoke Gmail + delete all data.
