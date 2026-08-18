-- Employer-safe candidate search exposes only the public manual verification state.
create or replace view public.public_candidate_search as
select
  cp.id, nullif(split_part(coalesce(p.full_name, ''), ' ', 1), '') as full_name,
  cp.headline, cp.nationality, cp.current_country, cp.current_city, cp.preferred_country, cp.preferred_city,
  cp.job_categories, cp.skills, cp.languages, cp.experience_years, cp.expected_salary_min, cp.expected_salary_max,
  cp.currency, cp.availability, cp.visa_status, cp.profile_photo_url, cp.bio,
  (cp.verification_status = 'verified') as is_verified,
  cp.created_at, cp.updated_at,
  cp.verification_status, cp.verified_at
from public.candidate_profiles cp
join public.profiles p on p.id = cp.id
where public.candidate_visible_to_employers(cp.id);

notify pgrst, 'reload schema';

