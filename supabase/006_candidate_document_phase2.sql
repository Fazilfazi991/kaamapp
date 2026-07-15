-- KAAM APP - CANDIDATE DOCUMENT PHASE 2 PATCH
-- Run this in Supabase SQL Editor for existing live projects after 005_candidate_identity_documents.sql.

begin;

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

update public.candidate_documents
set
  passport_status = case
    when passport_file_url is null or btrim(passport_file_url) = '' then 'not_uploaded'
    when passport_verified then 'verified'
    else 'pending_verification'
  end,
  visa_status = case
    when visa_file_url is null or btrim(visa_file_url) = '' then 'not_uploaded'
    when visa_verified then 'verified'
    else 'pending_verification'
  end,
  passport_uploaded_at = coalesce(passport_uploaded_at, case when passport_file_url is not null then updated_at end),
  visa_uploaded_at = coalesce(visa_uploaded_at, case when visa_file_url is not null then updated_at end),
  passport_version = case when passport_file_url is not null and passport_version = 0 then 1 else passport_version end,
  visa_version = case when visa_file_url is not null and visa_version = 0 then 1 else visa_version end,
  passport_is_active = passport_file_url is not null and btrim(passport_file_url) <> '',
  visa_is_active = visa_file_url is not null and btrim(visa_file_url) <> '';

create table if not exists public.candidate_document_versions (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  document_type text not null check (document_type in ('passport', 'visa')),
  file_path text not null,
  version_number integer not null default 1,
  status text not null default 'pending_verification',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists candidate_document_versions_candidate_idx
on public.candidate_document_versions(candidate_id, document_type);

insert into public.candidate_document_versions (
  candidate_id,
  document_type,
  file_path,
  version_number,
  status,
  is_active,
  created_at
)
select candidate_id, 'passport', passport_file_url, passport_version, passport_status, true, coalesce(passport_uploaded_at, updated_at)
from public.candidate_documents
where passport_file_url is not null
  and btrim(passport_file_url) <> ''
  and not exists (
    select 1
    from public.candidate_document_versions v
    where v.candidate_id = candidate_documents.candidate_id
      and v.document_type = 'passport'
      and v.file_path = candidate_documents.passport_file_url
  );

insert into public.candidate_document_versions (
  candidate_id,
  document_type,
  file_path,
  version_number,
  status,
  is_active,
  created_at
)
select candidate_id, 'visa', visa_file_url, visa_version, visa_status, true, coalesce(visa_uploaded_at, updated_at)
from public.candidate_documents
where visa_file_url is not null
  and btrim(visa_file_url) <> ''
  and not exists (
    select 1
    from public.candidate_document_versions v
    where v.candidate_id = candidate_documents.candidate_id
      and v.document_type = 'visa'
      and v.file_path = candidate_documents.visa_file_url
  );

create table if not exists public.candidate_document_notifications (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  document_type text not null check (document_type in ('passport', 'visa')),
  notification_type text not null,
  title text not null,
  body text not null,
  scheduled_for timestamptz,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists candidate_document_notifications_candidate_idx
on public.candidate_document_notifications(candidate_id, created_at desc);

alter table public.candidate_document_versions enable row level security;
alter table public.candidate_document_notifications enable row level security;

drop policy if exists "candidate_document_versions_owner_all" on public.candidate_document_versions;
create policy "candidate_document_versions_owner_all"
on public.candidate_document_versions for all
to authenticated
using (candidate_id = auth.uid() or public.is_admin())
with check (candidate_id = auth.uid() or public.is_admin());

drop policy if exists "candidate_document_notifications_owner_all" on public.candidate_document_notifications;
create policy "candidate_document_notifications_owner_all"
on public.candidate_document_notifications for all
to authenticated
using (candidate_id = auth.uid() or public.is_admin())
with check (candidate_id = auth.uid() or public.is_admin());

grant all on public.candidate_document_versions to authenticated;
grant all on public.candidate_document_notifications to authenticated;

commit;
