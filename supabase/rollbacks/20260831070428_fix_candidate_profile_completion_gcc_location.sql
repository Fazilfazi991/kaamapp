-- Manual rollback for 20260831070428_fix_candidate_profile_completion_gcc_location.sql.
-- This restores the exact function body captured from production before deployment.
create or replace function public.candidate_profile_completed(candidate_row public.candidate_profiles)
returns boolean
language sql
stable
as $function$
  select
    coalesce(btrim(candidate_row.nationality), '') <> ''
    and coalesce(btrim(candidate_row.current_city), '') <> ''
    and coalesce(btrim(candidate_row.preferred_city), '') <> ''
    and coalesce(array_length(candidate_row.job_categories, 1), 0) > 0
    and coalesce(btrim(candidate_row.headline), '') <> ''
    and coalesce(btrim(candidate_row.availability), '') <> '';
$function$;
