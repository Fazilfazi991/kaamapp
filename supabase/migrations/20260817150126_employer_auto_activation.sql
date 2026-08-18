-- Employer accounts are active immediately after authenticated profile bootstrap.
-- Company setup and optional business verification remain separate from account access.
create or replace function public.bootstrap_user_profile(selected_role text)
returns table (
  role public.user_role,
  status public.profile_status,
  candidate_profile_exists boolean,
  employer_company_exists boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_role public.user_role;
  v_existing public.profiles%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required.' using errcode = '28000';
  end if;

  if selected_role not in ('candidate', 'employer') then
    raise exception 'Unsupported KAAM role.' using errcode = '22023';
  end if;

  v_role := selected_role::public.user_role;

  select * into v_existing
  from public.profiles p
  where p.id = v_user_id
  for update;

  if found then
    if v_existing.role <> v_role then
      raise exception 'Existing KAAM profile uses a different role.' using errcode = '23514';
    end if;

    if v_existing.status = 'blocked' then
      raise exception 'KAAM profile is blocked.' using errcode = '42501';
    end if;

    -- A provisional profile may have been created before role selection.
    -- Employer bootstrap activates it; paused and blocked accounts remain controlled
    -- by the existing account-security workflow.
    if v_role = 'employer' and v_existing.status = 'draft' then
      update public.profiles set status = 'active' where id = v_user_id;
    end if;
  else
    insert into public.profiles (id, role, email, phone, status)
    select au.id, v_role, au.email, au.phone, 'active'::public.profile_status
    from auth.users au
    where au.id = v_user_id;

    if not found then
      raise exception 'Authenticated user was not found.' using errcode = '23503';
    end if;
  end if;

  if v_role = 'candidate' then
    insert into public.candidate_profiles (id)
    values (v_user_id)
    on conflict (id) do nothing;
  end if;

  return query
  select
    p.role,
    p.status,
    exists (select 1 from public.candidate_profiles cp where cp.id = v_user_id),
    exists (select 1 from public.employer_companies ec where ec.owner_id = v_user_id)
  from public.profiles p
  where p.id = v_user_id;
end;
$$;

-- Normalize legacy, unblocked employer drafts. Do not override a deliberate
-- paused or blocked security state.
update public.profiles
set status = 'active'
where role = 'employer' and status = 'draft';

update public.employer_companies ec
set status = 'active'
where ec.status = 'draft'
  and exists (
    select 1
    from public.profiles p
    where p.id = ec.owner_id
      and p.role = 'employer'
      and p.status not in ('paused', 'blocked')
  );

-- A company profile or an optional verification upload must not create an
-- employer account approval queue.
drop trigger if exists notifications_company_review_submitted on public.employer_companies;

-- Keep the existing optional verification audit trail, but use user-facing
-- language that cannot be confused with employer account activation.
create or replace function public.notify_company_reviewed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is not distinct from new.status
    and old.is_verified is not distinct from new.is_verified then
    return new;
  end if;

  if new.is_verified is not true then
    return new;
  end if;

  perform public.create_notification(
    new.owner_id,
    'company_approved',
    'Business verification complete',
    'Your optional business verification has been completed.',
    '/employer/onboarding',
    jsonb_build_object('company_id', new.id),
    'company-reviewed:' || new.id::text || ':' || coalesce(new.status::text, 'unknown') || ':' || coalesce(new.is_verified::text, 'false'),
    'employer_companies',
    new.id
  );
  return new;
end;
$$;
