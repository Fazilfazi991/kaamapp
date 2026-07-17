-- Allow admin broadcast notification types in the central notification feed.
-- This is additive and keeps existing notification rows intact.

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
      'urgent_alert'
    )
  );

notify pgrst, 'reload schema';

commit;
