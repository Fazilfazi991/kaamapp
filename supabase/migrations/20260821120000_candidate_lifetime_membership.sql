-- Candidate membership is a one-time, lifetime entitlement.  This migration
-- deliberately keeps expiry columns for historical payment records only.
begin;

alter table public.candidate_memberships
  add column if not exists membership_type text not null default 'lifetime';

update public.candidate_memberships
set membership_type = 'lifetime'
where membership_type is null;

alter table public.candidate_memberships
  alter column membership_type set default 'lifetime',
  alter column membership_type set not null;

alter table public.candidate_memberships
  drop constraint if exists candidate_memberships_membership_type_check;
alter table public.candidate_memberships
  add constraint candidate_memberships_membership_type_check
  check (membership_type = 'lifetime');

-- Only completed AED 50 Stripe payments receive the new entitlement.  This is
-- safe to rerun and intentionally excludes pending, failed, refunded and test
-- activation records that have no corresponding paid checkout record.
update public.candidate_memberships cm
set membership_type = 'lifetime',
    status = 'active',
    expires_at = null,
    updated_at = now()
where exists (
  select 1
  from public.candidate_membership_payments cmp
  where cmp.candidate_id = cm.candidate_id
    and cmp.payment_status = 'paid'
    and cmp.amount = 5000
    and cmp.currency = 'AED'
    and cmp.stripe_checkout_session_id = cm.stripe_checkout_session_id
)
and (cm.membership_type is distinct from 'lifetime' or cm.status is distinct from 'active' or cm.expires_at is not null);

-- Retire legacy test/manual active rows that do not have canonical evidence of
-- a completed AED 50 payment.  They must not look paid in the web UI or block
-- a legitimate checkout attempt.
update public.candidate_memberships cm
set status = 'inactive',
    expires_at = null,
    updated_at = now()
where cm.status = 'active'
  and not exists (
    select 1
    from public.candidate_membership_payments cmp
    where cmp.candidate_id = cm.candidate_id
      and cmp.payment_status = 'paid'
      and cmp.amount = 5000
      and cmp.currency = 'AED'
      and cmp.stripe_checkout_session_id = cm.stripe_checkout_session_id
  );

-- Historical payment expiry values remain untouched as audit data.  They are
-- no longer read by any entitlement or discovery function.

create index if not exists candidate_memberships_lifetime_active_idx
  on public.candidate_memberships (candidate_id)
  where status = 'active' and membership_type = 'lifetime';

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
      and cmp.amount = 5000
      and cmp.currency = 'AED'
    where cm.candidate_id = target_candidate_id
      and cm.status = 'active'
      and cm.membership_type = 'lifetime'
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

create or replace function public.set_candidate_employer_visibility(p_is_visible boolean)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_candidate_id uuid := auth.uid();
begin
  if v_candidate_id is null or public.my_role() <> 'candidate' then
    raise exception 'Only authenticated candidates can change profile visibility';
  end if;

  if p_is_visible and not public.candidate_membership_active(v_candidate_id) then
    raise exception 'Activate lifetime membership before becoming visible to employers';
  end if;

  update public.candidate_profiles
  set is_visible = p_is_visible,
      updated_at = now()
  where id = v_candidate_id;

  if not found then
    raise exception 'Candidate profile was not found';
  end if;

  return p_is_visible;
end;
$$;

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
  v_inserted integer;
begin
  if p_candidate_id is null or coalesce(btrim(p_checkout_session_id), '') = '' or p_paid_at is null then
    raise exception 'Invalid Stripe membership fulfillment input';
  end if;

  insert into public.candidate_membership_payments (
    candidate_id, stripe_checkout_session_id, stripe_payment_intent_id, stripe_event_id,
    amount, currency, payment_status, paid_at, membership_started_at, membership_expires_at, is_test
  ) values (
    p_candidate_id, p_checkout_session_id, p_payment_intent_id, p_stripe_event_id,
    5000, 'AED', 'paid', p_paid_at, p_paid_at, null, p_is_test
  ) on conflict (stripe_checkout_session_id) do nothing;

  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then return; end if;

  insert into public.candidate_memberships (
    candidate_id, plan_code, membership_type, status, started_at, expires_at, payment_provider,
    payment_reference, amount, currency, is_test, stripe_customer_id,
    stripe_checkout_session_id, stripe_payment_intent_id, stripe_event_id, paid_at
  ) values (
    p_candidate_id, 'lifetime', 'lifetime', 'active', p_paid_at, null, 'stripe',
    p_checkout_session_id, 50.00, 'AED', p_is_test, p_stripe_customer_id,
    p_checkout_session_id, p_payment_intent_id, p_stripe_event_id, p_paid_at
  ) on conflict (candidate_id) do update set
    plan_code = 'lifetime',
    membership_type = 'lifetime',
    status = 'active',
    started_at = coalesce(public.candidate_memberships.started_at, excluded.started_at),
    expires_at = null,
    payment_provider = 'stripe',
    payment_reference = coalesce(public.candidate_memberships.payment_reference, excluded.payment_reference),
    amount = 50.00,
    currency = 'AED',
    stripe_customer_id = coalesce(excluded.stripe_customer_id, public.candidate_memberships.stripe_customer_id),
    stripe_checkout_session_id = coalesce(public.candidate_memberships.stripe_checkout_session_id, excluded.stripe_checkout_session_id),
    stripe_payment_intent_id = coalesce(public.candidate_memberships.stripe_payment_intent_id, excluded.stripe_payment_intent_id),
    stripe_event_id = coalesce(public.candidate_memberships.stripe_event_id, excluded.stripe_event_id),
    paid_at = coalesce(public.candidate_memberships.paid_at, excluded.paid_at),
    updated_at = now();

  -- Payment grants discoverability by default; the candidate may turn it off later.
  update public.candidate_profiles set is_visible = true, updated_at = now() where id = p_candidate_id;
end;
$$;

revoke all on function public.set_candidate_employer_visibility(boolean) from public, anon;
grant execute on function public.set_candidate_employer_visibility(boolean) to authenticated;
revoke all on function public.fulfill_stripe_candidate_membership_payment(uuid, text, text, text, text, timestamptz, boolean) from public, anon, authenticated;
grant execute on function public.fulfill_stripe_candidate_membership_payment(uuid, text, text, text, text, timestamptz, boolean) to service_role;

notify pgrst, 'reload schema';
commit;
