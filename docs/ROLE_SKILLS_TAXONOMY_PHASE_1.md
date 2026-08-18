# KAAM role and skills taxonomy — Phase 1

Phase 1 adds a new master catalog beside KAAM's existing candidate `skills`
catalog. It does not change Flutter, web UI, employer verification, candidate
visibility, matching, or legacy profile data.

## Canonical model

`Industry → Job category → Job role → Competency skill`

- An **industry** is a hiring domain, such as Restaurant / Food & Beverage.
- A **job category** narrows the domain, such as Kitchen or Front of House.
- A **job role** is the canonical occupation selected by candidates and
  employers, such as Porotta Maker or Electrician. Its UUID is the durable
  matching identifier; display text is never the identifier.
- A **competency skill** is an ability, such as Dough preparation or Electrical
  wiring. It must never be an occupation.

`job_role_aliases` stores only equivalent spellings, punctuation variants, and
common transliterations. Related occupations remain separate canonical roles:
for example, AC Technician and HVAC Technician remain distinct roles even
though search can show both as relevant results.

## Search contract

`search_job_roles(search_text, result_limit)` returns the canonical role UUID,
role/category/industry labels and slugs, a matched alias when applicable, and
a relevance value. It normalizes case, punctuation, and repeated whitespace,
and uses trigram/prefix matching. Clients must query active catalog data and
persist IDs, never a result's display label.

The Phase 1 migration grants authenticated users read access only. Catalog
writes are restricted by RLS to KAAM admins (or controlled service-role import
processes). The future admin screen should deactivate records instead of
deleting referenced data and should record change audit events.

## Legacy safety

The old `skill_categories`, `skills`, `candidate_skills`,
`candidate_profiles.skills`, `candidate_profiles.job_categories`, and
`employer_hiring_requirements.role` remain unchanged. The migration seeds
`legacy_role_mappings` only for high-confidence exact name/alias matches from
the legacy `skills` table. Ambiguous and unknown values are deliberately left
unmapped; they must be reviewed before any later backfill.

`legacy_role_mapping_coverage` is the read-only report for rollout review. It
must be checked in staging after the migration is applied before Phase 2 uses
the new IDs.

## Future client and admin use

Phase 2 should add a shared catalog repository in Flutter and web, then expose
searchable role selectors, selected-role chips, and role-based competency
suggestions. It should write new IDs alongside legacy text during a monitored
dual-write period. No employer verification path should be changed as part of
that work.

Only after candidate/employer selection and search have run successfully in
production should a later phase introduce ID-driven matching and retirement of
legacy writes. Legacy columns must not be removed until mapping coverage,
backfill, client version adoption, and rollback criteria are approved.

## 2026-08-07 seed-ordering repair

The first controlled production attempt of the pending Phase 1 migration
rolled back atomically at its role-count guard. No taxonomy objects or seed data
were committed. The category and role seeds were initially in one statement;
the role insert reread `job_categories`, which cannot see rows inserted by a
data-modifying CTE through the base table in the same statement snapshot.

The repaired migration passes the category IDs directly from the
`inserted_categories` CTE into the role insert. Later dependent seed statements
remain separate statements inside the same transaction, so they can safely
read rows created by their predecessors. Production remains pending until a
runtime database validation succeeds and a new approval is given.

## Production sign-off — 2026-08-07

Migration `20260807151913_role_skills_taxonomy_phase_1_catalog.sql` was applied
to KAAM production after a successful rollback-only PostgreSQL rehearsal.
Production verification recorded 32 industries, 68 categories, 394 canonical
roles, 23 aliases, 306 competency skills, 2,039 role-skill mappings, and 123
conservative exact legacy mappings. Referential-integrity and duplicate checks
returned zero violations; RLS is enabled on the catalog tables. No candidate
records, legacy skills, verification, visibility, matching, or client UI were
changed. Remaining work is review of unmapped legacy catalog values before a
separate Phase 2 dual-write UI rollout.
