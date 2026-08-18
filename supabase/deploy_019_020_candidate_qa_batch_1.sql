-- KAAM live deployment script for Candidate QA Batch 1 database support.
-- Execute in Supabase SQL Editor only after confirming the project is:
-- bhuhojzqxnvwbsypijac / KAAM APP
--
-- Order:
-- 1. 019_passport_front_back_documents.sql
-- 2. 020_candidate_qa_batch_1_profile_fields.sql
-- 3. Verification queries

create temporary table if not exists kaam_pre_migration_candidate_snapshot as
select
  count(*)::bigint as candidate_profile_count,
  count(*) filter (
    where coalesce(btrim(nationality), '') <> ''
       or coalesce(btrim(current_city), '') <> ''
       or coalesce(btrim(preferred_city), '') <> ''
       or coalesce(btrim(headline), '') <> ''
       or coalesce(btrim(availability), '') <> ''
  )::bigint as candidates_with_onboarding_progress
from public.candidate_profiles;

-- 019: Passport front/back document support.
begin;

alter table public.candidate_documents
  add column if not exists passport_back_file_url text;

alter table public.candidate_document_versions
  add column if not exists file_paths jsonb not null default '{}'::jsonb;

update public.candidate_document_versions
set file_paths = jsonb_build_object('front', file_path)
where document_type = 'passport'
  and coalesce(file_paths, '{}'::jsonb) = '{}'::jsonb
  and coalesce(btrim(file_path), '') <> '';

notify pgrst, 'reload schema';

commit;

-- 020: Candidate QA Batch 1 profile fields.
begin;

do $$
declare
  had_driving_licenses boolean;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'candidate_profiles'
      and column_name = 'driving_licenses'
  ) into had_driving_licenses;

  alter table public.candidate_profiles
    add column if not exists driving_licenses text[] not null default '{}',
    add column if not exists current_employment_status text,
    add column if not exists current_employment_status_other text,
    add column if not exists profile_photo_file_name text,
    add column if not exists resume_file_name text,
    add column if not exists resume_file_size integer;

  if not had_driving_licenses then
    update public.candidate_profiles
    set driving_licenses = case
      when bio ilike '%Driving license: UAE%'
        then array['UAE Driving Licence']
      when bio ilike '%Driving license: India%'
        then array['India Driving Licence']
      when bio ilike '%Driving license: None%'
        then array['No Driving Licence']
      else driving_licenses
    end;
  end if;
end $$;

notify pgrst, 'reload schema';

commit;

-- Verification: required columns and data types.
select
  table_name,
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and (
    (table_name = 'candidate_documents'
      and column_name = 'passport_back_file_url')
    or (table_name = 'candidate_document_versions'
      and column_name = 'file_paths')
    or (table_name = 'candidate_profiles'
      and column_name in (
        'driving_licenses',
        'current_employment_status',
        'current_employment_status_other',
        'profile_photo_file_name',
        'resume_file_name',
        'resume_file_size'
      ))
  )
order by table_name, column_name;

-- Verification: RLS remains enabled on candidate tables.
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'candidate_profiles',
    'candidate_documents',
    'candidate_document_versions'
  )
order by c.relname;

-- Verification: private storage bucket remains private.
select
  id,
  name,
  public
from storage.buckets
where id = 'kaam-private';

-- Verification: inspect storage policies for kaam-private access.
select
  policyname,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and (
    coalesce(qual, '') ilike '%kaam-private%'
    or coalesce(with_check, '') ilike '%kaam-private%'
  )
order by policyname;

-- Verification: candidate records and onboarding progress are unchanged.
select
  before.candidate_profile_count as before_candidate_profiles,
  after_counts.candidate_profile_count as after_candidate_profiles,
  before.candidates_with_onboarding_progress as before_with_progress,
  after_counts.candidates_with_onboarding_progress as after_with_progress,
  before.candidate_profile_count = after_counts.candidate_profile_count
    as candidate_count_unchanged,
  before.candidates_with_onboarding_progress =
    after_counts.candidates_with_onboarding_progress
    as onboarding_progress_unchanged
from kaam_pre_migration_candidate_snapshot before
cross join (
  select
    count(*)::bigint as candidate_profile_count,
    count(*) filter (
      where coalesce(btrim(nationality), '') <> ''
         or coalesce(btrim(current_city), '') <> ''
         or coalesce(btrim(preferred_city), '') <> ''
         or coalesce(btrim(headline), '') <> ''
         or coalesce(btrim(availability), '') <> ''
    )::bigint as candidates_with_onboarding_progress
  from public.candidate_profiles
) after_counts;

-- Verification: legacy driving licence backfill summary.
select
  count(*) filter (where array_length(driving_licenses, 1) > 0)
    as profiles_with_driving_licenses,
  count(*) filter (
    where 'UAE Driving Licence' = any(driving_licenses)
       or 'India Driving Licence' = any(driving_licenses)
       or 'Other Country Driving Licence' = any(driving_licenses)
       or 'No Driving Licence' = any(driving_licenses)
  ) as profiles_with_supported_driving_license_values
from public.candidate_profiles;
