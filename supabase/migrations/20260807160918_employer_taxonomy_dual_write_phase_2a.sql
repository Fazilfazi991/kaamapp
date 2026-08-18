-- Phase 2A: additive employer taxonomy references. Do not apply until reviewed.
begin;

alter table public.employer_companies
  add column if not exists industry_id uuid references public.industries(id),
  add column if not exists company_size_code text check (company_size_code in ('1_10','11_25','26_50','51_100','101_250','251_500','500_plus')),
  add column if not exists contact_role_code text check (contact_role_code in ('owner','founder','co_founder','managing_director','director','general_manager','hr_manager','hr_executive','recruitment_manager','recruiter','operations_manager','operations_executive','admin_manager','administrator','supervisor','pro','other')),
  add column if not exists contact_role_other text,
  add column if not exists company_emirate text,
  add column if not exists company_area text,
  add column if not exists branch_name text;

alter table public.employer_hiring_requirements
  add column if not exists job_role_id uuid references public.job_roles(id);

create index if not exists employer_companies_industry_id_idx on public.employer_companies(industry_id);
create index if not exists employer_hiring_requirements_job_role_id_idx on public.employer_hiring_requirements(job_role_id);

create table if not exists public.employer_hiring_requirement_skills (
  requirement_id uuid not null references public.employer_hiring_requirements(id) on delete cascade,
  competency_skill_id uuid not null references public.competency_skills(id),
  created_at timestamptz not null default now(),
  primary key (requirement_id, competency_skill_id)
);
create index if not exists employer_requirement_skills_skill_idx on public.employer_hiring_requirement_skills(competency_skill_id);
alter table public.employer_hiring_requirement_skills enable row level security;
create policy "employer_requirement_skills_owner_select" on public.employer_hiring_requirement_skills for select to authenticated
using (exists (select 1 from public.employer_hiring_requirements r where r.id=requirement_id and (r.employer_id=auth.uid() or public.is_admin())));
create policy "employer_requirement_skills_owner_insert" on public.employer_hiring_requirement_skills for insert to authenticated
with check (exists (select 1 from public.employer_hiring_requirements r join public.employer_companies ec on ec.id=r.company_id where r.id=requirement_id and ((r.employer_id=auth.uid() and ec.owner_id=auth.uid()) or public.is_admin())));
create policy "employer_requirement_skills_owner_delete" on public.employer_hiring_requirement_skills for delete to authenticated
using (exists (select 1 from public.employer_hiring_requirements r where r.id=requirement_id and (r.employer_id=auth.uid() or public.is_admin())));
grant select,insert,delete on public.employer_hiring_requirement_skills to authenticated;

commit;
