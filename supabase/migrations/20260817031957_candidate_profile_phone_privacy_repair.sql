-- Align the live candidate profile table with the established Flutter privacy contract.
-- This is idempotent because production is missing only this column.
alter table public.candidate_profiles
  add column if not exists hide_phone_before_match boolean not null default true;
