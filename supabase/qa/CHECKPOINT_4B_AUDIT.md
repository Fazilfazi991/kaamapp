# Checkpoint 4B audit record

## Scope and target

- QA project: `skswbbcimwvwmuiapjnd`, verified through the Singapore Session Pooler as `postgres.skswbbcimwvwmuiapjnd`.
- Production was rejected by the target guard and was not queried or changed.
- Pre-apply `auth.users`: 0.
- Historical initialization units 1–34 were not edited or replayed.

## Pre-repair findings

`authenticated` had all seven relation privileges (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `TRIGGER`, `REFERENCES`) on 36 public tables/views. `qa_allowed_accounts` was the only exception and already lacked the three owner-like privileges. `PUBLIC` and `anon` had no public-relation grants. No public-schema sequences existed.

The broad grants included all application tables, all catalog tables, `public_candidate_search`, `admin_push_device_status`, and `legacy_role_mapping_coverage`. They came from historical relation ACLs and survived the initial additive grant patch.

The 33 KAAM-owned public routines comprised 29 `SECURITY DEFINER` and four invoker routines. Privileged definers had no unexpected `PUBLIC` or `anon` execution. `qa_reset` was authenticated/service only; Stripe fulfillment/failure was service only. The only public/anonymous KAAM helper was the non-definer catalog normalizer. Three invoker helpers had mutable paths.

Storage had a public-bucket `SELECT` policy for role `public`, allowing anonymous Data API object listing in addition to public URL retrieval. The private bucket was non-public and its policies were authenticated, owner/admin/eligible-employer scoped.

## Applied repair

Patch 35 revoked all public-schema table/sequence privileges from `PUBLIC`, `anon`, and `authenticated`, then restored the reviewed per-object grants in `PRIVILEGE_MATRIX.md`. It also:

- made `public_candidate_search` authenticated `SELECT`-only;
- removed all authenticated access to `admin_push_device_status` while leaving service-role access;
- removed `kaam_public_read`, preserving the public bucket and public object URLs while preventing anonymous Storage API listing;
- fixed search paths for `set_updated_at`, `candidate_profile_completed`, and `kaam_normalize_catalog_text`;
- removed `PUBLIC`/`anon` execution of the catalog normalizer.

No sequence grants changed because the QA public schema has no sequences. Service-role table grants were intentionally retained for trusted server workflows.

## Advisor disposition

Security Advisor changed from **2 errors / 19 warnings / 0 info** to **1 error / 15 warnings / 0 info**.

- `admin_push_device_status`: resolved by removing authenticated access.
- `public_candidate_search`: **ACCEPTED — INTENTIONAL PRIVILEGED VIEW**. It is authenticated `SELECT`-only, exposes 22 curated non-contact fields, and filters through `candidate_visible_to_employers`; `PUBLIC` and `anon` have no access.
- Three mutable-search-path warnings: resolved with `search_path=pg_catalog`.
- Public-bucket listing warning: resolved by removing the listing policy; bucket public-read URLs remain intentional.
- `pg_trgm` in `public`: safe to defer; moving an installed extension is outside this narrow patch.
- Fourteen signed-in `SECURITY DEFINER` warnings are intentional authenticated RPCs/RLS helpers: `activate_test_candidate_membership`, `bootstrap_user_profile`, `candidate_documents_verified`, `candidate_matches_with_access`, `candidate_membership_active`, `candidate_visible_to_employers`, `employer_matches_with_contact`, `is_admin`, `match_chat_enabled`, `my_role`, `qa_reset`, `reveal_candidate_contact`, `search_candidates_by_skills`, and `set_candidate_employer_visibility`. All deny `PUBLIC` and `anon`; internal and payment definers remain server-only.

Performance Advisor remained **0 errors / 54 warnings / 45 info**. Those pre-existing performance recommendations are outside this security repair.

## Regression verification

- `auth.users`, candidate profiles, employer companies, and Storage objects: 0.
- Taxonomy: 32 industries, 394 job roles, 306 competency skills.
- Public tables without RLS: 0.
- `pg_cron`, `pg_net`, and `public.app_config`: absent.
- Production-ref column defaults: 0.
- No Auth, OAuth, Vercel, SMTP, OTP, fixture, user, or external-integration configuration was performed.
