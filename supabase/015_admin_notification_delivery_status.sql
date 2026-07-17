-- Admin broadcast delivery accuracy and canonical mobile broadcast type.
-- Additive only: keeps existing broadcast/history rows intact.

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
      'admin_broadcast'
    )
  );

alter table public.admin_notifications
  add column if not exists push_eligible_device_count integer not null default 0 check (push_eligible_device_count >= 0),
  add column if not exists push_skipped_count integer not null default 0 check (push_skipped_count >= 0);

alter table public.admin_notifications
  drop constraint if exists admin_notifications_status_check;

alter table public.admin_notifications
  add constraint admin_notifications_status_check
  check (status in ('draft', 'scheduled', 'sending', 'sent', 'partially_sent', 'failed', 'cancelled', 'no_eligible_devices'));

notify pgrst, 'reload schema';

commit;
