# Execution order

`checksums.json` is the machine-readable authority. It contains 32 canonical historical sources followed by two QA-only patches, for 34 SQL units total. Deferred and excluded sources are listed in `QA_MIGRATION_PLAN.md` and are rejected by the preparation script.

Run one unit at a time, stop on first error, and verify its SHA-256 immediately before execution. Do not use the repository's Supabase link. Run `post-migration-assertions.sql` read-only only after all units succeed.

Transaction classification:

- Orders 1–32: preserve each historical file's own boundaries; do not wrap the chain globally.
- Order 1 is transaction-sensitive because it creates Storage bucket metadata/policies.
- Taxonomy sources contain static reference inserts and are transaction-safe within their authored transaction.
- Notification sources issue schema reload notifications but contain no scheduled/external execution.
- Orders 33–34 are transaction-safe hardening patches.
- No selected file installs `pg_cron`/`pg_net` or invokes external HTTP.
