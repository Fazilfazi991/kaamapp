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
      raise exception 'Existing KAAM profile uses a different role.'
        using errcode = '23514';
    end if;

    if v_existing.status = 'blocked' then
      raise exception 'KAAM profile is blocked.' using errcode = '42501';
    end if;
  else
    insert into public.profiles (id, role, email, phone, status)
    select
      au.id,
      v_role,
      au.email,
      au.phone,
      'active'::public.profile_status
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
    exists (
      select 1 from public.candidate_profiles cp where cp.id = v_user_id
    ) as candidate_profile_exists,
    exists (
      select 1 from public.employer_companies ec where ec.owner_id = v_user_id
    ) as employer_company_exists
  from public.profiles p
  where p.id = v_user_id;
end;
$$;

revoke all on function public.bootstrap_user_profile(text) from public;
grant execute on function public.bootstrap_user_profile(text) to authenticated;
