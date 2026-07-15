# Kaam App

Kaam is a privacy-first job matching application for candidates and employers. This repository currently contains the existing Flutter mobile application at the project root, plus Supabase database migrations and Edge Function code used by the app.

## Current Status

- Flutter mobile app remains in the root project structure.
- Supabase migrations and setup notes live in `supabase/`.
- Local environment files are required for development but must not be committed.
- A future web application and admin panel are planned, but they are not created in this setup task.

## Technology Stack

- Flutter and Dart for the mobile application
- Supabase for authentication, database, storage, memberships, matching, chat, and document verification support
- Supabase Edge Functions for server-side integrations such as OCR
- Android project files under `android/`

## Supabase Backend

The Flutter app uses the same Supabase backend that future web and admin clients will use. Database migrations are stored in `supabase/` and should be reviewed before applying to any shared or production environment.

Never place Supabase service-role keys, database passwords, Azure OCR keys, API secrets, or other private credentials in Flutter, browser code, APKs, GitHub, or client-visible assets.

## Branch Strategy

- `main`: stable and reviewed releases only
- `develop`: integration and testing branch
- `mobile-development`: Flutter mobile work
- `web-development`: future web application work
- `admin-development`: future admin panel work

Use pull requests into `develop` for feature work. Merge `develop` into `main` only for stable releases.

## Local Setup

1. Install Flutter and confirm it is available:

   ```bash
   flutter --version
   ```

2. Create a local environment file from the example:

   ```bash
   cp .env.example .env
   ```

3. Fill `.env` with local development values. Keep real secrets out of Git.

4. Install dependencies:

   ```bash
   flutter pub get
   ```

## Environment Variables

Use `.env.example` as the safe reference for required variable names. It contains placeholder values only.

Expected variables include:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `KAAM_USE_DEMO_FALLBACK`
- `EMAIL_OTP_LENGTH`
- `QA_MODE`
- `QA_CANDIDATE_EMAIL`
- `QA_EMPLOYER_EMAIL`
- `QA_ADMIN_EMAIL`
- `OCR_EDGE_FUNCTION`

Real `.env`, `.env.local`, `.env.qa`, `.env.production`, Supabase service-role keys, Azure OCR keys, API secrets, Android signing files, and private credentials must never be committed.

## Flutter Commands

Install dependencies:

```bash
flutter pub get
```

Analyze the app:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Run the mobile app:

```bash
flutter run
```

Select an environment file when needed:

```bash
flutter run --dart-define=KAAM_ENV_FILE=.env.qa
```

## Planned Web Application

The planned web application will use Next.js with TypeScript and live in a future `/web` folder. It will use the same Supabase project as the Flutter app and reuse authentication, candidate profiles, employer profiles, skills, matching, chat, document verification, memberships, and storage.

The web application is expected to include candidate, employer, and admin interfaces. Supabase service-role credentials must never be exposed in browser code.

## Planned Admin Panel

The planned admin panel will share the same backend and should be developed separately on the appropriate branch. Administrative operations that require elevated permissions must run server-side only.
