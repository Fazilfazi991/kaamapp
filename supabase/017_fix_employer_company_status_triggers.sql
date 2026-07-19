-- Keep employer company notification triggers compatible with the live
-- profile_status enum: draft, active, paused, blocked.

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
