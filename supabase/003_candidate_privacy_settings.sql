-- KAAM APP - CANDIDATE PRIVACY SETTINGS PATCH
-- Run this in Supabase SQL Editor for existing live projects.

begin;

alter table public.candidate_profiles
  add column if not exists hide_phone_before_match boolean not null default true,
  add column if not exists hide_email_before_match boolean not null default true,
  add column if not exists require_approval_before_chat boolean not null default true,
  add column if not exists allow_document_sharing_after_match boolean not null default true;

commit;
