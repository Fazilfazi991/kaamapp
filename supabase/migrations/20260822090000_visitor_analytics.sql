-- KAAM visitor analytics: first-party, pseudonymous, admin-readable only.
begin;

create table if not exists public.analytics_visitors (
  id uuid primary key default gen_random_uuid(),
  anonymous_id uuid not null unique,
  first_seen_at timestamptz not null default now(), last_seen_at timestamptz not null default now(),
  first_source text, first_medium text, first_campaign text, first_referrer text, first_landing_page text,
  latest_source text, latest_medium text, latest_campaign text,
  country text, city text, linked_user_id uuid references public.profiles(id) on delete set null,
  linked_at timestamptz
);

create table if not exists public.analytics_sessions (
  id uuid primary key default gen_random_uuid(),
  visitor_id uuid not null references public.analytics_visitors(id) on delete cascade,
  session_key uuid not null unique, user_id uuid references public.profiles(id) on delete set null,
  started_at timestamptz not null default now(), last_activity_at timestamptz not null default now(),
  landing_page text not null, exit_page text, source text, medium text, campaign text, referrer text,
  device_type text, browser text, os text, country text, city text, page_view_count integer not null default 0
);

create table if not exists public.analytics_events (
  id bigint generated always as identity primary key,
  visitor_id uuid not null references public.analytics_visitors(id) on delete cascade,
  session_id uuid references public.analytics_sessions(id) on delete set null,
  user_id uuid references public.profiles(id) on delete set null,
  event_name text not null check (event_name in ('page_view','registration_started','registration_completed','login','candidate_profile_completed','employer_profile_completed','membership_checkout_started','membership_purchased','candidate_visibility_enabled','contact_clicked')),
  page_path text, metadata jsonb not null default '{}'::jsonb, event_key uuid not null unique, created_at timestamptz not null default now()
);

create index if not exists analytics_visitors_linked_user_idx on public.analytics_visitors(linked_user_id);
create index if not exists analytics_sessions_visitor_started_idx on public.analytics_sessions(visitor_id, started_at desc);
create index if not exists analytics_sessions_started_idx on public.analytics_sessions(started_at desc);
create index if not exists analytics_events_created_idx on public.analytics_events(created_at desc);
create index if not exists analytics_events_name_created_idx on public.analytics_events(event_name, created_at desc);
create index if not exists analytics_events_user_idx on public.analytics_events(user_id, created_at desc);

alter table public.analytics_visitors enable row level security;
alter table public.analytics_sessions enable row level security;
alter table public.analytics_events enable row level security;
create policy "analytics visitors admin read" on public.analytics_visitors for select using (public.is_admin());
create policy "analytics sessions admin read" on public.analytics_sessions for select using (public.is_admin());
create policy "analytics events admin read" on public.analytics_events for select using (public.is_admin());

-- This RPC is intentionally the only browser-writable surface. It accepts no IP,
-- rejects arbitrary event names, and is idempotent through event_key.
create or replace function public.record_analytics_event(
  p_anonymous_id uuid, p_session_key uuid, p_event_name text, p_page_path text,
  p_metadata jsonb default '{}'::jsonb, p_event_key uuid default gen_random_uuid(),
  p_country text default null, p_city text default null
) returns void language plpgsql security definer set search_path = public as $$
declare v_visitor_id uuid; v_session_id uuid; v_user_id uuid := auth.uid();
begin
  if p_anonymous_id is null or p_session_key is null or p_event_name not in
    ('page_view','registration_started','registration_completed','login','candidate_profile_completed','employer_profile_completed','membership_checkout_started','membership_purchased','candidate_visibility_enabled','contact_clicked') then
    raise exception 'Invalid analytics payload';
  end if;
  insert into public.analytics_visitors (anonymous_id, first_source, first_medium, first_campaign, first_referrer, first_landing_page, latest_source, latest_medium, latest_campaign, country, city)
  values (p_anonymous_id, nullif(p_metadata->>'source',''), nullif(p_metadata->>'medium',''), nullif(p_metadata->>'campaign',''), nullif(p_metadata->>'referrer',''), nullif(p_metadata->>'landing_page',''), nullif(p_metadata->>'source',''), nullif(p_metadata->>'medium',''), nullif(p_metadata->>'campaign',''), p_country, p_city)
  on conflict (anonymous_id) do update set last_seen_at = now(), latest_source = coalesce(nullif(excluded.latest_source,''), analytics_visitors.latest_source), latest_medium = coalesce(nullif(excluded.latest_medium,''), analytics_visitors.latest_medium), latest_campaign = coalesce(nullif(excluded.latest_campaign,''), analytics_visitors.latest_campaign), country = coalesce(analytics_visitors.country, excluded.country), city = coalesce(analytics_visitors.city, excluded.city)
  returning id into v_visitor_id;
  insert into public.analytics_sessions (visitor_id, session_key, user_id, landing_page, exit_page, source, medium, campaign, referrer, device_type, browser, os, country, city, page_view_count)
  values (v_visitor_id, p_session_key, v_user_id, coalesce(nullif(p_metadata->>'landing_page',''), p_page_path, '/'), p_page_path, nullif(p_metadata->>'source',''), nullif(p_metadata->>'medium',''), nullif(p_metadata->>'campaign',''), nullif(p_metadata->>'referrer',''), nullif(p_metadata->>'device_type',''), nullif(p_metadata->>'browser',''), nullif(p_metadata->>'os',''), p_country, p_city, case when p_event_name = 'page_view' then 1 else 0 end)
  on conflict (session_key) do update set last_activity_at = now(), exit_page = excluded.exit_page, user_id = coalesce(excluded.user_id, analytics_sessions.user_id), page_view_count = analytics_sessions.page_view_count + case when p_event_name = 'page_view' then 1 else 0 end
  returning id into v_session_id;
  insert into public.analytics_events(visitor_id, session_id, user_id, event_name, page_path, metadata, event_key)
  values(v_visitor_id, v_session_id, v_user_id, p_event_name, p_page_path, coalesce(p_metadata,'{}'::jsonb), p_event_key)
  on conflict(event_key) do nothing;
end $$;

create or replace function public.link_analytics_identity(p_anonymous_id uuid, p_session_key uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
declare v_user_id uuid := auth.uid(); v_visitor_id uuid; v_session_id uuid;
begin
  if v_user_id is null or p_anonymous_id is null then raise exception 'Authentication required'; end if;
  update public.analytics_visitors set linked_user_id = v_user_id, linked_at = coalesce(linked_at, now()), last_seen_at = now() where anonymous_id = p_anonymous_id returning id into v_visitor_id;
  if v_visitor_id is null then return; end if;
  update public.analytics_sessions set user_id = v_user_id where visitor_id = v_visitor_id;
  select id into v_session_id from public.analytics_sessions where session_key = p_session_key;
  insert into public.analytics_events(visitor_id, session_id, user_id, event_name, page_path, metadata, event_key)
  values(v_visitor_id, v_session_id, v_user_id, 'registration_completed', null, jsonb_build_object('role', p_role), gen_random_uuid());
end $$;
revoke all on function public.record_analytics_event(uuid,uuid,text,text,jsonb,uuid,text,text) from public;
grant execute on function public.record_analytics_event(uuid,uuid,text,text,jsonb,uuid,text,text) to anon, authenticated;
revoke all on function public.link_analytics_identity(uuid,uuid,text) from public;
grant execute on function public.link_analytics_identity(uuid,uuid,text) to authenticated;

-- Canonical business-state triggers supplement client events and never depend on them.
create or replace function public.analytics_membership_purchase_event() returns trigger language plpgsql security definer set search_path = public as $$
declare v_visitor uuid; v_session uuid;
begin
  if new.payment_status = 'paid' and (tg_op = 'INSERT' or old.payment_status is distinct from 'paid') then
    select id into v_visitor from public.analytics_visitors where linked_user_id = new.candidate_id order by linked_at nulls last, first_seen_at limit 1;
    select id into v_session from public.analytics_sessions where visitor_id = v_visitor order by last_activity_at desc limit 1;
    if v_visitor is not null then insert into public.analytics_events(visitor_id,session_id,user_id,event_name,metadata,event_key) values(v_visitor,v_session,new.candidate_id,'membership_purchased',jsonb_build_object('payment_id',new.id),gen_random_uuid()); end if;
  end if; return new;
end $$;
drop trigger if exists analytics_membership_purchase_event on public.candidate_membership_payments;
create trigger analytics_membership_purchase_event after insert or update on public.candidate_membership_payments for each row execute function public.analytics_membership_purchase_event();

notify pgrst, 'reload schema';
commit;
