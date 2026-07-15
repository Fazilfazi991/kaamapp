-- KAAM APP - QA RESET TOOLS
-- Run this in Supabase SQL Editor for QA projects only.
-- The Flutter app calls public.qa_reset(action, build_version, platform) with the signed-in user's session.

begin;

create table if not exists public.qa_allowed_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete cascade,
  email text unique,
  role text,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.qa_reset_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  email text,
  role text,
  action text not null,
  performed_at timestamptz not null default now(),
  build_version text,
  platform text,
  result text not null,
  error_message text
);

alter table public.qa_allowed_accounts enable row level security;
alter table public.qa_reset_logs enable row level security;

drop policy if exists "qa_allowed_admin_only" on public.qa_allowed_accounts;
create policy "qa_allowed_admin_only"
on public.qa_allowed_accounts for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "qa_logs_admin_or_self_read" on public.qa_reset_logs;
create policy "qa_logs_admin_or_self_read"
on public.qa_reset_logs for select
to authenticated
using (public.is_admin() or user_id = auth.uid());

revoke all on public.qa_allowed_accounts from anon, authenticated;
grant select, insert, update, delete on public.qa_allowed_accounts to authenticated;
grant select on public.qa_reset_logs to authenticated;

create or replace function public.qa_reset(
  action text,
  build_version text default null,
  platform text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_role text;
  v_allowed boolean;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select p.role::text into v_role
  from public.profiles p
  where p.id = v_user_id;

  select exists (
    select 1
    from public.qa_allowed_accounts qa
    where qa.enabled = true
      and (
        qa.user_id = v_user_id
        or lower(coalesce(qa.email, '')) = v_email
      )
  ) into v_allowed;

  if not v_allowed then
    insert into public.qa_reset_logs(user_id, email, role, action, build_version, platform, result, error_message)
    values (v_user_id, v_email, v_role, action, build_version, platform, 'rejected', 'User is not in QA allowlist');
    raise exception 'QA reset rejected for this account';
  end if;

  if action in ('reset_candidate_onboarding', 'full_candidate_qa_reset') then
    if v_role <> 'candidate' then
      raise exception 'Candidate QA reset is only available for candidate accounts';
    end if;

    update public.profiles
    set full_name = null,
        phone = null,
        updated_at = now()
    where id = v_user_id
      and v_role = 'candidate';

    update public.candidate_profiles
    set headline = null,
        nationality = null,
        current_country = null,
        current_city = null,
        preferred_country = 'UAE',
        preferred_city = null,
        job_categories = '{}',
        skills = '{}',
        languages = '{}',
        experience_years = null,
        expected_salary_min = null,
        expected_salary_max = null,
        availability = null,
        visa_status = null,
        bio = null,
        is_visible = true,
        updated_at = now()
    where id = v_user_id;
  end if;

  if action in ('reset_document_status', 'delete_documents_and_reset', 'full_candidate_qa_reset') then
    if v_role <> 'candidate' then
      raise exception 'Document QA reset is only available for candidate accounts';
    end if;

    update public.candidate_documents
    set passport_file_url = null,
        visa_file_url = null,
        passport_number = null,
        passport_issue_date = null,
        passport_expiry_date = null,
        country_of_issue = null,
        full_name = null,
        nationality = null,
        gender = null,
        dob = null,
        place_of_birth = null,
        visa_number = null,
        visa_type = null,
        occupation = null,
        sponsor = null,
        uid_number = null,
        emirates_id = null,
        visa_issue_date = null,
        visa_expiry_date = null,
        passport_verified = false,
        visa_verified = false,
        ocr_completed = false,
        passport_status = 'not_uploaded',
        visa_status = 'not_uploaded',
        passport_uploaded_at = null,
        visa_uploaded_at = null,
        passport_verified_at = null,
        visa_verified_at = null,
        passport_version = 0,
        visa_version = 0,
        passport_is_active = false,
        visa_is_active = false,
        passport_archived = false,
        visa_archived = false,
        passport_expiry_notification_sent = false,
        visa_expiry_notification_sent = false,
        updated_at = now()
    where candidate_id = v_user_id;

    delete from public.candidate_document_notifications
    where candidate_id = v_user_id;

    update public.candidate_document_versions
    set is_active = false,
        status = 'archived'
    where candidate_id = v_user_id;

    if action = 'delete_documents_and_reset' then
      delete from storage.objects
      where bucket_id = 'kaam-private'
        and name like v_user_id::text || '/candidate-documents/%';

      delete from public.candidate_document_versions
      where candidate_id = v_user_id;
    end if;
  end if;

  if action in ('reset_employer_onboarding', 'full_employer_qa_reset') then
    if v_role <> 'employer' then
      raise exception 'Employer QA reset is only available for employer accounts';
    end if;

    update public.employer_companies
    set company_name = 'QA Company',
        trade_license_number = null,
        industry = null,
        company_size = null,
        city = null,
        office_area = null,
        contact_person = null,
        contact_role = null,
        hiring_needs = '{}',
        website = null,
        logo_url = null,
        description = null,
        is_verified = false,
        status = 'draft',
        updated_at = now()
    where owner_id = v_user_id;

    update public.employer_hiring_requirements
    set status = 'closed',
        updated_at = now()
    where employer_id = v_user_id;
  end if;

  insert into public.qa_reset_logs(user_id, email, role, action, build_version, platform, result)
  values (v_user_id, v_email, v_role, action, build_version, platform, 'success');

  return jsonb_build_object('ok', true, 'action', action, 'user_id', v_user_id);
exception
  when others then
    insert into public.qa_reset_logs(user_id, email, role, action, build_version, platform, result, error_message)
    values (v_user_id, v_email, v_role, action, build_version, platform, 'error', sqlerrm);
    raise;
end;
$$;

grant execute on function public.qa_reset(text, text, text) to authenticated;

-- Add real QA inboxes after running this migration.
-- Example:
-- insert into public.qa_allowed_accounts(email, role)
-- values ('candidate-test@example.com', 'candidate')
-- on conflict (email) do update set enabled = true;

commit;
