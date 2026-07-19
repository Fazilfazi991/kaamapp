-- Kaam notification foundation.
-- Additive only: this migration does not modify the legacy
-- candidate_document_notifications table.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (
    type in (
      'employer_interest_received',
      'interest_accepted',
      'interest_rejected',
      'match_created',
      'new_message',
      'candidate_document_pending',
      'candidate_document_approved',
      'candidate_document_rejected',
      'candidate_document_resubmission_requested',
      'candidate_accepted_interest',
      'candidate_rejected_interest',
      'employer_document_approved',
      'employer_document_rejected',
      'company_approved',
      'company_rejected',
      'candidate_document_submitted',
      'employer_document_submitted',
      'company_review_submitted',
      'admin_broadcast'
    )
  ),
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  action_route text,
  status text not null default 'unread' check (status in ('unread', 'read', 'archived')),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  failed_at timestamptz,
  expires_at timestamptz,
  dedupe_key text,
  created_by uuid references public.profiles(id) on delete set null,
  source_type text,
  source_id uuid,
  push_status text not null default 'pending' check (push_status in ('pending', 'sent', 'skipped', 'failed')),
  push_attempts integer not null default 0 check (push_attempts >= 0),
  last_push_error text,
  constraint notifications_no_sensitive_payload check (
    not (
      data ?| array[
        'passport_number',
        'dob',
        'date_of_birth',
        'phone',
        'email',
        'storage_path',
        'signed_url',
        'otp',
        'access_token',
        'message_body'
      ]
    )
  )
);

create unique index if not exists notifications_recipient_dedupe_idx
on public.notifications(recipient_id, dedupe_key)
where dedupe_key is not null;

create index if not exists notifications_recipient_status_created_idx
on public.notifications(recipient_id, status, created_at desc);

create index if not exists notifications_source_idx
on public.notifications(source_type, source_id);

create index if not exists notifications_push_pending_idx
on public.notifications(push_status, created_at)
where push_status = 'pending';

create table if not exists public.user_push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null check (platform in ('android', 'web')),
  fcm_token text not null,
  device_id text,
  app_version text,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(fcm_token)
);

create index if not exists user_push_devices_user_active_idx
on public.user_push_devices(user_id, is_active, last_seen_at desc);

create trigger user_push_devices_set_updated_at
before update on public.user_push_devices
for each row execute function public.set_updated_at();

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  push_enabled boolean not null default true,
  in_app_enabled boolean not null default true,
  email_enabled boolean not null default false,
  whatsapp_enabled boolean not null default false,
  new_messages_enabled boolean not null default true,
  interests_and_matches_enabled boolean not null default true,
  document_updates_enabled boolean not null default true,
  account_security_enabled boolean not null default true,
  quiet_hours jsonb not null default '{}'::jsonb,
  timezone text not null default 'UTC',
  updated_at timestamptz not null default now()
);

create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

alter table public.notifications enable row level security;
alter table public.user_push_devices enable row level security;
alter table public.notification_preferences enable row level security;

drop policy if exists "notifications_select_own_or_admin" on public.notifications;
create policy "notifications_select_own_or_admin"
on public.notifications for select
using (recipient_id = auth.uid() or public.is_admin());

drop policy if exists "notifications_update_own_read_state_or_admin" on public.notifications;
create policy "notifications_update_own_read_state_or_admin"
on public.notifications for update
using (recipient_id = auth.uid() or public.is_admin())
with check (recipient_id = auth.uid() or public.is_admin());

drop policy if exists "notifications_insert_admin_only" on public.notifications;
create policy "notifications_insert_admin_only"
on public.notifications for insert
with check (public.is_admin());

drop policy if exists "user_push_devices_select_own" on public.user_push_devices;
create policy "user_push_devices_select_own"
on public.user_push_devices for select
using (user_id = auth.uid());

drop policy if exists "user_push_devices_insert_own" on public.user_push_devices;
create policy "user_push_devices_insert_own"
on public.user_push_devices for insert
with check (user_id = auth.uid());

drop policy if exists "user_push_devices_update_own_or_admin" on public.user_push_devices;
create policy "user_push_devices_update_own_or_admin"
on public.user_push_devices for update
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "notification_preferences_select_own_or_admin" on public.notification_preferences;
create policy "notification_preferences_select_own_or_admin"
on public.notification_preferences for select
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "notification_preferences_insert_own" on public.notification_preferences;
create policy "notification_preferences_insert_own"
on public.notification_preferences for insert
with check (user_id = auth.uid());

drop policy if exists "notification_preferences_update_own_or_admin" on public.notification_preferences;
create policy "notification_preferences_update_own_or_admin"
on public.notification_preferences for update
using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create or replace view public.admin_push_device_status as
select
  id,
  user_id,
  platform,
  is_active,
  last_seen_at,
  created_at,
  updated_at,
  app_version,
  case when fcm_token is null then false else true end as has_fcm_token
from public.user_push_devices;

create or replace function public.create_notification(
  p_recipient_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_action_route text default null,
  p_data jsonb default '{}'::jsonb,
  p_dedupe_key text default null,
  p_source_type text default null,
  p_source_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_notification_id uuid;
begin
  if exists (
    select 1 from public.profiles
    where id = p_recipient_id and status = 'blocked'
  ) then
    return null;
  end if;

  insert into public.notifications (
    recipient_id,
    type,
    title,
    body,
    action_route,
    data,
    dedupe_key,
    source_type,
    source_id,
    created_by
  )
  values (
    p_recipient_id,
    p_type,
    left(p_title, 140),
    left(p_body, 280),
    p_action_route,
    coalesce(p_data, '{}'::jsonb),
    p_dedupe_key,
    p_source_type,
    p_source_id,
    auth.uid()
  )
  on conflict (recipient_id, dedupe_key) where dedupe_key is not null
  do update set created_at = public.notifications.created_at
  returning id into v_notification_id;

  return v_notification_id;
end;
$$;

grant select on public.notifications to authenticated;
grant update(status, read_at) on public.notifications to authenticated;
grant select, insert, update on public.user_push_devices to authenticated;
grant select, insert, update on public.notification_preferences to authenticated;
grant select on public.admin_push_device_status to authenticated;
revoke execute on function public.create_notification(uuid, text, text, text, text, jsonb, text, text, uuid) from public;
revoke execute on function public.create_notification(uuid, text, text, text, text, jsonb, text, text, uuid) from anon;
revoke execute on function public.create_notification(uuid, text, text, text, text, jsonb, text, text, uuid) from authenticated;

create or replace function public.notify_interest_request_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.create_notification(
    new.candidate_id,
    'employer_interest_received',
    'New employer interest',
    'A verified employer is interested in your profile.',
    '/candidate/interests',
    jsonb_build_object('interest_request_id', new.id),
    'interest-created:' || new.id::text,
    'interest_requests',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists notifications_interest_request_created on public.interest_requests;
create trigger notifications_interest_request_created
after insert on public.interest_requests
for each row execute function public.notify_interest_request_created();

create or replace function public.notify_interest_request_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is distinct from new.status and new.status in ('accepted', 'rejected') then
    perform public.create_notification(
      new.employer_id,
      case when new.status = 'accepted' then 'candidate_accepted_interest' else 'candidate_rejected_interest' end,
      case when new.status = 'accepted' then 'Interest accepted' else 'Interest declined' end,
      case when new.status = 'accepted' then 'A candidate accepted your interest request.' else 'A candidate declined your interest request.' end,
      '/employer/interests',
      jsonb_build_object('interest_request_id', new.id),
      'interest-status:' || new.id::text || ':' || new.status,
      'interest_requests',
      new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notifications_interest_request_status on public.interest_requests;
create trigger notifications_interest_request_status
after update of status on public.interest_requests
for each row execute function public.notify_interest_request_status();

create or replace function public.notify_match_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.create_notification(
    new.candidate_id,
    'match_created',
    'Match unlocked',
    'You have a new verified match.',
    '/candidate/matches',
    jsonb_build_object('match_id', new.id),
    'match-created:candidate:' || new.id::text,
    'matches',
    new.id
  );
  perform public.create_notification(
    new.employer_id,
    'match_created',
    'Match unlocked',
    'You have a new verified match.',
    '/employer/matches',
    jsonb_build_object('match_id', new.id),
    'match-created:employer:' || new.id::text,
    'matches',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists notifications_match_created on public.matches;
create trigger notifications_match_created
after insert on public.matches
for each row execute function public.notify_match_created();

create or replace function public.notify_chat_message_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches%rowtype;
  v_recipient_id uuid;
  v_route text;
begin
  select * into v_match from public.matches where id = new.match_id;
  if not found then
    return new;
  end if;

  if new.sender_id = v_match.candidate_id then
    v_recipient_id := v_match.employer_id;
    v_route := '/employer/messages';
  elsif new.sender_id = v_match.employer_id then
    v_recipient_id := v_match.candidate_id;
    v_route := '/candidate/messages';
  else
    return new;
  end if;

  perform public.create_notification(
    v_recipient_id,
    'new_message',
    'New message',
    'You received a new message.',
    v_route,
    jsonb_build_object('match_id', new.match_id),
    'message:' || new.id::text,
    'chat_messages',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists notifications_chat_message_created on public.chat_messages;
create trigger notifications_chat_message_created
after insert on public.chat_messages
for each row execute function public.notify_chat_message_created();

create or replace function public.notify_candidate_document_submitted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('pending', 'pending_review') then
    insert into public.notifications (
      recipient_id, type, title, body, action_route, data, dedupe_key, source_type, source_id
    )
    select
      p.id,
      'candidate_document_submitted',
      'Candidate document submitted',
      'A candidate document is ready for review.',
      '/admin/candidate-documents',
      jsonb_build_object('candidate_id', new.candidate_id, 'document_type', new.document_type),
      'candidate-document-submitted:' || new.id::text,
      'candidate_document_versions',
      new.id
    from public.profiles p
    where p.role = 'admin' and p.status <> 'blocked'
    on conflict (recipient_id, dedupe_key) where dedupe_key is not null do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists notifications_candidate_document_submitted on public.candidate_document_versions;
create trigger notifications_candidate_document_submitted
after insert on public.candidate_document_versions
for each row execute function public.notify_candidate_document_submitted();

create or replace function public.notify_candidate_document_reviewed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text;
  v_title text;
  v_body text;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status = 'verified' then
    v_type := 'candidate_document_approved';
    v_title := 'Document approved';
    v_body := 'Your document has been approved by Kaam.';
  elsif new.status = 'rejected' then
    v_type := 'candidate_document_rejected';
    v_title := 'Document needs review';
    v_body := 'Your document was not approved. Please review the request and resubmit.';
  elsif new.status = 'resubmission_requested' then
    v_type := 'candidate_document_resubmission_requested';
    v_title := 'Document resubmission requested';
    v_body := 'Please review the document request and upload a new version.';
  else
    return new;
  end if;

  perform public.create_notification(
    new.candidate_id,
    v_type,
    v_title,
    v_body,
    '/candidate/documents',
    jsonb_build_object('document_type', new.document_type, 'version_id', new.id),
    'candidate-document-reviewed:' || new.id::text || ':' || new.status,
    'candidate_document_versions',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists notifications_candidate_document_reviewed on public.candidate_document_versions;
create trigger notifications_candidate_document_reviewed
after update of status on public.candidate_document_versions
for each row execute function public.notify_candidate_document_reviewed();

create or replace function public.notify_verification_document_submitted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('pending', 'pending_review') then
    insert into public.notifications (
      recipient_id, type, title, body, action_route, data, dedupe_key, source_type, source_id
    )
    select
      p.id,
      'employer_document_submitted',
      'Employer document submitted',
      'An employer verification document is ready for review.',
      '/admin/employer-documents',
      jsonb_build_object('owner_id', new.owner_id, 'document_type', new.document_type),
      'employer-document-submitted:' || new.id::text,
      'verification_documents',
      new.id
    from public.profiles p
    where p.role = 'admin' and p.status <> 'blocked'
    on conflict (recipient_id, dedupe_key) where dedupe_key is not null do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists notifications_verification_document_submitted on public.verification_documents;
create trigger notifications_verification_document_submitted
after insert on public.verification_documents
for each row execute function public.notify_verification_document_submitted();

create or replace function public.notify_employer_document_reviewed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text;
  v_title text;
  v_body text;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status = 'approved' then
    v_type := 'employer_document_approved';
    v_title := 'Employer document approved';
    v_body := 'Your employer document has been approved by Kaam.';
  elsif new.status in ('rejected', 'resubmission_requested') then
    v_type := 'employer_document_rejected';
    v_title := 'Employer document needs review';
    v_body := 'Please review the document request and upload an updated document.';
  else
    return new;
  end if;

  perform public.create_notification(
    new.owner_id,
    v_type,
    v_title,
    v_body,
    '/employer/documents',
    jsonb_build_object('document_type', new.document_type, 'document_id', new.id),
    'employer-document-reviewed:' || new.id::text || ':' || new.status,
    'verification_documents',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists notifications_employer_document_reviewed on public.verification_documents;
create trigger notifications_employer_document_reviewed
after update of status on public.verification_documents
for each row execute function public.notify_employer_document_reviewed();

create or replace function public.notify_company_review_submitted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_verified = true or new.status = 'blocked' then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.status is not distinct from new.status
      and old.is_verified is not distinct from new.is_verified then
      return new;
    end if;
  end if;

  insert into public.notifications (
    recipient_id, type, title, body, action_route, data, dedupe_key, source_type, source_id
  )
  select
    p.id,
    'company_review_submitted',
    'Company review submitted',
    'An employer company profile is ready for review.',
    '/admin/employers',
    jsonb_build_object('company_id', new.id, 'owner_id', new.owner_id),
    'company-review-submitted:' || new.id::text || ':' || coalesce(new.status::text, 'unknown'),
    'employer_companies',
    new.id
  from public.profiles p
  where p.role = 'admin' and p.status <> 'blocked'
  on conflict (recipient_id, dedupe_key) where dedupe_key is not null do nothing;

  return new;
end;
$$;

drop trigger if exists notifications_company_review_submitted on public.employer_companies;
create trigger notifications_company_review_submitted
after insert or update of status on public.employer_companies
for each row execute function public.notify_company_review_submitted();

create or replace function public.notify_company_reviewed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is not distinct from new.status
    and old.is_verified is not distinct from new.is_verified then
    return new;
  end if;

  if new.is_verified is not true then
    return new;
  end if;

  perform public.create_notification(
    new.owner_id,
    'company_approved',
    'Company approved',
    'Your company profile has been approved by Kaam.',
    '/employer/profile',
    jsonb_build_object('company_id', new.id),
    'company-reviewed:' || new.id::text || ':' || coalesce(new.status::text, 'unknown') || ':' || coalesce(new.is_verified::text, 'false'),
    'employer_companies',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists notifications_company_reviewed on public.employer_companies;
create trigger notifications_company_reviewed
after update of status, is_verified on public.employer_companies
for each row execute function public.notify_company_reviewed();
