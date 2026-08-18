-- KAAM APP - CANDIDATE QA BATCH 1 PROFILE FIELDS
-- Safe additive fields for candidate onboarding profile media and details.

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
