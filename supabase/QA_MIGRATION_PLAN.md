# KAAM empty-QA migration plan

Status: planning checkpoint only. No SQL in this document has been applied.

## Target identity and hard stop

| Item | Verified value |
| --- | --- |
| Production project | `KAAM APP` |
| Production ref | `bhuhojzqxnvwbsypijac` |
| Production region | `ap-northeast-2` |
| QA project | `Kaam QA` (dashboard display name) |
| QA ref | `skswbbcimwvwmuiapjnd` |
| QA URL | `https://skswbbcimwvwmuiapjnd.supabase.co` |
| QA region | `ap-southeast-1` |
| Organization | `Zorx Dashboard` (`ooeeuvrflbeqtbwydtij`) |

The QA and Production refs differ. The regions do not: QA is Singapore while Production is Seoul. This is acceptable for functional Auth QA but not a faithful latency/data-residency replica. Do not delete or recreate QA without separate approval.

Before any future write, run:

```powershell
node scripts/assert-qa-supabase-target.mjs --project-ref skswbbcimwvwmuiapjnd --supabase-url https://skswbbcimwvwmuiapjnd.supabase.co
```

The repository is currently CLI-linked to Production. That link is not authorization to write. Do not use an implicit `supabase db push`, `db reset`, or `migration up`. A future executor must identify QA explicitly, run the guard, and prove the database host/ref again immediately before execution.

## Proposed initial Auth-QA execution order

This is a reviewed manifest, not a ready-to-run CLI migration directory. Execute each listed source once, in this order, only after the next approval checkpoint. Record every applied filename and checksum in a QA-only ledger.

| Order | Canonical source | Decision |
| ---: | --- | --- |
| 1 | `001_kaam_initial_schema.sql` | Required foundation, buckets and initial RLS |
| 2 | `002_mvp_functionality_patch.sql` | Required compatibility patch |
| 3 | `003_candidate_privacy_settings.sql` | Required candidate privacy |
| 4 | `004_employer_hiring_requirements.sql` | Required employer onboarding |
| 5 | `005_candidate_identity_documents.sql` | Required document schema |
| 6 | `006_candidate_document_phase2.sql` | Required document schema |
| 7 | `008_candidate_document_versions_repair.sql` | Required repair |
| 8 | `009_skill_categories_and_candidate_skills.sql` | Required legacy catalog compatibility |
| 9 | `010_identity_document_save_repair.sql` | Required repair |
| 10 | `011_candidate_membership_visibility.sql` | Required baseline membership/visibility |
| 11 | `012_employer_match_contact_rules.sql` | Required baseline match/contact rules |
| 12 | `013_notification_foundation.sql` | Required because employer auto-activation calls `create_notification` |
| 13 | `013_admin_notifications.sql` | Required notification schema parity; the duplicate numeric prefix is ordered explicitly here |
| 14 | `014_admin_broadcast_push_types.sql` | Required notification type/schema parity; delivery remains disabled |
| 15 | `015_admin_notification_delivery_status.sql` | Required notification status schema parity; delivery remains disabled |
| 16 | `017_fix_employer_company_status_triggers.sql` | Required corrected trigger behavior |
| 17 | `018_bootstrap_user_profile.sql` | Required initial Auth bootstrap definition |
| 18 | `019_passport_front_back_documents.sql` | Required onboarding/document parity |
| 19 | `020_candidate_qa_batch_1_profile_fields.sql` | Required candidate onboarding fields |
| 20 | `migrations/021_matching_chat_qa_batch_1.sql` | Canonical matching/chat copy |
| 21 | `migrations/022_employer_saved_recently_viewed.sql` | Canonical saved/recent copy |
| 22 | `migrations/023_candidate_profile_photo_employer_read.sql` | Canonical photo-policy copy |
| 23 | `migrations/20260731000400_candidate_profile_visa_expiry.sql` | Required current candidate onboarding field |
| 24 | `migrations/20260807151913_role_skills_taxonomy_phase_1_catalog.sql` | Required static reference catalog |
| 25 | `migrations/20260807160918_employer_taxonomy_dual_write_phase_2a.sql` | Required current employer taxonomy behavior |
| 26 | `migrations/20260816000100_candidate_profile_email_privacy_repair.sql` | Required privacy repair |
| 27 | `migrations/20260817031957_candidate_profile_phone_privacy_repair.sql` | Required privacy repair |
| 28 | `migrations/20260817133058_stripe_candidate_membership_payments.sql` | Schema required by later lifetime migration; no credentials, webhook, or payment execution |
| 29 | `migrations/20260817150126_employer_auto_activation.sql` | Required newer replacement for bootstrap/employer status behavior |
| 30 | `migrations/20260821120000_candidate_lifetime_membership.sql` | Required current membership model; depends on order 28 |
| 31 | `migrations/20260821120001_restrict_candidate_membership_function_access.sql` | Required least-privilege repair; run immediately after order 30 |
| 32 | `007_qa_reset_tools.sql` | QA-only and last, after the adjustments below |

Static industry, role, skill, and competency taxonomy rows are allowed. Production user, candidate, employer, admin, document, chat, analytics, payment, notification, and Storage object data are prohibited.

## Deferred from initial Auth QA

These changes are not dependencies of the initial candidate/employer Auth journey and add avoidable external or administrative surface:

- `016_scheduled_notifications.sql`: omit completely. Do not install `pg_cron`, `pg_net`, jobs, HTTP calls, or a schema-only fork yet.
- `migrations/024_production_push_hardening.sql`: defer push tables/functions. It contains legacy `auth.role()` checks and push is out of scope.
- `migrations/025_remote_app_config.sql`: defer the subsystem. Its constraint permits only development/staging/production and it seeds Production-labelled rows. If later needed, create a separately reviewed migration that supports `qa` and seeds QA-only values.
- Verification/admin-document suite: defer `migrations/20260731000100_candidate_manual_verification.sql`, `20260731000200_candidate_verification_notifications.sql`, `20260731000300_employer_candidate_manual_verification.sql`, `20260801000100_identity_document_validation.sql`, and `20260801000200_candidate_document_review_notifications.sql`. The notification migrations depend on push/outbox behavior, and identity validation needs a separately configured OCR flow. Add this suite later in timestamp order after those dependencies are reviewed.
- `migrations/20260822090000_visitor_analytics.sql`: defer; no required Auth migration depends on it.

## Excluded and duplicate files

Never execute `deploy_019_020_candidate_qa_batch_1.sql`. It is a Production deployment bundle with a hard-coded live target, not an empty-QA migration.

| File A | File B | Relationship | Canonical choice |
| --- | --- | --- | --- |
| root `021_matching_chat_qa_batch_1.sql` | `migrations/021_matching_chat_qa_batch_1.sql` | Exact duplicate | migrations copy |
| root `022_employer_saved_recently_viewed.sql` | `migrations/022_employer_saved_recently_viewed.sql` | Exact duplicate | migrations copy |
| root `023_candidate_profile_photo_employer_read.sql` | `migrations/023_candidate_profile_photo_employer_read.sql` | Exact duplicate | migrations copy |
| root `024_candidate_manual_verification.sql` | `migrations/20260731000100_candidate_manual_verification.sql` | Semantic duplicate; only trailing newline differs | timestamped copy, deferred |
| root `025_candidate_verification_notifications.sql` | `migrations/20260731000200_candidate_verification_notifications.sql` | Semantic duplicate; only trailing newline differs | timestamped copy, deferred |
| root `026_employer_candidate_manual_verification.sql` | `migrations/20260731000300_employer_candidate_manual_verification.sql` | Semantic duplicate; only trailing newline differs | timestamped copy, deferred |
| root `027_identity_document_validation.sql` | `migrations/20260801000100_identity_document_validation.sql` | Exact duplicate | timestamped copy, deferred |
| root `028_candidate_document_review_notifications.sql` | `migrations/20260801000200_candidate_document_review_notifications.sql` | Exact duplicate | timestamped copy, deferred |
| root `018_bootstrap_user_profile.sql` | `migrations/20260817150126_employer_auto_activation.sql` | Newer replacement plus employer-status/notification changes | Run both in chronological order |
| root `011`/`012` membership and match helpers | Stripe/lifetime membership migrations | Partially overlapping newer definitions | Run baseline, then Stripe, lifetime, access restriction |
| legacy root skill catalog | timestamped role-skills taxonomy | Distinct compatibility and normalized catalogs | Run both |

## Required QA-specific adjustments before execution

Create a reviewed QA-only hardening patch rather than editing historical sources:

1. Revoke default `PUBLIC`/`anon` execute on required public `SECURITY DEFINER` functions, then grant only the intended role. Baseline files often grant `authenticated` without first revoking default `PUBLIC` execute.
2. For `qa_reset`, add `revoke all on function public.qa_reset(text,text,text) from public, anon` before granting `authenticated`. Keep its `auth.uid()`, email allowlist, role, and self-owned Storage-path checks. Do not seed real QA inboxes in Git.
3. Explicitly restrict `is_admin`, `my_role`, membership, visibility, matching/contact, skill-search, document-save, and bootstrap RPCs. Service-only payment fulfillment/failure functions must remain inaccessible to anon/authenticated.
4. Preserve the current `set search_path` declarations. All reviewed definer functions have an explicit path; `qa_reset` intentionally includes `storage` and must reference only fixed object names.
5. Add explicit table/sequence/function grants because new Supabase projects may not automatically grant Data API roles. Do not assume schema creation makes APIs reachable.
6. Keep all Stripe credentials/webhooks absent. The membership tables and functions may exist, but service-role fulfillment must not be invoked.
7. Do not add QA values to `025_remote_app_config.sql`; that entire migration remains deferred.

### SECURITY DEFINER findings

- `bootstrap_user_profile` is structurally sound: explicit path, authenticated-user check, role whitelist, role-conflict and blocked-account checks, and self-only inserts. Its initial migration revokes `PUBLIC`; the replacement should receive the same explicit grants in the hardening patch.
- Membership/visibility helpers use a fixed path and are needed inside RLS/search logic. Some accept arbitrary candidate IDs and intentionally return visibility booleans; restrict them to authenticated callers. The final access-restriction migration repairs the two current helpers. `activate_test_candidate_membership` remains a QA-only bypass and must be unavailable to anon.
- Match/contact RPCs bind returned rows to `auth.uid()` and `reveal_candidate_contact` permits only the matched candidate. Their logic is ownership-aware, but historical files need explicit `PUBLIC`/anon revokes.
- Document review RPCs perform admin checks and submission RPCs bind to `auth.uid()`; they are deferred with the document suite. Trigger functions are not directly callable but still use fixed paths.
- `qa_reset` validates authentication, allowlist, role, and self-owned rows/Storage prefixes. The missing explicit function revoke is a real least-privilege weakness to patch before installation. The table grants are protected by RLS, but should still be narrowed where possible.
- `is_admin` and `my_role` expose only current-user-derived values, so the default execute is low impact, not zero impact. Explicit role grants are recommended.

## `public_candidate_search` RLS recommendation

The view is a privileged, deliberately reduced candidate projection and can read underlying rows as its owner, bypassing callers' table RLS. Do not blindly add `security_invoker = true`: that could make the employer search empty unless equivalent employer-safe base-table policies are added first. For initial QA, retain the existing curated projection, revoke all from anon/PUBLIC, grant select only to authenticated, verify every exposed column, and regression-test hidden/incomplete candidates. A later security migration should either:

- retain it as an explicitly audited privileged API with a restricted owner and grants; or
- add equivalent safe underlying RLS policies and then convert it to `security_invoker = true`.

## Storage plan

`001` expects private/public bucket metadata and later document/photo policies expect these IDs:

- `kaam-public`: public profile/company assets such as candidate profile photos and employer logos; authenticated writes must remain owner-scoped.
- `kaam-private`: identity, passport, visa, and employer verification documents; never public; access must be owner/admin scoped.

No objects or Production bucket data will be copied. Bucket creation/policy verification is a separate checkpoint. Document migrations 005, 006, 008, 010, 019 and the deferred validation suite depend on `kaam-private`; migration 023 depends on the profile-photo policy for `kaam-public`.

## Edge Functions and external integrations

| Function | Initial QA decision |
| --- | --- |
| `delete-account` | Do not deploy; later use a QA-only service-role secret if lifecycle QA is approved |
| `passport-ocr` | Disabled; do not reuse Production OCR credentials |
| `send-push-notification` | Disabled |
| `process-notification-push-outbox` | Disabled |
| `process-scheduled-notifications` | Disabled |

No Production Google, Stripe, push, OCR, SMTP, service-role, webhook, or Vercel secrets may be reused.

## Post-migration verification (future checkpoint)

Run read-only verification after each approved batch:

```sql
select current_database(), current_user;
select count(*) from auth.users; -- must begin at zero
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public' and rowsecurity is false;
select routine_schema, routine_name, security_type
from information_schema.routines
where routine_schema = 'public' and security_type = 'DEFINER';
select table_schema, table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema in ('public', 'storage') and grantee in ('anon', 'authenticated');
select bucket_id, name
from storage.objects
order by bucket_id, name; -- must remain empty before fixture approval
select * from public.public_candidate_search; -- empty before fixtures
```

Also verify via catalog queries that `PUBLIC` and `anon` cannot execute restricted definer functions, authenticated users cannot call service-role payment functions, every intended table has RLS, no cron jobs exist, no network calls are configured, and the migration ledger contains each canonical file exactly once.

## Rollback/reset strategy

Because QA is empty, use staged batches and stop on the first failure. Capture schema-only dumps and the QA-only ledger between batches. Do not attempt ad-hoc reverse SQL against Production. Before real fixtures exist, the safest failed-initialization recovery is to recreate/reset only the positively re-verified QA database through an approved procedure, rerun the guard, and replay the manifest. Once fixtures exist, prefer a QA backup plus a reviewed forward repair. `007_qa_reset_tools.sql` resets allowlisted users' test state; it is not a schema rollback tool.
