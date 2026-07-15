# Development Workflow

This repository supports parallel mobile, web, and admin development through separate branches.

## Branch Purposes

- `main`: stable and reviewed releases only
- `develop`: integration and testing branch
- `mobile-development`: Flutter mobile work
- `web-development`: future Next.js web application work
- `admin-development`: future admin panel work

## Recommended Flow

1. Pull the latest `develop`.
2. Work only on the appropriate feature branch.
3. Commit small, clear changes.
4. Push the feature branch.
5. Open a pull request into `develop`.
6. Test before merging.
7. Merge `develop` into `main` only for stable releases.

## Parallel Codex Sessions

Do not let two Codex sessions edit and push to the same branch at the same time. Use separate branches or coordinate one session at a time to avoid overwriting work or creating confusing conflicts.

## Future Web Architecture Note

The planned web application will use Next.js with TypeScript and live in a future `/web` folder. It will use the same Supabase project as the Flutter app and reuse authentication, candidate profiles, employer profiles, skills, matching, chat, document verification, memberships, and storage.

The future web work should include candidate, employer, and admin interfaces. Supabase service-role credentials must never be exposed in browser code; privileged operations must run only in trusted server-side code.
