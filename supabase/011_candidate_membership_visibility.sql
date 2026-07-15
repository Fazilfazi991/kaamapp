-- KAAM candidate test-mode membership and employer visibility patch.
-- Run after 010_identity_document_save_repair.sql.

begin;

create table if not exists public.candidate_memberships (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  plan_code text not null default 'premium',
  status text not null default 'inactive'
    check (status in ('inactive', 'pending', 'active', 'expired', 'cancelled')),
  started_at timestamptz,
  expires_at timestamptz,
  payment_provider text,
  payment_reference text,
  amount numeric(12,2),
  currency text not null default 'AED',
  is_test boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(candidate_id)
);

drop trigger if exists candidate_memberships_set_updated_at on public.candidate_memberships;
create trigger candidate_memberships_set_updated_at
before update on public.candidate_memberships
for each row execute function public.set_updated_at();

create index if not exists candidate_memberships_candidate_status_idx
on public.candidate_memberships(candidate_id, status, expires_at);

alter table public.candidate_memberships enable row level security;

drop policy if exists "candidate_memberships_select_own_or_admin" on public.candidate_memberships;
create policy "candidate_memberships_select_own_or_admin"
on public.candidate_memberships for select
to authenticated
using (candidate_id = auth.uid() or public.is_admin());

drop policy if exists "candidate_memberships_admin_insert" on public.candidate_memberships;
create policy "candidate_memberships_admin_insert"
on public.candidate_memberships for insert
to authenticated
with check (public.is_admin());

drop policy if exists "candidate_memberships_admin_update" on public.candidate_memberships;
create policy "candidate_memberships_admin_update"
on public.candidate_memberships for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.candidate_profile_completed(candidate_row public.candidate_profiles)
returns boolean
language sql
stable
as $$
  select
    coalesce(btrim(candidate_row.nationality), '') <> ''
    and coalesce(btrim(candidate_row.current_city), '') <> ''
    and coalesce(btrim(candidate_row.preferred_city), '') <> ''
    and coalesce(array_length(candidate_row.job_categories, 1), 0) > 0
    and coalesce(btrim(candidate_row.headline), '') <> ''
    and coalesce(btrim(candidate_row.availability), '') <> '';
$$;

create or replace function public.candidate_documents_verified(target_candidate_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.candidate_documents cd
    where cd.candidate_id = target_candidate_id
      and cd.passport_status = 'verified'
      and coalesce(btrim(cd.passport_file_url), '') <> ''
  );
$$;

create or replace function public.candidate_membership_active(target_candidate_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.candidate_memberships cm
    where cm.candidate_id = target_candidate_id
      and cm.status = 'active'
      and cm.expires_at > now()
  );
$$;

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
      and public.candidate_membership_active(cp.id)
  );
$$;

create or replace view public.public_candidate_search
as
select
  cp.id,
  p.full_name,
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

create or replace function public.activate_test_candidate_membership()
returns public.candidate_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  membership_row public.candidate_memberships;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if public.my_role() <> 'candidate' then
    raise exception 'Only candidates can activate a test membership';
  end if;

  insert into public.candidate_profiles (id)
  values (current_user_id)
  on conflict (id) do nothing;

  insert into public.candidate_memberships (
    candidate_id,
    plan_code,
    status,
    started_at,
    expires_at,
    payment_provider,
    payment_reference,
    amount,
    currency,
    is_test
  )
  values (
    current_user_id,
    'premium',
    'active',
    now(),
    now() + interval '30 days',
    'test',
    null,
    0,
    'AED',
    true
  )
  on conflict (candidate_id) do update set
    plan_code = excluded.plan_code,
    status = 'active',
    started_at = excluded.started_at,
    expires_at = excluded.expires_at,
    payment_provider = 'test',
    payment_reference = null,
    amount = 0,
    currency = 'AED',
    is_test = true,
    updated_at = now()
  returning * into membership_row;

  return membership_row;
end;
$$;

grant select on public.public_candidate_search to authenticated;
grant select on public.candidate_memberships to authenticated;
grant execute on function public.candidate_profile_completed(public.candidate_profiles) to authenticated;
grant execute on function public.candidate_documents_verified(uuid) to authenticated;
grant execute on function public.candidate_membership_active(uuid) to authenticated;
grant execute on function public.candidate_visible_to_employers(uuid) to authenticated;
grant execute on function public.activate_test_candidate_membership() to authenticated;

notify pgrst, 'reload schema';
commit;
