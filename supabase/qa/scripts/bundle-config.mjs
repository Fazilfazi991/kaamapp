export const productionRef = "bhuhojzqxnvwbsypijac";
export const qaRef = "skswbbcimwvwmuiapjnd";
export const qaUrl = `https://${qaRef}.supabase.co`;

export const sources = [
  "001_kaam_initial_schema.sql", "002_mvp_functionality_patch.sql",
  "003_candidate_privacy_settings.sql", "004_employer_hiring_requirements.sql",
  "005_candidate_identity_documents.sql", "006_candidate_document_phase2.sql",
  "008_candidate_document_versions_repair.sql", "009_skill_categories_and_candidate_skills.sql",
  "010_identity_document_save_repair.sql", "011_candidate_membership_visibility.sql",
  "012_employer_match_contact_rules.sql", "013_notification_foundation.sql",
  "013_admin_notifications.sql", "014_admin_broadcast_push_types.sql",
  "015_admin_notification_delivery_status.sql", "017_fix_employer_company_status_triggers.sql",
  "018_bootstrap_user_profile.sql", "019_passport_front_back_documents.sql",
  "020_candidate_qa_batch_1_profile_fields.sql", "migrations/021_matching_chat_qa_batch_1.sql",
  "migrations/022_employer_saved_recently_viewed.sql", "migrations/023_candidate_profile_photo_employer_read.sql",
  "migrations/20260731000400_candidate_profile_visa_expiry.sql",
  "migrations/20260807151913_role_skills_taxonomy_phase_1_catalog.sql",
  "migrations/20260807160918_employer_taxonomy_dual_write_phase_2a.sql",
  "migrations/20260816000100_candidate_profile_email_privacy_repair.sql",
  "migrations/20260817031957_candidate_profile_phone_privacy_repair.sql",
  "migrations/20260817133058_stripe_candidate_membership_payments.sql",
  "migrations/20260817150126_employer_auto_activation.sql",
  "migrations/20260821120000_candidate_lifetime_membership.sql",
  "migrations/20260821120001_restrict_candidate_membership_function_access.sql",
  "007_qa_reset_tools.sql",
];

export const patches = ["qa/patches/001_qa_security_hardening.sql", "qa/patches/002_qa_data_api_grants.sql"];

export const excluded = [
  "deploy_019_020_candidate_qa_batch_1.sql", "016_scheduled_notifications.sql",
  "migrations/024_production_push_hardening.sql", "migrations/025_remote_app_config.sql",
  "migrations/20260731000100_candidate_manual_verification.sql",
  "migrations/20260731000200_candidate_verification_notifications.sql",
  "migrations/20260731000300_employer_candidate_manual_verification.sql",
  "migrations/20260801000100_identity_document_validation.sql",
  "migrations/20260801000200_candidate_document_review_notifications.sql",
  "migrations/20260822090000_visitor_analytics.sql",
];

export const duplicateGroups = [
  ["021_matching_chat_qa_batch_1.sql", "migrations/021_matching_chat_qa_batch_1.sql"],
  ["022_employer_saved_recently_viewed.sql", "migrations/022_employer_saved_recently_viewed.sql"],
  ["023_candidate_profile_photo_employer_read.sql", "migrations/023_candidate_profile_photo_employer_read.sql"],
  ["024_candidate_manual_verification.sql", "migrations/20260731000100_candidate_manual_verification.sql"],
  ["025_candidate_verification_notifications.sql", "migrations/20260731000200_candidate_verification_notifications.sql"],
  ["026_employer_candidate_manual_verification.sql", "migrations/20260731000300_employer_candidate_manual_verification.sql"],
  ["027_identity_document_validation.sql", "migrations/20260801000100_identity_document_validation.sql"],
  ["028_candidate_document_review_notifications.sql", "migrations/20260801000200_candidate_document_review_notifications.sql"],
];
