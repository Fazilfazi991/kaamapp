-- Employment-profile visa expiry. This is intentionally separate from
-- candidate_documents.visa_expiry_date, which belongs to document verification.
alter table public.candidate_profiles
  add column if not exists visa_expiry_date date;
