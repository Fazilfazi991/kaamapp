# Kaam Supabase Setup

Use `001_kaam_initial_schema.sql` on a new Kaam Supabase project.

For the current live project that already has the initial schema, run
`002_mvp_functionality_patch.sql` once in Supabase SQL Editor.

Steps:
1. Open the new Supabase project SQL Editor.
2. Paste and run `001_kaam_initial_schema.sql`.
3. Keep Flutter configured with only `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
4. Never place `SUPABASE_SERVICE_ROLE_KEY`, database passwords, JWT secrets, SMTP passwords, or private API keys in Flutter, APKs, GitHub, or client code.

The scripts create the tables, safe candidate search view, triggers, RLS policies, and storage buckets. Candidate private fields remain protected by RLS; employers should browse candidates through `public.public_candidate_search`.
