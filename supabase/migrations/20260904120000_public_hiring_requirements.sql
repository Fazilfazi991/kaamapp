begin;

alter table public.employer_hiring_requirements
  add column if not exists application_deadline date,
  add column if not exists is_published boolean not null default false;

create index if not exists employer_hiring_requirements_public_idx
  on public.employer_hiring_requirements (is_published, status, created_at desc, application_deadline)
  where is_published = true and status = 'active';

create or replace function public.list_public_hiring_requirements(result_limit integer default 12)
returns table (
  id uuid,
  role text,
  custom_role text,
  openings integer,
  work_location text,
  application_deadline date,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    requirement.id,
    requirement.role,
    requirement.custom_role,
    requirement.openings,
    requirement.work_location,
    requirement.application_deadline,
    requirement.created_at
  from public.employer_hiring_requirements as requirement
  join public.employer_companies as company on company.id = requirement.company_id
  join public.profiles as employer on employer.id = requirement.employer_id
  where requirement.is_published = true
    and requirement.status = 'active'
    and requirement.application_deadline is not null
    and requirement.application_deadline >= current_date
    and company.status = 'active'
    and employer.status = 'active'
  order by requirement.created_at desc, requirement.application_deadline asc
  limit least(greatest(coalesce(result_limit, 12), 1), 15);
$$;

revoke all on function public.list_public_hiring_requirements(integer) from public;
grant execute on function public.list_public_hiring_requirements(integer) to anon, authenticated;

comment on function public.list_public_hiring_requirements(integer) is
  'Returns only public-safe fields for active, published and unexpired hiring requirements owned by active employers.';

notify pgrst, 'reload schema';

commit;
