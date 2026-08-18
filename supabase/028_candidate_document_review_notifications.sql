-- One candidate document review event creates one canonical notification.
begin;

create table if not exists public.candidate_document_review_events (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  document_id uuid not null references public.candidate_documents(id) on delete cascade,
  document_version_id uuid not null unique references public.candidate_document_versions(id) on delete cascade,
  document_type text not null check (document_type in ('passport', 'visa')),
  document_side text,
  review_action text not null check (review_action in ('approved', 'rejected', 'reupload_requested')),
  public_rejection_reason text,
  internal_notes text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  notification_id uuid references public.notifications(id) on delete set null
);

-- The former status trigger cannot know the admin's public reason. The RPC below
-- is now the only candidate-facing document-review notification source.
drop trigger if exists notifications_candidate_document_reviewed on public.candidate_document_versions;

create or replace function public.review_candidate_document(
  p_document_version_id uuid,
  p_action text,
  p_public_reason text default null,
  p_internal_notes text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_admin_id uuid := auth.uid(); v_doc public.candidate_document_versions%rowtype;
  v_status_field text; v_version_field text; v_reason text; v_title text; v_body text;
  v_type text; v_event_id uuid; v_notification_id uuid; v_route text;
begin
  if v_admin_id is null or not public.is_admin() then raise exception 'Admin access is required' using errcode='42501'; end if;
  if p_action not in ('approved','rejected','reupload_requested') then raise exception 'Unsupported document action'; end if;
  select * into v_doc from public.candidate_document_versions where id=p_document_version_id for update;
  if not found then raise exception 'Candidate document was not found'; end if;
  if v_doc.status <> 'pending_verification' or not v_doc.is_active then
    return jsonb_build_object('already_processed', true, 'notification_created', false);
  end if;
  v_reason := coalesce(nullif(trim(p_public_reason), ''), 'We could not verify this document. Please upload a clear and valid copy.');
  if p_action <> 'approved' and length(v_reason) < 6 then raise exception 'A candidate-facing reason is required'; end if;
  v_status_field := case when v_doc.document_type='passport' then 'passport_status' else 'visa_status' end;
  v_version_field := case when v_doc.document_type='passport' then 'passport_version' else 'visa_version' end;
  update public.candidate_document_versions set status=case p_action when 'approved' then 'verified' when 'rejected' then 'rejected' else 'resubmission_requested' end,
    verified_at=case when p_action='approved' then now() else null end where id=v_doc.id;
  execute format('update public.candidate_documents set %I=$1, %I=$2 where candidate_id=$3 and %I=$4', v_status_field,
    case when v_doc.document_type='passport' then 'passport_verified' else 'visa_verified' end, v_version_field)
    using case p_action when 'approved' then 'verified' when 'rejected' then 'rejected' else 'resubmission_requested' end,
      p_action='approved', v_doc.candidate_id, v_doc.version_number;
  insert into public.candidate_document_review_events(candidate_id,document_id,document_version_id,document_type,review_action,public_rejection_reason,internal_notes,reviewed_by)
  values(v_doc.candidate_id,v_doc.candidate_document_id,v_doc.id,v_doc.document_type,p_action,case when p_action='approved' then null else v_reason end,nullif(trim(p_internal_notes),''),v_admin_id)
  returning id into v_event_id;
  v_route := '/candidate/documents';
  if p_action='approved' then v_type:='candidate_document_approved'; v_title:=initcap(v_doc.document_type)||' approved'; v_body:='Your '||v_doc.document_type||' has been verified successfully.';
  elsif p_action='rejected' then v_type:='candidate_document_rejected'; v_title:=initcap(v_doc.document_type)||' was not approved'; v_body:='Your '||v_doc.document_type||' could not be approved. Reason: '||v_reason||' Please upload a clearer or corrected document.';
  else v_type:='candidate_document_resubmission_requested'; v_title:=initcap(v_doc.document_type)||' re-upload required'; v_body:='We need a new copy of your '||v_doc.document_type||'. Reason: '||v_reason||' Tap to replace the document.'; end if;
  insert into public.notifications(recipient_id,type,title,body,data,action_route,dedupe_key,created_by,source_type,source_id)
  values(v_doc.candidate_id,v_type,v_title,v_body,jsonb_build_object('type',v_type,'documentId',v_doc.candidate_document_id,'documentVersionId',v_doc.id,'documentType',v_doc.document_type,'documentSide',null,'reviewAction',p_action,'reviewEventId',v_event_id,'publicReason',case when p_action='approved' then null else v_reason end,'route',v_route),v_route,
    'document-review:'||v_event_id::text||':'||v_doc.candidate_id::text,v_admin_id,'candidate_document_review_event',v_event_id)
  on conflict(recipient_id,dedupe_key) where dedupe_key is not null do nothing returning id into v_notification_id;
  update public.candidate_document_review_events set notification_id=v_notification_id where id=v_event_id;
  return jsonb_build_object('already_processed',false,'notification_created',v_notification_id is not null,'review_event_id',v_event_id,'notification_id',v_notification_id);
end $$;
revoke all on function public.review_candidate_document(uuid,text,text,text) from public, anon;
grant execute on function public.review_candidate_document(uuid,text,text,text) to authenticated;
notify pgrst, 'reload schema';
commit;
