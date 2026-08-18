# Phase 2A employer taxonomy foundation

Applied production migration: `20260807160918_employer_taxonomy_dual_write_phase_2a.sql`.

The migration adds nullable employer taxonomy references and structured company
fields without backfilling or changing existing legacy values. It also adds the
employer hiring-requirement competency join table with owner-scoped RLS.

Phase 2A UI wiring is still pending. Candidate taxonomy migration, matching
changes, and employer verification-upload removal are explicitly out of scope.
