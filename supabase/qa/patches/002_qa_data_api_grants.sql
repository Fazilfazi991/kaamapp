-- Explicit Data API grants for new-project defaults. RLS remains authoritative.
begin;

-- No public-schema application table is directly exposed to unauthenticated callers.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;

-- User-owned and workflow tables. Policies in the canonical sources restrict rows.
grant select, insert, update on public.profiles, public.candidate_profiles, public.employer_companies to authenticated;
grant select, insert, update, delete on public.employer_hiring_requirements, public.interest_requests,
  public.saved_candidates, public.verification_documents, public.candidate_documents,
  public.candidate_document_versions, public.candidate_skills, public.candidate_custom_skills,
  public.employer_candidate_views, public.employer_hiring_requirement_skills to authenticated;
grant select, insert, update on public.matches to authenticated;
grant select, insert on public.chat_messages to authenticated;
grant select on public.candidate_document_notifications, public.candidate_memberships,
  public.candidate_membership_payments to authenticated;
grant select, update on public.notifications to authenticated;
grant select, insert, update, delete on public.user_push_devices to authenticated;
grant select, insert, update on public.notification_preferences to authenticated;

-- Admin operations still require is_admin()-based RLS policies.
grant select, insert, update, delete on public.admin_notifications, public.admin_notification_recipients to authenticated;

-- Read-only static reference catalogs.
grant select on public.skill_categories, public.skills, public.industries, public.job_categories,
  public.job_roles, public.job_role_aliases, public.competency_skills, public.job_role_skills,
  public.legacy_role_mappings, public.legacy_role_mapping_coverage to authenticated;

-- QA reset metadata: ordinary users can read only their own log through RLS; allowlist management is admin-only.
grant select, insert, update, delete on public.qa_allowed_accounts to authenticated;
grant select on public.qa_reset_logs to authenticated;

-- Views are explicitly scoped. public_candidate_search is intentionally privileged and curated.
revoke all on public.public_candidate_search, public.admin_push_device_status from public, anon;
grant select on public.public_candidate_search, public.admin_push_device_status to authenticated;

-- Service role is the trusted backend role. The grant is broad but explicitly limited to named schemas;
-- service_role already bypasses RLS and is never exposed to public clients.
grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;

commit;
