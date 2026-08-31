create or replace function public.candidate_profile_completed(candidate_row public.candidate_profiles)
returns boolean
language sql
stable
as $function$
  select
    coalesce(btrim(candidate_row.nationality), '') <> ''
    and coalesce(btrim(candidate_row.current_city), '') <> ''
    and candidate_row.preferred_country in (
      'UAE',
      'Saudi Arabia',
      'Qatar',
      'Oman',
      'Bahrain',
      'Kuwait'
    )
    and (
      candidate_row.preferred_country <> 'UAE'
      or coalesce(btrim(candidate_row.preferred_city), '') <> ''
    )
    and coalesce(array_length(candidate_row.job_categories, 1), 0) > 0
    and coalesce(btrim(candidate_row.headline), '') <> ''
    and coalesce(btrim(candidate_row.availability), '') <> '';
$function$;
