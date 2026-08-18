-- Production push hardening. Apply after migrations 013-023.
-- Canonical notifications stay in `notifications`; this table only records
-- dispatch work so database writes and FCM retries are independently durable.
create table if not exists public.notification_push_outbox (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null unique references public.notifications(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','processing','sent','failed','skipped')),
  attempts integer not null default 0 check (attempts >= 0),
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists notification_push_outbox_due_idx
  on public.notification_push_outbox(status, available_at)
  where status in ('pending','failed');

create table if not exists public.notification_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  device_id uuid references public.user_push_devices(id) on delete set null,
  status text not null check (status in ('accepted','failed','invalid','skipped')),
  provider_code text,
  created_at timestamptz not null default now()
);
create index if not exists notification_delivery_attempts_notification_idx
  on public.notification_delivery_attempts(notification_id, created_at desc);

alter table public.notification_preferences
  add column if not exists profile_views_enabled boolean not null default true,
  add column if not exists membership_updates_enabled boolean not null default true;

alter table public.user_push_devices
  add column if not exists device_name text,
  add column if not exists installation_id text;
create unique index if not exists user_push_devices_fcm_token_unique
  on public.user_push_devices(fcm_token);

create or replace function public.register_current_push_device(
  p_fcm_token text, p_platform text, p_device_id text default null, p_app_version text default null
) returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if length(trim(p_fcm_token)) < 20 or p_platform not in ('android','ios') then
    raise exception 'Invalid device registration' using errcode = '22023';
  end if;
  -- A token can only belong to one account. Deactivate its old association
  -- before assigning it to the authenticated account (shared-device switch).
  update public.user_push_devices set is_active=false, updated_at=now()
    where fcm_token=trim(p_fcm_token) and user_id <> v_user;
  insert into public.user_push_devices(user_id,fcm_token,platform,device_id,app_version,is_active,last_seen_at)
  values(v_user,trim(p_fcm_token),p_platform,nullif(trim(p_device_id),''),nullif(trim(p_app_version),''),true,now())
  on conflict (fcm_token) do update set user_id=excluded.user_id,platform=excluded.platform,
    device_id=coalesce(excluded.device_id,public.user_push_devices.device_id),
    app_version=coalesce(excluded.app_version,public.user_push_devices.app_version),is_active=true,last_seen_at=now(),updated_at=now();
end; $$;
revoke all on function public.register_current_push_device(text,text,text,text) from public, anon;
grant execute on function public.register_current_push_device(text,text,text,text) to authenticated;

alter table public.notification_push_outbox enable row level security;
alter table public.notification_delivery_attempts enable row level security;
-- Only trusted backend code can inspect delivery metadata or claim work.

create or replace function public.enqueue_notification_push()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.push_status = 'pending' then
    insert into public.notification_push_outbox(notification_id)
    values (new.id) on conflict (notification_id) do nothing;
  end if;
  return new;
end;
$$;
drop trigger if exists notification_push_outbox_enqueue on public.notifications;
create trigger notification_push_outbox_enqueue
after insert on public.notifications for each row execute function public.enqueue_notification_push();

create or replace function public.claim_notification_push_outbox(p_limit integer default 25)
returns table(id uuid, notification_id uuid, attempts integer)
language plpgsql security definer set search_path = public as $$
begin
  if auth.role() <> 'service_role' then raise exception 'Service role required' using errcode = '42501'; end if;
  return query
  with claimed as (
    select o.id from public.notification_push_outbox o
    where o.status in ('pending','failed') and o.available_at <= now()
    order by o.created_at for update skip locked limit greatest(1, least(p_limit, 100))
  )
  update public.notification_push_outbox o set status='processing', locked_at=now(), attempts=o.attempts+1, updated_at=now()
  from claimed where o.id=claimed.id returning o.id,o.notification_id,o.attempts;
end; $$;

create or replace function public.finish_notification_push_outbox(p_id uuid, p_status text, p_error text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.role() <> 'service_role' then raise exception 'Service role required' using errcode = '42501'; end if;
  update public.notification_push_outbox
  set status=p_status, last_error=left(p_error, 500), sent_at=case when p_status='sent' then now() else null end,
      available_at=case when p_status='failed' then now() + interval '5 minutes' else available_at end, updated_at=now()
  where id=p_id;
end; $$;
revoke all on function public.claim_notification_push_outbox(integer) from public, anon, authenticated;
revoke all on function public.finish_notification_push_outbox(uuid,text,text) from public, anon, authenticated;
