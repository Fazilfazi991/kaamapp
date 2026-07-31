export type UserRole = "candidate" | "employer" | "admin";

export type ProfileRow = {
  id: string;
  role: UserRole;
  full_name: string | null;
  phone?: string | null;
  email: string | null;
  status: string;
};

export type CandidateProfileRow = {
  id: string;
  headline: string | null;
  gender?: string | null;
  nationality: string | null;
  current_country: string | null;
  current_city: string | null;
  preferred_country: string | null;
  preferred_city: string | null;
  job_categories: string[] | null;
  skills: string[] | null;
  languages: string[] | null;
  availability: string | null;
  experience_years?: number | null;
  expected_salary_min?: number | null;
  expected_salary_max?: number | null;
  currency?: string | null;
  visa_status?: string | null;
  profile_photo_url?: string | null;
  resume_url?: string | null;
  bio?: string | null;
  is_visible?: boolean | null;
  hide_phone_before_match?: boolean | null;
  hide_email_before_match?: boolean | null;
  require_approval_before_chat?: boolean | null;
  allow_document_sharing_after_match?: boolean | null;
  is_verified: boolean | null;
};

export type SkillCategoryRow = {
  id: string;
  name: string;
  slug?: string | null;
  icon_name?: string | null;
};

export type SkillRow = {
  id: string;
  category_id: string;
  name: string;
  slug?: string | null;
};

export type CandidateSkillRow = {
  skill_id: string;
  is_primary: boolean | null;
  experience_range: string | null;
  skill_level: string | null;
  availability: string | null;
  skills: SkillRow & { skill_categories?: SkillCategoryRow | null };
};

export type CandidateMembershipRow = {
  status: string | null;
  plan_code: string | null;
  starts_at: string | null;
  expires_at: string | null;
};

export type EmployerCompanyRow = {
  id: string;
  company_name: string;
  industry: string | null;
  country: string | null;
  city: string | null;
  is_verified: boolean | null;
  status: string;
};

export type AccountContext = {
  userId: string;
  email: string | null;
  role: UserRole;
  profileStatus: string;
  hasCandidateProfile: boolean;
  hasEmployerProfile: boolean;
  candidatePhotoPath?: string | null;
};
