-- Candidate-level manual verification is intentionally separate from account,
-- profile-completion, and individual document review statuses.
alter table public.candidate_profiles
  add column if not exists verification_status text not null default 'pending_verification',
  add column if not exists verified_at timestamptz,
  add column if not exists verified_by uuid references public.profiles(id) on delete set null,
  add column if not exists verification_notes text,
  add column if not exists verification_updated_at timestamptz not null default now();

alter table public.candidate_profiles
  drop constraint if exists candidate_profiles_verification_status_check;

alter table public.candidate_profiles
  add constraint candidate_profiles_verification_status_check
  check (verification_status in (
    'not_submitted',
    'pending_verification',
    'verified',
    'rejected',
    'reverification_required'
  ));

create index if not exists candidate_profiles_verification_status_idx
  on public.candidate_profiles(verification_status);

create table if not exists public.candidate_verification_audit_events (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  admin_id uuid references public.profiles(id) on delete set null,
  previous_status text,
  new_status text not null check (new_status in (
    'not_submitted',
    'pending_verification',
    'verified',
    'rejected',
    'reverification_required'
  )),
  action text not null check (action in (
    'candidate_verified',
    'candidate_verification_rejected',
    'candidate_reverification_required'
  )),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists candidate_verification_audit_events_candidate_created_idx
  on public.candidate_verification_audit_events(candidate_id, created_at desc);

alter table public.candidate_verification_audit_events enable row level security;

drop policy if exists "candidate_verification_audit_events_admin_select" on public.candidate_verification_audit_events;
create policy "candidate_verification_audit_events_admin_select"
on public.candidate_verification_audit_events for select to authenticated
using (public.is_admin());

drop policy if exists "candidate_verification_audit_events_admin_insert" on public.candidate_verification_audit_events;
create policy "candidate_verification_audit_events_admin_insert"
on public.candidate_verification_audit_events for insert to authenticated
with check (public.is_admin() and admin_id = auth.uid());

grant select, insert on public.candidate_verification_audit_events to authenticated;

