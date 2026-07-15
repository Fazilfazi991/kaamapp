-- KAAM identity-document save compatibility repair.
-- Safe to run after 005, 006 and 008. It does not delete document data.
begin;

-- The Flutter save flow writes these lifecycle fields before inserting a
-- version row. Add them idempotently for projects that only applied 005/008.
alter table public.candidate_documents
  add column if not exists passport_status text not null default 'not_uploaded',
  add column if not exists visa_status text not null default 'not_uploaded',
  add column if not exists passport_uploaded_at timestamptz,
  add column if not exists visa_uploaded_at timestamptz,
  add column if not exists passport_verified_at timestamptz,
  add column if not exists visa_verified_at timestamptz,
  add column if not exists passport_version integer not null default 0,
  add column if not exists visa_version integer not null default 0,
  add column if not exists passport_is_active boolean not null default false,
  add column if not exists visa_is_active boolean not null default false,
  add column if not exists passport_archived boolean not null default false,
  add column if not exists visa_archived boolean not null default false,
  add column if not exists passport_expiry_notification_sent boolean not null default false,
  add column if not exists visa_expiry_notification_sent boolean not null default false;

create unique index if not exists candidate_documents_candidate_id_unique_idx
  on public.candidate_documents(candidate_id);

alter table public.candidate_documents enable row level security;
drop policy if exists "candidate_documents_owner_all" on public.candidate_documents;
create policy "candidate_documents_owner_all"
on public.candidate_documents for all to authenticated
using (candidate_id = auth.uid() or public.is_admin())
with check (candidate_id = auth.uid() or public.is_admin());

grant all on public.candidate_documents to authenticated;
notify pgrst, 'reload schema';
commit;
