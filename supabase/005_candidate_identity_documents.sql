-- KAAM APP - CANDIDATE IDENTITY DOCUMENTS PATCH
-- Run this in Supabase SQL Editor for existing live projects.

begin;

create table if not exists public.candidate_documents (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null unique references public.candidate_profiles(id) on delete cascade,
  passport_file_url text,
  visa_file_url text,
  passport_number text,
  passport_issue_date text,
  passport_expiry_date text,
  country_of_issue text,
  full_name text,
  nationality text,
  gender text,
  dob text,
  place_of_birth text,
  visa_number text,
  visa_type text,
  occupation text,
  sponsor text,
  uid_number text,
  emirates_id text,
  visa_issue_date text,
  visa_expiry_date text,
  passport_verified boolean not null default false,
  visa_verified boolean not null default false,
  ocr_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists candidate_documents_set_updated_at on public.candidate_documents;
create trigger candidate_documents_set_updated_at
before update on public.candidate_documents
for each row execute function public.set_updated_at();

create index if not exists candidate_documents_candidate_idx on public.candidate_documents(candidate_id);

alter table public.candidate_documents enable row level security;

drop policy if exists "candidate_documents_owner_all" on public.candidate_documents;
create policy "candidate_documents_owner_all"
on public.candidate_documents for all
to authenticated
using (candidate_id = auth.uid() or public.is_admin())
with check (candidate_id = auth.uid() or public.is_admin());

grant all on public.candidate_documents to authenticated;

commit;
