# QA post-initialization privilege matrix

This is the reviewed target for patch 35. Row Level Security remains authoritative for every public application table. `anon` has no direct public-schema relation access. `service_role` retains server-only broad access and must never be exposed to clients.

## Authenticated relation access

| Access | Objects | Reason |
|---|---|---|
| `SELECT, INSERT, UPDATE` | `profiles`, `candidate_profiles`, `employer_companies` | Account onboarding and owner/admin profile workflows |
| `SELECT, INSERT, UPDATE, DELETE` | `employer_hiring_requirements`, `interest_requests`, `saved_candidates`, `verification_documents`, `candidate_documents`, `candidate_document_versions`, `candidate_skills`, `candidate_custom_skills`, `employer_candidate_views`, `employer_hiring_requirement_skills` | RLS-controlled owner/admin workflows |
| `SELECT, INSERT` | `matches`, `chat_messages` | Match creation/admin workflow and participant messaging; no client edit/delete |
| `SELECT` | `candidate_document_notifications`, `candidate_memberships`, `candidate_membership_payments`, `qa_reset_logs` | Read-only status/history |
| `SELECT, UPDATE` | `notifications` | Read and own read-state updates; creation is server/admin-triggered |
| `SELECT, INSERT, UPDATE` | `user_push_devices`, `notification_preferences` | Own device/preference registration; no direct delete flow |
| `SELECT, INSERT, UPDATE, DELETE` | `admin_notifications`, `admin_notification_recipients`, `qa_allowed_accounts` | Admin-only RLS workflows |
| `SELECT` | `skill_categories`, `skills`, `industries`, `job_categories`, `job_roles`, `job_role_aliases`, `competency_skills`, `job_role_skills`, `legacy_role_mappings`, `legacy_role_mapping_coverage` | Read-only catalogs/report |
| `SELECT` | `public_candidate_search` | Curated authenticated employer search API |
| none | `admin_push_device_status` | Push/admin-notification QA is deferred; underlying owner-privileged view cannot safely serve ordinary authenticated users |

No authenticated public relation receives `TRUNCATE`, `TRIGGER`, or `REFERENCES`. There are no public-schema sequences in the initialized QA catalog.

## Function access

- Authenticated user RPCs: `bootstrap_user_profile`, `is_admin`, `my_role`, membership/visibility checks, matching/contact helpers, candidate search helpers, `qa_reset`, and the QA test-membership helper. Each has no `PUBLIC` or `anon` execute grant.
- Internal trigger/notification functions: service role only; no direct `PUBLIC`, `anon`, or authenticated execution.
- Stripe fulfillment/failure: service role only.
- `set_updated_at`, `candidate_profile_completed`, and `kaam_normalize_catalog_text` receive fixed paths. The catalog normalizer remains executable only by authenticated/service roles because catalog constraints and search use it.

## Privileged views and Storage

`public_candidate_search` remains an intentional owner-privileged curated projection. It returns 22 non-contact fields and filters through `candidate_visible_to_employers`, which enforces active account, completed profile, verified identity document, active membership, and employer visibility. It excludes email, phone, documents, payment details, and full names. With `PUBLIC`/`anon` denied and authenticated limited to `SELECT`, the Security Advisor finding is accepted as intentional.

`admin_push_device_status` remains defined for later push work but is unavailable to `PUBLIC`, `anon`, and authenticated. Server code can use `service_role` when that work is separately enabled.

`kaam-public` remains a public bucket, so known public object URLs continue to work. The broad `kaam_public_read` RLS policy is removed because it additionally allowed anonymous Storage API listing. `kaam-private` remains private with owner/admin/eligible-employer policies only.

`pg_trgm` remains in `public` because moving an installed extension is outside this narrow repair and its extension functions are not KAAM privileged routines. This warning is deferred to a separately rehearsed migration.
