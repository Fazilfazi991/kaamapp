-- KAAM APP - SERVER ENFORCED CANDIDATE IDENTITY DOCUMENT VALIDATION
-- Deploy after 019/020/023 and 20260731000400. Do not deploy 025 as part of this change.
-- The Edge Function writes validation rows using the service role; candidates can only read their own rows.

begin;

create table if not exists public.candidate_document_validations (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  document_type text not null check (document_type in ('passport_front', 'passport_back', 'visa')),
  storage_bucket text not null check (storage_bucket = 'kaam-private'),
  file_path text not null,
  file_hash text not null,
  status text not null check (status in ('accepted', 'rejected')),
  detected_document_type text,
  confidence numeric,
  quality jsonb not null default '{}'::jsonb,
  extracted_data jsonb not null default '{}'::jsonb,
  rejection_reasons jsonb not null default '[]'::jsonb,
  provider text not null,
  provider_version text,
  validated_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  consumed_at timestamptz,
  unique (candidate_id, file_hash, document_type)
);

create index if not exists candidate_document_validations_lookup_idx
  on public.candidate_document_validations (candidate_id, document_type, file_path, status, expires_at);

alter table public.candidate_document_validations enable row level security;
drop policy if exists "candidate_document_validations_select_own" on public.candidate_document_validations;
create policy "candidate_document_validations_select_own"
on public.candidate_document_validations for select to authenticated
using (candidate_id = auth.uid() or public.is_admin());
revoke all on public.candidate_document_validations from authenticated;
grant select on public.candidate_document_validations to authenticated;

-- Direct client writes to candidate_documents are deliberately rejected for document fields.
-- This prevents a client from inventing a path, OCR result, hash, or version.
create or replace function public.enforce_identity_document_submission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null
     and (tg_op = 'INSERT'
       or new.passport_file_url is distinct from old.passport_file_url
       or new.passport_back_file_url is distinct from old.passport_back_file_url
       or new.visa_file_url is distinct from old.visa_file_url)
     and current_setting('app.identity_document_submission', true) is distinct from 'true' then
    raise exception 'Identity documents must be submitted through submit_candidate_identity_documents';
  end if;
  return new;
end;
$$;

drop trigger if exists candidate_documents_require_server_validation on public.candidate_documents;
create trigger candidate_documents_require_server_validation
before insert or update on public.candidate_documents
for each row execute function public.enforce_identity_document_submission();

create or replace function public.submit_candidate_identity_documents(
  p_document_type text,
  p_front_path text,
  p_back_path text default null,
  p_fields jsonb default '{}'::jsonb,
  p_profile_fields jsonb default '{}'::jsonb,
  p_candidate_fields jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_candidate_id uuid := auth.uid();
  v_front_validation public.candidate_document_validations;
  v_back_validation public.candidate_document_validations;
  v_existing public.candidate_documents;
  v_document public.candidate_documents;
  v_version integer;
  v_now timestamptz := now();
begin
  if v_candidate_id is null then raise exception 'Authentication required'; end if;
  if p_document_type not in ('passport', 'visa') then raise exception 'Unsupported document type'; end if;
  if coalesce(btrim(p_front_path), '') = '' then raise exception 'Document path is required'; end if;
  if p_document_type = 'passport' and coalesce(btrim(p_back_path), '') = '' then
    raise exception 'Passport front and back are required';
  end if;

  select * into v_front_validation from public.candidate_document_validations
   where candidate_id = v_candidate_id
     and file_path = p_front_path
     and document_type = case when p_document_type = 'passport' then 'passport_front' else 'visa' end
     and status = 'accepted' and expires_at > v_now and consumed_at is null
   order by validated_at desc limit 1 for update;
  if not found then raise exception 'Document validation is missing, expired, or rejected'; end if;

  if p_document_type = 'passport' then
    select * into v_back_validation from public.candidate_document_validations
     where candidate_id = v_candidate_id and file_path = p_back_path
       and document_type = 'passport_back' and status = 'accepted'
       and expires_at > v_now and consumed_at is null
     order by validated_at desc limit 1 for update;
    if not found then raise exception 'Passport back validation is missing, expired, or rejected'; end if;
    if v_front_validation.file_hash = v_back_validation.file_hash then
      raise exception 'Passport front and back cannot use the same file';
    end if;
    if coalesce(p_fields->>'full_name','') !~ '^[[:alpha:]][[:alpha:] .''-]{1,79}$'
       or coalesce(p_fields->>'passport_number','') !~ '^[A-Za-z0-9]{5,20}$'
       or coalesce(p_fields->>'nationality','') !~ '^[[:alpha:]][[:alpha:] -]{1,63}$'
       or coalesce(p_fields->>'country_of_issue','') !~ '^[[:alpha:]][[:alpha:] -]{1,63}$'
       or coalesce(p_fields->>'dob','') !~ '^\\d{4}-\\d{2}-\\d{2}$'
       or coalesce(p_fields->>'passport_expiry_date','') !~ '^\\d{4}-\\d{2}-\\d{2}$' then
      raise exception 'Required passport fields do not match validated extraction';
    end if;
    if to_char(to_date(p_fields->>'dob', 'YYYY-MM-DD'), 'YYYY-MM-DD') <> p_fields->>'dob'
       or to_date(p_fields->>'dob', 'YYYY-MM-DD') >= current_date
       or to_char(to_date(p_fields->>'passport_expiry_date', 'YYYY-MM-DD'), 'YYYY-MM-DD') <> p_fields->>'passport_expiry_date'
       or to_date(p_fields->>'passport_expiry_date', 'YYYY-MM-DD') <= current_date
       or (coalesce(p_fields->>'passport_issue_date','') <> ''
         and (to_char(to_date(p_fields->>'passport_issue_date', 'YYYY-MM-DD'), 'YYYY-MM-DD') <> p_fields->>'passport_issue_date'
           or to_date(p_fields->>'passport_issue_date', 'YYYY-MM-DD') >= to_date(p_fields->>'passport_expiry_date', 'YYYY-MM-DD'))) then
      raise exception 'Passport dates are invalid';
    end if;
  end if;

  select * into v_existing from public.candidate_documents where candidate_id = v_candidate_id for update;
  perform set_config('app.identity_document_submission', 'true', true);
  if p_document_type = 'passport' then
    v_version := coalesce(v_existing.passport_version, 0) + 1;
    insert into public.candidate_documents (candidate_id, passport_file_url, passport_back_file_url,
      passport_number, passport_issue_date, passport_expiry_date, country_of_issue, full_name,
      nationality, gender, dob, place_of_birth, ocr_completed, passport_status, passport_uploaded_at,
      passport_verified_at, passport_version, passport_is_active, passport_archived, passport_verified,
      passport_expiry_notification_sent)
    values (v_candidate_id, p_front_path, p_back_path, p_fields->>'passport_number', p_fields->>'passport_issue_date',
      p_fields->>'passport_expiry_date', p_fields->>'country_of_issue', p_fields->>'full_name', p_fields->>'nationality',
      p_fields->>'gender', p_fields->>'dob', p_fields->>'place_of_birth', true, 'pending_verification', v_now,
      null, v_version, true, coalesce(v_existing.passport_file_url,'') <> '', false, false)
    on conflict (candidate_id) do update set passport_file_url = excluded.passport_file_url,
      passport_back_file_url = excluded.passport_back_file_url, passport_number = excluded.passport_number,
      passport_issue_date = excluded.passport_issue_date, passport_expiry_date = excluded.passport_expiry_date,
      country_of_issue = excluded.country_of_issue, full_name = excluded.full_name, nationality = excluded.nationality,
      gender = excluded.gender, dob = excluded.dob, place_of_birth = excluded.place_of_birth, ocr_completed = true,
      passport_status = 'pending_verification', passport_uploaded_at = v_now, passport_verified_at = null,
      passport_version = v_version, passport_is_active = true, passport_archived = coalesce(v_existing.passport_file_url,'') <> '',
      passport_verified = false, passport_expiry_notification_sent = false
    returning * into v_document;
    update public.candidate_document_versions set is_active = false where candidate_id = v_candidate_id and document_type = 'passport';
    insert into public.candidate_document_versions (candidate_document_id, candidate_id, document_type, file_path, file_paths,
      version_number, status, is_active, extracted_details)
    values (v_document.id, v_candidate_id, 'passport', p_front_path,
      jsonb_build_object('front', p_front_path, 'back', p_back_path,
        'validation', jsonb_build_object('front', v_front_validation.id, 'back', v_back_validation.id,
          'hashes', jsonb_build_array(v_front_validation.file_hash, v_back_validation.file_hash))),
      v_version, 'pending_verification', true, p_fields || jsonb_build_object(
        'validation', v_front_validation.quality,
        'correction', jsonb_build_object('reason', p_fields->>'identity_correction_reason',
          'submitted_at', v_now, 'candidate_id', v_candidate_id,
          'original_extraction', v_front_validation.extracted_data)));
    update public.candidate_document_validations set consumed_at = v_now where id in (v_front_validation.id, v_back_validation.id);
  else
    v_version := coalesce(v_existing.visa_version, 0) + 1;
    insert into public.candidate_documents (candidate_id, visa_file_url, visa_number, visa_type, occupation, sponsor, uid_number,
      emirates_id, visa_issue_date, visa_expiry_date, ocr_completed, visa_status, visa_uploaded_at, visa_verified_at, visa_version,
      visa_is_active, visa_archived, visa_verified, visa_expiry_notification_sent)
    values (v_candidate_id, p_front_path, p_fields->>'visa_number', p_fields->>'visa_type', p_fields->>'occupation',
      p_fields->>'sponsor', p_fields->>'uid_number', p_fields->>'emirates_id', p_fields->>'visa_issue_date',
      p_fields->>'visa_expiry_date', true, 'pending_verification', v_now, null, v_version, true,
      coalesce(v_existing.visa_file_url,'') <> '', false, false)
    on conflict (candidate_id) do update set visa_file_url = excluded.visa_file_url, visa_number = excluded.visa_number,
      visa_type = excluded.visa_type, occupation = excluded.occupation, sponsor = excluded.sponsor, uid_number = excluded.uid_number,
      emirates_id = excluded.emirates_id, visa_issue_date = excluded.visa_issue_date, visa_expiry_date = excluded.visa_expiry_date,
      ocr_completed = true, visa_status = 'pending_verification', visa_uploaded_at = v_now, visa_verified_at = null,
      visa_version = v_version, visa_is_active = true, visa_archived = coalesce(v_existing.visa_file_url,'') <> '',
      visa_verified = false, visa_expiry_notification_sent = false
    returning * into v_document;
    update public.candidate_document_versions set is_active = false where candidate_id = v_candidate_id and document_type = 'visa';
    insert into public.candidate_document_versions (candidate_document_id, candidate_id, document_type, file_path, file_paths,
      version_number, status, is_active, extracted_details)
    values (v_document.id, v_candidate_id, 'visa', p_front_path,
      jsonb_build_object('validation', jsonb_build_object('id', v_front_validation.id, 'hash', v_front_validation.file_hash)),
      v_version, 'pending_verification', true, p_fields || jsonb_build_object(
        'validation', v_front_validation.quality,
        'correction', jsonb_build_object('reason', p_fields->>'identity_correction_reason',
          'submitted_at', v_now, 'candidate_id', v_candidate_id,
          'original_extraction', v_front_validation.extracted_data)));
    update public.candidate_document_validations set consumed_at = v_now where id = v_front_validation.id;
  end if;
  if p_profile_fields <> '{}'::jsonb then update public.profiles set full_name = coalesce(p_profile_fields->>'full_name', full_name) where id = v_candidate_id; end if;
  if p_candidate_fields <> '{}'::jsonb then update public.candidate_profiles set nationality = coalesce(p_candidate_fields->>'nationality', nationality), gender = coalesce(p_candidate_fields->>'gender', gender) where id = v_candidate_id; end if;
  return to_jsonb(v_document);
end;
$$;

revoke all on function public.submit_candidate_identity_documents(text, text, text, jsonb, jsonb, jsonb) from public;
grant execute on function public.submit_candidate_identity_documents(text, text, text, jsonb, jsonb, jsonb) to authenticated;

notify pgrst, 'reload schema';
commit;
