-- Matching and Chat QA Fix Batch 1.
-- Adds structured interest-request job fields and enables realtime inserts for
-- chat messages without changing existing participant-only RLS policies.

begin;

alter table public.interest_requests
  add column if not exists job_title text,
  add column if not exists salary_range text,
  add column if not exists work_location text,
  add column if not exists working_hours text,
  add column if not exists accommodation_provided boolean,
  add column if not exists transport_provided boolean,
  add column if not exists visa_support boolean;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_messages'
  ) then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
exception
  when duplicate_object then
    null;
end $$;

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
    coalesce(nullif(ir.job_title, ''), ec.industry, 'Matched role') as role,
    coalesce(nullif(ir.work_location, ''), ec.city, '') as location,
    m.created_at as matched_at,
    public.candidate_membership_active(m.candidate_id) as chat_enabled,
    public.candidate_membership_active(m.candidate_id)
      and m.contact_revealed_at is null as can_reveal_contact,
    m.contact_revealed_at is not null
      and public.candidate_membership_active(m.candidate_id) as contact_revealed
  from public.matches m
  join public.employer_companies ec on ec.id = m.company_id
  left join public.interest_requests ir on ir.id = m.interest_request_id
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
    coalesce(nullif(p.full_name, ''), 'Candidate') as display_name,
    coalesce(nullif(ir.job_title, ''), cp.headline, 'Candidate') as role,
    coalesce(nullif(ir.work_location, ''), cp.current_city, '') as location,
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
  left join public.interest_requests ir on ir.id = m.interest_request_id
  where m.employer_id = auth.uid()
  order by m.created_at desc;
$$;

grant execute on function public.candidate_matches_with_access() to authenticated;
grant execute on function public.employer_matches_with_contact() to authenticated;

notify pgrst, 'reload schema';

commit;
