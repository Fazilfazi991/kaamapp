-- KAAM APP - EMPLOYER HIRING REQUIREMENTS PATCH
-- Run this in Supabase SQL Editor for existing live projects.

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

grant all on public.employer_hiring_requirements to authenticated;

notify pgrst, 'reload schema';

commit;
