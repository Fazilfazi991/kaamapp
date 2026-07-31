-- Candidate verification notifications reuse the central notification feed and
-- its existing AFTER INSERT push-outbox trigger from production push hardening.
alter table public.candidate_profiles
  add column if not exists candidate_message text;

alter table public.candidate_verification_audit_events
  add column if not exists notification_id uuid references public.notifications(id) on delete set null,
  add column if not exists push_outbox_id uuid references public.notification_push_outbox(id) on delete set null;

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check check (type in (
  'employer_interest_received', 'interest_accepted', 'interest_rejected', 'match_created', 'new_message',
  'candidate_document_pending', 'candidate_document_approved', 'candidate_document_rejected',
  'candidate_document_resubmission_requested', 'candidate_accepted_interest', 'candidate_rejected_interest',
  'employer_document_approved', 'employer_document_rejected', 'company_approved', 'company_rejected',
  'candidate_document_submitted', 'employer_document_submitted', 'company_review_submitted',
  'general_announcement', 'document_update', 'membership_update', 'match_update', 'account_alert',
  'promotional', 'maintenance', 'urgent_alert', 'admin_broadcast',
  'candidate_verification_approved', 'candidate_verification_rejected', 'candidate_reverification_required'
));

create or replace function public.review_candidate_manual_verification(
  p_candidate_id uuid,
  p_next_status text,
  p_internal_notes text default null,
  p_candidate_message text default null
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
  v_candidate public.candidate_profiles%rowtype;
  v_account_status text;
  v_passport_status text;
  v_previous_status text;
  v_audit_id uuid;
  v_notification_id uuid;
  v_outbox_id uuid;
  v_type text;
  v_title text;
  v_body text;
begin
  if v_admin_id is null or not public.is_admin() then
    raise exception 'Admin access is required' using errcode = '42501';
  end if;
  if p_next_status not in ('verified', 'rejected', 'reverification_required') then
    raise exception 'Unsupported verification action' using errcode = '22023';
  end if;

  select * into v_candidate from public.candidate_profiles where id = p_candidate_id for update;
  if not found then raise exception 'Candidate profile was not found' using errcode = 'P0002'; end if;
  select status into v_account_status from public.profiles where id = p_candidate_id and role = 'candidate';
  if v_account_status is null then raise exception 'Candidate account was not found' using errcode = 'P0002'; end if;

  if v_candidate.verification_status = p_next_status then
    return jsonb_build_object('already_processed', true, 'notification_created', false, 'push_queued', false);
  end if;

  if p_next_status = 'verified' then
    select passport_status into v_passport_status from public.candidate_documents where candidate_id = p_candidate_id;
    if v_account_status <> 'active' or not public.candidate_profile_completed(v_candidate) or coalesce(v_passport_status, '') <> 'verified' then
      raise exception 'Candidate does not meet manual verification requirements' using errcode = '22023';
    end if;
  end if;

  if p_next_status in ('rejected', 'reverification_required') and coalesce(length(trim(p_candidate_message)), 0) < 6 then
    raise exception 'A candidate-facing reason is required' using errcode = '22023';
  end if;

  v_previous_status := v_candidate.verification_status;
  update public.candidate_profiles set
    verification_status = p_next_status,
    verified_by = v_admin_id,
    verified_at = case when p_next_status = 'verified' then now() else null end,
    verification_notes = nullif(trim(p_internal_notes), ''),
    candidate_message = nullif(trim(p_candidate_message), ''),
    verification_updated_at = now()
  where id = p_candidate_id;

  insert into public.candidate_verification_audit_events(candidate_id, admin_id, previous_status, new_status, action, notes)
  values (
    p_candidate_id, v_admin_id, v_previous_status, p_next_status,
    case p_next_status when 'verified' then 'candidate_verified' when 'rejected' then 'candidate_verification_rejected' else 'candidate_reverification_required' end,
    nullif(trim(p_internal_notes), '')
  ) returning id into v_audit_id;

  if p_next_status = 'verified' then
    v_type := 'candidate_verification_approved';
    v_title := 'Your KAAM profile has been verified';
    v_body := 'Your profile verification is complete. You can now use all eligible KAAM candidate features.';
  elsif p_next_status = 'rejected' then
    v_type := 'candidate_verification_rejected';
    v_title := 'Profile verification was not approved';
    v_body := concat('Please review the verification reason and update your profile or documents. Reason: ', nullif(trim(p_candidate_message), ''));
  else
    v_type := 'candidate_reverification_required';
    v_title := 'Your KAAM profile needs an update';
    v_body := concat('Some profile information or documents require review again. Open KAAM to view the details. Reason: ', nullif(trim(p_candidate_message), ''));
  end if;

  insert into public.notifications(recipient_id, type, title, body, data, action_route, dedupe_key, created_by, source_type, source_id)
  values (
    p_candidate_id, v_type, v_title, v_body,
    jsonb_strip_nulls(jsonb_build_object('candidate_id', p_candidate_id, 'verification_status', p_next_status, 'route', '/candidate/profile')),
    '/candidate/profile', concat('candidate-verification:', p_candidate_id, ':', v_audit_id), v_admin_id,
    'candidate_verification_audit_event', v_audit_id
  ) returning id into v_notification_id;

  select id into v_outbox_id from public.notification_push_outbox where notification_id = v_notification_id;
  update public.candidate_verification_audit_events set notification_id = v_notification_id, push_outbox_id = v_outbox_id where id = v_audit_id;

  return jsonb_build_object('already_processed', false, 'notification_created', true, 'push_queued', v_outbox_id is not null, 'audit_id', v_audit_id, 'notification_id', v_notification_id, 'push_outbox_id', v_outbox_id);
end;
$$;

revoke all on function public.review_candidate_manual_verification(uuid, text, text, text) from public, anon;
grant execute on function public.review_candidate_manual_verification(uuid, text, text, text) to authenticated;
notify pgrst, 'reload schema';
