-- KAAM employer requirements and candidate-controlled contact rules patch.
-- Run after 011_candidate_membership_visibility.sql.

begin;

create table if not exists public.employer_hiring_requirements (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.profiles(id) on delete cascade,
  company_id uuid not null references public.employer_companies(id) on delete cascade,
  role text not null,
  custom_role text,
  openings integer not null default 1 check (openings > 0),
  salary_range text not null,
  work_location text not null,
  working_hours text not null,
  accommodation_provided boolean not null default false,
  transport_provided boolean not null default false,
  visa_provided boolean not null default false,
  immediate_joining boolean not null default false,
  description text,
  status text not null default 'active' check (status in ('active', 'paused', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists employer_hiring_requirements_set_updated_at on public.employer_hiring_requirements;
create trigger employer_hiring_requirements_set_updated_at
before update on public.employer_hiring_requirements
for each row execute function public.set_updated_at();

create index if not exists employer_hiring_requirements_employer_idx on public.employer_hiring_requirements(employer_id);
create index if not exists employer_hiring_requirements_company_idx on public.employer_hiring_requirements(company_id);

alter table public.employer_hiring_requirements enable row level security;

drop policy if exists "hiring_requirements_owner_all" on public.employer_hiring_requirements;
create policy "hiring_requirements_owner_all"
on public.employer_hiring_requirements for all
to authenticated
using (employer_id = auth.uid() or public.is_admin())
with check (
  (employer_id = auth.uid() and exists (
    select 1 from public.employer_companies ec
    where ec.id = company_id and ec.owner_id = auth.uid()
  ))
  or public.is_admin()
);

alter table public.matches
  add column if not exists contact_revealed_at timestamptz;

create or replace function public.candidate_visible_to_employers(target_candidate_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.candidate_profiles cp
    join public.profiles p on p.id = cp.id
    where cp.id = target_candidate_id
      and p.status = 'active'
      and cp.is_visible = true
      and public.candidate_profile_completed(cp)
      and public.candidate_documents_verified(cp.id)
  );
$$;

create or replace view public.public_candidate_search
as
select
  cp.id,
  nullif(split_part(coalesce(p.full_name, ''), ' ', 1), '') as full_name,
  cp.headline,
  cp.nationality,
  cp.current_country,
  cp.current_city,
  cp.preferred_country,
  cp.preferred_city,
  cp.job_categories,
  cp.skills,
  cp.languages,
  cp.experience_years,
  cp.expected_salary_min,
  cp.expected_salary_max,
  cp.currency,
  cp.availability,
  cp.visa_status,
  cp.profile_photo_url,
  cp.bio,
  true as is_verified,
  cp.created_at,
  cp.updated_at
from public.candidate_profiles cp
join public.profiles p on p.id = cp.id
where public.candidate_visible_to_employers(cp.id);

create or replace function public.match_chat_enabled(target_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.matches m
    where m.id = target_match_id
      and (m.employer_id = auth.uid() or m.candidate_id = auth.uid())
      and public.candidate_membership_active(m.candidate_id)
  );
$$;

create or replace function public.reveal_candidate_contact(target_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  update public.matches m
  set contact_revealed_at = coalesce(m.contact_revealed_at, now())
  where m.id = target_match_id
    and m.candidate_id = current_user_id
    and public.candidate_membership_active(m.candidate_id);

  if not found then
    raise exception 'Only paid candidates can reveal contact details for their own matched employers';
  end if;
end;
$$;

create or replace function public.candidate_matches_with_access()
returns table (
  match_id uuid,
  company_name text,
  role text,
  location text,
  matched_at timestamptz,
  chat_enabled boolean,
  can_reveal_contact boolean,
  contact_revealed boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    m.id as match_id,
    ec.company_name,
    coalesce(ec.industry, 'Matched role') as role,
    coalesce(ec.city, '') as location,
    m.created_at as matched_at,
    public.candidate_membership_active(m.candidate_id) as chat_enabled,
    public.candidate_membership_active(m.candidate_id)
      and m.contact_revealed_at is null as can_reveal_contact,
    m.contact_revealed_at is not null
      and public.candidate_membership_active(m.candidate_id) as contact_revealed
  from public.matches m
  join public.employer_companies ec on ec.id = m.company_id
  where m.candidate_id = auth.uid()
  order by m.created_at desc;
$$;

create or replace function public.employer_matches_with_contact()
returns table (
  match_id uuid,
  candidate_id uuid,
  display_name text,
  role text,
  location text,
  matched_at timestamptz,
  chat_enabled boolean,
  contact_revealed boolean,
  phone text,
  email text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    m.id as match_id,
    m.candidate_id,
    coalesce(nullif(split_part(coalesce(p.full_name, ''), ' ', 1), ''), 'Candidate #' || left(m.candidate_id::text, 8)) as display_name,
    coalesce(cp.headline, 'Candidate') as role,
    coalesce(cp.current_city, '') as location,
    m.created_at as matched_at,
    public.candidate_membership_active(m.candidate_id) as chat_enabled,
    m.contact_revealed_at is not null
      and public.candidate_membership_active(m.candidate_id) as contact_revealed,
    case
      when m.contact_revealed_at is not null
        and public.candidate_membership_active(m.candidate_id)
      then p.phone
      else null
    end as phone,
    case
      when m.contact_revealed_at is not null
        and public.candidate_membership_active(m.candidate_id)
      then p.email
      else null
    end as email
  from public.matches m
  join public.candidate_profiles cp on cp.id = m.candidate_id
  join public.profiles p on p.id = m.candidate_id
  where m.employer_id = auth.uid()
  order by m.created_at desc;
$$;

drop policy if exists "chat_select_match_participants_admin" on public.chat_messages;
create policy "chat_select_match_participants_admin"
on public.chat_messages for select
to authenticated
using (
  public.is_admin()
  or public.match_chat_enabled(match_id)
);

drop policy if exists "chat_insert_match_participants" on public.chat_messages;
create policy "chat_insert_match_participants"
on public.chat_messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and public.match_chat_enabled(match_id)
);

grant all on public.employer_hiring_requirements to authenticated;
grant select on public.public_candidate_search to authenticated;
grant all on public.matches to authenticated;
grant execute on function public.candidate_visible_to_employers(uuid) to authenticated;
grant execute on function public.match_chat_enabled(uuid) to authenticated;
grant execute on function public.reveal_candidate_contact(uuid) to authenticated;
grant execute on function public.candidate_matches_with_access() to authenticated;
grant execute on function public.employer_matches_with_contact() to authenticated;

notify pgrst, 'reload schema';

commit;
