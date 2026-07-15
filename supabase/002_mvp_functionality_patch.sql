-- KAAM APP - MVP FUNCTIONALITY PATCH
-- Run this on the existing live Supabase project after 001_kaam_initial_schema.sql.

begin;

alter table public.employer_companies
  add column if not exists office_area text,
  add column if not exists contact_person text,
  add column if not exists contact_role text,
  add column if not exists hiring_needs text[] not null default '{}';

create table if not exists public.saved_candidates (
  employer_id uuid not null references public.profiles(id) on delete cascade,
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (employer_id, candidate_id)
);

create index if not exists saved_candidates_candidate_idx on public.saved_candidates(candidate_id);

create table if not exists public.verification_documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  company_id uuid references public.employer_companies(id) on delete cascade,
  document_type text not null,
  bucket_id text not null,
  file_path text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists verification_documents_set_updated_at on public.verification_documents;
create trigger verification_documents_set_updated_at
before update on public.verification_documents
for each row execute function public.set_updated_at();

create index if not exists verification_documents_owner_idx on public.verification_documents(owner_id);
create index if not exists verification_documents_company_idx on public.verification_documents(company_id);

alter table public.saved_candidates enable row level security;
alter table public.verification_documents enable row level security;

drop policy if exists "saved_candidates_owner_all" on public.saved_candidates;
create policy "saved_candidates_owner_all"
on public.saved_candidates for all
to authenticated
using (employer_id = auth.uid() or public.is_admin())
with check (employer_id = auth.uid() or public.is_admin());

drop policy if exists "verification_documents_owner_admin_select" on public.verification_documents;
create policy "verification_documents_owner_admin_select"
on public.verification_documents for select
to authenticated
using (owner_id = auth.uid() or public.is_admin());

drop policy if exists "verification_documents_owner_insert" on public.verification_documents;
create policy "verification_documents_owner_insert"
on public.verification_documents for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists "verification_documents_owner_update" on public.verification_documents;
create policy "verification_documents_owner_update"
on public.verification_documents for update
to authenticated
using (owner_id = auth.uid() or public.is_admin())
with check (owner_id = auth.uid() or public.is_admin());

drop policy if exists "kaam_private_owner_update" on storage.objects;
create policy "kaam_private_owner_update"
on storage.objects for update
to authenticated
using (
  bucket_id = 'kaam-private'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'kaam-private'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "kaam_private_owner_delete" on storage.objects;
create policy "kaam_private_owner_delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'kaam-private'
  and (storage.foldername(name))[1] = auth.uid()::text
);

grant all on public.saved_candidates to authenticated;
grant all on public.verification_documents to authenticated;

commit;
