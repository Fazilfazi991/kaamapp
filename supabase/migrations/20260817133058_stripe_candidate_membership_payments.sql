-- Stripe-backed Candidate membership. Forward-only; do not apply until Preview QA is approved.
begin;

alter table public.candidate_memberships
  add column if not exists stripe_customer_id text,
  add column if not exists stripe_checkout_session_id text,
  add column if not exists stripe_payment_intent_id text,
  add column if not exists paid_at timestamptz,
  add column if not exists stripe_event_id text;

alter table public.candidate_memberships
  drop constraint if exists candidate_memberships_status_check;
alter table public.candidate_memberships
  add constraint candidate_memberships_status_check
  check (status in ('inactive', 'pending', 'payment_pending', 'active', 'expired', 'cancelled', 'refunded'));

create unique index if not exists candidate_memberships_stripe_customer_id_key
  on public.candidate_memberships (stripe_customer_id) where stripe_customer_id is not null;
create unique index if not exists candidate_memberships_stripe_checkout_session_id_key
  on public.candidate_memberships (stripe_checkout_session_id) where stripe_checkout_session_id is not null;
create unique index if not exists candidate_memberships_stripe_payment_intent_id_key
  on public.candidate_memberships (stripe_payment_intent_id) where stripe_payment_intent_id is not null;

create table if not exists public.candidate_membership_payments (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  stripe_checkout_session_id text not null unique,
  stripe_payment_intent_id text unique,
  stripe_event_id text unique,
  amount integer not null check (amount = 5000),
  currency text not null check (currency = 'AED'),
  payment_status text not null check (payment_status in ('pending', 'paid', 'failed', 'refunded')),
  paid_at timestamptz,
  membership_started_at timestamptz,
  membership_expires_at timestamptz,
  is_test boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists candidate_membership_payments_set_updated_at on public.candidate_membership_payments;
create trigger candidate_membership_payments_set_updated_at
before update on public.candidate_membership_payments
for each row execute function public.set_updated_at();

create index if not exists candidate_membership_payments_candidate_paid_idx
  on public.candidate_membership_payments (candidate_id, payment_status, membership_expires_at desc);

alter table public.candidate_membership_payments enable row level security;
drop policy if exists "candidate_membership_payments_select_own_or_admin" on public.candidate_membership_payments;
create policy "candidate_membership_payments_select_own_or_admin"
on public.candidate_membership_payments for select to authenticated
using (candidate_id = auth.uid() or public.is_admin());

create or replace function public.candidate_membership_active(target_candidate_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.candidate_memberships cm
    join public.candidate_membership_payments cmp
      on cmp.candidate_id = cm.candidate_id
      and cmp.stripe_checkout_session_id = cm.stripe_checkout_session_id
      and cmp.payment_status = 'paid'
    where cm.candidate_id = target_candidate_id
      and cm.status = 'active'
      and cm.payment_provider = 'stripe'
      and cm.expires_at > now()
  );
$$;

create or replace function public.candidate_visible_to_employers(target_candidate_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.candidate_profiles cp
    join public.profiles p on p.id = cp.id
    where cp.id = target_candidate_id
      and p.status = 'active'
      and cp.is_visible = true
      and public.candidate_profile_completed(cp)
      and public.candidate_documents_verified(cp.id)
      and public.candidate_membership_active(cp.id)
  );
$$;

create or replace function public.block_interest_for_hidden_candidate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.candidate_visible_to_employers(new.candidate_id) then
    raise exception 'Candidate is not currently available in Employer Search';
  end if;
  return new;
end;
$$;

drop trigger if exists interest_requests_candidate_visible on public.interest_requests;
create trigger interest_requests_candidate_visible
before insert on public.interest_requests
for each row execute function public.block_interest_for_hidden_candidate();

create or replace function public.fulfill_stripe_candidate_membership_payment(
  p_candidate_id uuid,
  p_checkout_session_id text,
  p_payment_intent_id text,
  p_stripe_customer_id text,
  p_stripe_event_id text,
  p_paid_at timestamptz,
  p_is_test boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.candidate_memberships;
  v_start timestamptz;
  v_expires timestamptz;
  v_inserted integer;
begin
  if p_candidate_id is null or coalesce(btrim(p_checkout_session_id), '') = '' or p_paid_at is null then
    raise exception 'Invalid Stripe membership fulfillment input';
  end if;

  insert into public.candidate_membership_payments (
    candidate_id, stripe_checkout_session_id, stripe_payment_intent_id, stripe_event_id,
    amount, currency, payment_status, paid_at, is_test
  ) values (
    p_candidate_id, p_checkout_session_id, p_payment_intent_id, p_stripe_event_id,
    5000, 'AED', 'paid', p_paid_at, p_is_test
  ) on conflict (stripe_checkout_session_id) do nothing;

  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    return;
  end if;

  select * into v_existing
  from public.candidate_memberships
  where candidate_id = p_candidate_id
  for update;

  v_start := greatest(coalesce(v_existing.expires_at, p_paid_at), p_paid_at);
  v_expires := v_start + interval '2 months';

  insert into public.candidate_memberships (
    candidate_id, plan_code, status, started_at, expires_at, payment_provider,
    payment_reference, amount, currency, is_test, stripe_customer_id,
    stripe_checkout_session_id, stripe_payment_intent_id, stripe_event_id, paid_at
  ) values (
    p_candidate_id, 'premium', 'active', v_start, v_expires, 'stripe',
    p_checkout_session_id, 50.00, 'AED', p_is_test, p_stripe_customer_id,
    p_checkout_session_id, p_payment_intent_id, p_stripe_event_id, p_paid_at
  ) on conflict (candidate_id) do update set
    plan_code = excluded.plan_code,
    status = 'active',
    started_at = excluded.started_at,
    expires_at = excluded.expires_at,
    payment_provider = 'stripe',
    payment_reference = excluded.payment_reference,
    amount = excluded.amount,
    currency = 'AED',
    is_test = excluded.is_test,
    stripe_customer_id = coalesce(excluded.stripe_customer_id, public.candidate_memberships.stripe_customer_id),
    stripe_checkout_session_id = excluded.stripe_checkout_session_id,
    stripe_payment_intent_id = excluded.stripe_payment_intent_id,
    stripe_event_id = excluded.stripe_event_id,
    paid_at = excluded.paid_at,
    updated_at = now();

  update public.candidate_membership_payments
  set membership_started_at = v_start,
      membership_expires_at = v_expires
  where stripe_checkout_session_id = p_checkout_session_id;
end;
$$;

create or replace function public.record_stripe_candidate_membership_payment_failure(
  p_candidate_id uuid,
  p_checkout_session_id text,
  p_payment_intent_id text,
  p_stripe_event_id text
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.candidate_membership_payments (
    candidate_id, stripe_checkout_session_id, stripe_payment_intent_id, stripe_event_id,
    amount, currency, payment_status
  ) values (p_candidate_id, p_checkout_session_id, p_payment_intent_id, p_stripe_event_id, 5000, 'AED', 'failed')
  on conflict (stripe_checkout_session_id) do nothing;
$$;

-- Discovery membership must not revoke already accepted matches or conversations.
create or replace function public.match_chat_enabled(target_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.matches m
    where m.id = target_match_id
      and (m.employer_id = auth.uid() or m.candidate_id = auth.uid())
  );
$$;

create or replace function public.reveal_candidate_contact(target_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare current_user_id uuid := auth.uid();
begin
  if current_user_id is null then raise exception 'Not authenticated'; end if;
  update public.matches m
  set contact_revealed_at = coalesce(m.contact_revealed_at, now())
  where m.id = target_match_id and m.candidate_id = current_user_id;
  if not found then raise exception 'Only the matched Candidate can reveal contact details'; end if;
end;
$$;

create or replace function public.candidate_matches_with_access()
returns table (match_id uuid, company_name text, role text, location text, matched_at timestamptz, chat_enabled boolean, can_reveal_contact boolean, contact_revealed boolean)
language sql stable security definer set search_path = public as $$
  select m.id, ec.company_name, coalesce(nullif(ir.job_title, ''), ec.industry, 'Matched role'),
    coalesce(nullif(ir.work_location, ''), ec.city, ''), m.created_at, true,
    m.contact_revealed_at is null, m.contact_revealed_at is not null
  from public.matches m join public.employer_companies ec on ec.id = m.company_id
  left join public.interest_requests ir on ir.id = m.interest_request_id
  where m.candidate_id = auth.uid() order by m.created_at desc;
$$;

create or replace function public.employer_matches_with_contact()
returns table (match_id uuid, candidate_id uuid, display_name text, role text, location text, matched_at timestamptz, chat_enabled boolean, contact_revealed boolean, phone text, email text)
language sql stable security definer set search_path = public as $$
  select m.id, m.candidate_id, coalesce(nullif(p.full_name, ''), 'Candidate'),
    coalesce(nullif(ir.job_title, ''), cp.headline, 'Candidate'), coalesce(nullif(ir.work_location, ''), cp.current_city, ''),
    m.created_at, true, m.contact_revealed_at is not null,
    case when m.contact_revealed_at is not null then p.phone else null end,
    case when m.contact_revealed_at is not null then p.email else null end
  from public.matches m join public.candidate_profiles cp on cp.id = m.candidate_id
  join public.profiles p on p.id = m.candidate_id
  left join public.interest_requests ir on ir.id = m.interest_request_id
  where m.employer_id = auth.uid() order by m.created_at desc;
$$;

revoke all on function public.fulfill_stripe_candidate_membership_payment(uuid, text, text, text, text, timestamptz, boolean) from public, anon, authenticated;
revoke all on function public.record_stripe_candidate_membership_payment_failure(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.fulfill_stripe_candidate_membership_payment(uuid, text, text, text, text, timestamptz, boolean) to service_role;
grant execute on function public.record_stripe_candidate_membership_payment_failure(uuid, text, text, text) to service_role;
grant select on public.candidate_membership_payments to authenticated;
grant execute on function public.candidate_membership_active(uuid) to authenticated;
grant execute on function public.candidate_visible_to_employers(uuid) to authenticated;
grant execute on function public.match_chat_enabled(uuid) to authenticated;
grant execute on function public.reveal_candidate_contact(uuid) to authenticated;
grant execute on function public.candidate_matches_with_access() to authenticated;
grant execute on function public.employer_matches_with_contact() to authenticated;

notify pgrst, 'reload schema';
commit;
