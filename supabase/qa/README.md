# Hardened Kaam QA schema bundle

This directory is preparation-only until a separate initialization approval. It is locked to QA ref `skswbbcimwvwmuiapjnd`; Production ref `bhuhojzqxnvwbsypijac` is always refused.

Prepare and validate locally:

```powershell
node supabase/qa/scripts/verify-target.mjs
node supabase/qa/scripts/prepare-bundle.mjs
node supabase/qa/scripts/apply-qa-schema.mjs --project-ref skswbbcimwvwmuiapjnd --supabase-url https://skswbbcimwvwmuiapjnd.supabase.co
```

The last command is dry-run by default and opens no database connection. The future write-capable form additionally requires `QA_DATABASE_URL` containing the QA ref and `--execute`. Never paste that connection string into a command, Git, logs, or chat.

The executor applies one file at a time, stops on the first error, and records an external JSONL ledger. Historical files remain unchanged. The 32nd source is the QA reset tool; the security and Data API patches follow it before any fixtures. No fixture, user, object, external secret, or Production data is included.

## Ledger and rollback

Use the append-only external `qa-schema-apply.log.jsonl` as the first-run ledger rather than falsifying Supabase migration history for legacy files. It is gitignored and records order, path, checksum, timestamps, and outcome. After a successful clean initialization, a later native baseline migration can be designed separately.

Each historical source controls its own transaction (`BEGIN`/`COMMIT` where authored); the executor does not wrap the entire chain. Extensions, Storage bucket metadata, and PostgREST reload notifications are transaction-sensitive and therefore remain per-file. On failure, stop. For an empty QA database, the safest approved recovery is a QA-only rebuild followed by checksum replay—not reverse SQL and never a Production reset.

## Candidate search projection

`public_candidate_search` exposes: candidate ID, first-name projection, headline, nationality, current/preferred country and city, job categories, skills, languages, experience, expected salary range/currency, availability, visa status, profile-photo URL, bio, verification flag, and timestamps. It deliberately excludes email, phone, documents, payment data, and full employer/contact records. Post-migration tests must prove hidden, incomplete, document-unverified, or membership-inactive candidates are absent.

## Storage expectations

- `kaam-public`: public reads as designed; authenticated writes must be owner-scoped.
- `kaam-private`: never public; candidate/employer owner access and explicit admin review only.

The post-migration assertions require both buckets and zero Storage objects. No Production objects are copied.

## Post-initialization patch 35

After the successful 34-unit initialization, apply the separately checksum-locked
`patches/003_qa_post_init_privilege_repair.sql` only under its own explicit approval.
It is not part of the initial bundle and does not change the historical 34 checksums.
The intended grants are documented in `PRIVILEGE_MATRIX.md`; verify the result with
`post-repair-assertions.sql`.
