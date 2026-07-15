# Kaam Web

This folder contains the Kaam Next.js web application foundation for the `web-development` branch. The Flutter mobile app remains at the repository root.

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
```

Only browser-safe Supabase values belong here. Never place service-role keys, database passwords, document URLs, payment references, OTPs, or private candidate data in browser code or committed files.

## Commands

```bash
npm run dev
npm run lint
npm run build
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
- Login and registration screens prepared for Supabase email OTP
- Browser-safe Supabase client
- Server-side session restoration
- Candidate and employer dashboard route protection
- Candidate dashboard shell
- Employer dashboard shell
- Employer candidate search UI foundation
- Admin placeholder notice

## Known Incomplete Features

- Full candidate profile editing
- Web document upload and OCR
- Real candidate search results
- Shortlist, messages, matches, and job-post workflows
- Admin panel
- Payment or production membership activation

## Branch Workflow

Work for this application belongs on `web-development`. Do not merge mobile, admin, or production branches from this task.
