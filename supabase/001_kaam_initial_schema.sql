-- KAAM APP - INITIAL SUPABASE SCHEMA
-- Run this on a NEW Supabase project from SQL Editor.
-- This script creates tables, views, RLS policies, triggers, and storage buckets.

begin;

-- Required extensions
create extension if not exists pgcrypto;

-- =========================================================
-- ENUMS
-- =========================================================
do $$ begin
  create type public.user_role as enum ('candidate', 'employer', 'admin');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.profile_status as enum ('draft', 'active', 'paused', 'blocked');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.interest_status as enum ('pending', 'accepted', 'rejected', 'withdrawn');
exception when duplicate_object then null;
end $$;

-- =========================================================
-- HELPERS
-- =========================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================================================
-- CORE USER PROFILE
-- One row per auth.users account.
-- =========================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role not null,
  full_name text,
  phone text,
  email text,
  avatar_url text,
  status public.profile_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint phone_or_email_present check (phone is not null or email is not null)
);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- Functions that read profiles must be created after profiles exists.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  );
$$;

create or replace function public.my_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- =========================================================
-- CANDIDATES
-- Private candidate profile table.
-- Public/employer-safe data is exposed through a view below.
-- =========================================================
create table if not exists public.candidate_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  headline text,
  gender text,
  nationality text,
  current_country text,
  current_city text,
  preferred_country text default 'UAE',
  preferred_city text,
  job_categories text[] not null default '{}',
  skills text[] not null default '{}',
  languages text[] not null default '{}',
  experience_years numeric(4,1),
  expected_salary_min integer,
  expected_salary_max integer,
  currency text default 'AED',
  availability text,
  visa_status text,
  profile_photo_url text,
  resume_url text,
  bio text,
  is_visible boolean not null default true,
  hide_phone_before_match boolean not null default true,
  hide_email_before_match boolean not null default true,
  require_approval_before_chat boolean not null default true,
  allow_document_sharing_after_match boolean not null default true,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger candidate_profiles_set_updated_at
before update on public.candidate_profiles
for each row execute function public.set_updated_at();

create index if not exists candidate_profiles_city_idx on public.candidate_profiles(current_city);
create index if not exists candidate_profiles_visible_idx on public.candidate_profiles(is_visible);
create index if not exists candidate_profiles_categories_gin on public.candidate_profiles using gin(job_categories);
create index if not exists candidate_profiles_skills_gin on public.candidate_profiles using gin(skills);

-- =========================================================
-- EMPLOYER COMPANIES
-- One employer user can own one or more companies.
-- =========================================================
create table if not exists public.employer_companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  company_name text not null,
  trade_license_number text,
  industry text,
  company_size text,
  country text default 'UAE',
  city text,
  office_area text,
  contact_person text,
  contact_role text,
  hiring_needs text[] not null default '{}',
  website text,
  logo_url text,
  description text,
  is_verified boolean not null default false,
  status public.profile_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger employer_companies_set_updated_at
before update on public.employer_companies
for each row execute function public.set_updated_at();

create index if not exists employer_companies_owner_idx on public.employer_companies(owner_id);

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

create trigger employer_hiring_requirements_set_updated_at
before update on public.employer_hiring_requirements
for each row execute function public.set_updated_at();

create index if not exists employer_hiring_requirements_employer_idx on public.employer_hiring_requirements(employer_id);
create index if not exists employer_hiring_requirements_company_idx on public.employer_hiring_requirements(company_id);

-- =========================================================
-- PUBLIC SAFE CANDIDATE SEARCH VIEW
-- This hides private phone/email/resume fields.
-- Employers should use this for browsing candidates.
-- =========================================================
drop view if exists public.public_candidate_search;
create view public.public_candidate_search
as
select
  cp.id,
  p.full_name,
  cp.headline,
  cp.nationality,
  cp.current_country,
  cp.current_city,
  cp.preferred_country,
  cp.preferred_city,
  cp.job_categories,
  cp.skills,
  cp.languages,
  cp.experience_years,
  cp.expected_salary_min,
  cp.expected_salary_max,
  cp.currency,
  cp.availability,
  cp.visa_status,
  cp.profile_photo_url,
  cp.bio,
  cp.is_verified,
  cp.created_at,
  cp.updated_at
from public.candidate_profiles cp
join public.profiles p on p.id = cp.id
where cp.is_visible = true
  and p.status = 'active';

-- =========================================================
-- INTEREST REQUESTS
-- Employer sends interest to candidate.
-- Candidate can accept/reject.
-- =========================================================
create table if not exists public.interest_requests (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.profiles(id) on delete cascade,
  company_id uuid not null references public.employer_companies(id) on delete cascade,
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  message text,
  status public.interest_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, candidate_id)
);

create trigger interest_requests_set_updated_at
before update on public.interest_requests
for each row execute function public.set_updated_at();

create index if not exists interest_requests_candidate_idx on public.interest_requests(candidate_id);
create index if not exists interest_requests_employer_idx on public.interest_requests(employer_id);
create index if not exists interest_requests_company_idx on public.interest_requests(company_id);

-- =========================================================
-- MATCHES + CHAT
-- Match is created automatically when candidate accepts request.
-- =========================================================
create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  interest_request_id uuid unique references public.interest_requests(id) on delete cascade,
  employer_id uuid not null references public.profiles(id) on delete cascade,
  company_id uuid not null references public.employer_companies(id) on delete cascade,
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(company_id, candidate_id)
);

create index if not exists matches_candidate_idx on public.matches(candidate_id);
create index if not exists matches_employer_idx on public.matches(employer_id);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_match_created_idx on public.chat_messages(match_id, created_at);

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

create trigger verification_documents_set_updated_at
before update on public.verification_documents
for each row execute function public.set_updated_at();

create index if not exists verification_documents_owner_idx on public.verification_documents(owner_id);
create index if not exists verification_documents_company_idx on public.verification_documents(company_id);

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
  passport_status text not null default 'not_uploaded',
  visa_status text not null default 'not_uploaded',
  passport_uploaded_at timestamptz,
  visa_uploaded_at timestamptz,
  passport_verified_at timestamptz,
  visa_verified_at timestamptz,
  passport_version integer not null default 0,
  visa_version integer not null default 0,
  passport_is_active boolean not null default false,
  visa_is_active boolean not null default false,
  passport_archived boolean not null default false,
  visa_archived boolean not null default false,
  passport_expiry_notification_sent boolean not null default false,
  visa_expiry_notification_sent boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger candidate_documents_set_updated_at
before update on public.candidate_documents
for each row execute function public.set_updated_at();

create index if not exists candidate_documents_candidate_idx on public.candidate_documents(candidate_id);

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

create or replace function public.create_match_when_interest_accepted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    insert into public.matches (interest_request_id, employer_id, company_id, candidate_id)
    values (new.id, new.employer_id, new.company_id, new.candidate_id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists interest_requests_create_match on public.interest_requests;
create trigger interest_requests_create_match
after update on public.interest_requests
for each row execute function public.create_match_when_interest_accepted();

-- =========================================================
-- STORAGE BUCKETS
-- Public: avatars/profile photos/company logos.
-- Private: resumes/documents.
-- =========================================================
insert into storage.buckets (id, name, public)
values
  ('kaam-public', 'kaam-public', true),
  ('kaam-private', 'kaam-private', false)
on conflict (id) do nothing;

-- =========================================================
-- RLS ENABLEMENT
-- =========================================================
alter table public.profiles enable row level security;
alter table public.candidate_profiles enable row level security;
alter table public.employer_companies enable row level security;
alter table public.employer_hiring_requirements enable row level security;
alter table public.interest_requests enable row level security;
alter table public.matches enable row level security;
alter table public.chat_messages enable row level security;
alter table public.saved_candidates enable row level security;
alter table public.verification_documents enable row level security;
alter table public.candidate_documents enable row level security;
alter table public.candidate_document_versions enable row level security;
alter table public.candidate_document_notifications enable row level security;

-- =========================================================
-- RLS POLICIES: profiles
-- =========================================================
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin"
on public.profiles for select
to authenticated
using (id = auth.uid() or public.is_admin());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles for insert
to authenticated
with check (id = auth.uid());

drop policy if exists "profiles_update_own_or_admin" on public.profiles;
create policy "profiles_update_own_or_admin"
on public.profiles for update
to authenticated
using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

-- =========================================================
-- RLS POLICIES: candidate_profiles
-- =========================================================
drop policy if exists "candidate_select_self_employers_admin" on public.candidate_profiles;
create policy "candidate_select_self_employers_admin"
on public.candidate_profiles for select
to authenticated
using (
  id = auth.uid()
  or public.is_admin()
);

drop policy if exists "candidate_insert_self" on public.candidate_profiles;
create policy "candidate_insert_self"
on public.candidate_profiles for insert
to authenticated
with check (id = auth.uid() and public.my_role() = 'candidate');

drop policy if exists "candidate_update_self_or_admin" on public.candidate_profiles;
create policy "candidate_update_self_or_admin"
on public.candidate_profiles for update
to authenticated
using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

-- =========================================================
-- RLS POLICIES: employer_companies
-- =========================================================
drop policy if exists "companies_select_owner_candidate_if_matched_admin" on public.employer_companies;
create policy "companies_select_owner_candidate_if_matched_admin"
on public.employer_companies for select
to authenticated
using (
  owner_id = auth.uid()
  or public.is_admin()
  or exists (
    select 1 from public.matches m
    where m.company_id = employer_companies.id
      and m.candidate_id = auth.uid()
  )
);

drop policy if exists "companies_insert_owner" on public.employer_companies;
create policy "companies_insert_owner"
on public.employer_companies for insert
to authenticated
with check (owner_id = auth.uid() and public.my_role() = 'employer');

drop policy if exists "companies_update_owner_or_admin" on public.employer_companies;
create policy "companies_update_owner_or_admin"
on public.employer_companies for update
to authenticated
using (owner_id = auth.uid() or public.is_admin())
with check (owner_id = auth.uid() or public.is_admin());

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

-- =========================================================
-- RLS POLICIES: interest_requests
-- =========================================================
drop policy if exists "interests_select_participants_admin" on public.interest_requests;
create policy "interests_select_participants_admin"
on public.interest_requests for select
to authenticated
using (
  employer_id = auth.uid()
  or candidate_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "interests_insert_employer_owner" on public.interest_requests;
create policy "interests_insert_employer_owner"
on public.interest_requests for insert
to authenticated
with check (
  employer_id = auth.uid()
  and public.my_role() = 'employer'
  and exists (
    select 1 from public.employer_companies ec
    where ec.id = company_id
      and ec.owner_id = auth.uid()
      and ec.status <> 'blocked'
  )
);

drop policy if exists "interests_update_participants_admin" on public.interest_requests;
create policy "interests_update_participants_admin"
on public.interest_requests for update
to authenticated
using (
  employer_id = auth.uid()
  or candidate_id = auth.uid()
  or public.is_admin()
)
with check (
  employer_id = auth.uid()
  or candidate_id = auth.uid()
  or public.is_admin()
);

-- =========================================================
-- RLS POLICIES: matches
-- =========================================================
drop policy if exists "matches_select_participants_admin" on public.matches;
create policy "matches_select_participants_admin"
on public.matches for select
to authenticated
using (
  employer_id = auth.uid()
  or candidate_id = auth.uid()
  or public.is_admin()
);

-- Matches are created by trigger/admin, not directly by normal users.
drop policy if exists "matches_insert_admin" on public.matches;
create policy "matches_insert_admin"
on public.matches for insert
to authenticated
with check (public.is_admin());

-- =========================================================
-- RLS POLICIES: chat_messages
-- =========================================================
drop policy if exists "chat_select_match_participants_admin" on public.chat_messages;
create policy "chat_select_match_participants_admin"
on public.chat_messages for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.matches m
    where m.id = chat_messages.match_id
      and (m.employer_id = auth.uid() or m.candidate_id = auth.uid())
  )
);

drop policy if exists "chat_insert_match_participants" on public.chat_messages;
create policy "chat_insert_match_participants"
on public.chat_messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.matches m
    where m.id = match_id
      and (m.employer_id = auth.uid() or m.candidate_id = auth.uid())
  )
);

drop policy if exists "chat_update_sender_or_admin" on public.chat_messages;
create policy "chat_update_sender_or_admin"
on public.chat_messages for update
to authenticated
using (sender_id = auth.uid() or public.is_admin())
with check (sender_id = auth.uid() or public.is_admin());

-- =========================================================
-- RLS POLICIES: saved_candidates
-- =========================================================
drop policy if exists "saved_candidates_owner_all" on public.saved_candidates;
create policy "saved_candidates_owner_all"
on public.saved_candidates for all
to authenticated
using (employer_id = auth.uid() or public.is_admin())
with check (employer_id = auth.uid() or public.is_admin());

-- =========================================================
-- RLS POLICIES: verification_documents
-- =========================================================
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

drop policy if exists "candidate_documents_owner_all" on public.candidate_documents;
create policy "candidate_documents_owner_all"
on public.candidate_documents for all
to authenticated
using (candidate_id = auth.uid() or public.is_admin())
with check (candidate_id = auth.uid() or public.is_admin());

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

-- =========================================================
-- STORAGE POLICIES
-- =========================================================
drop policy if exists "kaam_public_read" on storage.objects;
create policy "kaam_public_read"
on storage.objects for select
to public
using (bucket_id = 'kaam-public');

drop policy if exists "kaam_public_upload_own_folder" on storage.objects;
create policy "kaam_public_upload_own_folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'kaam-public'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "kaam_public_update_own_folder" on storage.objects;
create policy "kaam_public_update_own_folder"
on storage.objects for update
to authenticated
using (
  bucket_id = 'kaam-public'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'kaam-public'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "kaam_private_owner_read" on storage.objects;
create policy "kaam_private_owner_read"
on storage.objects for select
to authenticated
using (
  bucket_id = 'kaam-private'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
  )
);

drop policy if exists "kaam_private_owner_upload" on storage.objects;
create policy "kaam_private_owner_upload"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'kaam-private'
  and (storage.foldername(name))[1] = auth.uid()::text
);

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

-- =========================================================
-- GRANTS
-- =========================================================
grant usage on schema public to anon, authenticated;
grant select on public.public_candidate_search to authenticated;
grant all on public.profiles to authenticated;
grant all on public.candidate_profiles to authenticated;
grant all on public.employer_companies to authenticated;
grant all on public.employer_hiring_requirements to authenticated;
grant all on public.interest_requests to authenticated;
grant all on public.matches to authenticated;
grant all on public.chat_messages to authenticated;
grant all on public.saved_candidates to authenticated;
grant all on public.verification_documents to authenticated;
grant all on public.candidate_documents to authenticated;
grant all on public.candidate_document_versions to authenticated;
grant all on public.candidate_document_notifications to authenticated;

commit;
