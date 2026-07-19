-- KAAM scheduled and automatic notifications.
-- Additive only. Stores schedules in UTC and processes them server-side.

begin;

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (
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
      'general_announcement',
      'document_update',
      'membership_update',
      'match_update',
      'account_alert',
      'promotional',
      'maintenance',
      'urgent_alert',
      'admin_broadcast',
      'document_expiry_reminder',
      'document_expired',
      'membership_expiry_reminder',
      'membership_expired',
      'pending_interest_reminder',
      'incomplete_profile_reminder',
      'weekly_summary',
      'admin_alert',
      'notification_delivery_failure'
    )
  );

create table if not exists public.notification_schedules (
  id uuid primary key default gen_random_uuid(),
  notification_type text not null,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 140),
  body text not null check (char_length(btrim(body)) between 1 and 280),
  action_route text,
  data jsonb not null default '{}'::jsonb,
  scheduled_at timestamptz not null,
  status text not null default 'pending' check (
    status in ('pending', 'processing', 'sent', 'partially_sent', 'failed', 'cancelled', 'skipped')
  ),
  channels jsonb not null default '["in_app"]'::jsonb,
  dedupe_key text not null,
  attempts integer not null default 0 check (attempts >= 0),
  last_error_code text,
  failure_reason text,
  processed_at timestamptz,
  source_type text,
  source_id uuid,
  in_app_notification_id uuid references public.notifications(id) on delete set null,
  in_app_created_count integer not null default 0 check (in_app_created_count >= 0),
  push_eligible_count integer not null default 0 check (push_eligible_count >= 0),
  fcm_accepted_count integer not null default 0 check (fcm_accepted_count >= 0),
  push_failed_count integer not null default 0 check (push_failed_count >= 0),
  skipped_count integer not null default 0 check (skipped_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_schedules_channels_array check (jsonb_typeof(channels) = 'array'),
  constraint notification_schedules_no_sensitive_payload check (
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

drop trigger if exists notification_schedules_set_updated_at on public.notification_schedules;
create trigger notification_schedules_set_updated_at
before update on public.notification_schedules
for each row execute function public.set_updated_at();

create index if not exists notification_schedules_scheduled_at_idx
on public.notification_schedules(scheduled_at);

create index if not exists notification_schedules_status_scheduled_idx
on public.notification_schedules(status, scheduled_at);

create index if not exists notification_schedules_recipient_idx
on public.notification_schedules(recipient_id, scheduled_at desc);

create index if not exists notification_schedules_dedupe_idx
on public.notification_schedules(dedupe_key);

create unique index if not exists notification_schedules_recipient_dedupe_idx
on public.notification_schedules(recipient_id, dedupe_key);

create index if not exists notification_schedules_source_idx
on public.notification_schedules(source_type, source_id);

alter table public.notification_schedules enable row level security;

drop policy if exists "notification_schedules_admin_all" on public.notification_schedules;
create policy "notification_schedules_admin_all"
on public.notification_schedules for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "notification_schedules_user_select_own" on public.notification_schedules;
create policy "notification_schedules_user_select_own"
on public.notification_schedules for select
to authenticated
using (recipient_id = auth.uid());

grant select, insert, update on public.notification_schedules to authenticated;

create or replace function public.enqueue_notification_schedule(
  p_notification_type text,
  p_recipient_id uuid,
  p_title text,
  p_body text,
  p_action_route text,
  p_data jsonb,
  p_scheduled_at timestamptz,
  p_channels jsonb,
  p_dedupe_key text,
  p_source_type text default null,
  p_source_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_schedule_id uuid;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Admin access is required';
  end if;

  insert into public.notification_schedules (
    notification_type,
    recipient_id,
    title,
    body,
    action_route,
    data,
    scheduled_at,
    channels,
    dedupe_key,
    source_type,
    source_id
  )
  values (
    p_notification_type,
    p_recipient_id,
    left(p_title, 140),
    left(p_body, 280),
    p_action_route,
    coalesce(p_data, '{}'::jsonb),
    p_scheduled_at,
    coalesce(p_channels, '["in_app"]'::jsonb),
    p_dedupe_key,
    p_source_type,
    p_source_id
  )
  on conflict (recipient_id, dedupe_key) do update set
    title = excluded.title,
    body = excluded.body,
    action_route = excluded.action_route,
    data = excluded.data,
    scheduled_at = excluded.scheduled_at,
    channels = excluded.channels,
    source_type = excluded.source_type,
    source_id = excluded.source_id,
    status = case
      when public.notification_schedules.status in ('pending', 'failed') then 'pending'
      else public.notification_schedules.status
    end,
    last_error_code = null,
    failure_reason = null,
    updated_at = now()
  returning id into v_schedule_id;

  return v_schedule_id;
end;
$$;

revoke execute on function public.enqueue_notification_schedule(text, uuid, text, text, text, jsonb, timestamptz, jsonb, text, text, uuid) from public;
grant execute on function public.enqueue_notification_schedule(text, uuid, text, text, text, jsonb, timestamptz, jsonb, text, text, uuid) to authenticated;
grant execute on function public.enqueue_notification_schedule(text, uuid, text, text, text, jsonb, timestamptz, jsonb, text, text, uuid) to service_role;

create or replace function public.claim_due_notification_schedules(p_limit integer default 50)
returns setof public.notification_schedules
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with claimed as (
    select ns.id
    from public.notification_schedules ns
    where ns.scheduled_at <= now()
      and (
        ns.status = 'pending'
        or (
          ns.status = 'failed'
          and ns.attempts < 3
          and ns.updated_at <= now() - interval '5 minutes'
        )
      )
    order by ns.scheduled_at asc, ns.created_at asc
    limit greatest(1, least(coalesce(p_limit, 50), 100))
    for update skip locked
  )
  update public.notification_schedules ns
  set status = 'processing',
      attempts = ns.attempts + 1,
      last_error_code = null,
      failure_reason = null,
      updated_at = now()
  from claimed
  where ns.id = claimed.id
  returning ns.*;
end;
$$;

revoke execute on function public.claim_due_notification_schedules(integer) from public;
revoke execute on function public.claim_due_notification_schedules(integer) from anon;
revoke execute on function public.claim_due_notification_schedules(integer) from authenticated;
grant execute on function public.claim_due_notification_schedules(integer) to service_role;

create or replace function public.mark_notification_schedule_result(
  p_schedule_id uuid,
  p_status text,
  p_in_app_notification_id uuid default null,
  p_in_app_created_count integer default 0,
  p_push_eligible_count integer default 0,
  p_fcm_accepted_count integer default 0,
  p_push_failed_count integer default 0,
  p_skipped_count integer default 0,
  p_last_error_code text default null,
  p_failure_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notification_schedules
  set status = p_status,
      in_app_notification_id = coalesce(p_in_app_notification_id, in_app_notification_id),
      in_app_created_count = greatest(0, coalesce(p_in_app_created_count, 0)),
      push_eligible_count = greatest(0, coalesce(p_push_eligible_count, 0)),
      fcm_accepted_count = greatest(0, coalesce(p_fcm_accepted_count, 0)),
      push_failed_count = greatest(0, coalesce(p_push_failed_count, 0)),
      skipped_count = greatest(0, coalesce(p_skipped_count, 0)),
      last_error_code = p_last_error_code,
      failure_reason = p_failure_reason,
      processed_at = case when p_status in ('sent', 'partially_sent', 'skipped', 'cancelled') then now() else processed_at end,
      updated_at = now()
  where id = p_schedule_id;
end;
$$;

revoke execute on function public.mark_notification_schedule_result(uuid, text, uuid, integer, integer, integer, integer, integer, text, text) from public;
revoke execute on function public.mark_notification_schedule_result(uuid, text, uuid, integer, integer, integer, integer, integer, text, text) from anon;
revoke execute on function public.mark_notification_schedule_result(uuid, text, uuid, integer, integer, integer, integer, integer, text, text) from authenticated;
grant execute on function public.mark_notification_schedule_result(uuid, text, uuid, integer, integer, integer, integer, integer, text, text) to service_role;

create or replace function public.refresh_admin_notification_delivery_from_schedules(p_admin_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total integer;
  v_done integer;
  v_failed integer;
  v_cancelled integer;
  v_sent integer;
begin
  select
    count(*)::integer,
    count(*) filter (where status in ('sent', 'partially_sent', 'skipped', 'failed', 'cancelled'))::integer,
    count(*) filter (where status = 'failed')::integer,
    count(*) filter (where status = 'cancelled')::integer,
    count(*) filter (where status in ('sent', 'partially_sent', 'skipped'))::integer
  into v_total, v_done, v_failed, v_cancelled, v_sent
  from public.notification_schedules
  where source_type = 'admin_notification'
    and source_id = p_admin_notification_id;

  if coalesce(v_total, 0) = 0 then
    return;
  end if;

  update public.admin_notifications an
  set
    status = case
      when v_cancelled = v_total then 'cancelled'
      when v_failed = v_total then 'failed'
      when v_done < v_total then an.status
      when v_failed > 0 then 'partially_sent'
      when v_sent > 0 then 'sent'
      else an.status
    end,
    in_app_success_count = coalesce((
      select sum(in_app_created_count)::integer
      from public.notification_schedules
      where source_type = 'admin_notification' and source_id = p_admin_notification_id
    ), 0),
    push_eligible_device_count = coalesce((
      select sum(push_eligible_count)::integer
      from public.notification_schedules
      where source_type = 'admin_notification' and source_id = p_admin_notification_id
    ), 0),
    push_success_count = coalesce((
      select sum(fcm_accepted_count)::integer
      from public.notification_schedules
      where source_type = 'admin_notification' and source_id = p_admin_notification_id
    ), 0),
    push_failure_count = coalesce((
      select sum(push_failed_count)::integer
      from public.notification_schedules
      where source_type = 'admin_notification' and source_id = p_admin_notification_id
    ), 0),
    push_skipped_count = coalesce((
      select sum(skipped_count)::integer
      from public.notification_schedules
      where source_type = 'admin_notification' and source_id = p_admin_notification_id
    ), 0),
    failure_summary = (
      select string_agg(distinct failure_reason, '; ')
      from public.notification_schedules
      where source_type = 'admin_notification'
        and source_id = p_admin_notification_id
        and failure_reason is not null
    ),
    sent_at = case when v_done = v_total and an.sent_at is null then now() else an.sent_at end,
    updated_at = now()
  where an.id = p_admin_notification_id;
end;
$$;

revoke execute on function public.refresh_admin_notification_delivery_from_schedules(uuid) from public;
revoke execute on function public.refresh_admin_notification_delivery_from_schedules(uuid) from anon;
revoke execute on function public.refresh_admin_notification_delivery_from_schedules(uuid) from authenticated;
grant execute on function public.refresh_admin_notification_delivery_from_schedules(uuid) to service_role;

create or replace function public.generate_document_expiry_notification_schedules()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_row record;
  v_days integer;
  v_expiry date;
  v_scheduled_at timestamptz;
begin
  for v_row in
    select cd.candidate_id, kind.document_type, kind.expiry_text
    from public.candidate_documents cd
    cross join lateral (
      values
        ('passport'::text, cd.passport_expiry_date),
        ('visa'::text, cd.visa_expiry_date)
    ) as kind(document_type, expiry_text)
    join public.profiles p on p.id = cd.candidate_id
    where p.status <> 'blocked'
      and kind.expiry_text ~ '^\d{4}-\d{2}-\d{2}$'
  loop
    v_expiry := v_row.expiry_text::date;
    foreach v_days in array array[30, 7, 1, 0] loop
      v_scheduled_at := ((v_expiry - v_days) + time '18:00') at time zone 'Asia/Dubai';
      if v_scheduled_at >= now() - interval '1 day' then
        perform public.enqueue_notification_schedule(
          case when v_days = 0 then 'document_expired' else 'document_expiry_reminder' end,
          v_row.candidate_id,
          case when v_days = 0 then 'Document expired' else 'Document expiry reminder' end,
          case
            when v_days = 0 then 'One of your documents has expired. Please update it in Kaam.'
            when v_days = 1 then 'One of your documents expires tomorrow. Please update it in Kaam.'
            else 'One of your documents is expiring soon. Please review it in Kaam.'
          end,
          '/candidate/documents',
          jsonb_build_object('document_type', v_row.document_type, 'days_before', v_days),
          v_scheduled_at,
          '["in_app","push"]'::jsonb,
          'document-expiry:' || v_row.candidate_id::text || ':' || v_row.document_type || ':' || v_expiry::text || ':' || v_days::text,
          'candidate_documents',
          v_row.candidate_id
        );
        v_count := v_count + 1;
      end if;
    end loop;
  end loop;
  return v_count;
end;
$$;

create or replace function public.generate_membership_expiry_notification_schedules()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_row record;
  v_days integer;
  v_scheduled_at timestamptz;
begin
  for v_row in
    select cm.id, cm.candidate_id, cm.expires_at
    from public.candidate_memberships cm
    join public.profiles p on p.id = cm.candidate_id
    where cm.expires_at is not null
      and cm.status in ('active', 'expired')
      and p.status <> 'blocked'
  loop
    foreach v_days in array array[7, 3, 1, 0] loop
      v_scheduled_at := ((v_row.expires_at at time zone 'Asia/Dubai')::date - v_days + time '18:00') at time zone 'Asia/Dubai';
      if v_scheduled_at >= now() - interval '1 day' then
        perform public.enqueue_notification_schedule(
          case when v_days = 0 then 'membership_expired' else 'membership_expiry_reminder' end,
          v_row.candidate_id,
          case when v_days = 0 then 'Membership expired' else 'Membership expiry reminder' end,
          case
            when v_days = 0 then 'Your Kaam membership has expired.'
            when v_days = 1 then 'Your Kaam membership expires tomorrow.'
            else 'Your Kaam membership is expiring soon.'
          end,
          '/candidate/membership',
          jsonb_build_object('membership_id', v_row.id, 'days_before', v_days),
          v_scheduled_at,
          '["in_app","push"]'::jsonb,
          'membership-expiry:' || v_row.id::text || ':' || v_days::text,
          'candidate_memberships',
          v_row.id
        );
        v_count := v_count + 1;
      end if;
    end loop;
  end loop;
  return v_count;
end;
$$;

create or replace function public.generate_pending_interest_notification_schedules()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_row record;
begin
  for v_row in
    select ir.id, ir.candidate_id, ir.created_at
    from public.interest_requests ir
    join public.profiles p on p.id = ir.candidate_id
    where ir.status = 'pending'
      and p.status <> 'blocked'
  loop
    perform public.enqueue_notification_schedule(
      'pending_interest_reminder',
      v_row.candidate_id,
      'Pending employer interest',
      'You have an employer interest request waiting for your response.',
      '/candidate/interests',
      jsonb_build_object('interest_request_id', v_row.id),
      v_row.created_at + interval '24 hours',
      '["in_app","push"]'::jsonb,
      'interest-pending-24h:' || v_row.id::text,
      'interest_requests',
      v_row.id
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.generate_incomplete_profile_notification_schedules()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_row record;
  v_hours integer;
begin
  for v_row in
    select p.id, p.created_at, p.role
    from public.profiles p
    left join public.candidate_profiles cp on cp.id = p.id
    left join public.employer_companies ec on ec.owner_id = p.id
    where p.status <> 'blocked'
      and p.role in ('candidate', 'employer')
      and (
        (p.role = 'candidate' and (cp.id is null or not public.candidate_profile_completed(cp)))
        or (p.role = 'employer' and ec.id is null)
      )
  loop
    foreach v_hours in array array[24, 72, 168] loop
      perform public.enqueue_notification_schedule(
        'incomplete_profile_reminder',
        v_row.id,
        'Complete your Kaam profile',
        'Finish your profile so Kaam can show you better opportunities.',
        case when v_row.role = 'candidate' then '/candidate/onboarding' else '/employer/onboarding' end,
        jsonb_build_object('hours_after_signup', v_hours),
        v_row.created_at + make_interval(hours => v_hours),
        '["in_app","push"]'::jsonb,
        'incomplete-profile:' || v_row.id::text || ':' || v_hours::text,
        'profiles',
        v_row.id
      );
      v_count := v_count + 1;
    end loop;
  end loop;
  return v_count;
end;
$$;

create or replace function public.generate_weekly_summary_notification_schedules()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_row record;
  v_next_sunday timestamptz;
  v_target timestamptz;
begin
  v_next_sunday := ((date_trunc('week', now() at time zone 'Asia/Dubai')::date + 6) + time '18:00') at time zone 'Asia/Dubai';
  if v_next_sunday <= now() then
    v_next_sunday := v_next_sunday + interval '7 days';
  end if;

  for v_row in
    select p.id, p.role,
      coalesce((select count(*) from public.interest_requests ir where ir.candidate_id = p.id and ir.created_at >= now() - interval '7 days'), 0) as interests_received,
      coalesce((select count(*) from public.matches m where (m.candidate_id = p.id or m.employer_id = p.id) and m.created_at >= now() - interval '7 days'), 0) as matches_count,
      coalesce((select count(*) from public.chat_messages cm join public.matches m on m.id = cm.match_id where cm.is_read = false and cm.sender_id <> p.id and (m.candidate_id = p.id or m.employer_id = p.id)), 0) as unread_messages
    from public.profiles p
    where p.role in ('candidate', 'employer') and p.status <> 'blocked'
  loop
    if (v_row.interests_received + v_row.matches_count + v_row.unread_messages) > 0 then
      v_target := v_next_sunday;
      perform public.enqueue_notification_schedule(
        'weekly_summary',
        v_row.id,
        'Your weekly Kaam summary',
        'Your weekly Kaam activity summary is ready.',
        case when v_row.role = 'candidate' then '/candidate/dashboard' else '/employer/dashboard' end,
        jsonb_build_object(
          'interests_received', v_row.interests_received,
          'matches', v_row.matches_count,
          'unread_messages', v_row.unread_messages
        ),
        v_target,
        '["in_app","push"]'::jsonb,
        'weekly-summary:' || v_row.id::text || ':' || to_char(v_target at time zone 'Asia/Dubai', 'IYYY-IW'),
        'profiles',
        v_row.id
      );
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

create or replace function public.generate_admin_alert_notification_schedules()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_admin record;
  v_candidate_pending integer;
  v_employer_pending integer;
  v_delivery_failures integer;
begin
  select count(*)::integer into v_candidate_pending
  from public.candidate_document_versions
  where status in ('pending', 'pending_review', 'pending_verification');

  select count(*)::integer into v_employer_pending
  from public.verification_documents
  where status in ('pending', 'pending_review', 'pending_verification');

  select count(*)::integer into v_delivery_failures
  from public.notification_schedules
  where status = 'failed' and updated_at >= now() - interval '1 day';

  for v_admin in select id from public.profiles where role = 'admin' and status <> 'blocked' loop
    if v_candidate_pending > 0 then
      perform public.enqueue_notification_schedule(
        'admin_alert',
        v_admin.id,
        'Candidate documents pending',
        'Candidate documents are waiting for admin review.',
        '/admin/candidate-documents',
        jsonb_build_object('pending_count', v_candidate_pending),
        now(),
        '["in_app"]'::jsonb,
        'admin-alert:candidate-documents:' || to_char(now() at time zone 'Asia/Dubai', 'YYYY-MM-DD-HH24'),
        'candidate_document_versions',
        null
      );
      v_count := v_count + 1;
    end if;
    if v_employer_pending > 0 then
      perform public.enqueue_notification_schedule(
        'admin_alert',
        v_admin.id,
        'Employer documents pending',
        'Employer documents are waiting for admin review.',
        '/admin/employer-documents',
        jsonb_build_object('pending_count', v_employer_pending),
        now(),
        '["in_app"]'::jsonb,
        'admin-alert:employer-documents:' || to_char(now() at time zone 'Asia/Dubai', 'YYYY-MM-DD-HH24'),
        'verification_documents',
        null
      );
      v_count := v_count + 1;
    end if;
    if v_delivery_failures > 0 then
      perform public.enqueue_notification_schedule(
        'notification_delivery_failure',
        v_admin.id,
        'Notification delivery failures',
        'Some scheduled notifications failed delivery and need review.',
        '/admin/notifications?status=failed',
        jsonb_build_object('failure_count', v_delivery_failures),
        now(),
        '["in_app"]'::jsonb,
        'admin-alert:notification-failures:' || to_char(now() at time zone 'Asia/Dubai', 'YYYY-MM-DD-HH24'),
        'notification_schedules',
        null
      );
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

create or replace function public.generate_automatic_notification_schedules()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_document integer;
  v_membership integer;
  v_interest integer;
  v_incomplete integer;
  v_weekly integer;
  v_admin integer;
begin
  v_document := public.generate_document_expiry_notification_schedules();
  v_membership := public.generate_membership_expiry_notification_schedules();
  v_interest := public.generate_pending_interest_notification_schedules();
  v_incomplete := public.generate_incomplete_profile_notification_schedules();
  v_weekly := public.generate_weekly_summary_notification_schedules();
  v_admin := public.generate_admin_alert_notification_schedules();
  return jsonb_build_object(
    'document_expiry', v_document,
    'membership_expiry', v_membership,
    'pending_interest', v_interest,
    'incomplete_profile', v_incomplete,
    'weekly_summary', v_weekly,
    'admin_alerts', v_admin
  );
end;
$$;

revoke execute on function public.generate_document_expiry_notification_schedules() from public;
revoke execute on function public.generate_membership_expiry_notification_schedules() from public;
revoke execute on function public.generate_pending_interest_notification_schedules() from public;
revoke execute on function public.generate_incomplete_profile_notification_schedules() from public;
revoke execute on function public.generate_weekly_summary_notification_schedules() from public;
revoke execute on function public.generate_admin_alert_notification_schedules() from public;
revoke execute on function public.generate_automatic_notification_schedules() from public;
revoke execute on function public.generate_document_expiry_notification_schedules() from anon, authenticated;
revoke execute on function public.generate_membership_expiry_notification_schedules() from anon, authenticated;
revoke execute on function public.generate_pending_interest_notification_schedules() from anon, authenticated;
revoke execute on function public.generate_incomplete_profile_notification_schedules() from anon, authenticated;
revoke execute on function public.generate_weekly_summary_notification_schedules() from anon, authenticated;
revoke execute on function public.generate_admin_alert_notification_schedules() from anon, authenticated;
revoke execute on function public.generate_automatic_notification_schedules() from anon, authenticated;
grant execute on function public.generate_document_expiry_notification_schedules() to service_role;
grant execute on function public.generate_membership_expiry_notification_schedules() to service_role;
grant execute on function public.generate_pending_interest_notification_schedules() to service_role;
grant execute on function public.generate_incomplete_profile_notification_schedules() to service_role;
grant execute on function public.generate_weekly_summary_notification_schedules() to service_role;
grant execute on function public.generate_admin_alert_notification_schedules() to service_role;
grant execute on function public.generate_automatic_notification_schedules() to service_role;

-- Supabase Cron option. The processor verifies the shared bearer secret.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

do $$
begin
  perform cron.unschedule('kaam-process-scheduled-notifications');
exception when others then
  null;
end $$;

select cron.schedule(
  'kaam-process-scheduled-notifications',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := current_setting('app.settings.supabase_url', true) || '/functions/v1/process-scheduled-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.scheduled_notifications_secret', true)
    ),
    body := jsonb_build_object('source', 'pg_cron')
  );
  $$
);

notify pgrst, 'reload schema';

commit;

-- Rollback cron only:
-- select cron.unschedule('kaam-process-scheduled-notifications');
