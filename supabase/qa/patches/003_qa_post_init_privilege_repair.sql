-- QA-only post-initialization least-privilege repair (patch 35).
-- Apply only after the checksum-locked 34-unit QA initialization.
begin;

-- Historical sources granted table-owner-like privileges to authenticated.
-- Reset every public relation, then restore only reviewed Data API operations.
revoke all privileges on all tables in schema public from public, anon, authenticated;
revoke all privileges on all sequences in schema public from public, anon, authenticated;

-- Candidate, employer, and shared workflow tables. RLS remains authoritative.
grant select, insert, update on public.profiles, public.candidate_profiles,
  public.employer_companies to authenticated;
grant select, insert, update, delete on public.employer_hiring_requirements,
  public.interest_requests, public.saved_candidates, public.verification_documents,
  public.candidate_documents, public.candidate_document_versions,
  public.candidate_skills, public.candidate_custom_skills,
  public.employer_candidate_views, public.employer_hiring_requirement_skills
  to authenticated;
grant select, insert on public.matches, public.chat_messages to authenticated;
grant select on public.candidate_document_notifications,
  public.candidate_memberships, public.candidate_membership_payments to authenticated;
grant select, update on public.notifications to authenticated;
grant select, insert, update on public.user_push_devices,
  public.notification_preferences to authenticated;

-- Admin operations are still restricted by is_admin()-based RLS policies.
grant select, insert, update, delete on public.admin_notifications,
  public.admin_notification_recipients, public.qa_allowed_accounts to authenticated;
grant select on public.qa_reset_logs to authenticated;

-- Static catalogs and the rollout report are read-only through the Data API.
grant select on public.skill_categories, public.skills, public.industries,
  public.job_categories, public.job_roles, public.job_role_aliases,
  public.competency_skills, public.job_role_skills,
  public.legacy_role_mappings, public.legacy_role_mapping_coverage to authenticated;

-- Curated employer-search projection: authenticated SELECT only.
grant select on public.public_candidate_search to authenticated;

-- Push/admin notification QA is deferred. The owner-privileged view must not be
-- reachable by Candidate, Employer, or ordinary authenticated Data API clients.
revoke all privileges on public.admin_push_device_status
  from public, anon, authenticated;

-- Public bucket object URLs remain public because the bucket is public. Removing
-- this policy blocks anonymous Storage API listing of every object in the bucket.
drop policy if exists "kaam_public_read" on storage.objects;

-- Lock the three invoker helper paths reported by Security Advisor. Direct RPC
-- execution remains restricted according to the existing reviewed function ACLs.
alter function public.set_updated_at() set search_path = pg_catalog;
alter function public.candidate_profile_completed(public.candidate_profiles)
  set search_path = pg_catalog;
alter function public.kaam_normalize_catalog_text(text) set search_path = pg_catalog;
revoke all on function public.kaam_normalize_catalog_text(text) from public, anon;
grant execute on function public.kaam_normalize_catalog_text(text)
  to authenticated, service_role;

commit;
