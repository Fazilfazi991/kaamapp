# Kaam Web

This folder contains the Kaam Next.js web application, including public, candidate, employer, and admin routes. The Flutter mobile app remains at the repository root.

## Requirements

- Node.js compatible with Next.js 16
- npm
- Access to the same Supabase project used by the mobile app

## Installation

```bash
npm install
```

## Environment Variables

Create a local `web/.env.local` file from `web/.env.example`:

```text
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_EMAIL_OTP_LENGTH=6
OCR_EDGE_FUNCTION=
```

Only browser-safe Supabase values belong in `NEXT_PUBLIC_*` variables. Never place service-role keys, database passwords, document URLs, payment references, OTPs, or private candidate data in browser code or committed files. The current admin implementation uses the authenticated Supabase session and does not require a service-role key.

Set these variables in Vercel for Production, Preview, and Development:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_EMAIL_OTP_LENGTH`
- `OCR_EDGE_FUNCTION` when candidate document OCR is enabled

Supabase Auth URL configuration should include the production site URL `https://kaamapp.vercel.app`, the admin entry URL `https://kaamapp.vercel.app/admin`, and localhost development URLs such as `http://localhost:3000` and `http://localhost:3000/admin`. This app verifies email OTPs in-app, so no separate callback route is required by the current flow.

## Commands

```bash
npm run dev
npm run lint
npm run build
npm test
```

## Folder Structure

```text
src/
  app/
  components/
  config/
  features/
  lib/
  types/
```

## Current Scope

- Public homepage
- Login and registration screens using Supabase email OTP
- Browser-safe Supabase client
- Server-side session restoration
- Candidate and employer dashboard route protection
- Candidate dashboard shell
- Employer dashboard shell
- Employer candidate search UI foundation
- Admin dashboard under `/admin`
- Candidate and employer document review routes
- Admin user, report, and audit surfaces backed by the current schema where available

## Admin Routes

- `/admin`
- `/admin/candidates`
- `/admin/candidate-documents`
- `/admin/employers`
- `/admin/employer-documents`
- `/admin/users`
- `/admin/reports`
- `/admin/audit`

## Authentication QA

See `docs/auth-qa-checklist.md` for manual checks covering candidate-to-employer logout/login, employer-to-candidate logout/login, wrong role-tab selection, refresh, and browser restart.

See `docs/candidate-onboarding-qa-checklist.md` for candidate onboarding, profile editing, skills, location, contact privacy, and profile photo checks.

## Branch Workflow

Production deployment currently tracks `main`; feature work may still happen on `web-development` or `admin-development` before being merged through `develop` and into `main`.
