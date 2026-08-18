-- Employer saved/recently viewed QA support.
-- Additive and owner-scoped. Does not expose candidate private documents.

create table if not exists public.employer_candidate_views (
  employer_id uuid not null references public.profiles(id) on delete cascade,
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (employer_id, candidate_id)
);

create index if not exists employer_candidate_views_candidate_idx
on public.employer_candidate_views(candidate_id);

create index if not exists employer_candidate_views_employer_viewed_idx
on public.employer_candidate_views(employer_id, viewed_at desc);

alter table public.employer_candidate_views enable row level security;

drop policy if exists "employer_candidate_views_owner_all"
on public.employer_candidate_views;

create policy "employer_candidate_views_owner_all"
on public.employer_candidate_views for all
to authenticated
using (
  employer_id = auth.uid()
  or public.is_admin()
)
with check (
  (
    employer_id = auth.uid()
    and public.my_role() = 'employer'
  )
  or public.is_admin()
);

grant all on public.employer_candidate_views to authenticated;
