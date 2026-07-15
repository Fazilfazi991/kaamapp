-- KAAM APP - DOCUMENT VERSION HISTORY REPAIR
-- Run this once in the Supabase SQL Editor on the live project.
-- Safe to run after 005/006 or on a project that only has candidate_documents.

begin;

create table if not exists public.candidate_document_versions (
  id uuid primary key default gen_random_uuid(),
  candidate_document_id uuid references public.candidate_documents(id) on delete cascade,
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  document_type text not null check (document_type in ('passport', 'visa')),
  file_path text not null,
  version_number integer not null default 1 check (version_number > 0),
  status text not null default 'pending_verification',
  is_active boolean not null default true,
  extracted_details jsonb not null default '{}'::jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (candidate_id, document_type, version_number)
);

alter table public.candidate_document_versions
  add column if not exists candidate_document_id uuid references public.candidate_documents(id) on delete cascade,
  add column if not exists extracted_details jsonb not null default '{}'::jsonb,
  add column if not exists verified_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists candidate_document_versions_candidate_idx
  on public.candidate_document_versions(candidate_id, document_type, created_at desc);
create index if not exists candidate_document_versions_document_idx
  on public.candidate_document_versions(candidate_document_id);

update public.candidate_document_versions version_row
set candidate_document_id = document_row.id
from public.candidate_documents document_row
where version_row.candidate_document_id is null
  and version_row.candidate_id = document_row.candidate_id
  and (
    (version_row.document_type = 'passport' and version_row.file_path = document_row.passport_file_url)
    or (version_row.document_type = 'visa' and version_row.file_path = document_row.visa_file_url)
  );

drop trigger if exists candidate_document_versions_set_updated_at on public.candidate_document_versions;
create trigger candidate_document_versions_set_updated_at
before update on public.candidate_document_versions
for each row execute function public.set_updated_at();

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

notify pgrst, 'reload schema';

commit;
