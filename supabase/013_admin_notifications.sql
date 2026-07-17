-- KAAM admin broadcast notifications.
-- Apply manually after review. This migration does not send external push,
-- email, or WhatsApp messages by itself.

begin;

create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 140),
  message text not null check (char_length(btrim(message)) between 1 and 1200),
  notification_type text not null check (
    notification_type in (
      'general_announcement',
      'document_update',
      'membership_update',
      'match_update',
      'account_alert',
      'promotional',
      'maintenance',
      'urgent_alert'
    )
  ),
  audience_type text not null check (
    audience_type in (
      'all_users',
      'all_candidates',
      'all_employers',
      'selected_candidates',
      'selected_employers',
      'pending_documents',
      'rejected_documents',
      'paid_candidates',
      'unpaid_candidates',
      'matched_users',
      'inactive_users'
    )
  ),
  audience_filters jsonb not null default '{}'::jsonb,
  action_type text not null default 'none' check (
    action_type in (
      'none',
      'candidate_profile',
      'employer_profile',
      'documents',
      'membership',
      'matches',
      'chat',
      'custom_route'
    )
  ),
  action_value text,
  channels jsonb not null default '["in_app"]'::jsonb,
  status text not null default 'draft' check (
    status in ('draft', 'scheduled', 'sending', 'sent', 'partially_sent', 'failed', 'cancelled', 'no_eligible_devices')
  ),
  recipient_count integer not null default 0 check (recipient_count >= 0),
  in_app_success_count integer not null default 0 check (in_app_success_count >= 0),
  push_eligible_device_count integer not null default 0 check (push_eligible_device_count >= 0),
  push_success_count integer not null default 0 check (push_success_count >= 0),
  push_failure_count integer not null default 0 check (push_failure_count >= 0),
  push_skipped_count integer not null default 0 check (push_skipped_count >= 0),
  failure_summary text,
  idempotency_key text,
  scheduled_at timestamptz,
  sent_at timestamptz,
  created_by uuid not null references public.profiles(id) on delete restrict,
  sent_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists admin_notifications_set_updated_at on public.admin_notifications;
create trigger admin_notifications_set_updated_at
before update on public.admin_notifications
for each row execute function public.set_updated_at();

create index if not exists admin_notifications_status_created_idx
on public.admin_notifications(status, created_at desc);

create index if not exists admin_notifications_created_by_idx
on public.admin_notifications(created_by, created_at desc);

create unique index if not exists admin_notifications_idempotency_idx
on public.admin_notifications(created_by, idempotency_key)
where idempotency_key is not null;

create table if not exists public.admin_notification_recipients (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.admin_notifications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  in_app_status text not null default 'pending' check (in_app_status in ('pending', 'sent', 'skipped', 'failed')),
  push_status text not null default 'skipped' check (push_status in ('pending', 'sent', 'skipped', 'failed')),
  email_status text not null default 'skipped' check (email_status in ('pending', 'sent', 'skipped', 'failed')),
  whatsapp_status text not null default 'skipped' check (whatsapp_status in ('pending', 'sent', 'skipped', 'failed')),
  delivered_at timestamptz,
  read_at timestamptz,
  error_message text,
  created_at timestamptz not null default now(),
  unique(notification_id, user_id)
);

create index if not exists admin_notification_recipients_notification_idx
on public.admin_notification_recipients(notification_id);

create index if not exists admin_notification_recipients_user_created_idx
on public.admin_notification_recipients(user_id, created_at desc);

alter table public.admin_notifications enable row level security;
alter table public.admin_notification_recipients enable row level security;

drop policy if exists "admin_notifications_admin_all" on public.admin_notifications;
create policy "admin_notifications_admin_all"
on public.admin_notifications for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "admin_notification_recipients_admin_all" on public.admin_notification_recipients;
create policy "admin_notification_recipients_admin_all"
on public.admin_notification_recipients for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "admin_notification_recipients_user_select_own" on public.admin_notification_recipients;
create policy "admin_notification_recipients_user_select_own"
on public.admin_notification_recipients for select
to authenticated
using (user_id = auth.uid());

grant select, insert, update on public.admin_notifications to authenticated;
grant select, insert, update on public.admin_notification_recipients to authenticated;

notify pgrst, 'reload schema';

commit;
