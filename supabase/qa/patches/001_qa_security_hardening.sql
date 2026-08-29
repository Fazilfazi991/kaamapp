-- QA-only least-privilege patch. Run after all 32 canonical sources.
begin;

-- Authenticated, current-user-scoped helpers/RPCs.
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
revoke all on function public.my_role() from public, anon;
grant execute on function public.my_role() to authenticated;
revoke all on function public.bootstrap_user_profile(text) from public, anon;
grant execute on function public.bootstrap_user_profile(text) to authenticated;
revoke all on function public.candidate_profile_completed(public.candidate_profiles) from public, anon;
grant execute on function public.candidate_profile_completed(public.candidate_profiles) to authenticated;
revoke all on function public.candidate_documents_verified(uuid) from public, anon;
grant execute on function public.candidate_documents_verified(uuid) to authenticated;
revoke all on function public.candidate_membership_active(uuid) from public, anon;
grant execute on function public.candidate_membership_active(uuid) to authenticated;
revoke all on function public.candidate_visible_to_employers(uuid) from public, anon;
grant execute on function public.candidate_visible_to_employers(uuid) to authenticated;
revoke all on function public.activate_test_candidate_membership() from public, anon;
grant execute on function public.activate_test_candidate_membership() to authenticated;
revoke all on function public.set_candidate_employer_visibility(boolean) from public, anon;
grant execute on function public.set_candidate_employer_visibility(boolean) to authenticated;
revoke all on function public.match_chat_enabled(uuid) from public, anon;
grant execute on function public.match_chat_enabled(uuid) to authenticated;
revoke all on function public.reveal_candidate_contact(uuid) from public, anon;
grant execute on function public.reveal_candidate_contact(uuid) to authenticated;
revoke all on function public.candidate_matches_with_access() from public, anon;
grant execute on function public.candidate_matches_with_access() to authenticated;
revoke all on function public.employer_matches_with_contact() from public, anon;
grant execute on function public.employer_matches_with_contact() to authenticated;
revoke all on function public.search_candidates_by_skills(text,text,boolean,text) from public, anon;
grant execute on function public.search_candidates_by_skills(text,text,boolean,text) to authenticated;
revoke all on function public.search_job_roles(text,integer) from public, anon;
grant execute on function public.search_job_roles(text,integer) to authenticated;

-- Mandatory QA reset restriction. Allowlist rows are populated later, never here.
revoke all on function public.qa_reset(text,text,text) from public, anon;
grant execute on function public.qa_reset(text,text,text) to authenticated;

-- Payment mutation is server-only. Schema presence does not authorize payment execution.
revoke all on function public.fulfill_stripe_candidate_membership_payment(uuid,text,text,text,text,timestamptz,boolean) from public, anon, authenticated;
grant execute on function public.fulfill_stripe_candidate_membership_payment(uuid,text,text,text,text,timestamptz,boolean) to service_role;
revoke all on function public.record_stripe_candidate_membership_payment_failure(uuid,text,text,text) from public, anon, authenticated;
grant execute on function public.record_stripe_candidate_membership_payment_failure(uuid,text,text,text) to service_role;

-- Internal notification creator and trigger routines are not direct Data API RPCs.
revoke all on function public.create_notification(uuid,text,text,text,text,jsonb,text,text,uuid) from public, anon, authenticated;
grant execute on function public.create_notification(uuid,text,text,text,text,jsonb,text,text,uuid) to service_role;
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.create_match_when_interest_accepted() from public, anon, authenticated;
revoke all on function public.block_interest_for_hidden_candidate() from public, anon, authenticated;
revoke all on function public.notify_interest_request_created() from public, anon, authenticated;
revoke all on function public.notify_interest_request_status() from public, anon, authenticated;
revoke all on function public.notify_match_created() from public, anon, authenticated;
revoke all on function public.notify_chat_message_created() from public, anon, authenticated;
revoke all on function public.notify_candidate_document_submitted() from public, anon, authenticated;
revoke all on function public.notify_candidate_document_reviewed() from public, anon, authenticated;
revoke all on function public.notify_verification_document_submitted() from public, anon, authenticated;
revoke all on function public.notify_employer_document_reviewed() from public, anon, authenticated;
revoke all on function public.notify_company_review_submitted() from public, anon, authenticated;
revoke all on function public.notify_company_reviewed() from public, anon, authenticated;

-- Curated privileged projection: authenticated employer-search API only.
revoke all on table public.public_candidate_search from public, anon;
grant select on table public.public_candidate_search to authenticated;

commit;
